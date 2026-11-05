Property = {
    property_id = nil,
    propertyData = nil,
    playersInside = nil,
    playersInGarden = nil,
    playersDoorbell = nil,

    raiding = false,
}
Property.__index = Property

local function stashName(propertyId)
    return ("property_%s"):format(propertyId)
end

local function stashLabel(propertyData)
    return ('Property: %s #%s'):format(propertyData.street or propertyData.apartment or 'Unknown', propertyData.property_id)
end

function Property:new(propertyData)
    local self = setmetatable({}, Property)

    self.property_id = tostring(propertyData.property_id)
    self.propertyData = propertyData

    self.playersInside = {}
    self.playersInGarden = {}
    self.playersDoorbell = {}

    local shell = Config.Shells[propertyData.shell]
    Framework.ox.RegisterInventory(stashName(self.property_id), stashLabel(propertyData), shell and shell.stash)

    return self
end

function Property:GetDoorCoords()
    local apt = self.propertyData.apartment and Config.Apartments[self.propertyData.apartment]
    local door = apt and apt.door or self.propertyData.door_data
    if type(door) == 'table' and door.x then
        return { x = door.x, y = door.y, z = door.z, h = door.h or 0.0 }
    end
end

function Property:PlayerEnter(src)
    local _src = tostring(src)
    local isMlo = self.propertyData.shell == 'mlo'
    local apt = self.propertyData.apartment and Config.Apartments[self.propertyData.apartment]
    local isIpl = apt and apt.interior

    self.playersInside[_src] = true

    if not isMlo then
        TriggerClientEvent('qb-weathersync:client:DisableSync', src)
    end

    TriggerClientEvent('vr-housing:client:enterProperty', src, self.property_id)

    if next(self.playersDoorbell) then
        TriggerClientEvent("vr-housing:client:updateDoorbellPool", src, self.property_id, self.playersDoorbell)
        self.playersDoorbell[_src] = nil
    end

    local player = GetPlayer(src)
    if player then
        local insideMeta = player.PlayerData.metadata.inside or {}
        insideMeta.property_id = self.property_id
        insideMeta.property_door = self:GetDoorCoords()
        player.Functions.SetMetaData("inside", insideMeta)
    end

    if not isMlo or isIpl then
        VRCore.Functions.SetPlayerBucket(src, tonumber(self.property_id))
    end
end

function Property:PlayerLeave(src)
    local _src = tostring(src)
    if not self.playersInside[_src] then return end
    self.playersInside[_src] = nil

    TriggerClientEvent('qb-weathersync:client:EnableSync', src)

    local player = GetPlayer(src)
    if player then
        local insideMeta = player.PlayerData.metadata.inside or {}
        insideMeta.property_id = nil
        insideMeta.property_door = nil
        player.Functions.SetMetaData("inside", insideMeta)
    end

    VRCore.Functions.SetPlayerBucket(src, 0)
end

function Property:Forget(src)
    local _src = tostring(src)
    self.playersInside[_src] = nil
    self.playersInGarden[_src] = nil
    self.playersDoorbell[_src] = nil
end

function Property:CheckForAccess(citizenid)
    if not citizenid then return false end
    if self.propertyData.owner == citizenid then return true end
    return lib.table.contains(self.propertyData.has_access or {}, citizenid)
end

function Property:AddToDoorbellPoolTemp(src)
    local _src = tostring(src)

    self.playersDoorbell[_src] = {
        src = src,
        name = GetCharName(src)
    }

    for insideSrc in pairs(self.playersInside) do
        local targetSrc = tonumber(insideSrc)
        Framework.ox.Notify(targetSrc, "Someone is at the door.", "info")
        TriggerClientEvent("vr-housing:client:updateDoorbellPool", targetSrc, self.property_id, self.playersDoorbell)
    end

    Framework.ox.Notify(src, "You rang the doorbell. Just wait...", "info")

    SetTimeout(10000, function()
        if self.playersDoorbell[_src] then
            self.playersDoorbell[_src] = nil
            Framework.ox.Notify(src, "No one answered the door.", "error")
        end

        for insideSrc in pairs(self.playersInside) do
            TriggerClientEvent("vr-housing:client:updateDoorbellPool", tonumber(insideSrc), self.property_id, self.playersDoorbell)
        end
    end)
end

function Property:RemoveFromDoorbellPool(src)
    self.playersDoorbell[tostring(src)] = nil

    for insideSrc in pairs(self.playersInside) do
        TriggerClientEvent("vr-housing:client:updateDoorbellPool", tonumber(insideSrc), self.property_id, self.playersDoorbell)
    end
end

function Property:StartRaid()
    self.raiding = true

    for insideSrc in pairs(self.playersInside) do
        Framework.ox.Notify(tonumber(insideSrc), "This Property is being Raided.", "error")
    end

    SetTimeout(Config.RaidTimer * 60000, function()
        self.raiding = false
    end)
end

local function cleanFurniture(f)
    return {
        id = f.id,
        label = f.label,
        object = f.object,
        position = f.position,
        rotation = f.rotation,
        type = f.type
    }
end

function Property:UpdateFurnitures(furnitures, isGarden, movedId)
    local newfurnitures = {}

    for i = 1, #furnitures do
        newfurnitures[i] = cleanFurniture(furnitures[i])
    end

    self.propertyData.furnitures = newfurnitures

    MySQL.update("UPDATE properties SET furnitures = ? WHERE property_id = ?", { json.encode(newfurnitures), self.property_id })

    local forClients = newfurnitures
    if movedId then
        forClients = {}
        for i = 1, #newfurnitures do
            local f = newfurnitures[i]
            if f.id == movedId then
                f = cleanFurniture(f)
                f.movedObject = true
            end
            forClients[i] = f
        end
    end

    local list = isGarden and self.playersInGarden or self.playersInside
    for playerSrc in pairs(list) do
        TriggerClientEvent("vr-housing:client:updateFurniture", tonumber(playerSrc), self.property_id, forClients, isGarden)
    end
end

function Property:UpdateDescription(data)
    local description = data.description
    local realtorSrc = data.realtorSrc

    if self.propertyData.description == description then return end

    self.propertyData.description = description

    MySQL.update("UPDATE properties SET description = ? WHERE property_id = ?", { description, self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateDescription", self.property_id, description)

    Framework.ox.SendLog("**Changed Description** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdatePrice(data)
    local price = data.price
    local realtorSrc = data.realtorSrc

    if self.propertyData.price == price then return end

    self.propertyData.price = price

    MySQL.update("UPDATE properties SET price = ? WHERE property_id = ?", { price, self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdatePrice", self.property_id, price)

    Framework.ox.SendLog("**Changed Price** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateForSale(data)
    local forsale = data.forsale and true or false
    local realtorSrc = data.realtorSrc

    self.propertyData.for_sale = forsale

    MySQL.update("UPDATE properties SET for_sale = ? WHERE property_id = ?", { forsale and 1 or 0, self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateForSale", self.property_id, forsale)

    if realtorSrc then
        Framework.ox.SendLog("**Changed For Sale** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
    end
end

function Property:UpdateShell(data)
    local shell = data.shell
    local realtorSrc = data.realtorSrc

    if self.propertyData.shell == shell then return end

    self.propertyData.shell = shell

    MySQL.update("UPDATE properties SET shell = ? WHERE property_id = ?", { shell, self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateShell", self.property_id, shell)

    Framework.ox.SendLog("**Changed Shell** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
end

function Property:MloDoorName(index)
    return ('ps_mloproperty%s_%s'):format(self.property_id, index)
end

function Property:ForEachMloDoor(fn)
    if self.propertyData.shell ~= 'mlo' or not DoorResource then return end
    local count = type(self.propertyData.door_data) == 'table' and tonumber(self.propertyData.door_data.count) or 0
    for i = 1, count do
        local door = exports['vr-doorlock']:getDoorFromName(self:MloDoorName(i))
        if door then fn(door) end
    end
end

function Property:addMloDoorsAccess(citizenid)
    self:ForEachMloDoor(function(door)
        local characters = door.characters or {}
        if not lib.table.contains(characters, citizenid) then
            characters[#characters + 1] = citizenid
            exports['vr-doorlock']:editDoor(door.id, { characters = characters })
        end
    end)
end

function Property:removeMloDoorsAccess(citizenid)
    self:ForEachMloDoor(function(door)
        local characters = door.characters or {}
        for index = #characters, 1, -1 do
            if characters[index] == citizenid then
                table.remove(characters, index)
            end
        end
        exports['vr-doorlock']:editDoor(door.id, { characters = characters })
    end)
end

function Property:clearMloDoorsAccess()
    self:ForEachMloDoor(function(door)
        exports['vr-doorlock']:editDoor(door.id, { characters = {} })
    end)
end

local function payCharacter(citizenid, amount, reason)
    if not citizenid or amount <= 0 then return end
    local player = exports['vr-core']:GetPlayerByCitizenId(citizenid)
    if player then
        player.Functions.AddMoney('bank', amount, reason)
        Framework.ox.Notify(player.PlayerData.source, reason, "success")
        return
    end
    MySQL.update("UPDATE vr_players SET money = JSON_SET(money, '$.bank', COALESCE(JSON_EXTRACT(money, '$.bank'), 0) + ?) WHERE citizenid = ?",
        { amount, citizenid })
end

function Property:SetOwner(citizenid)
    self:clearMloDoorsAccess()
    if citizenid then self:addMloDoorsAccess(citizenid) end

    self.propertyData.owner = citizenid
    self.propertyData.has_access = {}
    self.propertyData.furnitures = {}

    MySQL.update("UPDATE properties SET owner_citizenid = ?, has_access = '[]', furnitures = '[]' WHERE property_id = ?",
        { citizenid, self.property_id })

    pcall(function() exports['vr-inventory']:ClearInventory(stashName(self.property_id)) end)

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateOwner", self.property_id, citizenid)
    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateHas_access", self.property_id, {})
end

function Property:UpdateOwner(data)
    local targetSrc = tonumber(data.targetSrc)
    local realtorSrc = tonumber(data.realtorSrc)

    if not realtorSrc then Debug("No Realtor Src found") return end
    if not targetSrc then Debug("No Target Src found") return end

    local previousOwner = self.propertyData.owner
    local price = tonumber(self.propertyData.price) or 0

    local targetPlayer = GetPlayer(targetSrc)
    local realtor = GetPlayer(realtorSrc)
    if not targetPlayer or not realtor then return end

    local PlayerData = targetPlayer.PlayerData
    local citizenid = PlayerData.citizenid

    if previousOwner == citizenid then
        Framework.ox.Notify(targetSrc, "You already own this property", "error")
        Framework.ox.Notify(realtorSrc, "Client already owns this property", "error")
        return
    end

    if self.buying then return end
    self.buying = true

    local targetAllow = lib.callback.await("vr-housing:cb:confirmPurchase", targetSrc, price, self.propertyData.street or self.propertyData.apartment or '', self.property_id)

    if targetAllow ~= "confirm" then
        self.buying = nil
        Framework.ox.Notify(targetSrc, "You did not confirm the purchase", "info")
        Framework.ox.Notify(realtorSrc, "Client did not confirm the purchase", "error")
        return
    end

    targetPlayer = GetPlayer(targetSrc)
    if not targetPlayer or (targetPlayer.PlayerData.money.bank or 0) < price
        or not targetPlayer.Functions.RemoveMoney('bank', price, "Bought Property: " .. (self.propertyData.street or '') .. " " .. self.property_id) then
        self.buying = nil
        Framework.ox.Notify(targetSrc, "You do not have enough money in your bank account", "error")
        Framework.ox.Notify(realtorSrc, "Client does not have enough money in their bank account", "error")
        return
    end

    local realtorGradeLevel = tonumber(realtor.PlayerData.job.grade.level) or 0
    local commission = math.floor(price * (Config.Commissions[realtorGradeLevel] or 0))
    local totalAfterCommission = price - commission

    if previousOwner then
        payCharacter(previousOwner, totalAfterCommission, "Sold Property: " .. (self.propertyData.street or '') .. " " .. self.property_id)
    end

    if commission > 0 then
        realtor.Functions.AddMoney('bank', commission, "Commission from Property: " .. (self.propertyData.street or '') .. " " .. self.property_id)
    end

    self:SetOwner(citizenid)
    self:UpdateForSale({ forsale = false })
    self.buying = nil

    Framework.ox.SendLog("**House Bought** by: **" .. PlayerData.charinfo.firstname .. " " .. PlayerData.charinfo.lastname .. "** for $" .. price .. " from **" .. realtor.PlayerData.charinfo.firstname .. " " .. realtor.PlayerData.charinfo.lastname .. "** !")

    Framework.ox.Notify(targetSrc, "You have bought the property for $" .. price, "success")
    Framework.ox.Notify(realtorSrc, "Client has bought the property for $" .. price, "success")
end

function Property:UpdateImgs(data)
    local imgs = data.imgs
    local realtorSrc = data.realtorSrc

    self.propertyData.extra_imgs = imgs
    self.propertyData.imgs = imgs

    MySQL.update("UPDATE properties SET extra_imgs = ? WHERE property_id = ?", { json.encode(imgs), self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateImgs", self.property_id, imgs)

    Framework.ox.SendLog("**Changed Images** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
end

local function round4(n)
    return math.floor((tonumber(n) or 0) * 10000) / 10000
end

function Property:UpdateDoor(data)
    local door = data.door
    if not door then return end
    local realtorSrc = data.realtorSrc

    local newDoor = {
        x = round4(door.x),
        y = round4(door.y),
        z = round4(door.z),
        h = round4(door.h),
        length = tonumber(door.length) or 1.5,
        width = tonumber(door.width) or 2.2,
        locked = door.locked and true or false,
    }

    self.propertyData.door_data = newDoor
    self.propertyData.street = data.street
    self.propertyData.region = data.region

    MySQL.update("UPDATE properties SET door_data = ?, street = ?, region = ? WHERE property_id = ?",
        { json.encode(newDoor), data.street, data.region, self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateDoor", self.property_id, newDoor, data.street, data.region)

    Framework.ox.SendLog("**Changed Door** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateHas_access(has_access)
    has_access = has_access or {}

    self.propertyData.has_access = has_access

    MySQL.update("UPDATE properties SET has_access = ? WHERE property_id = ?", { json.encode(has_access), self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateHas_access", self.property_id, has_access)
end

function Property:UpdateGarage(data)
    local garage = data.garage
    local realtorSrc = data.realtorSrc

    local newData = {}

    if garage then
        newData = {
            x = round4(garage.x),
            y = round4(garage.y),
            z = round4(garage.z),
            h = round4(garage.h),
            length = tonumber(garage.length) or 3.0,
            width = tonumber(garage.width) or 5.0,
        }
    end

    self.propertyData.garage_data = newData

    MySQL.update("UPDATE properties SET garage_data = ? WHERE property_id = ?", { json.encode(newData), self.property_id })

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateGarage", self.property_id, newData)

    Framework.ox.SendLog("**Changed Garage** of property with id: " .. self.property_id .. " by: " .. GetPlayerName(realtorSrc))
end

function Property:UpdateApartment(data)
    local apartment = data.apartment
    local realtorSrc = data.realtorSrc
    local targetSrc = data.targetSrc

    self.propertyData.apartment = apartment

    MySQL.update("UPDATE properties SET apartment = ? WHERE property_id = ?", { apartment, self.property_id })

    Framework.ox.Notify(realtorSrc, "Changed Apartment of property with id: " .. self.property_id .. " to " .. apartment, "success")
    Framework.ox.Notify(targetSrc, "Changed Apartment to " .. apartment, "success")

    Framework.ox.SendLog("**Changed Apartment** with id: " .. self.property_id .. " by: **" .. GetPlayerName(realtorSrc) .. "** for **" .. GetPlayerName(targetSrc) .. "**")

    TriggerClientEvent("vr-housing:client:updateProperty", -1, "UpdateApartment", self.property_id, apartment)
end

function Property:DeleteProperty(data)
    local realtorSrc = data and data.realtorSrc
    local propertyid = self.property_id
    local realtorName = realtorSrc and GetPlayerName(realtorSrc) or 'server'

    for insideSrc in pairs(self.playersInside) do
        local src = tonumber(insideSrc)
        self:PlayerLeave(src)
        TriggerClientEvent("vr-housing:client:forceLeave", src, propertyid)
    end

    self:ForEachMloDoor(function(door)
        exports['vr-doorlock']:vrDeleteDoor(door.id)
    end)

    pcall(function() exports['vr-inventory']:ClearInventory(stashName(propertyid)) end)

    MySQL.update("DELETE FROM properties WHERE property_id = ?", { propertyid })

    TriggerClientEvent("vr-housing:client:removeProperty", -1, propertyid)

    if realtorSrc then
        Framework.ox.Notify(realtorSrc, "Property with id: " .. propertyid .. " has been removed.", "info")
    end

    Framework.ox.SendLog("**Property Deleted** with id: " .. propertyid .. " by: " .. realtorName)

    PropertiesTable[propertyid] = nil
end

function Property.Get(property_id)
    return PropertiesTable[tostring(property_id)]
end

RegisterNetEvent('vr-housing:server:enterGarden', function(property_id)
    local property = Property.Get(property_id)
    if not property then return end
    property.playersInGarden[tostring(source)] = true
end)

RegisterNetEvent('vr-housing:server:enterProperty', function(property_id, spawn)
    local src = source
    local property = Property.Get(property_id)
    if not property then return end

    local citizenid = GetCitizenid(src)
    if not citizenid then return end

    if property:CheckForAccess(citizenid) then
        if spawn == 'spawn' and property.propertyData.shell == 'mlo' then
            TriggerClientEvent("vr-housing:client:spawnAtMlo", src, property.property_id)
        else
            property:PlayerEnter(src)
        end
        return
    end

    if spawn == 'spawn' then
        TriggerClientEvent("vr-housing:client:forceLeave", src, property.property_id)
        return
    end

    local ringDoorbellConfirmation = lib.callback.await('vr-housing:cb:ringDoorbell', src)
    if ringDoorbellConfirmation == "confirm" then
        property:AddToDoorbellPoolTemp(src)
    end
end)

RegisterNetEvent("vr-housing:server:showcaseProperty", function(property_id)
    local src = source
    local property = Property.Get(property_id)
    if not property then return end

    local PlayerData = GetPlayerData(src)
    if not PlayerData then return end
    local job = PlayerData.job

    if RealtorJobs[job.name] and job.onduty then
        local showcase = lib.callback.await('vr-housing:cb:showcase', src)
        if showcase == "confirm" then
            property:PlayerEnter(src)
        end
    end
end)

RegisterNetEvent('vr-housing:server:raidProperty', function(property_id)
    local src = source
    local property = Property.Get(property_id)
    if not property then return end

    local PlayerData = GetPlayerData(src)
    if not PlayerData then return end
    local job = PlayerData.job
    local jobName = job.name
    local gradeAllowed = (tonumber(job.grade.level) or 0) >= Config.MinGradeToRaid
    local onDuty = job.onduty
    local raidItem = Config.RaidItem

    if not (PoliceJobs[jobName] and onDuty and gradeAllowed) then
        if not PoliceJobs[jobName] then
            Framework.ox.Notify(src, "Only police officers are permitted to perform raids", "error")
        elseif not onDuty then
            Framework.ox.Notify(src, "You must be onduty before performing a raid", "error")
        else
            Framework.ox.Notify(src, "You must be a higher rank before performing a raid", "error")
        end
        return
    end

    if property.raiding then
        Framework.ox.Notify(src, "Raid in progress", "success")
        property:PlayerEnter(src)
        return
    end

    if (exports['vr-inventory']:Search(src, "count", raidItem) or 0) < 1 then
        Framework.ox.Notify(src, "You need a stormram to perform a raid", "error")
        return
    end

    local confirmRaid = lib.callback.await('vr-housing:cb:confirmRaid', src, (property.propertyData.street or property.propertyData.apartment or '') .. " " .. property.property_id, property_id)
    if confirmRaid ~= "confirm" then return end

    property:StartRaid()
    property:PlayerEnter(src)
    Framework.ox.Notify(src, "Raid started", "success")

    if Config.ConsumeRaidItem then
        exports['vr-inventory']:RemoveItem(src, raidItem, 1)
    end

    property:ForEachMloDoor(function(door)
        exports['vr-doorlock']:setDoorState(door.id, 0)
    end)
end)

lib.callback.register('vr-housing:cb:getFurnitures', function(source, property_id)
    local property = Property.Get(property_id)
    if not property then return end
    return property.propertyData.furnitures or {}
end)

lib.callback.register('vr-housing:cb:getPlayersInProperty', function(source, property_id)
    local property = Property.Get(property_id)
    if not property then return end

    local players = {}

    for insideSrc in pairs(property.playersInside) do
        local targetSrc = tonumber(insideSrc)
        if targetSrc ~= source then
            players[#players + 1] = { src = targetSrc, name = GetCharName(targetSrc) }
        end
    end

    return players
end)

RegisterNetEvent('vr-housing:server:leaveProperty', function(property_id)
    local property = Property.Get(property_id)
    if not property then return end
    property:PlayerLeave(source)
end)

RegisterNetEvent("vr-housing:server:doorbellAnswer", function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local targetSrc = tonumber(data.targetSrc)

    local property = Property.Get(data.property_id)
    if not property or not targetSrc then return end

    if not property.playersInside[tostring(src)] then return end
    if not property.playersDoorbell[tostring(targetSrc)] then return end

    property:RemoveFromDoorbellPool(targetSrc)
    property:PlayerEnter(targetSrc)
end)

local catalog = {}
for _, category in ipairs(Config.Furnitures) do
    for _, item in ipairs(category.items) do
        catalog[item.object] = item
    end
end

local function validVec(v)
    local t = type(v)
    return (t == 'table' or t == 'vector3') and tonumber(v.x) ~= nil and tonumber(v.y) ~= nil and tonumber(v.z) ~= nil
end

RegisterNetEvent("vr-housing:server:buyFurniture", function(property_id, items, _, isGarden)
    local src = source
    if type(items) ~= 'table' or #items == 0 or #items > 50 then return end

    local citizenid = GetCitizenid(src)
    local Player = GetPlayer(src)
    local property = Property.Get(property_id)
    if not property or not Player or not property:CheckForAccess(citizenid) then return end
    if property.propertyData.owner ~= citizenid and not Config.AccessCanEditFurniture then return end

    local propertyData = property.propertyData
    local counts = {}
    for _, f in ipairs(propertyData.furnitures) do
        counts[f.object] = (counts[f.object] or 0) + 1
    end

    local price = 0
    local toAdd = {}
    for i = 1, #items do
        local item = items[i]
        local entry = type(item) == 'table' and catalog[item.object]
        if not entry or not validVec(item.position) or not validVec(item.rotation) then
            Framework.ox.Notify(src, "That furniture isn't in the catalog.", "error")
            return
        end
        counts[entry.object] = (counts[entry.object] or 0) + 1
        if entry.max and counts[entry.object] > entry.max then
            Framework.ox.Notify(src, ("You can only place %s %s."):format(entry.max, entry.label), "error")
            return
        end
        price = price + (tonumber(entry.price) or 0)
        toAdd[#toAdd + 1] = {
            id = tostring(item.id or (math.random(100000, 999999) .. property.property_id)),
            object = entry.object,
            label = entry.label,
            position = { x = tonumber(item.position.x) or 0.0, y = tonumber(item.position.y) or 0.0, z = tonumber(item.position.z) or 0.0 },
            rotation = { x = tonumber(item.rotation.x) or 0.0, y = tonumber(item.rotation.y) or 0.0, z = tonumber(item.rotation.z) or 0.0 },
            type = entry.type,
        }
    end

    local money = Player.PlayerData.money
    if price > 0 then
        local paid = (money.cash >= price and Player.Functions.RemoveMoney('cash', price, "Bought furniture"))
            or (money.bank >= price and Player.Functions.RemoveMoney('bank', price, "Bought furniture"))
        if not paid then
            Framework.ox.Notify(src, "You do not have enough money!", "error")
            return
        end
    end

    for i = 1, #toAdd do
        propertyData.furnitures[#propertyData.furnitures + 1] = toAdd[i]
    end

    property:UpdateFurnitures(propertyData.furnitures, isGarden)

    Framework.ox.Notify(src, "You bought furniture for $" .. price, "success")
    Framework.ox.SendLog("**Player " .. GetPlayerName(src) .. "** bought furniture for **$" .. price .. "**")
end)

RegisterNetEvent("vr-housing:server:removeFurniture", function(property_id, itemid)
    local src = source

    local property = Property.Get(property_id)
    if not property then return end

    local citizenid = GetCitizenid(src)
    if not property:CheckForAccess(citizenid) then return end
    if property.propertyData.owner ~= citizenid and not Config.AccessCanEditFurniture then return end

    local currentFurnitures = property.propertyData.furnitures

    for k, v in ipairs(currentFurnitures) do
        if v.id == itemid then
            table.remove(currentFurnitures, k)
            break
        end
    end

    property:UpdateFurnitures(currentFurnitures)
end)

RegisterNetEvent("vr-housing:server:updateFurniture", function(property_id, item)
    local src = source
    if type(item) ~= 'table' then return end

    local property = Property.Get(property_id)
    if not property then return end

    local citizenid = GetCitizenid(src)
    if not property:CheckForAccess(citizenid) then return end
    if property.propertyData.owner ~= citizenid and not Config.AccessCanEditFurniture then return end

    local currentFurnitures = property.propertyData.furnitures
    local moved

    for k, v in ipairs(currentFurnitures) do
        if v.id == item.id then
            moved = v.id
            v.position = validVec(item.position) and { x = tonumber(item.position.x) or 0.0, y = tonumber(item.position.y) or 0.0, z = tonumber(item.position.z) or 0.0 } or v.position
            v.rotation = validVec(item.rotation) and { x = tonumber(item.rotation.x) or 0.0, y = tonumber(item.rotation.y) or 0.0, z = tonumber(item.rotation.z) or 0.0 } or v.rotation
            currentFurnitures[k] = v
            break
        end
    end

    if moved then property:UpdateFurnitures(currentFurnitures, nil, moved) end
end)

RegisterNetEvent("vr-housing:server:addAccess", function(property_id, srcToAdd)
    local src = source
    srcToAdd = tonumber(srcToAdd)

    local citizenid = GetCitizenid(src)
    local property = Property.Get(property_id)
    if not property or not srcToAdd then return end

    if not citizenid or property.propertyData.owner ~= citizenid then
        Framework.ox.Notify(src, "You are not the owner of this property!", "error")
        return
    end

    if not property.playersInside[tostring(srcToAdd)] then return end

    local targetCitizenid = GetCitizenid(srcToAdd)
    local targetPlayer = GetPlayerData(srcToAdd)
    if not targetCitizenid or not targetPlayer then return end

    if property:CheckForAccess(targetCitizenid) then
        Framework.ox.Notify(src, "This person already has access to this property!", "error")
        return
    end

    local has_access = property.propertyData.has_access
    has_access[#has_access + 1] = targetCitizenid
    property:addMloDoorsAccess(targetCitizenid)
    property:UpdateHas_access(has_access)

    Framework.ox.Notify(src, "You added access to " .. targetPlayer.charinfo.firstname .. " " .. targetPlayer.charinfo.lastname, "success")
    Framework.ox.Notify(srcToAdd, "You got access to this property!", "success")
end)

RegisterNetEvent("vr-housing:server:removeAccess", function(property_id, citizenidToRemove)
    local src = source

    local citizenid = GetCitizenid(src)
    local property = Property.Get(property_id)
    if not property or type(citizenidToRemove) ~= 'string' then return end

    if not citizenid or property.propertyData.owner ~= citizenid then
        Framework.ox.Notify(src, "You are not the owner of this property!", "error")
        return
    end

    local has_access = property.propertyData.has_access
    local found = false
    for i = #has_access, 1, -1 do
        if has_access[i] == citizenidToRemove then
            table.remove(has_access, i)
            found = true
        end
    end

    if not found then
        Framework.ox.Notify(src, "This person does not have access to this property!", "error")
        return
    end

    property:removeMloDoorsAccess(citizenidToRemove)
    property:UpdateHas_access(has_access)

    Framework.ox.Notify(src, "You removed access from " .. GetCharNameByCitizenId(citizenidToRemove), "success")

    local removed = exports['vr-core']:GetPlayerByCitizenId(citizenidToRemove)
    if removed then
        Framework.ox.Notify(removed.PlayerData.source, "You lost access to " .. (property.propertyData.street or property.propertyData.apartment or '') .. " " .. property.property_id, "error")
    end
end)

lib.callback.register("vr-housing:cb:getPlayersWithAccess", function(source, property_id)
    local property = Property.Get(property_id)
    if not property then return end
    if property.propertyData.owner ~= GetCitizenid(source) then return end

    local withAccess = {}
    for _, citizenid in ipairs(property.propertyData.has_access) do
        withAccess[#withAccess + 1] = { citizenid = citizenid, name = GetCharNameByCitizenId(citizenid) }
    end

    return withAccess
end)

lib.callback.register('vr-housing:cb:getPropertyInfo', function(source, property_id)
    local property = Property.Get(property_id)
    if not property then return end

    local PlayerData = GetPlayerData(source)
    if not PlayerData then return end
    local job = PlayerData.job
    if not RealtorJobs[job.name] or not job.onduty then return end

    local ownerCid = property.propertyData.owner

    return {
        owner = ownerCid and GetCharNameByCitizenId(ownerCid) or "No Owner",
        street = property.propertyData.street,
        region = property.propertyData.region,
        description = property.propertyData.description,
        for_sale = property.propertyData.for_sale,
        price = property.propertyData.price,
        shell = property.propertyData.shell,
        property_id = property.property_id,
    }
end)

RegisterNetEvent('vr-housing:server:resetMetaData', function()
    local player = GetPlayer(source)
    if not player then return end
    local insideMeta = player.PlayerData.metadata.inside or {}
    insideMeta.property_id = nil
    insideMeta.property_door = nil
    player.Functions.SetMetaData("inside", insideMeta)
end)
