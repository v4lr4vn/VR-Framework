-- Spawn side of vr-multicharacter (this used to be the separate vr-spawn resource).
local VRCore = exports['vr-core']:GetCoreObject({ 'Functions', 'Player' })

local providers = {}
local spawning = {}

-- Other housing scripts can offer their houses on the spawn map from here.
-- Also reachable as exports['vr-spawn']:RegisterHouseProvider (this resource provides that name).
exports('RegisterHouseProvider', function(fn, enterEvent)
    providers[GetInvokingResource() or GetCurrentResourceName()] = { fn = fn, event = enterEvent }
end)

AddEventHandler('onResourceStop', function(resource)
    providers[resource] = nil
end)

local qbHousesTables
local function qbHouses(citizenid)
    if qbHousesTables == nil then
        local found = MySQL.scalar.await([[SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = DATABASE() AND table_name IN ('player_houses', 'houselocations')]])
        qbHousesTables = tonumber(found) == 2
    end
    if not qbHousesTables then return {} end

    local rows = MySQL.query.await([[SELECT ph.house AS id, hl.label, hl.coords FROM player_houses ph
        JOIN houselocations hl ON hl.name = ph.house WHERE ph.citizenid = ?]], { citizenid }) or {}
    local houses = {}
    for i = 1, #rows do
        local ok, coords = pcall(json.decode, rows[i].coords)
        local enter = ok and type(coords) == 'table' and coords.enter
        if enter then
            houses[#houses + 1] = { id = rows[i].id, label = rows[i].label or rows[i].id, coords = enter, event = Config.HouseEnterEvent }
        end
    end
    return houses
end

local function getHouses(src, citizenid)
    local houses, last = {}, nil
    for resource, provider in pairs(providers) do
        local ok, result = pcall(provider.fn, src, citizenid)
        if ok and type(result) == 'table' then
            local list = result.houses or result
            for i = 1, #list do
                local house = list[i]
                if type(house) == 'table' and house.coords then
                    house.event = house.event or provider.event
                    houses[#houses + 1] = house
                end
            end
            if not last and type(result.last) == 'table' then
                last = result.last
                last.event = last.event or provider.event
            end
        elseif not ok then
            print(('^3[vr-multicharacter] house provider from %s failed: %s^0'):format(resource, tostring(result)))
        end
    end
    local ok, fromQb = pcall(qbHouses, citizenid)
    if ok then
        for i = 1, #fromQb do houses[#houses + 1] = fromQb[i] end
    end
    return houses, last
end

local function hasSkin(citizenid)
    local ok, found = pcall(MySQL.scalar.await, 'SELECT 1 FROM vr_clothing_skins WHERE citizenid = ? LIMIT 1', { citizenid })
    return not ok or found ~= nil
end

local function begin(src, isNew)
    local player = exports['vr-core']:GetPlayer(src)
    if not player then return end
    spawning[src] = true

    if isNew then
        return TriggerClientEvent('vr-multicharacter:client:firstSpawn', src, Config.FirstSpawn)
    end

    local pd = player.PlayerData
    local houses, last = getHouses(src, pd.citizenid)

    local data = {
        last = pd.position,
        houses = houses,
        needsSkin = not hasSkin(pd.citizenid),
        job = pd.job and pd.job.name or nil,
    }
    if last then
        if last.fallback then
            data.last = nil
        else
            data.last = last.coords
            data.lastHouse = last.id
            data.lastEvent = last.id ~= nil and last.event or nil
        end
    end

    TriggerClientEvent('vr-multicharacter:client:spawnChoose', src, data)
end

AddEventHandler('vr-multicharacter:server:begin', begin)
-- old name, kept so anything still calling the vr-spawn event keeps working
AddEventHandler('vr-spawn:server:begin', begin)

-- the player is in the world now
RegisterNetEvent('vr-multicharacter:server:spawned', function()
    spawning[source] = nil
end)

-- "Change character" on the spawn map: log the character out again and reopen the select screen.
-- Only allowed while the player is still on the spawn map, never once they are in the world.
RegisterNetEvent('vr-multicharacter:server:backToSelect', function()
    local src = source
    if not spawning[src] then return end
    spawning[src] = nil
    VRCore.Player.Logout(src)
    TriggerClientEvent('vr-multicharacter:client:chooseChar', src)
end)

AddEventHandler('VRCore:Server:OnPlayerUnload', function(src) spawning[src] = nil end)
AddEventHandler('playerDropped', function() spawning[source] = nil end)
