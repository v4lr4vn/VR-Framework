local tracked = {}
local last = {}

local function limited(src, key, ms)
    local now = GetGameTimer()
    local id = src .. ':' .. key
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

local function near(src, entity, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - GetEntityCoords(entity)) <= maxDistance
end

RegisterNetEvent('vr-target:setEntityHasOptions', function(netId)
    local src = source
    if type(netId) ~= 'number' or limited(src, 'opt', 50) then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    local bag = Entity(entity)
    bag.state:set('hasTargetOptions', true, true)
    tracked[netId] = entity
end)

RegisterNetEvent('vr-target:toggleEntityDoor', function(netId, door)
    local src = source
    if type(netId) ~= 'number' or type(door) ~= 'number' or door < 0 or door > 7 or limited(src, 'door', 150) then return end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if not near(src, entity, 10.0) then return end
    local ownerId = NetworkGetEntityOwner(entity)
    if ownerId and ownerId > 0 then
        TriggerClientEvent('vr-target:toggleEntityDoor', ownerId, netId, door)
    end
end)

AddEventHandler('playerDropped', function()
    local src = tostring(source)
    for id in pairs(last) do
        if id:sub(1, #src + 1) == src .. ':' then last[id] = nil end
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        local gone = {}
        for netId, entity in pairs(tracked) do
            if not DoesEntityExist(entity) or not Entity(entity).state.hasTargetOptions then
                tracked[netId] = nil
                gone[#gone + 1] = netId
            end
        end
        if #gone > 0 then TriggerClientEvent('vr-target:removeEntity', -1, gone) end
    end
end)
