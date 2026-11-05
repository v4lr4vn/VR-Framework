local busy = false

local function finish(res, veh, success, label)
    if not res.ok then return Keys.notify(Keys.errorText(res.error), 'error') end
    local d = res.data
    if d.broke then Keys.notify('Your lockpick snapped', 'error') end
    if d.alarm and DoesEntityExist(veh) then
        SetVehicleAlarm(veh, true)
        StartVehicleAlarm(veh)
    end
    if success then
        Keys.notify(label, 'success')
    else
        Keys.notify('You could not get it done', 'error')
    end
end

function Keys.lockpick(veh)
    if busy or not veh or not DoesEntityExist(veh) or not NetworkGetEntityIsNetworked(veh) then return end
    busy = true
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local start = Keys.api('breakin.start', { netId = netId, kind = 'lockpick' })
    if not start.ok then
        busy = false
        return Keys.notify(Keys.errorText(start.error), 'error')
    end
    local ped = cache.ped or PlayerPedId()
    TaskTurnPedToFaceEntity(ped, veh, 800)
    Wait(800)
    local dict = lib.requestAnimDict('mp_common_heist')
    if dict then TaskPlayAnim(ped, dict, 'pick_door', 3.0, 1.0, -1, 49, 0, false, false, false) end
    local success = lib.skillCheck(Config.Lockpick.skill) == true
    ClearPedTasks(ped)
    if dict then RemoveAnimDict(dict) end
    local res = Keys.api('breakin.done', { success = success })
    if res.ok and success then Keys.applyLock(veh, false) end
    finish(res, veh, success, 'The lock gives way')
    busy = false
end

function Keys.hotwire()
    if busy then return end
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 or GetPedInVehicleSeat(veh, -1) ~= ped then return end
    if Keys.has(veh) then return Keys.notify(Keys.errorText('have_keys'), 'inform') end
    if not NetworkGetEntityIsNetworked(veh) then return end
    busy = true
    local start = Keys.api('breakin.start', { netId = NetworkGetNetworkIdFromEntity(veh), kind = 'hotwire' })
    if not start.ok then
        busy = false
        return Keys.notify(Keys.errorText(start.error), 'error')
    end
    local dict = lib.requestAnimDict('veh@std@ds@base')
    if dict then TaskPlayAnim(ped, dict, 'hotwire', 8.0, 8.0, -1, 1, 0.0, false, false, false) end
    local success = lib.skillCheck(Config.Hotwire.skill) == true
    if dict then
        StopAnimTask(ped, dict, 'hotwire', 1.0)
        RemoveAnimDict(dict)
    end
    local res = Keys.api('breakin.done', { success = success })
    if res.ok and success then
        Keys.hotLocal[veh] = true
        SetVehicleEngineOn(veh, true, false, true)
    end
    finish(res, veh, success, 'The engine turns over')
    busy = false
end

Keys.hotwireBind = lib.addKeybind({
    name = 'hotwire',
    description = 'Hotwire the vehicle you are driving',
    defaultKey = 'H',
    onPressed = function() Keys.hotwire() end,
})

RegisterCommand('hotwire', function() Keys.hotwire() end, false)

CreateThread(function()
    Bridge.target.addGlobalVehicle({
        {
            name = 'vr-vehiclekeys:lockpick',
            label = 'Pick the lock',
            icon = 'fa-solid fa-unlock-keyhole',
            distance = 2.0,
            items = Config.Lockpick.items,
            anyItem = true,
            canInteract = function(entity)
                if busy or not entity or entity == 0 then return false end
                return GetVehicleDoorLockStatus(entity) >= 2 and not Keys.has(entity)
            end,
            onSelect = function(data) Keys.lockpick(type(data) == 'table' and data.entity or data) end,
        },
    })
end)

local function jack(npc, veh)
    local ped = cache.ped or PlayerPedId()
    SetBlockingOfNonTemporaryEvents(npc, false)
    TaskLeaveVehicle(npc, veh, 0)
    local t = GetGameTimer()
    while IsPedInVehicle(npc, veh, false) and GetGameTimer() - t < 5000 do Wait(100) end
    if DoesEntityExist(npc) then TaskReactAndFleePed(npc, ped) end
    if not NetworkGetEntityIsNetworked(veh) then return end
    local res = Keys.api('claim', { netId = NetworkGetNetworkIdFromEntity(veh), how = 'carjack' })
    if res.ok then Keys.notify('They left the keys in it', 'success') end
end

CreateThread(function()
    local cfg = Config.Carjack
    if not cfg.enabled then return end
    local aimed, since = nil, 0
    local done = {}
    while true do
        local ped = cache.ped or PlayerPedId()
        if GetVehiclePedIsIn(ped, false) == 0 and IsPlayerFreeAiming(PlayerId()) and IsPedArmed(ped, 4) then
            local has, ent = GetEntityPlayerIsFreeAimingAt(PlayerId())
            local ok = false
            if has and ent and ent ~= 0 and IsEntityAPed(ent) and not IsPedAPlayer(ent) and IsPedInAnyVehicle(ent, false) then
                local veh = GetVehiclePedIsIn(ent, false)
                if GetPedInVehicleSeat(veh, -1) == ent and not done[veh] and #(GetEntityCoords(ped) - GetEntityCoords(ent)) <= cfg.distance then
                    ok = true
                    if aimed ~= ent then aimed, since = ent, GetGameTimer() end
                    if GetGameTimer() - since >= cfg.aimTime then
                        done[veh] = true
                        aimed = nil
                        CreateThread(function() jack(ent, veh) end)
                    end
                end
            end
            if not ok then aimed = nil end
            Wait(0)
        else
            aimed = nil
            Wait(250)
        end
    end
end)
