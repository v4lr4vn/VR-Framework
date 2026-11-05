Core = {}

local last = {}
local alerted = {}

function Core.info(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return { src = src, cid = p.cid, name = p.name or 'Citizen' }
end

function Core.notify(src, text, kind, title)
    if not src or src <= 0 then return print(('[vr-bankheist] %s'):format(tostring(text))) end
    Bridge.notify(src, text, kind or 'inform', nil, title or 'Bank heist')
end

function Core.throttle(src, key, ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return false end
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

function Core.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0.0) - (b.z or 0.0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Core.near(src, c, radius)
    local p = Bridge.coords(src)
    if not p or not c then return false end
    return Core.dist(p, c) <= radius
end

function Core.admin(src)
    if not src or src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

function Core.between(a, b)
    a, b = math.floor(tonumber(a) or 0), math.floor(tonumber(b) or 0)
    if b < a then b = a end
    if a == b then return a end
    return math.random(a, b)
end

function Core.count(src, item)
    return tonumber(Bridge.inventory.count(src, item)) or 0
end

function Core.take(src, item, count)
    return Bridge.inventory.remove(src, item, count or 1) ~= false
end

function Core.give(src, item, count)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return true end
    if Bridge.inventory.itemExists and not Bridge.inventory.itemExists(item) then return false, 'missing' end
    if Bridge.inventory.canCarry and not Bridge.inventory.canCarry(src, item, count) then return false, 'full' end
    return Bridge.inventory.add(src, item, count) ~= false
end

function Core.payout(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local item = Config.Items.cash
    if item then return Core.give(src, item, amount) end
    return Bridge.addMoney(src, Config.Account, amount, 'Bank heist') == true
end

function Core.police()
    local cfg = Config.Police
    local n = 0
    local lookup = {}
    for _, j in ipairs(cfg.jobs) do lookup[j] = true end
    for _, p in ipairs(Bridge.players()) do
        local job = p.job
        if job and lookup[job.name] and (not cfg.onDutyOnly or job.onduty) then n = n + 1 end
    end
    return n
end

function Core.alert(src, title, text, coords)
    local cfg = Config.Police
    if not cfg.enabled or not coords then return false end
    if GetResourceState('vr-mdt') ~= 'started' then return false end
    return (pcall(function()
        exports['vr-mdt']:SendAlert({
            codeName = 'custom',
            title = title,
            description = text,
            priority = 1,
            coords = { x = coords.x, y = coords.y, z = coords.z },
            jobs = cfg.jobs,
        }, src)
    end))
end

function Core.doors()
    if GetResourceState('vr-doorlock') ~= 'started' then return nil end
    return exports['vr-doorlock']
end

function Core.doorId(name)
    local api = Core.doors()
    if not api then return nil end
    local ok, door = pcall(function() return api:getDoorFromName(name) end)
    if ok and type(door) == 'table' then return door.id end
    return nil
end

function Core.doorList()
    local api = Core.doors()
    if not api then return {}, false end
    local ok, list = pcall(function() return api:getAllDoors() end)
    if not ok or type(list) ~= 'table' then return {}, true end
    local out = {}
    for _, d in ipairs(list) do
        if d.name and d.coords then out[#out + 1] = { name = d.name, x = d.coords.x, y = d.coords.y, z = d.coords.z } end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out, true
end

function Core.doorName(id)
    local api = Core.doors()
    if not api then return nil end
    local ok, door = pcall(function() return api:getDoor(id) end)
    if ok and type(door) == 'table' then return door.name end
    return nil
end

function Core.makeDoor(name, data)
    local api = Core.doors()
    if not api then return nil, 'no_doorlock' end
    local ok, id = pcall(function()
        return api:vrCreateDoor({
            name = name,
            state = 1,
            hideUi = true,
            maxDistance = 2.0,
            model = data.model,
            coords = data.coords,
            heading = data.heading,
            doors = data.doors,
        })
    end)
    if not ok or not id then return nil, 'door_failed' end
    return id
end

function Core.dropDoor(name)
    local api = Core.doors()
    local id = Core.doorId(name)
    if not api or not id then return false end
    return (pcall(function() return api:vrDeleteDoor(id) end))
end

function Core.setDoor(name, locked)
    local api = Core.doors()
    local id = Core.doorId(name)
    if not api or not id then return false end
    return (pcall(function() api:setDoorState(id, locked and 1 or 0) end))
end

AddEventHandler('playerDropped', function()
    local src = source
    alerted[src] = nil
    local prefix = ('%s:'):format(src)
    for id in pairs(last) do
        if id:sub(1, #prefix) == prefix then last[id] = nil end
    end
end)
