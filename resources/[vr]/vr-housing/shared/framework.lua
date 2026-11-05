Framework = { ox = {} }

PoliceJobs = {}
RealtorJobs = {}

for i = 1, #Config.PoliceJobNames do
    PoliceJobs[Config.PoliceJobNames[i]] = true
end

for i = 1, #Config.RealtorJobNames do
    RealtorJobs[Config.RealtorJobNames[i]] = true
end

if IsDuplicityVersion() then
    function Framework.ox.Notify(src, message, type)
        if not src or src == 0 then return end
        type = type == "inform" and "info" or type
        TriggerClientEvent("vr-ui:notify", src, { title = "Property", description = message, type = type })
    end

    function Framework.ox.RegisterInventory(stash, label, stashConfig)
        stashConfig = stashConfig or {}
        exports['vr-inventory']:RegisterStash(stash, label, stashConfig.slots or 50, stashConfig.maxweight or 100000, nil)
    end

    function Framework.ox.SendLog(message)
        if not Config.EnableLogs then return end
        TriggerEvent('vr-log:server:CreateLog', 'housing', 'Housing System', 'blue', message)
    end

    return
end

local function hasApartment(apts)
    for propertyId in pairs(apts) do
        local property = PropertiesTable[propertyId]
        if property and property.owner then
            return true
        end
    end
    return false
end

local function job()
    return PlayerData.job or { name = 'unemployed', onduty = false, grade = { level = 0 } }
end

local function canRaid()
    local j = job()
    return PoliceJobs[j.name] and j.onduty and (tonumber(j.grade and j.grade.level) or 0) >= Config.MinGradeToRaid
end

local function isRealtor(needDuty)
    local j = job()
    return RealtorJobs[j.name] and (not needDuty or j.onduty)
end

Framework.ox = {
    Notify = function(message, type)
        type = type == "inform" and "info" or type
        lib.notify({ title = 'Property', description = message, type = type })
    end,

    AddEntrance = function(coords, size, heading, propertyId, enter, raid, showcase, showData)
        local property_id = propertyId

        return exports['vr-target']:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(size.y, size.x, size.z),
            rotation = heading,
            debug = Config.DebugMode,
            options = {
                {
                    label = "Enter Property",
                    icon = "fas fa-door-open",
                    onSelect = enter,
                    canInteract = function()
                        local property = Property.Get(property_id)
                        return property and (property.has_access or property.owner)
                    end,
                },
                {
                    label = "Showcase Property",
                    icon = "fas fa-eye",
                    onSelect = showcase,
                    canInteract = function() return isRealtor(true) end,
                },
                {
                    label = "Property Info",
                    icon = "fas fa-circle-info",
                    onSelect = showData,
                    canInteract = function() return isRealtor(true) end,
                },
                {
                    label = "Ring Doorbell",
                    icon = "fas fa-bell",
                    onSelect = enter,
                    canInteract = function()
                        local property = Property.Get(property_id)
                        return property and not property.has_access and not property.owner
                    end,
                },
                {
                    label = "Raid Property",
                    icon = "fas fa-building-shield",
                    onSelect = raid,
                    canInteract = canRaid,
                },
            },
        })
    end,

    AddApartmentEntrance = function(coords, size, heading, apartment, enter, seeAll, seeAllToRaid)
        return exports['vr-target']:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(size.y, size.x, size.z),
            rotation = heading,
            debug = Config.DebugMode,
            options = {
                {
                    label = "Enter Apartment",
                    onSelect = enter,
                    icon = "fas fa-door-open",
                    canInteract = function()
                        local apt = ApartmentsTable[apartment]
                        return apt and hasApartment(apt.apartments)
                    end,
                },
                {
                    label = "See all apartments",
                    onSelect = seeAll,
                    icon = "fas fa-circle-info",
                },
                {
                    label = "Raid Apartment",
                    onSelect = seeAllToRaid,
                    icon = "fas fa-building-shield",
                    canInteract = canRaid,
                },
            },
        })
    end,

    AddDoorZoneInside = function(coords, size, heading, leave, checkDoor)
        return exports['vr-target']:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(size.y, size.x, size.z),
            rotation = heading,
            debug = Config.DebugMode,
            options = {
                { name = "leave", label = "Leave Property", onSelect = leave, icon = "fas fa-right-from-bracket" },
                { name = "doorbell", label = "Check Door", onSelect = checkDoor, icon = "fas fa-bell" },
            },
        })
    end,

    AddDoorZoneInsideTempShell = function(coords, size, heading, leave)
        return exports['vr-target']:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(size.y, size.x, size.z),
            rotation = heading,
            debug = Config.DebugMode,
            options = {
                { name = "leave", label = "Leave", onSelect = leave, icon = "fas fa-right-from-bracket" },
            },
        })
    end,

    RemoveTargetZone = function(handler)
        if handler then exports['vr-target']:removeZone(handler) end
    end,

    AddRadialOption = function(id, label, icon, fn)
        lib.addRadialItem({ id = id, icon = icon, label = label, onSelect = fn })
    end,

    RemoveRadialOption = function(id)
        lib.removeRadialItem(id)
    end,

    AddTargetEntity = function(entity, label, icon, action)
        exports['vr-target']:addLocalEntity(entity, {
            { name = label, label = label, icon = icon, onSelect = action },
        })
    end,

    RemoveTargetEntity = function(entity)
        exports['vr-target']:removeLocalEntity(entity)
    end,

    inventoryHasItems = function(stash)
        return lib.callback.await('vr-housing:cb:inventoryHasItems', 10, stash)
    end,

    OpenInventory = function(stash)
        exports['vr-inventory']:openInventory('stash', stash)
    end,
}
