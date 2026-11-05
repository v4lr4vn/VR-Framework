Biz = {}

local DAY = 86400

function Biz.type(id)
    for _, t in ipairs(Config.Business.types) do
        if t.id == id then return t end
    end
    return nil
end

local function statusOf(row, now)
    if row.status ~= 'active' then return row.status end
    if (tonumber(row.expires) or 0) <= now then return 'expired' end
    return 'active'
end

Biz.statusOf = statusOf

local function present(row, now)
    local t = Biz.type(row.type)
    local st = statusOf(row, now)
    local left = (tonumber(row.expires) or 0) - now
    local window = (tonumber(Config.Business.renewWindowDays) or 0) * DAY
    return {
        id = tonumber(row.id),
        number = row.number,
        type = row.type,
        typeLabel = t and t.label or row.type,
        icon = t and t.icon or 'fa-store',
        name = row.business,
        issued = tonumber(row.issued),
        expires = tonumber(row.expires),
        status = st,
        fee = t and t.fee or 0,
        renewable = t ~= nil and (st == 'expired' or (st == 'active' and left <= window)),
        note = row.note,
    }
end

Biz.present = present

function Biz.rows(cid)
    return MySQL.query.await('SELECT * FROM vr_business_licences WHERE citizenid = ? ORDER BY id', { cid }) or {}
end

function Biz.row(id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.single.await('SELECT * FROM vr_business_licences WHERE id = ? LIMIT 1', { id })
end

function Biz.byNumber(number)
    if type(number) ~= 'string' then return nil end
    return MySQL.single.await('SELECT * FROM vr_business_licences WHERE number = ? LIMIT 1', { number:upper() })
end

function Biz.list(cid)
    local now = os.time()
    local out = {}
    for _, r in ipairs(Biz.rows(cid)) do
        if r.status ~= 'surrendered' then out[#out + 1] = present(r, now) end
    end
    return out
end

function Biz.activeCount(cid, exceptId)
    local now = os.time()
    local n = 0
    for _, r in ipairs(Biz.rows(cid)) do
        if statusOf(r, now) == 'active' and tonumber(r.id) ~= tonumber(exceptId) then n = n + 1 end
    end
    return n
end

function Biz.nameTaken(key, exceptId)
    local row = MySQL.single.await(
        "SELECT id FROM vr_business_licences WHERE business_key = ? AND status = 'active' AND expires > ? AND id <> ? LIMIT 1",
        { key, os.time(), tonumber(exceptId) or 0 })
    return row ~= nil
end

function Biz.syncFlag(cid)
    local now = os.time()
    local any = false
    for _, r in ipairs(Biz.rows(cid)) do
        if statusOf(r, now) == 'active' then any = true break end
    end
    Core.setLicence(cid, 'business', any)
    return any
end

function Biz.hasActive(cid, typeId)
    local now = os.time()
    for _, r in ipairs(Biz.rows(cid)) do
        if statusOf(r, now) == 'active' and (typeId == nil or r.type == typeId) then return true end
    end
    return false
end

local function numberFor(id)
    return ('%s%06d'):format(Config.Business.numberPrefix or 'BL-', tonumber(id))
end

function Biz.giveItem(info, row)
    local item = Config.Business.item
    if not item or item == '' or not Core.itemExists(item) then return false end
    local t = Biz.type(row.type)
    local meta = {
        number = row.number,
        business = row.business,
        type = t and t.label or row.type,
        holder = row.holder,
        description = ('%s | %s | %s'):format(row.business, t and t.label or row.type, row.number),
    }
    return Bridge.inventory.add(info.src, item, 1, meta) == true
end

local function carrying(info, number)
    local item = Config.Business.item
    if not item or item == '' then return false end
    local ok, found = pcall(Bridge.inventory.search, info.src, item)
    if ok and type(found) == 'table' then
        for _, s in ipairs(found) do
            local md = s.metadata or {}
            if md.number == number then return true end
        end
        return false
    end
    return Core.countItem(info.src, item) > 0
end

local function nameCheck(raw)
    local name = CU.clean(raw, Config.Business.nameMax)
    if not name or #name < Config.Business.nameMin then return nil, 'bad_name' end
    local key = CU.key(name)
    if #key < 2 then return nil, 'bad_name' end
    return name, nil, key
end

function Biz.create(info, typeId, rawName, opts)
    opts = opts or {}
    local cfg = Config.Business
    if not cfg.enabled then return false, 'disabled' end
    local t = type(typeId) == 'string' and Biz.type(typeId) or nil
    if not t then return false, 'bad_request' end
    local name, err, key = nameCheck(rawName)
    if not name then return false, err end
    if not opts.force and Biz.activeCount(info.cid) >= cfg.maxPerPlayer then return false, 'limit' end
    if Biz.nameTaken(key) then return false, 'name_taken' end
    local fee = opts.free and 0 or t.fee
    if not Core.charge(info.src, fee, ('City Hall: %s licence'):format(t.label)) then return false, 'no_money' end
    local now = os.time()
    local days = tonumber(opts.days) or t.days
    local id = MySQL.insert.await(
        'INSERT INTO vr_business_licences (citizenid, holder, type, business, business_key, status, issued, expires) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { info.cid, info.name, t.id, name, key, 'active', now, now + days * DAY })
    if not id then
        Core.refund(info.src, fee, 'City Hall: refund licence')
        return false, 'failed'
    end
    local number = numberFor(id)
    MySQL.update.await('UPDATE vr_business_licences SET number = ? WHERE id = ?', { number, id })
    local row = Biz.row(id)
    Biz.giveItem(info, row)
    Biz.syncFlag(info.cid)
    TriggerEvent('vr-cityhall:server:licenceIssued', info.src, info.cid, number, t.id, name)
    return true, nil, present(row, now)
end

function Biz.renew(info, id)
    local row = Biz.row(id)
    if not row or row.citizenid ~= info.cid then return false, 'not_found' end
    local now = os.time()
    local st = statusOf(row, now)
    if st == 'revoked' then return false, 'revoked' end
    if st == 'surrendered' then return false, 'not_found' end
    local t = Biz.type(row.type)
    if not t then return false, 'no_such_type' end
    local p = present(row, now)
    if not p.renewable then return false, 'too_early' end
    if st == 'expired' then
        if Biz.activeCount(info.cid, row.id) >= Config.Business.maxPerPlayer then return false, 'limit' end
        if Biz.nameTaken(row.business_key, row.id) then return false, 'name_taken' end
    end
    if not Core.charge(info.src, t.fee, ('City Hall: renew %s'):format(row.number)) then return false, 'no_money' end
    local base = math.max(tonumber(row.expires) or 0, now)
    MySQL.update.await("UPDATE vr_business_licences SET expires = ?, status = 'active' WHERE id = ?", { base + t.days * DAY, row.id })
    Biz.syncFlag(info.cid)
    return true, nil, present(Biz.row(row.id), now)
end

function Biz.surrender(info, id)
    local row = Biz.row(id)
    if not row or row.citizenid ~= info.cid then return false, 'not_found' end
    local now = os.time()
    local st = statusOf(row, now)
    if st == 'revoked' then return false, 'revoked' end
    if st == 'surrendered' then return false, 'not_found' end
    local refund = 0
    local t = Biz.type(row.type)
    if st == 'active' and t and (tonumber(Config.Business.refundPercent) or 0) > 0 then
        refund = math.floor(t.fee * Config.Business.refundPercent / 100)
    end
    MySQL.update.await("UPDATE vr_business_licences SET status = 'surrendered' WHERE id = ?", { row.id })
    if refund > 0 then Core.refund(info.src, refund, ('City Hall: surrendered %s'):format(row.number)) end
    Biz.syncFlag(info.cid)
    TriggerEvent('vr-cityhall:server:licenceEnded', row.citizenid, row.number, 'surrendered')
    return true, nil, { number = row.number, refund = refund }
end

function Biz.reprint(info, id)
    local row = Biz.row(id)
    if not row or row.citizenid ~= info.cid then return false, 'not_found' end
    local now = os.time()
    if statusOf(row, now) ~= 'active' then return false, 'not_active' end
    if carrying(info, row.number) then return false, 'carrying' end
    local item = Config.Business.item
    if not item or item == '' or not Core.itemExists(item) then return false, 'failed' end
    local okCarry, can = pcall(Bridge.inventory.canCarry, info.src, item, 1)
    if okCarry and can == false then return false, 'no_room' end
    if not Core.charge(info.src, Config.Business.reprintFee, ('City Hall: replacement certificate %s'):format(row.number)) then return false, 'no_money' end
    if not Biz.giveItem(info, row) then
        Core.refund(info.src, Config.Business.reprintFee, 'City Hall: refund certificate')
        return false, 'failed'
    end
    return true, nil, { number = row.number, fee = Config.Business.reprintFee }
end

function Biz.revoke(number, note)
    local row = Biz.byNumber(number)
    if not row then return false, 'not_found' end
    if row.status == 'revoked' then return false, 'already' end
    MySQL.update.await("UPDATE vr_business_licences SET status = 'revoked', note = ? WHERE id = ?", { CU.clean(note, 160), row.id })
    Biz.syncFlag(row.citizenid)
    local src = Bridge.source(row.citizenid)
    if src then Core.notify(src, ('Your business licence %s for %s has been revoked'):format(row.number, row.business), 'error') end
    TriggerEvent('vr-cityhall:server:licenceEnded', row.citizenid, row.number, 'revoked')
    return true, nil, row
end

function Biz.reinstate(number)
    local row = Biz.byNumber(number)
    if not row then return false, 'not_found' end
    if row.status == 'active' then return false, 'already' end
    if Biz.nameTaken(row.business_key, row.id) then return false, 'name_taken' end
    MySQL.update.await("UPDATE vr_business_licences SET status = 'active', note = NULL WHERE id = ?", { row.id })
    Biz.syncFlag(row.citizenid)
    local src = Bridge.source(row.citizenid)
    if src then Core.notify(src, ('Your business licence %s for %s is valid again'):format(row.number, row.business), 'success') end
    return true, nil, row
end

function Biz.remind(src)
    local info = Core.info(src)
    if not info then return end
    local now = os.time()
    local soon, gone = 0, 0
    for _, r in ipairs(Biz.rows(info.cid)) do
        local st = statusOf(r, now)
        if st == 'expired' then gone = gone + 1
        elseif st == 'active' and (tonumber(r.expires) or 0) - now <= 3 * DAY then soon = soon + 1 end
    end
    if gone > 0 then
        Core.notify(src, gone == 1 and 'A business licence of yours has expired. Renew it at City Hall.' or ('%d business licences of yours have expired. Renew them at City Hall.'):format(gone), 'error')
    elseif soon > 0 then
        Core.notify(src, soon == 1 and 'A business licence of yours expires soon.' or ('%d business licences of yours expire soon.'):format(soon), 'inform')
    end
end
