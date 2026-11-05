Property = {
    property_id = nil,
    propertyData = nil,

    mloData = nil,

    shell = nil,
    shellData = nil,
    inProperty = false,
    shellObj = nil,

    has_access = false,
    owner = false,

    clothingTarget = nil,
    storageTarget = {},
    furnitureObjs = {},

    garageZone = nil,
    doorbellPool = {},

    entranceTarget = nil,
    exitTarget = nil,

    blip = nil,
}
Property.__index = Property

function Property:new(propertyData)
    local self = setmetatable({}, Property)
    self.property_id = tostring(propertyData.property_id)

    self.storageTarget = {}
    self.furnitureObjs = {}
    self.doorbellPool = {}

    propertyData.furnitures = {}
    propertyData.has_access = propertyData.has_access or {}
    self.propertyData = propertyData
    local citizenid = PlayerData.citizenid

    self.owner = citizenid ~= nil and propertyData.owner == citizenid
    self.has_access = lib.table.contains(self.propertyData.has_access, citizenid)

    if propertyData.apartment then
        local aptName = propertyData.apartment
        local apartment = ApartmentsTable[aptName]

        if not apartment and Config.Apartments[aptName] then
            ApartmentsTable[aptName] = Apartment:new(Config.Apartments[aptName])
            apartment = ApartmentsTable[aptName]
        elseif not apartment then
            Debug(aptName .. " not found in Config")
            return
        end

        apartment:AddProperty(self.property_id, self)
    else
        self:RegisterPropertyEntrance()
        self:RegisterGarageZone()
    end

    return self
end

function Property:GetDoorCoords()
    local coords = nil

    local dataApartment = self.propertyData.apartment
    if dataApartment then
        local apartment = dataApartment
        coords = Config.Apartments[apartment].door
    else
        coords = self.propertyData.door_data
    end

    return coords
end

function Property:CreateShell()
    local coords = self:GetDoorCoords()

    coords = vec3(coords.x, coords.y, coords.z - 25.0)
    self.shell = Shell:CreatePropertyShell(self.propertyData.shell, coords)

    self.shellObj = self.shell.entity

    local doorOffset = self.shellData.doorOffset
    local offset = GetOffsetFromEntityInWorldCoords(self.shellObj, doorOffset.x, doorOffset.y, doorOffset.z)
    self:RegisterDoorZone(offset)
    SetEntityCoordsNoOffset(cache.ped, offset.x, offset.y, offset.z, false, false, true)
    SetEntityHeading(cache.ped, doorOffset.h)
end

function Property:RegisterDoorZone(offset)
    local function leave()
        self:LeaveShell()
    end

    local function checkDoor()
        self:OpenDoorbellMenu()
    end

    local doorOffset = self.shellData.doorOffset
    local size = vector3(1.0, doorOffset.width, 3.0)
    local heading = doorOffset.h

    self.exitTarget = Framework.ox.AddDoorZoneInside(offset, size, heading, leave, checkDoor)
end

local function convertToVector(zone, garden)
    if not zone or not zone[1] then return end
    local z = garden and zone[1].z - 0.2 or zone[1].z - 1
    local points = {}
    for k,v in ipairs(zone) do
        points[k] = vec3(v.x, v.y, z)
    end
    return points
end

function Property:RegisterMlo()
    local data = lib.callback.await("vr-housing:cb:getMainMloDoor", false, self.property_id, 1)
    if not data then return end

    local coords = data.objCoords or data.coords or data.doors[1] and data.doors[1].coords or data.doors[1].objCoords
    local zoneData = type(self.propertyData.zone_data) == 'string' and json.decode(self.propertyData.zone_data) or self.propertyData.zone_data
    if not zoneData then return end

    if self.propertyData.owner then
        self.mloData = {}
        self.mloData.point = lib.points.new({
            coords = vec3(coords.x, coords.y, coords.z),
            distance = 40,
            onEnter = function()
                self:LoadFurnitures()
            end,
            onExit = function()
                self:UnloadFurnitures()
                self.propertyData.furnitures = {}
            end
        })
    end

    if self.owner or self.has_access then
        self.mloData = self.mloData or {}
        self.mloData.poly = lib.zones.poly({
            points = convertToVector(zoneData.points),
            thickness = zoneData.thickness + 3,
            debug = Config.DebugMode,
            onEnter = function()
                TriggerServerEvent("vr-housing:server:enterProperty", self.property_id)
            end,
            onExit = function()
                self:LeaveShell()
            end
        })
    end

    return {
        x = coords.x,
        y = coords.y,
        z = coords.z,
        length = 2.0,
        h = 100.0,
        width = 2.0,
    }
end

function Property:RegisterPropertyEntrance()
    local function enter()
        TriggerServerEvent("vr-housing:server:enterProperty", self.property_id)
    end

    local function raid()
        TriggerServerEvent("vr-housing:server:raidProperty", self.property_id)
    end

    local function showcase()
        TriggerServerEvent("vr-housing:server:showcaseProperty", self.property_id)
    end

    local function showData()
        local data = lib.callback.await("vr-housing:cb:getPropertyInfo", false, self.property_id)
        if not data then return end

        local content = "**Owner:** " .. data.owner .. "  \n" .. "**Description:** " .. data.description .. "  \n" .. "**Street:** " .. data.street .. "  \n" .. "**Region:** " .. data.region .. "  \n" .. "**Shell:** " .. data.shell .. "  \n" .. "**For Sale:** " .. (data.for_sale and "Yes" or "No")

        if data.for_sale then
            content = content .. "  \n" .. "**Price:** " .. data.price
        end

        lib.alertDialog({
            header = data.street .. " " .. data.property_id,
            content = content,
            centered = true,
        })
    end

    local targetName = string.format("%s_%s", self.propertyData.street, self.property_id)
    local isMlo = self.propertyData.shell == 'mlo'

    if not isMlo then
        local zoneData = type(self.propertyData.zone_data) == 'string' and json.decode(self.propertyData.zone_data) or self.propertyData.zone_data
        if not zoneData then return end

        local coords = convertToVector(zoneData.points, true)
        if not coords then
            goto skip
        end

        local poly = lib.zones.poly({
            points = coords,
            debug = Config.DebugMode,
            onEnter = function()
                self:GiveMenus(true)
                self.inGarden = true
                TriggerServerEvent("vr-housing:server:enterGarden", self.property_id)
            end,
            onExit = function()
                self:RemoveMenus(true)
                self.inGarden = false
            end
        })
        self.propertyData.garden_data = {
            poly = poly,
            point = lib.points.new({
                coords = vec3(coords[1].x, coords[1].y, coords[1].z),
                distance = 40,
                onEnter = function()
                    self:LoadFurnitures(poly)
                end,
                onExit = function()
                    self:UnloadFurnitures('garden')
                end
            })
        }
    end

    ::skip::
    local door = isMlo and self:RegisterMlo() or self.propertyData.door_data
    if not door or not door.length then return end

    local size = vector3(door.length, door.width, 2.5)
    self.entranceTarget = Framework.ox.AddEntrance(door, size, door.h, self.property_id, enter, raid, showcase, showData, targetName)
    if self.owner or self.has_access then
        self:CreateBlip()
    end
end

function Property:UnregisterPropertyEntrance()
    if not self.entranceTarget then return end

    Framework.ox.RemoveTargetZone(self.entranceTarget)
    self.entranceTarget = nil
end

function Property:RegisterGarageZone()
    if not next(self.propertyData.garage_data) then return end
    if not self.owner then return end

    local garageData = self.propertyData.garage_data
    local label = (self.propertyData.street or 'House') .. self.property_id .. " Garage"
    local coords = vec4(garageData.x, garageData.y, garageData.z, garageData.h)

    TriggerEvent("qb-garages:client:addHouseGarage", self.property_id, {
        takeVehicle = { x = garageData.x, y = garageData.y, z = garageData.z, w = garageData.h },
        type = "house",
        label = label,
    })

    self.garageZone = lib.zones.box({
        coords = coords.xyz,
        size = vector3(garageData.length + 5.0, garageData.width + 5.0, 3.5),
        rotation = coords.w,
        debug = Config.DebugMode,
        onEnter = function()
            TriggerEvent('qb-garages:client:setHouseGarage', self.property_id, true)
        end,
    })
end

function Property:UnregisterGarageZone()
    if not self.garageZone then return end

    TriggerEvent("qb-garages:client:removeHouseGarage", self.property_id)

    self.garageZone:remove()
    self.garageZone = nil
end

function Property:EnterShell()
    self = self
    local isMlo = self.propertyData.shell == 'mlo'
    local isIpl = self.propertyData.apartment and Config.Apartments[self.propertyData.apartment]
    self.shellData = Config.Shells[self.propertyData.shell]

    if not isMlo or isIpl then
        DoScreenFadeOut(250)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.25)
        Wait(250)

        if isIpl and isIpl.zone then
            self.mloData = {}
            self.mloData.poly = lib.zones.poly({
                points = isIpl.zone,
                thickness = isIpl.thickness,
                debug = Config.DebugMode,
            })
            local coords = isIpl.interior
            self:RegisterDoorZone(coords)
            SetEntityCoordsNoOffset(cache.ped, coords.x, coords.y, coords.z, false, false, true)
        else
            self:CreateShell()
        end
        self:LoadFurnitures()
    end

    self.inProperty = true
    self:GiveMenus()

    if not isMlo or isIpl then
        DoScreenFadeIn(250)
    end
end

function Property:LeaveShell(skipServer)
    if not self.inProperty then return end

    local isMlo = self.propertyData.shell == 'mlo'
    local apt = self.propertyData.apartment and Config.Apartments[self.propertyData.apartment]
    local isIpl = apt and apt.interior

    if not isMlo or isIpl then
        DoScreenFadeOut(250)
        TriggerServerEvent("InteractSound_SV:PlayOnSource", "houses_door_open", 0.25)
        Wait(250)

        local coords = self:GetDoorCoords()
        if coords then
            SetEntityCoordsNoOffset(cache.ped, coords.x, coords.y, coords.z, false, false, true)
        end

        self:UnloadFurnitures('inside')
        self.propertyData.furnitures = {}
        if not isIpl then
            if self.shell then self.shell:DespawnShell() end
            self.shell = nil
        else
            local mloData = self.mloData
            if mloData and mloData.poly then
                mloData.poly:remove()
                self.mloData = nil
            end
        end
    end

    if not skipServer then
        TriggerServerEvent("vr-housing:server:leaveProperty", self.property_id)
    end

    if self.exitTarget then
        Framework.ox.RemoveTargetZone(self.exitTarget)
        self.exitTarget = nil
    end

    self:RemoveMenus()
    self.doorbellPool = {}
    self.inProperty = false

    if not isMlo or isIpl then
        Wait(250)
        DoScreenFadeIn(250)
    end
end

function Property:GiveMenus(garden)
    if not garden and not self.inProperty then return end

    local accessAndConfig = self.has_access and Config.AccessCanEditFurniture

    if self.owner or accessAndConfig then
        Framework.ox.AddRadialOption(
            "furniture_menu",
            "Furniture Menu",
            "house",
            function()
                Modeler:OpenMenu(self.property_id)
            end,
            "vr-housing:client:openFurnitureMenu",
            { propertyId = self.property_id }
        )
    end

    if self.owner and not garden then
        Framework.ox.AddRadialOption(
            "access_menu",
            "Manage Property",
            "key",
            function()
                self:ManageAccessMenu()
            end,
            "vr-housing:client:openManagePropertyAccessMenu",
            { propertyId = self.property_id }
        )
    end
end

function Property:RemoveMenus(force)
    if not force and not self.inProperty then return end

    Framework.ox.RemoveRadialOption("furniture_menu")

    if self.owner then
        Framework.ox.RemoveRadialOption("access_menu")
    end
end

function Property:ManageAccessMenu()
    if not self.inProperty then return end

    if not self.owner then
        Framework.ox.Notify("Only the owner can do this.", "error")
        return
    end

    local id = "property-" .. self.property_id .. "-access"
    local menu = {
        id = id,
        title = "Manage Access",
        options = {},
    }

    menu.options[#menu.options + 1] = {
        title = "Give Access",
        onSelect = function()
            self:GiveAccessMenu()
        end,
    }

    menu.options[#menu.options + 1] = {
        title = "Revoke Access",
        onSelect = function()
            self:RevokeAccessMenu()
        end,
    }

    lib.registerContext(menu)
    lib.showContext(id)
end

function Property:GiveAccessMenu()
    if not self.inProperty then return end

    if not self.owner then
        return
    end

    local id = "property-" .. self.property_id .. "-access-give"
    local menu = {
        id = id,
        title = "Give Access",
        options = {},
    }

    local players = lib.callback.await("vr-housing:cb:getPlayersInProperty", false, self.property_id) or {}

    if #players > 0 then
        for i = 1, #players do
            local v = players[i]
            menu.options[#menu.options + 1] = {
                title = v.name,
                description = "Give Access",
                onSelect = function()
                    TriggerServerEvent("vr-housing:server:addAccess", self.property_id, v.src)
                end,
            }
        end

        lib.registerContext(menu)
        lib.showContext(id)
    else
        Framework.ox.Notify("No one is in the property", "error")
    end
end

function Property:RevokeAccessMenu()
    if not self.owner then
        return
    end

    local id = "property-" .. self.property_id .. "-access-already"
    local alreadyAccessMenu = {
        id = id,
        title = "Revoke Access",
        options = {},
    }

    local playersWithAccess = lib.callback.await("vr-housing:cb:getPlayersWithAccess", false, self.property_id) or {}

    if #playersWithAccess > 0 then
        for i = 1, #playersWithAccess do
            local v = playersWithAccess[i]
            alreadyAccessMenu.options[#alreadyAccessMenu.options + 1] = {
                title = v.name,
                description = "Remove Access",
                onSelect = function()
                    TriggerServerEvent("vr-housing:server:removeAccess", self.property_id, v.citizenid)
                end,
            }
        end

        lib.registerContext(alreadyAccessMenu)
        lib.showContext(id)
    else
        Framework.ox.Notify("No one has access to this property", "error")
    end
end

function Property:OpenDoorbellMenu()
    if not self.inProperty then return end

    if not next(self.doorbellPool) then
        Framework.ox.Notify("No one is at the door", "error")
        return
    end

    local id = string.format("property-%s-doorbell", self.property_id)
    local menu = {
        id = id,
        title = "People at the door",
        options = {},
    }

    for k, v in pairs(self.doorbellPool) do
        menu.options[#menu.options + 1] = {
            title = v.name,
            onSelect = function()
                TriggerServerEvent(
                    "vr-housing:server:doorbellAnswer",
                    { targetSrc = v.src, property_id = self.property_id }
                )
            end,
        }
    end

    lib.registerContext(menu)
    lib.showContext(id)
end

function Property:LoadFurniture(furniture)
    local coords = self.shellObj and GetOffsetFromEntityInWorldCoords(self.shellObj, furniture.position.x, furniture.position.y, furniture.position.z) or vec3(furniture.position.x, furniture.position.y, furniture.position.z)
    local hash = furniture.object

    lib.requestModel(hash)
    local entity = CreateObjectNoOffset(hash, coords.x, coords.y, coords.z, false, true, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityRotation(entity, furniture.rotation.x, furniture.rotation.y, furniture.rotation.z, 2, true)

    if furniture.type == 'door' and Config.DynamicDoors then
        Debug("Object: "..furniture.label.." wont be frozen")
    else
        FreezeEntityPosition(entity, true)
    end

    if furniture.type and Config.FurnitureTypes[furniture.type] then
        Config.FurnitureTypes[furniture.type](entity, self.property_id, self.propertyData.shell, #self.furnitureObjs == 1 or furniture.id)
    end

    self.furnitureObjs[#self.furnitureObjs + 1] = {
        entity = entity,
        id = furniture.id,
        propertyId = self.property_id,
        label = furniture.label,
        object = furniture.object,
        position = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        },
        rotation = furniture.rotation,
        type = furniture.type,
    }
end

function Property:LoadFurnitures(isGarden)
    self.propertyData.furnitures = lib.callback.await('vr-housing:cb:getFurnitures', false, self.property_id) or {}

    local garden = self.propertyData.garden_data and self.propertyData.garden_data.poly

    for i = 1, #self.propertyData.furnitures do
        local furniture = self.propertyData.furnitures[i]
        local isInGarden = garden and garden:contains(vec3(furniture.position.x, furniture.position.y, furniture.position.z))

        if (isGarden and isInGarden) or (not isGarden and not isInGarden) then
            self:LoadFurniture(furniture)
        end
    end
    return self.propertyData.furnitures
end

function Property:UnloadFurniture(furniture, index)
    local entity = furniture?.entity
    if not entity then
        for i = 1, #self.furnitureObjs do
            if self.furnitureObjs[i]?.id and furniture?.id and self.furnitureObjs[i].id == furniture.id then
                entity = self.furnitureObjs[i]?.entity
                break
            end
        end
    end

    if self.clothingTarget == entity or self.storageTarget[entity] then
        Framework.ox.RemoveTargetEntity(entity)

        if self.clothingTarget == entity then
            self.clothingTarget = nil
        elseif self.storageTarget[entity] then
            self.storageTarget[entity] = nil
        end
    end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)

    if not index then
        for i = 1, #self.furnitureObjs do
            if self.furnitureObjs[i]?.id and furniture?.id and self.furnitureObjs[i].id == furniture.id then
                table.remove(self.furnitureObjs, i)
                break
            end
        end
    end
end

function Property:UnloadFurnitures(which)
    local garden = self.propertyData.garden_data and self.propertyData.garden_data.poly
    for i = #self.furnitureObjs, 1, -1 do
        local furniture = self.furnitureObjs[i]
        local inGarden = garden and garden:contains(vec3(furniture.position.x, furniture.position.y, furniture.position.z))
        if not which or (which == 'garden' and inGarden) or (which == 'inside' and not inGarden) then
            self:UnloadFurniture(furniture, i)
            table.remove(self.furnitureObjs, i)
        end
    end
end

function getCenter(zone)
    local sumX, sumY, sumZ, count = 0, 0, 0, 0
    for i = 1, #zone do
        count = count + 1
        sumX = sumX + zone[i].x
        sumY = sumY + zone[i].y
        sumZ = sumZ + zone[i].z
    end

    local centerX = sumX / count
    local centerY = sumY / count
    local centerZ = sumY / count

    return {x = centerX, y = centerY, z = centerZ}
end

function Property:CreateBlip()
    local door_data = self.propertyData.door_data
    if door_data.x == nil then
        local zone_data = self.propertyData.zone_data
        if type(zone_data) == "string" then
            zone_data = json.decode(zone_data)
        end
        door_data = getCenter(zone_data.points)
    end
    local blip = AddBlipForCoord(door_data.x, door_data.y, door_data.z)
    if self.propertyData.garage_data.x ~= nil then
        SetBlipSprite(blip, 492)
    else
        SetBlipSprite(blip, 40)
    end
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(self.propertyData.street .. " " .. self.property_id)
    EndTextCommandSetBlipName(blip)
    self.blip = blip
end

function Property:RefreshBlip()
    self:RemoveBlip()
    if self.propertyData.apartment then return end
    if self.owner or self.has_access then self:CreateBlip() end
end

function Property:RemoveBlip()
    if not self.blip then return end
    RemoveBlip(self.blip)
    self.blip = nil
end

function Property:RemoveProperty(localOnly)
    self:UnregisterPropertyEntrance()

    local mloData = self.mloData
    if mloData then
        if mloData.point then mloData.point:remove() end
        if mloData.poly then mloData.poly:remove() end
        self.mloData = nil
    end

    local gardenData = self.propertyData.garden_data
    if gardenData then
        if gardenData.point then gardenData.point:remove() end
        if gardenData.poly then gardenData.poly:remove() end
    end

    self:LeaveShell(localOnly)
    self:UnloadFurnitures()
    self:RemoveBlip()
    self:UnregisterGarageZone()

    if self.propertyData.apartment and ApartmentsTable[self.propertyData.apartment] then
        ApartmentsTable[self.propertyData.apartment]:RemoveProperty(self.property_id)
    end
end

local function findFurnitureDifference(new, old)
    local added = {}
    local removed = {}
    local edited = {}

    for i = 1, #new do
        local found = false
        for j = 1, #old do
            if new[i].id == old[j].id then
                found = true
                break
            end
        end
        if not found then
            added[#added + 1] = new[i]
        end
    end

    for i = 1, #old do
        local found = false
        for j = 1, #new do
            if old[i].id == new[j].id then
                found = true
                break
            end
        end
        if not found then
            removed[#removed + 1] = old[i]
        end
    end

    for i = 1, #new do
        if new[i].movedObject then
            edited[#edited + 1] = new[i]
        end
    end

    return added, removed, edited
end

local function prepareFornitures(newFurnitures)
    local furnitures = {}
    for i = 1, #newFurnitures do
        local newFurniture = newFurnitures[i]
        furnitures[i] = {
            id = newFurniture.id,
            label = newFurniture.label,
            object = newFurniture.object,
            position = newFurniture.position,
            rotation = newFurniture.rotation,
            type = newFurniture.type
        }
    end
    return furnitures
end

function Property:UpdateFurnitures(newFurnitures, isGarden)
    if not isGarden and not self.inProperty then return end

    local added, removed, edited = findFurnitureDifference(newFurnitures, self.propertyData.furnitures)
    local poly = self.propertyData.garden_data and self.propertyData.garden_data.poly

    for i = 1, #added do
        local furniture = added[i]
        if not isGarden or poly:contains(vec3(furniture.position.x, furniture.position.y, furniture.position.z)) then
            self:LoadFurniture(furniture)
        end
    end

    for i = 1, #removed do
        local furniture = removed[i]
        self:UnloadFurniture(furniture)
    end

    for i = 1, #edited do
        local furniture = edited[i]
        self:UnloadFurniture(furniture)
        if not isGarden or poly:contains(vec3(furniture.position.x, furniture.position.y, furniture.position.z)) then
            self:LoadFurniture(furniture)
        end
    end

    self.propertyData.furnitures = prepareFornitures(newFurnitures)

    Modeler:UpdateFurnitures()
end

function Property:UpdateDescription(newDescription)
    self.propertyData.description = newDescription
end

function Property:UpdatePrice(newPrice)
    self.propertyData.price = newPrice
end

function Property:UpdateForSale(forSale)
    self.propertyData.for_sale = forSale
end

function Property:UpdateShell(newShell)
    self:LeaveShell()
    self.propertyData.shell = newShell

    if self.inProperty then
        self:EnterShell()
    end
end

function Property:UpdateOwner(newOwner)
    self.propertyData.owner = newOwner

    local citizenid = PlayerData.citizenid

    self.owner = newOwner == citizenid

    if self.propertyData.shell == 'mlo' then
        if self.mloData then
            if self.mloData.point then self.mloData.point:remove() end
            if self.mloData.poly then self.mloData.poly:remove() end
            self.mloData = nil
        end
        self:RegisterMlo()
    end
    self:UnregisterGarageZone()
    self:RegisterGarageZone()

    self:RefreshBlip()

    if not self.inProperty then return end

    self:RemoveMenus()
    self:GiveMenus()
end

function Property:UpdateImgs(newImgs)
    self.propertyData.imgs = newImgs
end

function Property:UpdateDoor(newDoor, newStreet, newRegion)
    self.propertyData.door_data = newDoor
    self.propertyData.street = newStreet
    self.propertyData.region = newRegion

    self:UnregisterPropertyEntrance()
    self:RegisterPropertyEntrance()
end

function Property:UpdateHas_access(newHas_access)
    local citizenid = PlayerData.citizenid
    self.propertyData.has_access = newHas_access
    self.has_access = lib.table.contains(newHas_access, citizenid)
    self:RefreshBlip()

    if not self.inProperty then return end

    self:RemoveMenus()
    self:GiveMenus()
end

function Property:UpdateGarage(newGarage)
    self.propertyData.garage_data = newGarage

    self:UnregisterGarageZone()
    self:RegisterGarageZone()
end

function Property:UpdateApartment(newApartment)
    self:LeaveShell()

    local oldAptName = self.propertyData.apartment
    local oldApt = ApartmentsTable[oldAptName]
    if oldApt then
        oldApt:RemoveProperty(self.property_id)
    end

    self.propertyData.apartment = newApartment

    local newApt = ApartmentsTable[newApartment]

    if newApt then
        newApt:AddProperty(self.property_id)
    end

    TriggerEvent("vr-housing:client:updateApartment", oldAptName, newApartment)
end

function Property.Get(property_id)
    return PropertiesTable[tostring(property_id)]
end

RegisterNetEvent("vr-housing:client:enterProperty", function(property_id)
    local property = Property.Get(property_id)
    if property then
        property:EnterShell()
    end
    if SpawningInto == tostring(property_id) then
        SpawnDone()
    end
end)

RegisterNetEvent("vr-housing:client:updateDoorbellPool", function(property_id, data)
    local property = Property.Get(property_id)
    if property then property.doorbellPool = data end
end)

RegisterNetEvent("vr-housing:client:updateFurniture", function(property_id, furnitures, isGarden)
    local property = Property.Get(property_id)
    if not property then return end

    property:UpdateFurnitures(furnitures, isGarden)
end)

RegisterNetEvent("vr-housing:client:updateProperty", function(type, property_id, ...)
    local property = Property.Get(property_id)

    if not property or type:sub(1, 6) ~= 'Update' or not property[type] then return end

    property[type](property, ...)

    TriggerEvent("vr-housing:client:updatedProperty", property_id)
end)

RegisterNetEvent("vr-housing:client:openFurnitureMenu", function(data)
    Modeler:OpenMenu(data.options.propertyId)
end)

AddEventHandler("vr-housing:client:openManagePropertyAccessMenu", function(data)
    local property = Property.Get(data.options.propertyId)
    if not property then return end

    property:ManageAccessMenu()
end)
