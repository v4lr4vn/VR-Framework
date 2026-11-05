-- Tells the server when the player is indoors (for wall-socket charging) and plays the power bank animation.
local lastSent, lastState = 0, nil

CreateThread(function()
    local rate = Config.Phone.Battery.charge or {}
    if (rate.indoors or 0) <= 0 then return end
    while true do
        Wait(4000)
        local inside = GetInteriorFromEntity(PlayerPedId()) ~= 0
        local now = GetGameTimer()
        -- Say it when it changes, and keep saying it while it is true (the server lets a report run out).
        if inside ~= lastState or (inside and now - lastSent > 12000) then
            lastState, lastSent = inside, now
            TriggerServerEvent('vr-phone:server:indoors', inside)
        end
    end
end)

RegisterNetEvent('vr-phone:client:plug', function(seconds)
    local ped = PlayerPedId()
    Bridge.notify(locale('charging.plugging'), 'info')
    local ok = pcall(lib.requestAnimDict, 'mp_common', 3000)
    if ok then TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 3.0, 3.0, math.floor(seconds * 1000), 49, 0.0, false, false, false) end
end)

RegisterNetEvent('vr-phone:client:charging', function(key)
    local kind = (key == 'charged') and 'success' or 'error'
    Bridge.notify(locale('charging.' .. tostring(key)), kind)
end)
