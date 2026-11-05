local function canPick(entity)
    if PickingLock then return false end
    local door = DoorFromEntity(entity)
    return door ~= nil and door.lockpick == true and (DoorConfig.canPickUnlockedDoors or door.state == 1)
end

local function pickLock(entity)
    local door = DoorFromEntity(entity)
    if not door or PickingLock or not door.lockpick then return end
    if not DoorConfig.canPickUnlockedDoors and door.state == 0 then return end
    PickingLock = true
    TriggerServerEvent('vr-doorlock:startLockpick', door.id)
    local ped = PlayerPedId()
    TaskTurnPedToFaceCoord(ped, door.coords.x, door.coords.y, door.coords.z, 4000)
    Wait(500)
    local dict = lib.requestAnimDict('mp_common_heist')
    TaskPlayAnim(ped, dict, 'pick_door', 3.0, 1.0, -1, 49, 0, true, true, true)
    local success = lib.skillCheck(door.lockpickDifficulty or DoorConfig.lockDifficulty)
    if success then
        TriggerServerEvent('vr-doorlock:setState', door.id, door.state == 1 and 0 or 1, true)
    end
    local chance = success and DoorConfig.lockpickBreakChance.success or DoorConfig.lockpickBreakChance.fail
    if math.random(1, 100) <= chance then
        TriggerServerEvent('vr-doorlock:breakLockpick')
        lib.notify({ type = 'error', description = locale('lockpick_broke') })
    end
    StopEntityAnim(ped, 'pick_door', dict, 0)
    RemoveAnimDict(dict)
    PickingLock = false
end

exports('pickClosestDoor', function()
    if not ClosestDoor then return end
    pickLock(ClosestDoor.entity or (ClosestDoor.doors and ClosestDoor.doors[1].entity))
end)

CreateThread(function()
    Bridge.target.addGlobalObject({
        {
            name = 'vr-doorlock:pick',
            label = locale('pick_lock'),
            icon = 'fa-solid fa-user-lock',
            onSelect = function(data) pickLock(data.entity) end,
            canInteract = canPick,
            items = DoorConfig.lockpickItems,
            anyItem = true,
            distance = 1.2,
        },
    })
end)
