Copies = {}

local ALPHA = '0123456789ABCDEFGHJKLMNPQRSTUVWXYZ'

local function token(n)
    local t = {}
    for i = 1, n do
        local k = math.random(1, #ALPHA)
        t[i] = ALPHA:sub(k, k)
    end
    return table.concat(t)
end

local function subgrade()
    return tonumber(CU.pick(Config.Grading.subgrades)) or 8
end

function Copies.gradeOf(c)
    local s = { c.centering, c.corners, c.edges, c.surface }
    local sum, low = 0, 10
    for _, v in ipairs(s) do
        sum = sum + v
        if v < low then low = v end
    end
    return math.max(1, math.min(10, math.floor(sum / 4 + 0.25), low + 1))
end

local function nextSerial(card)
    MySQL.update.await('INSERT INTO vr_cards_prints (card, n) VALUES (?, 1) ON DUPLICATE KEY UPDATE n = n + 1', { card })
    return tonumber(MySQL.scalar.await('SELECT n FROM vr_cards_prints WHERE card = ?', { card })) or 1
end

function Copies.create(cardId, foil, cid, state)
    local card = Catalog.get(cardId)
    if not card then return nil end
    foil = Config.Foils.labels[foil] and foil or 'none'
    local c = {
        uid = token(10), card = card.id, foil = foil, serial = nextSerial(card.id),
        centering = subgrade(), corners = subgrade(), edges = subgrade(), surface = subgrade(),
        state = state or 'item', holder = cid, pulled_by = cid, created = os.time(),
    }
    for _ = 1, 5 do
        local n = MySQL.update.await('INSERT IGNORE INTO vr_cards_copies (uid, card, foil, serial, centering, corners, edges, surface, state, holder, pulled_by, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
            c.uid, c.card, c.foil, c.serial, c.centering, c.corners, c.edges, c.surface, c.state, c.holder, c.pulled_by, c.created,
        })
        if (tonumber(n) or 0) > 0 then return c end
        c.uid = token(10)
    end
    return nil
end

function Copies.get(uid)
    if type(uid) ~= 'string' then return nil end
    local r = MySQL.single.await('SELECT * FROM vr_cards_copies WHERE uid = ?', { uid })
    if not r then return nil end
    for _, k in ipairs({ 'serial', 'centering', 'corners', 'edges', 'surface', 'grade', 'created' }) do r[k] = tonumber(r[k]) end
    return r
end

function Copies.many(uids)
    local out = {}
    if #uids == 0 then return out end
    local marks = {}
    for i = 1, #uids do marks[i] = '?' end
    local rows = MySQL.query.await(('SELECT * FROM vr_cards_copies WHERE uid IN (%s)'):format(table.concat(marks, ',')), uids) or {}
    for _, r in ipairs(rows) do
        for _, k in ipairs({ 'serial', 'centering', 'corners', 'edges', 'surface', 'grade', 'created' }) do r[k] = tonumber(r[k]) end
        out[r.uid] = r
    end
    return out
end

function Copies.set(uid, fields)
    local sets, params = {}, {}
    for k, v in pairs(fields) do
        sets[#sets + 1] = ('`%s` = ?'):format(k)
        params[#params + 1] = v
    end
    params[#params + 1] = uid
    MySQL.update.await(('UPDATE vr_cards_copies SET %s WHERE uid = ?'):format(table.concat(sets, ', ')), params)
end

function Copies.price(c)
    local card = Catalog.get(c.card)
    if not card then return 0 end
    local base = Config.Rarities[card.rarity].sell or 0
    local mult = (Config.Foils.sell[c.foil] or 1.0) * (c.grade and Config.Grading.sell[c.grade] or 1.0)
    return math.floor(base * mult)
end

function Copies.view(c)
    local card = Catalog.get(c.card)
    if not card then return nil end
    local v = Catalog.view(card)
    v.uid = c.uid
    v.foil = c.foil
    v.serial = c.serial
    v.price = Copies.price(c)
    if c.grade then
        v.grade = c.grade
        v.cert = c.cert
        v.sub = { centering = c.centering, corners = c.corners, edges = c.edges, surface = c.surface }
    end
    return v
end

function Copies.meta(c)
    local card = Catalog.get(c.card)
    local set = Cards.Sets[card.set]
    local foil = c.foil ~= 'none' and (' (%s)'):format(Config.Foils.labels[c.foil]) or ''
    local graded = c.grade and (' · %s %d %s'):format(Config.Grading.company, c.grade, Config.Grading.names[c.grade] or '') or ''
    return {
        uid = c.uid,
        card = c.card,
        foil = c.foil,
        grade = c.grade,
        cert = c.cert,
        label = c.grade and ('%s %d %s'):format(Config.Grading.company, c.grade, card.name) or (card.name .. foil),
        description = ('%s · %s %03d/%03d · Print #%d%s%s'):format(Config.Rarities[card.rarity].label, set.code, card.number, Catalog.totals[card.set] or 0, c.serial, c.grade and foil or '', graded),
        image = c.grade and 'tcg_slab' or ('tcg_' .. card.rarity),
    }
end

function Copies.give(src, c, cid)
    if not Core.addItem(src, Config.Items.card, 1, Copies.meta(c)) then return false end
    Copies.set(c.uid, { state = 'item', holder = cid })
    return true
end

function Copies.inHand(src)
    local out = {}
    local list = Core.slots(src, Config.Items.card)
    local uids, bySlot = {}, {}
    for _, it in ipairs(list) do
        local uid = type(it.metadata) == 'table' and it.metadata.uid
        if type(uid) == 'string' then
            uids[#uids + 1] = uid
            bySlot[uid] = it.slot
        end
    end
    local rows = Copies.many(uids)
    for _, uid in ipairs(uids) do
        local r = rows[uid]
        if r and r.state == 'item' then
            local v = Copies.view(r)
            if v then
                v.slot = bySlot[uid]
                out[#out + 1] = v
            end
        end
    end
    return out
end

function Copies.take(src, uid)
    local found = Core.slots(src, Config.Items.card, { uid = uid })[1]
    if not found then return nil, 'no_card' end
    local c = Copies.get(uid)
    if not c or c.state ~= 'item' then return nil, 'no_card' end
    if not Core.removeSlot(src, Config.Items.card, found.slot, 1) then return nil, 'no_card' end
    return c
end

function Copies.markDex(cid, cardId)
    local r = MySQL.update.await('INSERT IGNORE INTO vr_cards_dex (citizenid, card, first_at) VALUES (?, ?, ?)', { cid, cardId, os.time() })
    return (tonumber(r) or 0) > 0
end
