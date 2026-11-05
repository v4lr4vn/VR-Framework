local VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })
PlayerData = {}
local loaded = false

local function createProperty(propertyData)
    PropertiesTable[propertyData.property_id] = Property:new(propertyData)
end
RegisterNetEvent('vr-housing:client:addProperty', function(propertyData)
    if not loaded then return end
    createProperty(propertyData)
end)

RegisterNetEvent('vr-housing:client:removeProperty', function(property_id)
    local property = Property.Get(property_id)
    if property then
        property:RemoveProperty()
    end
    PropertiesTable[property_id] = nil
end)

local function clearProperties()
    if Modeler.IsMenuActive then
        Modeler:CloseMenu()
    end
    for _, property in pairs(PropertiesTable) do
        property:RemoveProperty(true)
    end
    for _, apartment in pairs(ApartmentsTable) do
        apartment:RemoveApartment()
    end
    PropertiesTable = {}
    ApartmentsTable = {}
    loaded = false
end

local initialising = false
function InitialiseProperties(properties)
    if loaded or initialising then return end
    initialising = true
    Debug("Initialising properties")
    PlayerData = VRCore.Functions.GetPlayerData()

    for k, v in pairs(Config.Apartments) do
        ApartmentsTable[k] = Apartment:new(v)
    end

    if not properties then
        properties = lib.callback.await('vr-housing:server:requestProperties', false)
    end

    for _, propertyData in pairs(properties or {}) do
        createProperty(propertyData.propertyData or propertyData)
    end

    loaded = true
    initialising = false
    TriggerEvent("vr-housing:client:initialisedProperties")
    Debug("Initialised properties")
end

RegisterNetEvent("VRCore:Client:OnPlayerLoaded", function() InitialiseProperties() end)
RegisterNetEvent('vr-housing:client:initialiseProperties', function(properties)
    clearProperties()
    InitialiseProperties(properties)
end)

RegisterNetEvent("VRCore:Client:OnPlayerUnload", function()
    clearProperties()
    PlayerData = {}
end)

RegisterNetEvent('VRCore:Client:OnJobUpdate', function(job)
    PlayerData.job = job
end)

AddEventHandler('VRCore:Player:SetPlayerData', function(pd)
    if pd and pd.citizenid then PlayerData = pd end
end)

function SpawnDone()
    SpawningInto = nil
    TriggerEvent('vr-spawn:client:entered')
end
local spawnDone = SpawnDone

AddEventHandler('vr-housing:client:spawnInProperty', function(propertyId)
    local deadline = GetGameTimer() + 15000
    while not loaded and GetGameTimer() < deadline do Wait(50) end
    if not loaded or not Property.Get(propertyId) then return spawnDone() end
    SpawningInto = tostring(propertyId)
    TriggerServerEvent('vr-housing:server:enterProperty', SpawningInto, 'spawn')
    SetTimeout(10000, function()
        if SpawningInto == tostring(propertyId) then SpawningInto = nil; spawnDone() end
    end)
end)

RegisterNetEvent('vr-housing:client:spawnAtMlo', function(propertyId)
    local data = lib.callback.await("vr-housing:cb:getMainMloDoor", false, propertyId, 1)
    local c = data and (data.coords or (data.doors and data.doors[1] and data.doors[1].coords))
    if c then SetEntityCoords(cache.ped, c.x, c.y, c.z, false, false, false, false) end
    spawnDone()
end)

RegisterNetEvent('vr-housing:client:forceLeave', function(propertyId)
    local property = Property.Get(propertyId)
    if property and property.inProperty then
        property:LeaveShell(true)
    elseif property then
        local door = property:GetDoorCoords()
        if door then SetEntityCoordsNoOffset(cache.ped, door.x, door.y, door.z, false, false, true) end
    end
    spawnDone()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        clearProperties()
    end
end)

local clientExports = {
    GetProperties = function() return PropertiesTable end,
    GetProperty = function(property_id) return Property.Get(property_id) end,
    GetApartments = function() return ApartmentsTable end,
    GetApartment = function(apartment) return Apartment.Get(apartment) end,
    GetShells = function() return Config.Shells end,
}

for name, fn in pairs(clientExports) do
    exports(name, fn)
    AddEventHandler(('__cfx_export_ps-housing_%s'):format(name), function(setCB) setCB(fn) end)
end

lib.callback.register('vr-housing:cb:confirmPurchase', function(amount, street, id)
    return lib.alertDialog({
        header = 'Purchase Confirmation',
        content = 'Are you sure you want to purchase ' .. street .. ' ' .. id .. ' for $' .. amount .. '?',
        centered = true,
        cancel = true,
        labels = { confirm = "Purchase", cancel = "Cancel" }
    })
end)

lib.callback.register('vr-housing:cb:confirmRaid', function(street, id)
    return lib.alertDialog({
        header = 'Raid',
        content = 'Do you want to raid ' .. street .. ' ' .. id .. '?',
        centered = true,
        cancel = true,
        labels = { confirm = "Raid", cancel = "Cancel" }
    })
end)

lib.callback.register('vr-housing:cb:ringDoorbell', function()
    return lib.alertDialog({
        header = 'Ring Doorbell',
        content = 'You dont have a key for this property, would you like to ring the doorbell?',
        centered = true,
        cancel = true,
        labels = { confirm = "Ring", cancel = "Cancel" }
    })
end)

lib.callback.register('vr-housing:cb:showcase', function()
    return lib.alertDialog({
        header = 'Showcase Property',
        content = 'Do you want to showcase this property?',
        centered = true,
        cancel = true,
        labels = { confirm = "Yes", cancel = "Cancel" }
    })
end)
