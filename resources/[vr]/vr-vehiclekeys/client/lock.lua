local lastToggle = 0
local decided = {}

local function pick()
    local ped = cache.ped or PlayerPedId()
    local inside = GetVehiclePedIsIn(ped, false)
    if inside ~= 0 then
        local kind = Keys.has(inside)
        if kind and kind ~= 'free' then return inside end
        return nil, inside
    end
    local pos = GetEntityCoords(ped)
    local best, bestD, nearest, nearD
    for _, v in ipairs(lib.getNearbyVehicles(pos, Config.Lock.range, true)) do
        local d = #(pos - v.coords)
        local kind = Keys.has(v.vehicle)
        if kind and kind ~= 'free' and (not bestD or d < bestD) then best, bestD = v.vehicle, d end
        if d <= 5.0 and (not nearD or d < nearD) then nearest, nearD = v.vehicle, d end
    end
    return best, nearest
end

local function feedback(veh, locked)
    local ped = cache.ped or PlayerPedId()
    if Config.Lock.animation and GetVehiclePedIsIn(ped, false) == 0 then
        local dict = lib.requestAnimDict('anim@mp_player_intmenu@key_fob@')
        if dict then
            TaskPlayAnim(ped, dict, 'fob_click', 8.0, 8.0, 900, 48, 0.0, false, false, false)
        end
    end
    PlaySoundFromEntity(-1, locked and 'Remote_Control_Close' or 'Remote_Control_Open', veh, 'PI_Menu_Sounds', true, 0)
    CreateThread(function()
        for _ = 1, Config.Lock.flashes do
            if not DoesEntityExist(veh) then return end
            SetVehicleLights(veh, 2)
            if Config.Lock.horn then StartVehicleHorn(veh, 60, joaat('HELDDOWN'), false) end
            Wait(160)
            SetVehicleLights(veh, 0)
            Wait(160)
        end
    end)
end

function Keys.applyLock(veh, locked)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return end
    SetVehicleDoorsLocked(veh, locked and 2 or 1)
end

function Keys.toggleLock()
    local t = GetGameTimer()
    if t - lastToggle < Config.Lock.cooldown then return end
    lastToggle = t
    local veh, near = pick()
    if not veh then
        if near then Keys.notify(Keys.errorText('no_keys'), 'error') end
        return
    end
    if not NetworkGetEntityIsNetworked(veh) then return end
    local res = Keys.api('toggle', { netId = NetworkGetNetworkIdFromEntity(veh) })
    if not res.ok then return Keys.notify(Keys.errorText(res.error), 'error') end
    local locked = res.data.locked == true
    Keys.applyLock(veh, locked)
    feedback(veh, locked)
    Keys.notify(locked and 'Vehicle locked' or 'Vehicle unlocked', locked and 'inform' or 'success')
end

lib.addKeybind({
    name = 'lock',
    description = 'Lock or unlock your vehicle',
    defaultKey = 'L',
    onPressed = function() Keys.toggleLock() end,
})

RegisterCommand('lock', function() Keys.toggleLock() end, false)

AddStateBagChangeHandler('vr_locked', nil, function(bagName, _, value)
    if type(value) ~= 'boolean' then return end
    CreateThread(function()
        for _ = 1, 20 do
            local ent = GetEntityFromStateBagName(bagName)
            if ent and ent ~= 0 and DoesEntityExist(ent) then
                Keys.applyLock(ent, value)
                return
            end
            Wait(100)
        end
    end)
end)

local function ambient(veh)
    if Keys.bag(veh, 'vr_plate') or Keys.bag(veh, 'vr_jobveh') or Keys.bag(veh, 'vr_locked') ~= nil then return false end
    local plate = Keys.plateOf(veh)
    if plate and Keys.held[plate] then return false end
    return IsVehicleSeatFree(veh, -1) and GetVehicleDoorLockStatus(veh) <= 1
end

CreateThread(function()
    while true do
        Wait(250)
        local chance = tonumber(Config.NpcVehicles.lockedChance) or 0
        local ped = cache.ped or PlayerPedId()
        if chance > 0 and GetVehiclePedIsIn(ped, false) == 0 then
            local veh = GetVehiclePedIsTryingToEnter(ped)
            if veh and veh ~= 0 and not decided[veh] then
                decided[veh] = true
                if ambient(veh) and math.random(100) <= chance then
                    SetVehicleDoorsLocked(veh, 2)
                    ClearPedTasks(ped)
                    Keys.notify('The doors are locked', 'error')
                end
            end
        else
            Wait(750)
        end
        if next(decided) and math.random(100) <= 3 then
            local n = 0
            for _ in pairs(decided) do n = n + 1 end
            if n > 400 then decided = {} end
        end
    end
end)
