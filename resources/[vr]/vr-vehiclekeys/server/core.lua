Core = {}

local lastAlert = {}

function Core.info(src)
    src = tonumber(src)
    if not src then return nil end
    local p = Bridge.player(src)
    if not p then return nil end
    local job, gang = p.job or {}, p.gang or {}
    return {
        src = src,
        cid = p.cid,
        name = p.name,
        job = { name = job.name, onduty = job.onduty == true },
        gang = { name = gang.name },
    }
end

function Core.sourceOf(cid)
    if type(cid) ~= 'string' then return nil end
    return Bridge.source(cid)
end

function Core.notify(src, text, kind)
    if not src then return end
    Bridge.notify(src, text, kind or 'inform', nil, 'Vehicle keys')
end

function Core.coords(src)
    return Bridge.coords(src)
end

function Core.vehicle(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return nil end
    return veh
end

function Core.near(src, veh, dist)
    local me = Core.coords(src)
    if not me then return false end
    return #(vector3(me.x, me.y, me.z) - GetEntityCoords(veh)) <= dist
end

function Core.label(model)
    if type(model) ~= 'string' or model == '' then return 'Vehicle' end
    return Bridge.vehicleLabel(model) or model
end

function Core.firstItem(src, items)
    for _, name in ipairs(items or {}) do
        if (Bridge.inventory.count(src, name) or 0) > 0 then return name end
    end
    return nil
end

function Core.atLocksmith(src)
    local me = Core.coords(src)
    if not me then return false end
    for _, l in ipairs(Config.Locksmith.locations) do
        if #(vector3(me.x, me.y, me.z) - vector3(l.coords.x, l.coords.y, l.coords.z)) <= 6.0 then return true end
    end
    return false
end

local TITLES = {
    lockpick = { 'Vehicle break-in', 'Someone is picking the lock of a vehicle' },
    hotwire = { 'Vehicle theft', 'Someone is hotwiring a vehicle' },
    carjack = { 'Carjacking', 'A driver was forced out of their vehicle at gunpoint' },
}

function Core.alert(src, kind)
    local cfg = Config.Alert
    if not cfg.enabled then return false end
    local text = TITLES[kind]
    if not text then return false end
    if math.random(100) > (tonumber(cfg.chance[kind]) or 0) then return false end
    local t = os.time()
    if lastAlert[src] and t - lastAlert[src] < cfg.cooldown then return false end
    if GetResourceState('vr-mdt') ~= 'started' then return false end
    local me = Core.coords(src)
    if not me then return false end
    lastAlert[src] = t
    local ok = pcall(function()
        exports['vr-mdt']:SendAlert({
            codeName = 'custom',
            title = text[1],
            description = text[2],
            priority = 2,
            coords = { x = me.x, y = me.y, z = me.z },
            jobs = cfg.jobs,
        }, src)
    end)
    return ok
end

AddEventHandler('playerDropped', function()
    lastAlert[source] = nil
end)
