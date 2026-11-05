Gather = { points = {}, ready = false }
local G = Gather
local RES = GetCurrentResourceName()

local active, nodeUntil, playerUntil, last, waiting = {}, {}, {}, {}, {}

local function now() return GetGameTimer() // 1000 end
local function name(n) return RES .. ':' .. n end
G.name = name

function G.num(v)
    v = tonumber(v)
    if v and v == v and v ~= math.huge and v ~= -math.huge then return v end
    return nil
end

function G.onReady(fn)
    if G.ready then CreateThread(fn) else waiting[#waiting + 1] = fn end
end

function G.notify(src, text, kind)
    if src and src > 0 then Bridge.notify(src, text, kind or 'inform', nil, Config.Title) end
end

function G.throttle(src, key, ms)
    local t = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and t - last[id] < ms then return true end
    last[id] = t
    return false
end

function G.fail(code, data)
    return { ok = false, error = code, data = data }
end

function G.admin(src)
    if not src or src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.AdminCommand)
end

function G.player(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return p
end

local TABLE = ([[CREATE TABLE IF NOT EXISTS `%s` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(24) NOT NULL,
    `label` VARCHAR(48) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `w` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]):format(Config.Table)

-- Points ---------------------------------------------------------------------------------

function G.view(pt)
    return { id = pt.id, kind = pt.kind, label = pt.label, x = pt.x, y = pt.y, z = pt.z, w = pt.w }
end

function G.list()
    local out = {}
    for _, pt in pairs(G.points) do out[#out + 1] = G.view(pt) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function G.push(target)
    TriggerClientEvent(name('client:points'), target or -1, G.list())
end

function G.save(pt)
    MySQL.update.await(('UPDATE `%s` SET `kind` = ?, `label` = ?, `x` = ?, `y` = ?, `z` = ?, `w` = ? WHERE `id` = ?'):format(Config.Table),
        { pt.kind, pt.label, pt.x, pt.y, pt.z, pt.w, pt.id })
end

function G.create(kind, label, pos)
    local id = MySQL.insert.await(('INSERT INTO `%s` (`kind`, `label`, `x`, `y`, `z`, `w`) VALUES (?, ?, ?, ?, ?, ?)'):format(Config.Table),
        { kind, label, pos.x, pos.y, pos.z, pos.w or 0.0 })
    if not id then return nil end
    local pt = { id = id, kind = kind, label = label, x = pos.x, y = pos.y, z = pos.z, w = pos.w or 0.0 }
    G.points[id] = pt
    return pt
end

function G.delete(pt)
    MySQL.update.await(('DELETE FROM `%s` WHERE `id` = ?'):format(Config.Table), { pt.id })
    G.points[pt.id] = nil
end

function G.count()
    local n = 0
    for _ in pairs(G.points) do n = n + 1 end
    return n
end

-- Helpers ---------------------------------------------------------------------------------

local inv = function() return Bridge.inventory end

local function have(src, item)
    local ok, n = pcall(inv().count, src, item)
    return ok and tonumber(n) or 0
end

local function itemLabel(item)
    local ok, label = pcall(inv().label, item)
    return ok and label or item
end

local function itemKnown(item)
    local ok, res = pcall(inv().itemExists, item)
    return ok and res == true
end

local function dist(src, x, y, z)
    local me = Bridge.coords(src)
    if not me then return nil end
    local dx, dy, dz = x - me.x, y - me.y, z - me.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- A placed point (number) or a prop the client is standing at (kind name + coords).
local function resolve(src, ref, at)
    local pt, kind, key
    if type(ref) == 'number' then
        pt = G.points[ref]
        if not pt then return nil end
        kind, key = pt.kind, 'p' .. pt.id
    elseif type(ref) == 'string' then
        local cfg = Config.Kinds[ref]
        if not cfg or not cfg.models or type(at) ~= 'table' then return nil end
        local x, y, z = G.num(at.x), G.num(at.y), G.num(at.z)
        if not (x and y and z) then return nil end
        pt = { x = x, y = y, z = z }
        kind = ref
        key = ('m:%s:%d:%d:%d'):format(ref, math.floor(x), math.floor(y), math.floor(z))
    else
        return nil
    end
    local cfg = Config.Kinds[kind]
    if not cfg then return nil end
    local d = dist(src, pt.x, pt.y, pt.z)
    if not d or d > (Config.Range or 4.0) then return nil, 'too_far' end
    return { key = key, kind = kind, pt = pt }, cfg
end

local function rollAmount(row)
    local lo = math.floor(row.min or 1)
    local hi = math.floor(row.max or lo)
    if hi < lo then hi = lo end
    return math.random(lo, hi)
end

-- cfg.pick = 'all': every row rolls on its own chance. 'one': one row wins, by weight (chance), rows with item = false are a miss.
local function roll(cfg)
    local out = {}
    local rows = cfg.yield or {}
    if cfg.pick == 'one' then
        local total = 0
        for _, r in ipairs(rows) do total = total + (r.chance or 0) end
        if total <= 0 then return out end
        local at, acc = math.random() * total, 0
        for _, r in ipairs(rows) do
            acc = acc + (r.chance or 0)
            if at <= acc then
                if r.item then out[#out + 1] = { item = r.item, count = rollAmount(r) } end
                break
            end
        end
    else
        for _, r in ipairs(rows) do
            if r.item and math.random() * 100 <= (r.chance or 100) then
                out[#out + 1] = { item = r.item, count = rollAmount(r) }
            end
        end
    end
    return out
end

local function give(src, list)
    local gained = {}
    for _, row in ipairs(list) do
        local carry = true
        local okc, res = pcall(inv().canCarry, src, row.item, row.count)
        carry = okc and res ~= false
        if carry then
            local oka, added = pcall(inv().add, src, row.item, row.count)
            if oka and added then gained[#gained + 1] = { item = row.item, label = itemLabel(row.item), count = row.count } end
        end
    end
    return gained
end

local function firstTool(src, cfg)
    if not cfg.tools then return true end
    for _, item in ipairs(cfg.tools) do
        if have(src, item) > 0 then return item end
    end
    return nil
end

local function missingTakes(src, takes)
    for item, count in pairs(takes or {}) do
        if have(src, item) < count then return item end
    end
    return nil
end

local function removeTakes(src, takes)
    for item, count in pairs(takes or {}) do
        local ok, done = pcall(inv().remove, src, item, count)
        if not ok or not done then return false end
    end
    return true
end

local function token()
    return ('%x%x%x'):format(math.random(0, 0xffffff), math.random(0, 0xffffff), GetGameTimer())
end

-- Callbacks ---------------------------------------------------------------------------------

lib.callback.register(name('points'), function() return G.list() end)

lib.callback.register(name('recipes'), function(src, ref, at)
    local r, cfg = resolve(src, ref, at)
    if not r then return G.fail(cfg or 'bad_request') end
    if cfg.mode ~= 'craft' then return G.fail('bad_request') end
    local out = {}
    for i, rec in ipairs(cfg.recipes or {}) do
        local known = true
        for item in pairs(rec.takes or {}) do known = known and itemKnown(item) end
        for item in pairs(rec.gives or {}) do known = known and itemKnown(item) end
        if known then
            local takes, can = {}, true
            for item, count in pairs(rec.takes or {}) do
                local n = have(src, item)
                takes[#takes + 1] = { item = item, label = itemLabel(item), count = count, have = n }
                if n < count then can = false end
            end
            table.sort(takes, function(a, b) return a.item < b.item end)
            local gives = {}
            for item, count in pairs(rec.gives or {}) do gives[#gives + 1] = { item = item, label = itemLabel(item), count = count } end
            out[#out + 1] = { index = i, label = rec.label, takes = takes, gives = gives, can = can }
        end
    end
    return { ok = true, data = { recipes = out, label = cfg.label } }
end)

lib.callback.register(name('start'), function(src, ref, at, index)
    if G.throttle(src, 'start', 700) then return G.fail('slow_down') end
    local p = G.player(src)
    if not p then return G.fail('no_player') end
    if active[src] then return G.fail('busy') end
    local r, cfg = resolve(src, ref, at)
    if not r then return G.fail(cfg or 'bad_request') end
    local t = now()
    if cfg.mode == 'gather' then
        if (nodeUntil[r.key] or 0) > t then return G.fail('depleted', nodeUntil[r.key] - t) end
        if (playerUntil[p.cid .. r.key] or 0) > t then return G.fail('cooldown', playerUntil[p.cid .. r.key] - t) end
        if not firstTool(src, cfg) then return G.fail('no_tool', cfg.tools and cfg.tools[1]) end
        local miss = missingTakes(src, cfg.consumes)
        if miss then return G.fail('missing', itemLabel(miss)) end
        active[src] = { token = token(), key = r.key, ref = ref, kind = r.kind, pt = r.pt, started = GetGameTimer(), duration = cfg.duration or 8000 }
    elseif cfg.mode == 'craft' then
        local rec = cfg.recipes and cfg.recipes[tonumber(index) or -1]
        if not rec then return G.fail('bad_request') end
        local miss = missingTakes(src, rec.takes)
        if miss then return G.fail('missing', itemLabel(miss)) end
        active[src] = { token = token(), key = r.key, ref = ref, kind = r.kind, pt = r.pt, recipe = tonumber(index), started = GetGameTimer(), duration = rec.duration or cfg.duration or 6000 }
    else
        return G.fail('bad_request')
    end
    local a = active[src]
    return { ok = true, data = { token = a.token, duration = a.duration } }
end)

lib.callback.register(name('cancel'), function(src)
    active[src] = nil
    return true
end)

lib.callback.register(name('finish'), function(src, tok, good)
    local a = active[src]
    active[src] = nil
    if not a or type(tok) ~= 'string' or a.token ~= tok then return G.fail('bad_request') end
    local p = G.player(src)
    local cfg = Config.Kinds[a.kind]
    if not p or not cfg then return G.fail('no_player') end
    if GetGameTimer() - a.started < a.duration - 1500 then return G.fail('too_fast') end
    local d = dist(src, a.pt.x, a.pt.y, a.pt.z)
    if not d or d > (Config.Range or 4.0) + 3.0 then return G.fail('too_far') end
    if good ~= true then return G.fail('failed') end
    local t = now()
    if cfg.mode == 'gather' then
        if (nodeUntil[a.key] or 0) > t then return G.fail('depleted', nodeUntil[a.key] - t) end
        local tool = firstTool(src, cfg)
        if not tool then return G.fail('no_tool', cfg.tools and cfg.tools[1]) end
        if cfg.consumes then
            if missingTakes(src, cfg.consumes) or not removeTakes(src, cfg.consumes) then return G.fail('missing') end
        end
        nodeUntil[a.key] = t + (cfg.nodeCooldown or 0)
        playerUntil[p.cid .. a.key] = t + (cfg.playerCooldown or 0)
        local gained = give(src, roll(cfg))
        local broke = false
        if cfg.tools and tool ~= true and (cfg.toolBreak or 0) > 0 and math.random() < cfg.toolBreak then
            local ok, done = pcall(inv().remove, src, tool, 1)
            broke = ok and done == true and itemLabel(tool) or false
        end
        return { ok = true, data = { items = gained, broke = broke } }
    end
    local rec = cfg.recipes and cfg.recipes[a.recipe or -1]
    if not rec then return G.fail('bad_request') end
    if missingTakes(src, rec.takes) then return G.fail('missing') end
    for item, count in pairs(rec.gives or {}) do
        local ok, can = pcall(inv().canCarry, src, item, count)
        if not ok or can == false then return G.fail('full') end
    end
    if not removeTakes(src, rec.takes) then return G.fail('missing') end
    local list = {}
    for item, count in pairs(rec.gives or {}) do list[#list + 1] = { item = item, count = count } end
    return { ok = true, data = { items = give(src, list) } }
end)

lib.callback.register(name('sellList'), function(src, ref, at)
    local r, cfg = resolve(src, ref, at)
    if not r then return G.fail(cfg or 'bad_request') end
    if cfg.mode ~= 'sell' then return G.fail('bad_request') end
    local out = {}
    for item, price in pairs(cfg.prices or {}) do
        local n = have(src, item)
        if n > 0 then out[#out + 1] = { item = item, label = itemLabel(item), count = n, price = price } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return { ok = true, data = { items = out, label = cfg.label } }
end)

lib.callback.register(name('sell'), function(src, ref, at, item, count)
    if G.throttle(src, 'sell', 500) then return G.fail('slow_down') end
    local p = G.player(src)
    if not p then return G.fail('no_player') end
    local r, cfg = resolve(src, ref, at)
    if not r then return G.fail(cfg or 'bad_request') end
    if cfg.mode ~= 'sell' or type(item) ~= 'string' then return G.fail('bad_request') end
    local price = cfg.prices and cfg.prices[item]
    count = math.floor(G.num(count) or 0)
    if not price or count < 1 or count > 1000 then return G.fail('bad_request') end
    if have(src, item) < count then return G.fail('missing') end
    local ok, done = pcall(inv().remove, src, item, count)
    if not ok or not done then return G.fail('missing') end
    local total = math.floor(price * count)
    Bridge.addMoney(src, 'cash', total, ('%s: sold %dx %s'):format(RES, count, item))
    return { ok = true, data = { total = total, count = count, label = itemLabel(item) } }
end)

AddEventHandler('playerDropped', function() active[source] = nil end)

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(TABLE) end)
    if not ok then print(('^1[%s] schema: %s^0'):format(RES, tostring(err))) end
    for _, r in ipairs(MySQL.query.await(('SELECT * FROM `%s`'):format(Config.Table)) or {}) do
        if Config.Kinds[r.kind] then
            G.points[r.id] = { id = r.id, kind = r.kind, label = r.label, x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, w = (r.w or 0) + 0.0 }
        end
    end
    math.randomseed(GetGameTimer() + os.time())
    G.ready = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
end)
