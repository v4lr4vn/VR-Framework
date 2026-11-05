-- Fuel level lives in a state bag on the vehicle (`vrFuel`, percent) so every client and the server see it.
-- The native fuel level is kept in step with it so the engine really stops when the tank is empty.
--
-- The server runs with state bag strict mode on, so a client can not write the bag itself. Instead this client keeps the
-- level it is working on in `mine`, and reports changes to the server (`vr-fuel:set`), which checks them and writes the bag.
local STATE = 'vrFuel'
local HOLD = 4000          -- how long (ms) a level this client set is trusted over the state bag
local REPORT_EVERY = 1000  -- ms between reports to the server

local noFuel = {}
for _, name in ipairs(Config.NoFuel) do noFuel[joaat(name)] = true end

local mine = {}    -- [vehicle] = { v = percent, t = time of the last change }
local dirty = {}   -- [vehicle] = true while there is a change the server has not heard about

local function tankSize(vehicle)
    local size = GetVehicleHandlingFloat(vehicle, 'CHandlingData', 'fPetrolTankVolume')
    return (size and size > 0) and size or 65.0
end

local function exempt(vehicle)
    return noFuel[GetEntityModel(vehicle)] or (Config.Classes[GetVehicleClass(vehicle)] or 1.0) <= 0.0
end

-- A vehicle that only exists on this client has no state bag to fall back on, so what this client set always stands.
local function fresh(vehicle)
    local m = mine[vehicle]
    if m == nil then return false end
    return not NetworkGetEntityIsNetworked(vehicle) or GetGameTimer() - m.t < HOLD
end

-- True when the level of this vehicle is known (from this client or from the state bag).
local function known(vehicle)
    return fresh(vehicle) or Entity(vehicle).state[STATE] ~= nil
end

function GetFuel(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return 0.0 end
    if fresh(vehicle) then return mine[vehicle].v end
    local v = Entity(vehicle).state[STATE]
    if v ~= nil then return v + 0.0 end
    return GetVehicleFuelLevel(vehicle) / tankSize(vehicle) * 100.0
end

function SetFuel(vehicle, percent)
    percent = tonumber(percent)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not percent or percent ~= percent then return end
    percent = math.max(0.0, math.min(100.0, percent + 0.0))
    SetVehicleFuelLevel(vehicle, percent / 100.0 * tankSize(vehicle))
    mine[vehicle] = { v = percent, t = GetGameTimer() }
    dirty[vehicle] = true
end

exports('GetFuel', GetFuel)
exports('SetFuel', SetFuel)

-- Tell the server about changes, at most once per vehicle per REPORT_EVERY.
CreateThread(function()
    while true do
        Wait(REPORT_EVERY)
        for vehicle in pairs(dirty) do
            dirty[vehicle] = nil
            local m = mine[vehicle]
            if m and DoesEntityExist(vehicle) and NetworkGetEntityIsNetworked(vehicle) then
                TriggerServerEvent('vr-fuel:set', NetworkGetNetworkIdFromEntity(vehicle), m.v)
            end
        end
        for vehicle, m in pairs(mine) do
            if not DoesEntityExist(vehicle) or (NetworkGetEntityIsNetworked(vehicle) and GetGameTimer() - m.t > 60000 and not dirty[vehicle]) then mine[vehicle] = nil end
        end
    end
end)

-- Other clients follow what the server writes. The client that is changing the level right now ignores the echo of its own reports.
AddStateBagChangeHandler(STATE, nil, function(bag, _, value)
    if type(value) ~= 'number' then return end
    local entity = GetEntityFromStateBagName(bag)
    if entity == 0 or not DoesEntityExist(entity) or fresh(entity) then return end
    SetVehicleFuelLevel(entity, value / 100.0 * tankSize(entity))
end)

-- Consumption: only the driver's client runs it.
CreateThread(function()
    local last = GetGameTimer()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local dt = (now - last) / 1000.0
        last = now

        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and not exempt(vehicle) then
            if not known(vehicle) then
                SetFuel(vehicle, math.random(400, 900) / 10.0)   -- a vehicle nobody set: some fuel, not a full tank
            end
            local fuel = GetFuel(vehicle)
            if IsVehicleEngineOn(vehicle) then
                local rpm = GetVehicleCurrentRpm(vehicle)
                local rate = Config.Usage.idle + (Config.Usage.full - Config.Usage.idle) * rpm * rpm
                fuel = math.max(0.0, fuel - rate * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) * dt)
                SetFuel(vehicle, fuel)
            end
            if fuel <= 0.0 then
                SetVehicleEngineOn(vehicle, false, true, true)
            end
        end
    end
end)

-- An empty tank also stops a running engine immediately.
CreateThread(function()
    while true do
        Wait(300)
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle ~= 0 and GetPedInVehicleSeat(vehicle, -1) == ped and not exempt(vehicle) and GetFuel(vehicle) <= 0.0 then
            SetVehicleEngineOn(vehicle, false, true, true)
        end
    end
end)
