VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })

DoorResource = GetResourceState('vr-doorlock') ~= 'missing' and 'ox' or nil
if not DoorResource then
    print('^3[vr-housing] vr-doorlock is not installed - MLO properties will have no door locks^0')
end

function GetPlayer(src)
    src = tonumber(src)
    return src and exports['vr-core']:GetPlayer(src) or nil
end

function GetPlayerData(src)
    local player = GetPlayer(src)
    return player and player.PlayerData or nil
end

function GetCitizenid(targetSrc, callerSrc)
    local pd = GetPlayerData(targetSrc)
    if not pd then
        if callerSrc then Framework.ox.Notify(callerSrc, "Player not found.", "error") end
        return
    end
    return pd.citizenid
end

function GetCharName(src)
    local pd = GetPlayerData(src)
    if not pd then return 'Unknown' end
    return pd.charinfo.firstname .. " " .. pd.charinfo.lastname
end

function GetCharNameByCitizenId(citizenid)
    local online = exports['vr-core']:GetPlayerByCitizenId(citizenid)
    if online then return online.PlayerData.charinfo.firstname .. " " .. online.PlayerData.charinfo.lastname end
    local charinfo = MySQL.scalar.await('SELECT charinfo FROM vr_players WHERE citizenid = ? LIMIT 1', { citizenid })
    local ok, ci = pcall(json.decode, charinfo or '')
    if ok and type(ci) == 'table' and ci.firstname then return ci.firstname .. " " .. (ci.lastname or '') end
    return "Unknown"
end

local function decodeJson(value, default)
    if type(value) ~= 'string' then return value or default end
    local ok, result = pcall(json.decode, value)
    if ok and result ~= nil then return result end
    return default
end

local SCHEMA = [[
CREATE TABLE IF NOT EXISTS `properties` (
    `property_id` int(11) NOT NULL AUTO_INCREMENT,
    `owner_citizenid` varchar(50) NULL,
    `street` VARCHAR(100) NULL,
    `region` VARCHAR(100) NULL,
    `description` LONGTEXT NULL,
    `has_access` LONGTEXT NULL,
    `extra_imgs` LONGTEXT NULL,
    `furnitures` LONGTEXT NULL,
    `for_sale` boolean NOT NULL DEFAULT 1,
    `price` int(11) NOT NULL DEFAULT 0,
    `shell` varchar(50) NOT NULL,
    `apartment` varchar(50) NULL DEFAULT NULL,
    `door_data` LONGTEXT NULL DEFAULT NULL,
    `garage_data` LONGTEXT NULL DEFAULT NULL,
    `zone_data` LONGTEXT NULL DEFAULT NULL,
    PRIMARY KEY (`property_id`),
    CONSTRAINT `UQ_owner_apartment` UNIQUE (`owner_citizenid`, `apartment`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci]]

local dbloaded = false

local function loadProperty(v)
    local id = tostring(v.property_id)
    PropertiesTable[id] = Property:new({
        property_id = id,
        owner = v.owner_citizenid,
        street = v.street,
        region = v.region,
        description = v.description,
        has_access = decodeJson(v.has_access, {}),
        extra_imgs = decodeJson(v.extra_imgs, {}),
        furnitures = decodeJson(v.furnitures, {}),
        for_sale = v.for_sale == true or v.for_sale == 1,
        price = v.price,
        shell = v.shell,
        apartment = v.apartment,
        door_data = decodeJson(v.door_data, {}),
        garage_data = decodeJson(v.garage_data, {}),
        zone_data = v.zone_data,
    })
end

MySQL.ready(function()
    local ok, err = pcall(MySQL.query.await, SCHEMA)
    if not ok then print('^1[vr-housing] could not create the properties table: ' .. tostring(err) .. '^0') end

    local result = MySQL.query.await('SELECT * FROM properties') or {}
    for i = 1, #result do
        local loaded, loadErr = pcall(loadProperty, result[i])
        if not loaded then
            print(('^1[vr-housing] property %s failed to load: %s^0'):format(tostring(result[i].property_id), tostring(loadErr)))
        end
    end

    dbloaded = true
end)

local function clientProperties()
    while not dbloaded do Wait(100) end
    local list = {}
    for id, property in pairs(PropertiesTable) do
        local data = {}
        for k, v in pairs(property.propertyData) do
            if k ~= 'furnitures' then data[k] = v end
        end
        list[id] = data
    end
    return list
end

lib.callback.register("vr-housing:server:requestProperties", function()
    return clientProperties()
end)

local function cleanDoor(door)
    if type(door) ~= 'table' then return nil end
    local coords = door.coords
    if type(coords) ~= 'vector3' and type(coords) ~= 'table' then return nil end
    return {
        model = tonumber(door.model),
        heading = tonumber(door.heading) or 0,
        coords = vector3(tonumber(coords.x) or 0.0, tonumber(coords.y) or 0.0, tonumber(coords.z) or 0.0),
    }
end

local function createMloDoors(propertyId, doorList)
    if not DoorResource or GetResourceState('vr-doorlock') ~= 'started' or type(doorList) ~= 'table' then return 0 end
    local count = 0
    for index, door in ipairs(doorList) do
        local name = ('ps_mloproperty%s_%s'):format(propertyId, index)
        local payload
        if door[1] then
            local a, b = cleanDoor(door[1]), cleanDoor(door[2])
            if a and b then payload = { doors = { a, b }, name = name, maxDistance = 2.5, state = 1 } end
        else
            local d = cleanDoor(door)
            if d then
                payload = { model = d.model, heading = d.heading, coords = d.coords, name = name, maxDistance = 2.5, state = 1 }
            end
        end
        if payload then
            local ok, err = pcall(function() return exports['vr-doorlock']:vrCreateDoor(payload) end)
            if ok then
                count = count + 1
            else
                print('^1[vr-housing] could not create MLO door: ' .. tostring(err) .. '^0')
            end
        end
    end
    return count
end

function RegisterProperty(propertyData, preventEnter, source)
    propertyData.owner = propertyData.owner or nil
    propertyData.has_access = propertyData.has_access or {}
    propertyData.extra_imgs = propertyData.extra_imgs or {}
    propertyData.furnitures = propertyData.furnitures or {}
    propertyData.door_data = propertyData.door_data or {}
    propertyData.garage_data = propertyData.garage_data or {}
    propertyData.zone_data = propertyData.zone_data or {}

    local isMlo = propertyData.shell == 'mlo'
    local mloDoors = isMlo and propertyData.door_data or nil
    if isMlo then propertyData.door_data = { count = 0 } end

    local id = MySQL.insert.await([[INSERT INTO properties
        (owner_citizenid, street, region, description, has_access, extra_imgs, furnitures, for_sale, price, shell, apartment, door_data, garage_data, zone_data)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        propertyData.owner,
        propertyData.street,
        propertyData.region,
        propertyData.description,
        json.encode(propertyData.has_access),
        json.encode(propertyData.extra_imgs),
        json.encode(propertyData.furnitures),
        (propertyData.for_sale == nil or propertyData.for_sale) and 1 or 0,
        tonumber(propertyData.price) or 0,
        propertyData.shell or '',
        propertyData.apartment,
        json.encode(propertyData.door_data),
        json.encode(propertyData.garage_data),
        json.encode(propertyData.zone_data),
    })
    if not id then return end

    id = tostring(id)

    if isMlo then
        propertyData.door_data = { count = createMloDoors(id, mloDoors) }
        MySQL.update('UPDATE properties SET door_data = ? WHERE property_id = ?', { json.encode(propertyData.door_data), id })
    end

    propertyData.property_id = id
    propertyData.for_sale = (propertyData.for_sale == nil or propertyData.for_sale) and true or false
    PropertiesTable[id] = Property:new(propertyData)

    if isMlo and propertyData.owner then
        PropertiesTable[id]:addMloDoorsAccess(propertyData.owner)
    end

    local forClients = {}
    for k, v in pairs(propertyData) do
        if k ~= 'furnitures' then forClients[k] = v end
    end
    TriggerClientEvent("vr-housing:client:addProperty", -1, forClients)

    if propertyData.apartment and not preventEnter and propertyData.owner then
        local player = exports['vr-core']:GetPlayerByCitizenId(propertyData.owner)
        if player then
            PropertiesTable[id]:PlayerEnter(player.PlayerData.source)
            Framework.ox.Notify(player.PlayerData.source, "Open radial menu for furniture menu and place down your stash and clothing locker.", "info")
        end
    end

    return id
end

exports('registerProperty', RegisterProperty)
AddEventHandler("vr-housing:server:registerProperty", RegisterProperty)

local function getMainDoor(propertyId, doorIndex, isShell)
    if isShell then
        local property = Property.Get(propertyId)
        if not property then return end
        return { coords = property.propertyData.door_data }
    end
    if not DoorResource then return end
    return exports['vr-doorlock']:getDoorFromName(('ps_mloproperty%s_%s'):format(propertyId, doorIndex or 1))
end
exports('getMainDoor', getMainDoor)

lib.callback.register("vr-housing:cb:getMainMloDoor", function(_, propertyId, doorIndex)
    return getMainDoor(propertyId, doorIndex)
end)

lib.callback.register("vr-housing:cb:GetOwnedApartment", function(source)
    local citizenid = GetCitizenid(source)
    if not citizenid then return end
    for _, property in pairs(PropertiesTable) do
        local data = property.propertyData
        if data.owner == citizenid and data.apartment then
            return data
        end
    end
end)

lib.callback.register("vr-housing:cb:inventoryHasItems", function(source, stash)
    if type(stash) ~= 'string' then return false end
    local propertyId = stash:match('^property_(%d+)$')
    local property = propertyId and Property.Get(propertyId)
    if not property or not property:CheckForAccess(GetCitizenid(source)) then return false end
    local items = exports['vr-inventory']:GetInventoryItems(stash)
    return items ~= nil and next(items) ~= nil
end)

local updatable = {
    UpdateDescription = true, UpdatePrice = true, UpdateForSale = true, UpdateShell = true, UpdateOwner = true,
    UpdateImgs = true, UpdateDoor = true, UpdateGarage = true, UpdateApartment = true, DeleteProperty = true,
}

AddEventHandler("vr-housing:server:updateProperty", function(type, property_id, data)
    if not updatable[type] then return end
    local property = Property.Get(property_id)
    if not property then return end
    property[type](property, data)
end)

AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    CreateThread(function()
        local list = clientProperties()
        for _, playerId in ipairs(GetPlayers()) do
            if GetPlayer(playerId) then
                TriggerClientEvent('vr-housing:client:initialiseProperties', playerId, list)
            end
        end
    end)
end)

AddEventHandler("vr-housing:server:addTenantToApartment", function(data)
    local apartment = data.apartment
    local targetSrc = tonumber(data.targetSrc)
    local realtorSrc = data.realtorSrc

    local newApartment = Config.Apartments[apartment]
    if not newApartment or not targetSrc then return end

    local targetPlayer = GetPlayerData(targetSrc)
    if not targetPlayer then
        Framework.ox.Notify(realtorSrc, "Player not found.", "error")
        return
    end
    local targetCitizenid = targetPlayer.citizenid
    local targetName = targetPlayer.charinfo.firstname .. " " .. targetPlayer.charinfo.lastname

    local current
    for _, v in pairs(PropertiesTable) do
        local propertyData = v.propertyData
        if propertyData.owner == targetCitizenid and propertyData.apartment then
            if propertyData.apartment == apartment then
                Framework.ox.Notify(realtorSrc, "This person is already in this apartment", "error")
                return
            end
            current = v
            break
        end
    end

    if not current then
        RegisterProperty({
            owner = targetCitizenid,
            description = string.format("This is %s's apartment in %s", targetName, newApartment.label),
            for_sale = false,
            shell = newApartment.shell,
            apartment = newApartment.label,
        }, true)
        Framework.ox.SendLog("Creating new apartment for " .. GetPlayerName(targetSrc) .. " in " .. newApartment.label)
    else
        current:UpdateApartment(data)
    end

    Framework.ox.Notify(targetSrc, "Your apartment is now at " .. apartment, "success")
    Framework.ox.Notify(realtorSrc, "You have added " .. targetName .. " to apartment " .. apartment, "success")
end)

local function isOwner(src, property_id)
    local property = Property.Get(property_id)
    if not property then return false end
    return property:CheckForAccess(GetCitizenid(src))
end
exports('IsOwner', isOwner)

exports('IsInside', function(src, property_id)
    local property = Property.Get(property_id)
    return property ~= nil and property.playersInside[tostring(src)] == true
end)

local function propertyLabel(property)
    local data = property.propertyData
    if data.apartment then return ('%s #%s'):format(data.apartment, property.property_id) end
    return ('%s %s'):format(data.street or 'House', property.property_id)
end

local function frontDoor(property)
    local door = property:GetDoorCoords()
    if not door and property.propertyData.shell == 'mlo' then
        local main = getMainDoor(property.property_id, 1)
        local c = main and (main.coords or (main.doors and main.doors[1] and main.doors[1].coords))
        if c then door = { x = c.x, y = c.y, z = c.z, h = main.heading or 0.0 } end
    end
    if door then return vector4(door.x + 0.0, door.y + 0.0, door.z + 0.0, (door.h or 0.0) + 0.0) end
end

local function spawnProvider(src, citizenid)
    while not dbloaded do Wait(100) end

    local houses = {}
    for _, property in pairs(PropertiesTable) do
        if property:CheckForAccess(citizenid) then
            local coords = frontDoor(property)
            if coords then
                houses[#houses + 1] = { id = property.property_id, label = propertyLabel(property), coords = coords }
            end
        end
    end
    table.sort(houses, function(a, b) return tonumber(a.id) < tonumber(b.id) end)

    local last
    local pd = GetPlayerData(src)
    local inside = pd and pd.metadata and pd.metadata.inside
    if inside and inside.property_id then
        local property = Property.Get(inside.property_id)
        if property then
            last = { coords = frontDoor(property), id = property:CheckForAccess(citizenid) and property.property_id or nil }
        elseif inside.property_door then
            local d = inside.property_door
            last = { coords = vector4(d.x + 0.0, d.y + 0.0, d.z + 0.0, (d.h or 0.0) + 0.0) }
        else
            last = { fallback = true }
        end
        if not last.coords and not last.fallback then last = { fallback = true } end
    end

    return { houses = houses, last = last }
end

local function registerWithSpawn()
    -- spawning now lives in vr-multicharacter; vr-spawn is only used if someone still runs it
    local target = (GetResourceState('vr-multicharacter') == 'started' and 'vr-multicharacter')
        or (GetResourceState('vr-spawn') == 'started' and 'vr-spawn')
    if not target then return end
    exports[target]:RegisterHouseProvider(spawnProvider, 'vr-housing:client:spawnInProperty')
end

CreateThread(registerWithSpawn)
AddEventHandler('onResourceStart', function(resource)
    if resource == 'vr-spawn' or resource == 'vr-multicharacter' then registerWithSpawn() end
end)

AddEventHandler('vr-multicharacter:server:characterCreated', function(src, citizenid)
    if not Config.StartingApartment then return end
    local apartment = Config.Apartments[Config.StartingApartmentName]
    if not apartment or not citizenid then return end
    for _, property in pairs(PropertiesTable) do
        if property.propertyData.owner == citizenid and property.propertyData.apartment then return end
    end
    RegisterProperty({
        owner = citizenid,
        description = string.format("This is %s's apartment in %s", GetCharName(src), apartment.label),
        for_sale = false,
        shell = apartment.shell,
        apartment = apartment.label,
    }, true)
end)

AddEventHandler('VRCore:Server:OnCharacterDeleted', function(citizenid)
    if type(citizenid) ~= 'string' then return end
    for _, property in pairs(PropertiesTable) do
        local data = property.propertyData
        if data.owner == citizenid then
            if data.apartment then
                property:DeleteProperty({})
            else
                property:SetOwner(nil)
                if Config.ReturnHousesToMarketOnDelete then property:UpdateForSale({ forsale = true }) end
            end
        elseif lib.table.contains(data.has_access or {}, citizenid) then
            local keys = {}
            for _, cid in ipairs(data.has_access) do
                if cid ~= citizenid then keys[#keys + 1] = cid end
            end
            property:removeMloDoorsAccess(citizenid)
            property:UpdateHas_access(keys)
        end
    end
end)

local function forgetPlayer(src, resetBucket)
    for _, property in pairs(PropertiesTable) do
        if property.playersInside[tostring(src)] and resetBucket then
            VRCore.Functions.SetPlayerBucket(src, 0)
        end
        property:Forget(src)
    end
end

AddEventHandler('VRCore:Server:OnPlayerUnload', function(src) forgetPlayer(src, true) end)
AddEventHandler('playerDropped', function() forgetPlayer(source, false) end)

CreateThread(function()
    while GetResourceState('vr-inventory') ~= 'started' do Wait(500) end
    exports['vr-inventory']:registerHook('openInventory', function(payload)
        local propertyId = tostring(payload.inventoryId):match('^property_(%d+)$')
        local property = propertyId and Property.Get(propertyId)
        if not property then return true end
        local src = payload.source
        if property:CheckForAccess(GetCitizenid(src)) then return true end
        return property.raiding and property.playersInside[tostring(src)] == true
    end, { inventoryFilter = { '^property_%d+$' } })
end)

for name, fn in pairs({ IsOwner = isOwner, registerProperty = RegisterProperty, getMainDoor = getMainDoor }) do
    AddEventHandler(('__cfx_export_ps-housing_%s'):format(name), function(setCB) setCB(fn) end)
end
