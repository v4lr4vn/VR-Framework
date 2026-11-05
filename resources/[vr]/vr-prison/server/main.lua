Prison = { points = {}, stats = {}, outfits = {}, ready = false }
local P = Prison

local seen = {}
local seenSrc = {}
local active = {}
local cooldown = {}
local last = {}
local waiting = {}

local POINTS = [[CREATE TABLE IF NOT EXISTS `vr_prison_points` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(12) NOT NULL,
    `type` VARCHAR(24) NOT NULL DEFAULT '',
    `label` VARCHAR(48) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `w` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local STATS = [[CREATE TABLE IF NOT EXISTS `vr_prison_stats` (
    `cid` VARCHAR(64) NOT NULL,
    `since` INT UNSIGNED NOT NULL DEFAULT 0,
    `reduced` INT UNSIGNED NOT NULL DEFAULT 0,
    `credits` INT UNSIGNED NOT NULL DEFAULT 0,
    `cell` INT UNSIGNED DEFAULT NULL,
    `released` TINYINT(1) NOT NULL DEFAULT 0,
    `original` LONGTEXT DEFAULT NULL,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local OUTFITS = [[CREATE TABLE IF NOT EXISTS `vr_prison_outfits` (
    `gender` VARCHAR(8) NOT NULL,
    `data` LONGTEXT NOT NULL,
    PRIMARY KEY (`gender`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local COMPONENTS = { [1] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true }
local PROPS = { [0] = true, [1] = true, [2] = true, [6] = true, [7] = true }
P.COMPONENTS, P.PROPS = COMPONENTS, PROPS

function P.num(v)
    v = tonumber(v)
    if v and v == v and v ~= math.huge and v ~= -math.huge then return v end
    return nil
end

function P.onReady(fn)
    if P.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

function P.notify(src, text, kind)
    if src and src > 0 then Bridge.notify(src, text, kind or 'inform', nil, 'Prison') end
end

function P.throttle(src, key, ms)
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

function P.fail(code, data)
    return { ok = false, error = code, data = data }
end

local function mdt(fn, ...)
    local args = table.pack(...)
    local ok, res = pcall(function()
        return exports['vr-mdt'][fn](nil, table.unpack(args, 1, args.n))
    end)
    if not ok then return nil end
    return res
end
P.mdt = mdt

function P.admin(src)
    if not src or src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

-- Points -------------------------------------------------------------------

function P.view(pt)
    return { id = pt.id, kind = pt.kind, type = pt.type, label = pt.label, x = pt.x, y = pt.y, z = pt.z, w = pt.w }
end

function P.list()
    local out = {}
    for _, pt in pairs(P.points) do out[#out + 1] = P.view(pt) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function P.push(target)
    TriggerClientEvent('vr-prison:client:points', target or -1, P.list())
end

function P.save(pt)
    MySQL.update.await('UPDATE `vr_prison_points` SET `kind` = ?, `type` = ?, `label` = ?, `x` = ?, `y` = ?, `z` = ?, `w` = ? WHERE `id` = ?',
        { pt.kind, pt.type, pt.label, pt.x, pt.y, pt.z, pt.w, pt.id })
end

function P.create(kind, typ, label, pos)
    local id = MySQL.insert.await('INSERT INTO `vr_prison_points` (`kind`, `type`, `label`, `x`, `y`, `z`, `w`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { kind, typ or '', label, pos.x, pos.y, pos.z, pos.w or 0.0 })
    if not id then return nil end
    local pt = { id = id, kind = kind, type = typ or '', label = label, x = pos.x, y = pos.y, z = pos.z, w = pos.w or 0.0 }
    P.points[id] = pt
    return pt
end

function P.delete(pt)
    MySQL.update.await('DELETE FROM `vr_prison_points` WHERE `id` = ?', { pt.id })
    P.points[pt.id] = nil
end

function P.count(kind)
    local n = 0
    for _, pt in pairs(P.points) do if kind == nil or pt.kind == kind then n = n + 1 end end
    return n
end

-- Prisoner records ----------------------------------------------------------

local function saveStats(st)
    MySQL.update.await([[INSERT INTO `vr_prison_stats` (`cid`, `since`, `reduced`, `credits`, `cell`, `released`, `original`) VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE `since` = VALUES(`since`), `reduced` = VALUES(`reduced`), `credits` = VALUES(`credits`), `cell` = VALUES(`cell`),
        `released` = VALUES(`released`), `original` = VALUES(`original`)]],
        { st.cid, st.since, st.reduced, st.credits, st.cell or 0, st.released and 1 or 0, st.original or '' })
end
P.saveStats = saveStats

local function dropStats(cid)
    P.stats[cid] = nil
    MySQL.update.await('DELETE FROM `vr_prison_stats` WHERE `cid` = ?', { cid })
end

function P.player(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return p
end

-- The prisoner behind a source and what the MDT says about their sentence, or nil when they are free.
function P.inmate(src)
    local p = P.player(src)
    if not p then return nil end
    local status = mdt('PrisonStatus', p.cid)
    if not status then return nil end
    return p, status, P.stats[p.cid]
end

function P.capSeconds(status)
    local per = tonumber(status.secondsPerMonth) or 60
    local total = (tonumber(status.months) or 0) * per
    return math.max(0, math.floor(total * (Config.Cap.percent or 50) / 100))
end

function P.view_state(st, status)
    return {
        jailed = true,
        credits = st and st.credits or 0,
        reduced = st and st.reduced or 0,
        cap = status and P.capSeconds(status) or 0,
    }
end

function P.pushState(src)
    local p, status, st = P.inmate(src)
    if not p then return end
    TriggerClientEvent('vr-prison:client:state', src, P.view_state(st, status))
end

function P.outfitFor(gender)
    return P.outfits[gender] or Config.Outfits[gender]
end

function P.outfitsView()
    return { male = P.outfitFor('male'), female = P.outfitFor('female') }
end

function P.assignCell()
    if not Config.Cells.enabled then return nil end
    local counts = {}
    for _, st in pairs(P.stats) do
        if st.cell and not st.released then counts[st.cell] = (counts[st.cell] or 0) + 1 end
    end
    local ids = {}
    for id, pt in pairs(P.points) do
        if pt.kind == 'cell' then ids[#ids + 1] = id end
    end
    table.sort(ids)
    local best, bestN
    for _, id in ipairs(ids) do
        local n = counts[id] or 0
        if not bestN or n < bestN then best, bestN = id, n end
    end
    return best
end

local function cellPos(id)
    local pt = id and P.points[id]
    if not pt or pt.kind ~= 'cell' then return nil end
    return { x = pt.x, y = pt.y, z = pt.z, w = pt.w }
end

-- Called whenever the MDT says a sentence started, changed or ended. status is nil once the person is free.
function P.sync(cid, status, startup)
    if type(cid) ~= 'string' then return end
    local p = Bridge.playerByCid(cid)
    local src = p and p.source or nil
    if status then
        local st = P.stats[cid]
        local fresh = st == nil or st.since ~= status.since or st.released == true
        if fresh then
            st = { cid = cid, since = status.since, reduced = 0, credits = 0, cell = P.assignCell(), released = false, original = nil }
            P.stats[cid] = st
            saveStats(st)
        end
        if src and status.online then
            if fresh or not seen[cid] then
                seen[cid] = src
                seenSrc[src] = cid
                if st.cell and not cellPos(st.cell) then
                    st.cell = P.assignCell()
                    saveStats(st)
                end
                local info = mdt('PrisonInfo') or {}
                TriggerClientEvent('vr-prison:client:intake', src, {
                    capture = st.original == nil,
                    fresh = fresh,
                    move = not startup,
                    cell = cellPos(st.cell),
                    area = info.centre and { x = info.centre.x, y = info.centre.y, z = info.centre.z, r = info.radius } or nil,
                    outfits = P.outfitsView(),
                    state = P.view_state(st, status),
                })
            end
        else
            local old = seen[cid]
            seen[cid] = nil
            if old then seenSrc[old] = nil end
        end
        return
    end
    local st = P.stats[cid]
    local old = seen[cid]
    seen[cid] = nil
    if old then seenSrc[old] = nil end
    if not st then return end
    if src then
        TriggerClientEvent('vr-prison:client:release', src, st.original)
        dropStats(cid)
    else
        st.released = true
        saveStats(st)
    end
end

AddEventHandler('vr-mdt:server:prisonChanged', function(cid, status)
    if not P.ready then return end
    P.sync(cid, status, false)
end)

local function forget(src)
    src = tonumber(src)
    if not src then return end
    local cid = seenSrc[src]
    seenSrc[src] = nil
    if cid and seen[cid] == src then seen[cid] = nil end
    active[src] = nil
end

AddEventHandler('playerDropped', function() forget(source) end)
Bridge.on('playerUnloaded', function(src) forget(src) end)

Bridge.on('playerLoaded', function(src)
    src = tonumber(src)
    if not src then return end
    CreateThread(function()
        Wait(2500)
        P.onReady(function()
            local p = P.player(src)
            if not p then return end
            P.sync(p.cid, mdt('PrisonStatus', p.cid), false)
        end)
    end)
end)

RegisterNetEvent('vr-prison:server:original', function(snap)
    local src = source
    if P.throttle(src, 'original', 2000) then return end
    local p, _, st = P.inmate(src)
    if not p or not st or st.original ~= nil or type(snap) ~= 'table' then return end
    local out = { components = {}, props = {} }
    for _, c in ipairs(type(snap.components) == 'table' and snap.components or {}) do
        local id, d, t = P.num(c.id), P.num(c.d), P.num(c.t)
        if id and d and t and COMPONENTS[id] and d >= 0 and d < 3000 and t >= 0 and t < 300 and #out.components < 20 then
            out.components[#out.components + 1] = { id = id, d = math.floor(d), t = math.floor(t) }
        end
    end
    for _, c in ipairs(type(snap.props) == 'table' and snap.props or {}) do
        local id, d, t = P.num(c.id), P.num(c.d), P.num(c.t)
        if id and d and t and PROPS[id] and d >= -1 and d < 3000 and t >= 0 and t < 300 and #out.props < 20 then
            out.props[#out.props + 1] = { id = id, d = math.floor(d), t = math.floor(t) }
        end
    end
    st.original = json.encode(out)
    saveStats(st)
end)

-- Work ----------------------------------------------------------------------

local function near(src, pt, extra)
    local me = Bridge.coords(src)
    if not me then return false end
    local dx, dy, dz = pt.x - me.x, pt.y - me.y, pt.z - me.z
    local limit = (Config.Interact.distance or 2.0) + (extra or 3.0)
    return dx * dx + dy * dy + dz * dz <= limit * limit
end

local function token()
    return ('%x%x%x'):format(math.random(0, 0xffffff), math.random(0, 0xffffff), GetGameTimer())
end

lib.callback.register('vr-prison:me', function(src)
    local p, status, st = P.inmate(src)
    if not p then return { jailed = false } end
    local out = P.view_state(st, status)
    out.outfits = P.outfitsView()
    return out
end)

lib.callback.register('vr-prison:points', function()
    return P.list()
end)

lib.callback.register('vr-prison:start', function(src, id)
    if P.throttle(src, 'start', 800) then return P.fail('slow_down') end
    local p, status, st = P.inmate(src)
    if not p then return P.fail('not_inmate') end
    local pt = P.points[tonumber(id) or -1]
    local cfg = pt and pt.kind == 'station' and Config.Stations[pt.type]
    if not cfg then return P.fail('bad_request') end
    if not near(src, pt) then return P.fail('too_far') end
    st = st or P.stats[p.cid]
    if not st then return P.fail('not_ready') end
    local key = ('%s:%d'):format(p.cid, pt.id)
    local now = GetGameTimer() // 1000
    if cooldown[key] and cooldown[key] > now then return P.fail('cooldown', cooldown[key] - now) end
    if P.capSeconds(status) - st.reduced <= 0 then return P.fail('capped') end
    if (status.remaining or 0) <= (Config.Cap.keepSeconds or 60) then return P.fail('nearly_out') end
    local t = token()
    active[src] = { token = t, point = pt.id, started = GetGameTimer(), duration = cfg.duration }
    return { ok = true, data = { token = t, duration = cfg.duration } }
end)

lib.callback.register('vr-prison:cancel', function(src)
    active[src] = nil
    return true
end)

lib.callback.register('vr-prison:finish', function(src, tok, good)
    local a = active[src]
    active[src] = nil
    if not a or type(tok) ~= 'string' or a.token ~= tok then return P.fail('bad_request') end
    local p, status, st = P.inmate(src)
    local pt = P.points[a.point]
    local cfg = pt and Config.Stations[pt.type]
    if not p or not st or not pt or not cfg then return P.fail('not_inmate') end
    if GetGameTimer() - a.started < a.duration - 1500 then return P.fail('too_fast') end
    if not near(src, pt, 6.0) then return P.fail('too_far') end
    local key = ('%s:%d'):format(p.cid, pt.id)
    if good ~= true then
        cooldown[key] = GetGameTimer() // 1000 + math.max(10, math.floor((cfg.cooldown or 60) / 6))
        return P.fail('failed')
    end
    cooldown[key] = GetGameTimer() // 1000 + (cfg.cooldown or 60)
    local room = P.capSeconds(status) - st.reduced
    local want = math.min(math.floor((cfg.minutes or 0) * 60), math.max(0, room))
    local took = 0
    if want > 0 then
        took = tonumber(mdt('PrisonReduce', p.cid, want, Config.Cap.keepSeconds)) or 0
    end
    local credits = math.max(0, math.floor(cfg.credits or 0))
    st.reduced = st.reduced + took
    st.credits = st.credits + credits
    saveStats(st)
    P.pushState(src)
    return { ok = true, data = { seconds = took, credits = credits, total = st.credits } }
end)

-- Canteen -------------------------------------------------------------------

local function itemList()
    local out = {}
    for i, row in ipairs(Config.Canteen.items or {}) do
        local exists = true
        if Bridge.inventory and Bridge.inventory.itemExists then
            local ok, res = pcall(Bridge.inventory.itemExists, row.item)
            exists = ok and res == true
        end
        if exists then
            local label = row.label
            if not label and Bridge.inventory.label then
                local ok, res = pcall(Bridge.inventory.label, row.item)
                label = ok and res or nil
            end
            out[#out + 1] = { index = i, item = row.item, label = label or row.item, price = row.price, count = row.count or 1 }
        end
    end
    return out
end

lib.callback.register('vr-prison:canteen', function(src, id)
    local p, _, st = P.inmate(src)
    if not p then return P.fail('not_inmate') end
    local pt = P.points[tonumber(id) or -1]
    if not pt or pt.kind ~= 'canteen' or not near(src, pt) then return P.fail('too_far') end
    st = st or P.stats[p.cid]
    return { ok = true, data = { items = itemList(), credits = st and st.credits or 0, label = pt.label } }
end)

lib.callback.register('vr-prison:buy', function(src, id, index)
    if P.throttle(src, 'buy', 700) then return P.fail('slow_down') end
    local p, _, st = P.inmate(src)
    if not p then return P.fail('not_inmate') end
    local pt = P.points[tonumber(id) or -1]
    if not pt or pt.kind ~= 'canteen' or not near(src, pt) then return P.fail('too_far') end
    st = st or P.stats[p.cid]
    local row = Config.Canteen.items[tonumber(index) or -1]
    if not st or not row then return P.fail('bad_request') end
    local allowed = false
    for _, r in ipairs(itemList()) do
        if r.item == row.item then allowed = true end
    end
    if not allowed then return P.fail('not_sold') end
    local price = math.max(0, math.floor(row.price or 0))
    local count = row.count or 1
    if st.credits < price then return P.fail('no_credit') end
    local carry = true
    if Bridge.inventory.canCarry then
        local ok, res = pcall(Bridge.inventory.canCarry, src, row.item, count)
        carry = ok and res ~= false
    end
    if not carry then return P.fail('full') end
    local ok, res = pcall(Bridge.inventory.add, src, row.item, count)
    if not ok or not res then return P.fail('full') end
    st.credits = st.credits - price
    saveStats(st)
    P.pushState(src)
    return { ok = true, data = { credits = st.credits, item = row.item } }
end)

-- Exports -------------------------------------------------------------------

exports('IsInmate', function(src)
    local p = P.inmate(src)
    return p ~= nil
end)

exports('GetCredits', function(cid)
    local st = P.stats[cid]
    return st and st.credits or 0
end)

exports('AddCredits', function(cid, amount)
    local st = P.stats[cid]
    amount = math.floor(P.num(amount) or 0)
    if not st or amount == 0 then return false end
    st.credits = math.max(0, st.credits + amount)
    saveStats(st)
    local p = Bridge.playerByCid(cid)
    if p and p.source then P.pushState(p.source) end
    return true
end)

-- Start up ------------------------------------------------------------------

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(POINTS)
        MySQL.query.await(STATS)
        MySQL.query.await(OUTFITS)
    end)
    if not ok then print(('^1[vr-prison] schema: %s^0'):format(tostring(err))) end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `vr_prison_points`') or {}) do
        P.points[r.id] = { id = r.id, kind = r.kind, type = r.type, label = r.label, x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, w = (r.w or 0) + 0.0 }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `vr_prison_stats`') or {}) do
        P.stats[r.cid] = {
            cid = r.cid, since = tonumber(r.since) or 0, reduced = tonumber(r.reduced) or 0, credits = tonumber(r.credits) or 0,
            cell = (tonumber(r.cell) or 0) > 0 and tonumber(r.cell) or nil, released = tonumber(r.released) == 1,
            original = (r.original ~= nil and r.original ~= '') and r.original or nil,
        }
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM `vr_prison_outfits`') or {}) do
        local good, data = pcall(json.decode, r.data)
        if good and type(data) == 'table' then P.outfits[r.gender] = data end
    end
    P.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)

-- People already inside when this resource starts or restarts.
CreateThread(function()
    while not P.ready do Wait(500) end
    Wait(3000)
    for _, s in ipairs(GetPlayers()) do
        local p = P.player(tonumber(s))
        if p then
            local status = mdt('PrisonStatus', p.cid)
            if status then P.sync(p.cid, status, true) end
        end
    end
end)
