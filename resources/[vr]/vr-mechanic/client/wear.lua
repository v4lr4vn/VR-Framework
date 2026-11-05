Wear = { veh = nil, pending = {}, distance = 0, lastSend = 0, lastBody = nil, warned = {} }

local W = Config.Wear
local SKIP = { [13] = true, [21] = true }

function Wear.tracked(veh)
    return veh ~= 0 and DoesEntityExist(veh) and not SKIP[GetVehicleClass(veh)] and NetworkGetEntityIsNetworked(veh)
end

function Wear.current(veh)
    local st = MU.fullStatus(Entity(veh).state.vr_status)
    if veh == Wear.veh then
        for k, v in pairs(Wear.pending) do
            if st[k] then st[k] = math.max(0, st[k] - v) end
        end
    end
    return st
end

function Wear.send()
    local veh = Wear.veh
    if not veh or not DoesEntityExist(veh) then
        Wear.pending, Wear.distance = {}, 0
        return
    end
    if Wear.distance <= 0 and next(Wear.pending) == nil then return end
    local status = Wear.current(veh)
    TriggerServerEvent('vr-mechanic:server:wear', NetworkGetNetworkIdFromEntity(veh), status, math.floor(Wear.distance))
    Wear.pending, Wear.distance = {}, 0
    Wear.lastSend = GetGameTimer()
end

function Wear.check(veh, entering)
    local st = Wear.current(veh)
    local low = {}
    local keys = {}
    for k in pairs(Config.Parts) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, part in ipairs(keys) do
        local v = st[part]
        if v < W.warnAt then
            if not Wear.warned[part] then
                Wear.warned[part] = true
                low[#low + 1] = ('%s %d%%'):format(Config.Parts[part].label, math.floor(v))
            end
        elseif v >= W.warnAt + 5 then
            Wear.warned[part] = nil
        end
    end
    if #low > 0 then
        lib.notify({
            title = entering and 'This vehicle needs a service' or 'Worn parts',
            description = table.concat(low, ', '),
            type = 'warning',
        })
    end
end

local function enter(veh)
    Wear.send()
    Wear.veh = veh
    Wear.pending, Wear.distance = {}, 0
    Wear.lastBody = GetVehicleBodyHealth(veh)
    Wear.lastSend = GetGameTimer()
    Wear.warned = {}
    Wear.check(veh, true)
end

local function leave()
    Wear.send()
    if Wear.veh and Effects then Effects.restore(Wear.veh) end
    Wear.veh = nil
end

CreateThread(function()
    if not W.enabled then return end
    local dt = W.intervalSeconds
    while true do
        Wait(dt * 1000)
        local ped = cache.ped
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and Wear.tracked(veh) then
            if veh ~= Wear.veh then
                if Wear.veh then leave() end
                enter(veh)
            end
            if GetIsVehicleEngineRunning(veh) then
                local speed = math.min(GetEntitySpeed(veh), W.maxSpeed)
                local dist = speed * dt
                if dist > 0.5 then
                    Wear.distance = Wear.distance + dist
                    local km = dist / 1000.0
                    local fast = speed > W.fastSpeed
                    for part, rate in pairs(W.perKm) do
                        local mult = fast and (W.fastMultiplier[part] or 1.0) or 1.0
                        Wear.pending[part] = (Wear.pending[part] or 0) + rate * km * mult
                    end
                end
            end
            local body = GetVehicleBodyHealth(veh)
            local drop = (Wear.lastBody or body) - body
            if drop >= W.crash.minDrop then
                for part, per in pairs(W.crash.per100Body) do
                    Wear.pending[part] = (Wear.pending[part] or 0) + per * drop / 100.0
                end
            end
            Wear.lastBody = body
            Wear.check(veh)
            if GetGameTimer() - Wear.lastSend >= W.reportSeconds * 1000 then Wear.send() end
        elseif Wear.veh then
            leave()
        end
    end
end)
