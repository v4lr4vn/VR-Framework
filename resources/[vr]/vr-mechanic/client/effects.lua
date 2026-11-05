Effects = {}

local E = Config.Effects
local FIELDS = { drive = 'fInitialDriveForce', brake = 'fBrakeForce', traction = 'fTractionCurveMax', susp = 'fSuspensionForce' }
local orig, applied = {}, {}
local slipUntil, stallAt = 0, 0
local WHEELS = { 0, 1, 4, 5 }

local function originals(veh)
    local o = orig[veh]
    if not o then
        o = {}
        for k, f in pairs(FIELDS) do o[k] = GetVehicleHandlingFloat(veh, 'CHandlingData', f) end
        orig[veh] = o
    end
    return o
end

local function scale(value, below, minMult)
    if value >= below then return 1.0 end
    return minMult + (1.0 - minMult) * (math.max(0, value) / below)
end

function Effects.apply(veh, st)
    local o = originals(veh)
    local want = {
        drive = scale(st.engine, E.engine.below, E.engine.minPower),
        brake = scale(st.brakes, E.brakes.below, E.brakes.minForce),
        traction = scale(st.tyres, E.tyres.below, E.tyres.minGrip),
        susp = scale(st.suspension, E.suspension.below, E.suspension.minForce),
    }
    local a = applied[veh] or {}
    for k, m in pairs(want) do
        if not a[k] or math.abs(a[k] - m) > 0.01 then
            SetVehicleHandlingFloat(veh, 'CHandlingData', FIELDS[k], o[k] * m)
            a[k] = m
        end
    end
    applied[veh] = a
end

function Effects.restore(veh)
    local o = orig[veh]
    if o and DoesEntityExist(veh) then
        for k, f in pairs(FIELDS) do SetVehicleHandlingFloat(veh, 'CHandlingData', f, o[k]) end
    end
    orig[veh], applied[veh] = nil, nil
end

function Effects.reset(veh)
    applied[veh] = nil
end

local function slip()
    slipUntil = GetGameTimer() + 900
    CreateThread(function()
        while GetGameTimer() < slipUntil do
            DisableControlAction(0, 71, true)
            Wait(0)
        end
    end)
end

local function breakdowns(veh, st)
    local now = GetGameTimer()
    local speed = GetEntitySpeed(veh)
    if st.engine < E.engine.stallBelow and speed > 3.0 and now > stallAt and math.random() < 0.06 then
        stallAt = now + 20000
        SetVehicleEngineOn(veh, false, true, true)
        lib.notify({ title = 'Vehicle', description = 'The engine stalled', type = 'error' })
    end
    if st.clutch < E.clutch.below and speed > 4.0 and now > slipUntil and IsControlPressed(0, 71) and math.random() < E.clutch.slipChance then
        slip()
    end
    if st.tyres < E.tyres.burstBelow and speed > 15.0 and math.random() < E.tyres.burstChance then
        local w = WHEELS[math.random(1, #WHEELS)]
        if not IsVehicleTyreBurst(veh, w, false) then SetVehicleTyreBurst(veh, w, false, 1000.0) end
    end
    if st.radiator < E.radiator.below then
        local h = GetVehicleEngineHealth(veh)
        if h > E.radiator.floor then
            SetVehicleEngineHealth(veh, math.max(E.radiator.floor, h - E.radiator.heatPerSecond) + 0.0)
        end
    end
end

CreateThread(function()
    if not Config.Wear.enabled then return end
    while true do
        Wait(1000)
        local veh = Wear.veh
        if veh and DoesEntityExist(veh) and GetPedInVehicleSeat(veh, -1) == cache.ped then
            local st = Wear.current(veh)
            Effects.apply(veh, st)
            if GetIsVehicleEngineRunning(veh) then breakdowns(veh, st) end
        end
    end
end)
