local U = InvUtil

Inventory = {}

Inventory.Dumpsters = { 218085040, 666561306, -58485588, -206690185, 1511880420, 682791951 }

local dumpsterSet = {}
for i = 1, #Inventory.Dumpsters do dumpsterSet[Inventory.Dumpsters[i]] = true end

function Inventory.IsDumpster(model) return dumpsterSet[model] == true end

if shared.networkdumpsters then
    SetInterval(function()
        local objects = GetGamePool('CObject')
        for i = 1, #objects do
            local object = objects[i]
            local state = Entity(object).state
            if state.isDumpster == nil then
                local isDumpster = dumpsterSet[GetEntityModel(object)] == true
                state:set('isDumpster', isDumpster, false)
                if isDumpster then FreezeEntityPosition(object, true) end
            end
        end
    end, 3000)
end

function Inventory.OpenDumpster(entity)
    if shared.networkdumpsters then
        client.openInventory('dumpster', GetEntityCoords(entity))
        return
    end

    local netId = NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity)
    if not netId then
        local coords = GetEntityCoords(entity)
        entity = GetClosestObjectOfType(coords.x, coords.y, coords.z, 0.1, GetEntityModel(entity), true, true, true)
        netId = entity ~= 0 and NetworkGetEntityIsNetworked(entity) and NetworkGetNetworkIdFromEntity(entity)
    end

    if netId then client.openInventory('dumpster', 'dumpster' .. netId) end
end

local Vehicles = InvData('vehicles')
Inventory.Vehicles = Vehicles
local backDoors = { 2, 3 }

function Inventory.CanAccessTrunk(entity)
    if cache.vehicle or not NetworkGetEntityIsNetworked(entity) then return end
    if IsEntityDead(entity) then return end

    local model = GetEntityModel(entity)
    local class = GetVehicleClass(entity)
    local storage = Vehicles.Storage and Vehicles.Storage[model]

    if storage == 0 or storage == 1 or (not Vehicles.trunk[class] and not (Vehicles.trunk.models and Vehicles.trunk.models[model])) then return end

    local doorId = storage and 4 or 5

    if not (Vehicles.trunk.boneIndex and Vehicles.trunk.boneIndex[model]) and not GetIsDoorValid(entity, doorId) then
        if class ~= 11 and (doorId ~= 5 or GetEntityBoneIndexByName(entity, 'boot') ~= -1 or not GetIsDoorValid(entity, 2)) then return end
        if class ~= 11 then doorId = backDoors end
    end

    local min, max = GetModelDimensions(model)
    local scale = storage and vec3(0.5, 1, 0.5) or vec3(0.5, 0, 0.5)
    local offset = vec3((max.x - min.x) * scale.x + min.x, (max.y - min.y) * scale.y + min.y, (max.z - min.z) * scale.z + min.z)
    offset = GetOffsetFromEntityInWorldCoords(entity, offset.x, offset.y, offset.z)

    if #(GetEntityCoords(cache.ped) - offset) < 1.5 then return doorId end
end

function Inventory.OpenTrunk(entity)
    local door = Inventory.CanAccessTrunk(entity)
    if not door then return end

    local coords = GetEntityCoords(entity)
    TaskTurnPedToFaceCoord(cache.ped, coords.x, coords.y, coords.z, 0)

    if not client.openInventory('trunk', { netid = NetworkGetNetworkIdFromEntity(entity), entity = entity, door = door }) then return end

    if type(door) == 'table' then
        for i = 1, #door do SetVehicleDoorOpen(entity, door[i], false, false) end
    else
        SetVehicleDoorOpen(entity, door, false, false)
    end
end

if shared.target then
    CreateThread(function()
        while GetResourceState('vr-target') ~= 'started' do Wait(500) end
        Bridge.target.addModel(Inventory.Dumpsters, {
            icon = 'fas fa-dumpster',
            label = locale('search_dumpster'),
            onSelect = function(data) return Inventory.OpenDumpster(data.entity) end,
            distance = 2,
        })
        Bridge.target.addGlobalVehicle({
            icon = 'fas fa-truck-ramp-box',
            label = locale('open_label', locale('storage')),
            distance = 1.5,
            canInteract = function(entity) return Inventory.CanAccessTrunk(entity) ~= nil end,
            onSelect = function(data) return Inventory.OpenTrunk(data.entity) end,
        })
    end)
end

local function waitLoaded()
    if PlayerData.loaded then return true end
    if not coroutine.isyieldable() then return false end
    local started = GetGameTimer()
    repeat Wait(100) until PlayerData.loaded or GetGameTimer() - started > 30000
    return PlayerData.loaded == true
end

local function assertMetadata(metadata)
    if metadata and type(metadata) ~= 'table' then metadata = { type = metadata } end
    return metadata
end

function Inventory.Search(search, item, metadata)
    if not waitLoaded() then return false end
    if not item then return false end

    if search == 'slots' then search = 1 elseif search == 'count' then search = 2 end
    if type(item) == 'string' then item = { item } end
    if type(item) ~= 'table' then return false end
    metadata = assertMetadata(metadata)

    local total = #item
    local out = {}

    for i = 1, total do
        local name = U.itemName(item[i])
        if name then
            if search == 1 then out[name] = {} elseif search == 2 then out[name] = 0 end
            for _, v in pairs(PlayerData.inventory) do
                if v.name == name then
                    if not v.metadata then v.metadata = {} end
                    if not metadata or U.contains(v.metadata, metadata) then
                        if search == 1 then
                            out[name][#out[name] + 1] = PlayerData.inventory[v.slot]
                        elseif search == 2 then
                            out[name] = out[name] + v.count
                        end
                    end
                end
            end
            if search == 1 then table.sort(out[name], function(a, b) return a.slot < b.slot end) end
        end
    end

    if next(out) then
        if total == 1 then return out[U.itemName(item[1])] end
        return out
    end
    return false
end

exports('Search', Inventory.Search)
exports('GetPlayerItems', function() return PlayerData.inventory end)
exports('GetPlayerWeight', function() return PlayerData.weight end)
exports('GetPlayerMaxWeight', function() return PlayerData.maxWeight end)

local function eachMatch(itemName, metadata, strict, fn)
    local inventory = PlayerData.inventory
    local item = Items(itemName)
    if not inventory or not item then return false end
    metadata = assertMetadata(metadata)
    local match = strict and U.matches or U.contains
    local slots = {}
    for slot in pairs(inventory) do slots[#slots + 1] = slot end
    table.sort(slots)
    for i = 1, #slots do
        local slotData = inventory[slots[i]]
        if slotData and slotData.name == item.name and (not metadata or match(slotData.metadata or {}, metadata)) then
            if fn(slotData) == false then break end
        end
    end
    return true
end

function Inventory.GetSlotWithItem(itemName, metadata, strict)
    local found
    eachMatch(itemName, metadata, strict, function(slot)
        found = slot
        return false
    end)
    return found
end

exports('GetSlotWithItem', Inventory.GetSlotWithItem)

function Inventory.GetSlotIdWithItem(itemName, metadata, strict)
    local slot = Inventory.GetSlotWithItem(itemName, metadata, strict)
    return slot and slot.slot
end

exports('GetSlotIdWithItem', Inventory.GetSlotIdWithItem)

function Inventory.GetSlotsWithItem(itemName, metadata, strict)
    local out = {}
    if not eachMatch(itemName, metadata, strict, function(slot) out[#out + 1] = slot end) then return end
    return out
end

exports('GetSlotsWithItem', Inventory.GetSlotsWithItem)

function Inventory.GetSlotIdsWithItem(itemName, metadata, strict)
    local items = Inventory.GetSlotsWithItem(itemName, metadata, strict)
    if not items then return end
    for i = 1, #items do items[i] = items[i].slot end
    return items
end

exports('GetSlotIdsWithItem', Inventory.GetSlotIdsWithItem)

function Inventory.GetItemCount(itemName, metadata, strict)
    local item = Items(itemName)
    if not PlayerData.inventory or not item then return 0 end
    if not metadata then return item.count or 0 end
    local count = 0
    eachMatch(itemName, metadata, strict, function(slot) count = count + slot.count end)
    return count
end

exports('GetItemCount', Inventory.GetItemCount)

local textPrompts = {
    evidence = { options = { icon = 'fa-box-archive' }, message = Utils.prompt(locale('open_police_evidence')) },
    stash = { options = { icon = 'fa-warehouse' }, message = Utils.prompt(locale('open_stash')) },
}

local function openEvidence() client.openInventory('policeevidence') end

local function removeTarget(entry)
    if entry.point then
        Utils.clearPrompt(entry.point)
        entry.point:remove()
        entry.point = nil
    elseif entry.zoneId then
        Bridge.target.removeZone(entry.zoneId)
        entry.zoneId = nil
    end
end

Inventory.Evidence = setmetatable(InvData('evidence'), {
    __call = function(self)
        for _, evidence in pairs(self) do
            removeTarget(evidence)
            if client.hasGroup(shared.police) then
                if shared.target then
                    if evidence.target then
                        evidence.zoneId = Utils.CreateBoxZone(U.deepclone(evidence.target), {
                            {
                                icon = evidence.target.icon or 'fas fa-box-archive',
                                label = locale('open_police_evidence'),
                                groups = shared.police,
                                onSelect = openEvidence,
                                iconColor = evidence.target.iconColor,
                            },
                        })
                    end
                elseif evidence.coords then
                    evidence.point = lib.points.new({
                        coords = evidence.coords,
                        distance = 16,
                        inv = 'policeevidence',
                        marker = client.evidencemarker,
                        prompt = textPrompts.evidence,
                        nearby = Utils.nearbyMarker,
                    })
                end
            end
        end
    end,
})

Inventory.Stashes = setmetatable(InvData('stashes'), {
    __call = function(self)
        for _, stash in pairs(self) do
            if stash.jobs then stash.groups = stash.jobs end
            removeTarget(stash)
            if not stash.groups or client.hasGroup(stash.groups) then
                if shared.target then
                    if stash.target then
                        stash.zoneId = Utils.CreateBoxZone(U.deepclone(stash.target), {
                            {
                                icon = stash.target.icon or 'fas fa-warehouse',
                                label = stash.target.label or locale('open_stash'),
                                groups = stash.groups,
                                onSelect = function() client.openInventory('stash', stash.name) end,
                                iconColor = stash.target.iconColor,
                            },
                        })
                    end
                elseif stash.coords then
                    stash.point = lib.points.new({
                        coords = stash.coords,
                        distance = 16,
                        inv = 'stash',
                        invId = stash.name,
                        marker = client.evidencemarker,
                        prompt = textPrompts.stash,
                        nearby = Utils.nearbyMarker,
                    })
                end
            end
        end
    end,
})

RegisterNetEvent('vr-inventory:refreshMaxWeight', function(data)
    if type(data) ~= 'table' then return end
    if data.inventoryId == cache.serverId then
        PlayerData.maxWeight = data.maxWeight
        data.inventoryId = 'player'
    end
    SendNUIMessage({ action = 'slots', data = { weightData = { inventoryId = data.inventoryId, maxWeight = data.maxWeight } } })
end)

RegisterNetEvent('vr-inventory:refreshSlotCount', function(data)
    if type(data) ~= 'table' then return end
    if data.inventoryId == cache.serverId then data.inventoryId = 'player' end
    SendNUIMessage({ action = 'slots', data = { slotsData = { inventoryId = data.inventoryId, slots = data.slots } } })
end)
