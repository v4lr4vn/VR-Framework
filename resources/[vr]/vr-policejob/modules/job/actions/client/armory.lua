local SetEntityCoords = SetEntityCoords
local SetEntityHeading = SetEntityHeading
local SetCurrentPedWeapon = SetCurrentPedWeapon
local CreateObject = CreateObject
local AttachEntityToEntity = AttachEntityToEntity
local GetPedBoneIndex = GetPedBoneIndex
local Wait = Wait
local TaskPlayAnim = TaskPlayAnim
local DeleteEntity = DeleteEntity
local SetEntityRotation = SetEntityRotation
local ClearPedTasks = ClearPedTasks
local IsEntityPlayingAnim = IsEntityPlayingAnim
local TriggerServerEvent = TriggerServerEvent

local function handOver(policePed, playerPed, animDict, equipmentItem)
    TaskPlayAnim(policePed, animDict, 'pistol_on_counter_cop', 1.0, -1, 1.0, 0, 0, 0, 0, 0)

    Wait(1100)

    local prop = equipmentItem.prop
    local itemModel = prop and lib.requestModel(prop.model)
    local object, placedObject

    if itemModel then
        local playerCoords = cache.coords
        object = CreateObject(itemModel, playerCoords.x, playerCoords.y, playerCoords.z + 1, true, true, true)
        AttachEntityToEntity(object, policePed, GetPedBoneIndex(policePed, 57005), 0, 0, -0, 0, 0, 0, true, true, false, true, 1, true)
    end

    TaskPlayAnim(playerPed, animDict, 'pistol_on_counter', 1.0, -1, 1.0, 0, 0, 0, 0, 0)

    Wait(2000)

    if object then DeleteEntity(object) end
    if itemModel then
        placedObject = CreateObject(itemModel, prop.placePos, true, true, true)
        SetEntityRotation(placedObject, 90.0, 0.0, -90.0, 2, true)
    end
    Wait(2000)
    if placedObject then
        AttachEntityToEntity(placedObject, playerPed, GetPedBoneIndex(playerPed, 57005), 0, 0, -0, -0, 0, -0, true, true, false, true, 1, true)
    end

    while IsEntityPlayingAnim(playerPed, animDict, 'pistol_on_counter', 3) do
        Wait(0)
    end

    ClearPedTasks(policePed)
    return placedObject
end

local function getEquipment(data)
    utils.debug("Getting equipment")

    local playerPed = cache.ped
    local policePed = data.entity

    SetEntityCoords(playerPed, data.playerPos.x, data.playerPos.y, data.playerPos.z)
    SetEntityHeading(playerPed, data.playerPos.w)
    SetCurrentPedWeapon(playerPed, joaat('weapon_unarmed'), true)

    local animDict = lib.requestAnimDict('mp_cop_armoury')
    local jobGrade = getPlayerJobGrade()
    local equipment = data.equipment[jobGrade] or data.equipment[1]

    for index, equipmentItem in ipairs(equipment or {}) do
        local playerItem = tonumber(exports['vr-inventory']:Search('count', equipmentItem.item)) or 0

        if playerItem >= equipmentItem.quantity then
            utils.showNotification(equipmentItem.label .. ' ' .. locale('already_have_item'))
        else
            local inStock = true
            if data.require_storage then
                local storageItem = lib.callback.await('vr-policejob:getItemCount', false, data.storage.stashId, equipmentItem.item) or 0
                inStock = tonumber(storageItem) and storageItem >= 1
            end

            if inStock then
                utils.debug("Getting item " .. equipmentItem.item)
                local placedObject = handOver(policePed, playerPed, animDict, equipmentItem)
                TriggerServerEvent('vr-policejob:server:takeArmoryItem', data.stationId, index)
                if placedObject then DeleteEntity(placedObject) end
            else
                utils.showNotification(equipmentItem.label .. ' ' .. locale('no_item_in_storage'))
            end
        end
    end
end

function initArmory(data)
    local ped = utils.createPed(data.model, data.pedPos)
    local options = {
        {
            name = 'armory' .. ped,
            label = locale('armory_interact_label'),
            icon = 'fa-solid fa-road',
            canInteract = function(entity, distance, coords, name, bone)
                if IsEntityPlayingAnim(entity, 'mp_cop_armoury', 'pistol_on_counter_cop', 3) or IsEntityPlayingAnim(entity, 'mp_cop_armoury', 'rifle_on_counter_cop', 3) then
                    return false
                end

                return hasJob(data.jobs) and player.inDuty()
            end,
            onSelect = function(entity)
                data.entity = entity.entity
                getEquipment(data)
            end
        },
        {
            name = 'armory_storage' .. ped,
            label = locale('armory_interact_storage_label'),
            icon = 'fa-solid fa-road',
            canInteract = function(entity, distance, coords, name, bone)
                return data.require_storage and hasJob(data.jobs) and getPlayerJobGrade() >= data.storage.minGradeAccess and player.inDuty()
            end,
            onSelect = function(entity)
                exports['vr-inventory']:openInventory('stash', data.storage.stashId)
            end
        }
    }
    exports['vr-target']:addLocalEntity(ped, options)
end
