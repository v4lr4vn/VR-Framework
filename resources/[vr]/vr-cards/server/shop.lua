Shop = { coords = nil }

local G = Config.Grading

function Shop.load()
    local raw = MySQL.scalar.await("SELECT value FROM vr_cards_settings WHERE `key` = 'shop'")
    local ok, d = pcall(json.decode, raw or '')
    local c = Config.Shop.coords
    if ok and type(d) == 'table' and tonumber(d.x) then c = vec4(d.x + 0.0, d.y + 0.0, d.z + 0.0, (d.w or 0) + 0.0) end
    Shop.coords = c
    GlobalState.vrCardShop = { x = c.x, y = c.y, z = c.z, w = c.w, label = Config.Shop.label }
end

function Shop.move(c)
    MySQL.query.await("INSERT INTO vr_cards_settings (`key`, value) VALUES ('shop', ?) ON DUPLICATE KEY UPDATE value = VALUES(value)", { json.encode({ x = c.x, y = c.y, z = c.z, w = c.w }) })
    Shop.load()
end

function Shop.near(src)
    local pos = Core.coords(src)
    local c = Shop.coords
    if not pos or not c then return false end
    return #(pos - vec3(c.x, c.y, c.z)) <= Config.Shop.radius + 2.0
end

local function method(m)
    return m == 'cash' and 'cash' or 'bank'
end

function Shop.submissions(cid)
    local rows = MySQL.query.await('SELECT id, uid, tier, submitted, ready_at FROM vr_cards_grading WHERE citizenid = ? AND collected = 0 ORDER BY id', { cid }) or {}
    local uids = {}
    for _, r in ipairs(rows) do uids[#uids + 1] = r.uid end
    local copies = Copies.many(uids)
    local now, out = os.time(), {}
    for _, r in ipairs(rows) do
        local c = copies[r.uid]
        local v = c and Copies.view(c)
        if v then
            local ready = tonumber(r.ready_at) or 0
            out[#out + 1] = { id = tonumber(r.id), card = v, tier = r.tier, readyIn = math.max(0, ready - now), ready = ready <= now }
        end
    end
    return out
end

function Shop.unclaimed(cid)
    return tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM vr_cards_copies WHERE state = 'unclaimed' AND holder = ?", { cid })) or 0
end

function Shop.data(info)
    local packs = {}
    for id, p in pairs(Config.Packs) do
        local set = Cards.Sets[p.set]
        packs[#packs + 1] = { id = id, label = p.label, price = p.price, cards = #p.slots, set = set and set.label, code = set and set.code }
    end
    table.sort(packs, function(a, b) return a.price < b.price end)
    local tiers = {}
    for id, t in pairs(G.tiers) do tiers[#tiers + 1] = { id = id, label = t.label, fee = t.fee, minutes = t.minutes } end
    table.sort(tiers, function(a, b) return a.fee < b.fee end)
    return {
        label = Config.Shop.label,
        packs = packs,
        binder = { price = Config.Binder.price, capacity = Config.Binder.pages * Config.Binder.perPage },
        hand = Copies.inHand(info.src),
        grading = { tiers = tiers, max = G.maxPerSubmit, submissions = Shop.submissions(info.cid) },
        sell = Config.Sell.enabled,
        unclaimed = Shop.unclaimed(info.cid),
        me = { cash = Core.money(info.src, 'cash'), bank = Core.money(info.src, 'bank') },
        meta = Catalog.meta(),
    }
end

function Shop.buyPack(info, id, count, m)
    local p = Packs.def(id)
    if not p then return false, 'bad_pack' end
    count = math.floor(tonumber(count) or 1)
    if count < 1 or count > 10 then return false, 'bad_count' end
    if not Core.canCarry(info.src, Config.Items.pack, count) then return false, 'no_room' end
    local total = p.price * count
    m = method(m)
    if not Core.take(info.src, total, m, 'card-packs') then return false, 'no_money' end
    local ok = Packs.give(info.src, id, count)
    if not ok then
        Core.give(info.src, total, m, 'card-packs-refund')
        return false, 'no_room'
    end
    return true, { count = count, total = total }
end

function Shop.buyBinder(info, m)
    if not Core.canCarry(info.src, Config.Items.binder, 1) then return false, 'no_room' end
    m = method(m)
    if not Core.take(info.src, Config.Binder.price, m, 'card-binder') then return false, 'no_money' end
    local id = Binders.create(info, ('%s\'s Binder'):format((info.name or 'My'):match('^(%S+)') or 'My'))
    local row = Binders.row(id)
    if not id or not Core.addItem(info.src, Config.Items.binder, 1, Binders.meta(id, row and row.title)) then
        Core.give(info.src, Config.Binder.price, m, 'card-binder-refund')
        return false, 'no_room'
    end
    return true, { id = id }
end

local function uidList(uids, max)
    if type(uids) ~= 'table' then return nil end
    local out, seen = {}, {}
    for _, u in ipairs(uids) do
        if type(u) == 'string' and not seen[u] then
            seen[u] = true
            out[#out + 1] = u
        end
    end
    if #out == 0 or #out > max then return nil end
    return out
end

function Shop.sell(info, uids, m)
    if not Config.Sell.enabled then return false, 'disabled' end
    uids = uidList(uids, Config.Sell.maxPerSale)
    if not uids then return false, 'bad_cards' end
    local total, sold = 0, 0
    for _, uid in ipairs(uids) do
        local c = Copies.take(info.src, uid)
        if c then
            total = total + Copies.price(c)
            sold = sold + 1
            Copies.set(uid, { state = 'sold', holder = nil })
        end
    end
    if sold == 0 then return false, 'no_card' end
    Core.give(info.src, total, method(m), 'card-sale')
    return true, { sold = sold, total = total }
end

function Shop.grade(info, uids, tierId, m)
    local tier = G.tiers[tierId]
    if not tier then return false, 'bad_tier' end
    uids = uidList(uids, G.maxPerSubmit)
    if not uids then return false, 'bad_cards' end
    local rows = Copies.many(uids)
    for _, uid in ipairs(uids) do
        local c = rows[uid]
        if not c or c.state ~= 'item' then return false, 'no_card' end
        if c.grade then return false, 'already_graded' end
        if not Core.slots(info.src, Config.Items.card, { uid = uid })[1] then return false, 'no_card' end
    end
    local fee = tier.fee * #uids
    m = method(m)
    if not Core.take(info.src, fee, m, 'card-grading') then return false, 'no_money' end
    local now = os.time()
    local done = 0
    for _, uid in ipairs(uids) do
        if Copies.take(info.src, uid) then
            Copies.set(uid, { state = 'grading', holder = info.cid })
            MySQL.insert.await('INSERT INTO vr_cards_grading (uid, citizenid, tier, fee, submitted, ready_at) VALUES (?, ?, ?, ?, ?, ?)', { uid, info.cid, tierId, tier.fee, now, now + tier.minutes * 60 })
            done = done + 1
        end
    end
    if done < #uids then Core.give(info.src, tier.fee * (#uids - done), m, 'card-grading-refund') end
    return true, { submitted = done, fee = tier.fee * done, minutes = tier.minutes }
end

local CERT = '0123456789'

local function cert()
    local t = {}
    for i = 1, 8 do
        local k = math.random(1, 10)
        t[i] = CERT:sub(k, k)
    end
    return table.concat(t)
end

function Shop.collect(info)
    local rows = MySQL.query.await('SELECT id, uid FROM vr_cards_grading WHERE citizenid = ? AND collected = 0 AND ready_at <= ? ORDER BY id', { info.cid, os.time() }) or {}
    local claimed = MySQL.query.await("SELECT uid FROM vr_cards_copies WHERE state = 'unclaimed' AND holder = ?", { info.cid }) or {}
    if #rows == 0 and #claimed == 0 then return false, 'nothing_ready' end
    local graded, given = {}, 0
    for _, r in ipairs(rows) do
        if not Core.canCarry(info.src, Config.Items.card, 1) then break end
        local c = Copies.get(r.uid)
        if c then
            if not c.grade then
                c.grade = Copies.gradeOf(c)
                c.cert = cert()
                Copies.set(c.uid, { grade = c.grade, cert = c.cert })
            end
            if Copies.give(info.src, c, info.cid) then
                MySQL.update.await('UPDATE vr_cards_grading SET collected = 1 WHERE id = ?', { r.id })
                graded[#graded + 1] = Copies.view(c)
                given = given + 1
            end
        end
    end
    for _, r in ipairs(claimed) do
        if not Core.canCarry(info.src, Config.Items.card, 1) then break end
        local c = Copies.get(r.uid)
        if c and Copies.give(info.src, c, info.cid) then given = given + 1 end
    end
    if given == 0 then return false, 'no_room' end
    return true, { graded = graded, given = given }
end

function Shop.readyTick()
    local rows = MySQL.query.await('SELECT id, citizenid FROM vr_cards_grading WHERE collected = 0 AND notified = 0 AND ready_at <= ?', { os.time() }) or {}
    if #rows == 0 then return end
    local byCid = {}
    for _, r in ipairs(rows) do byCid[r.citizenid] = (byCid[r.citizenid] or 0) + 1 end
    local told = {}
    for _, id in ipairs(GetPlayers()) do
        local info = Core.info(id)
        local n = info and byCid[info.cid]
        if n then
            told[info.cid] = true
            Core.notify(info.src, ('%d graded card%s ready to collect at the card shop'):format(n, n == 1 and ' is' or 's are'), 'success')
        end
    end
    for _, r in ipairs(rows) do
        if told[r.citizenid] then MySQL.update.await('UPDATE vr_cards_grading SET notified = 1 WHERE id = ?', { r.id }) end
    end
end
