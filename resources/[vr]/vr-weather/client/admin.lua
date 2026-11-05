local open = false

local function close()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    TriggerServerEvent('vr-weather:server:adminClosed')
end

RegisterNetEvent('vr-weather:client:openAdmin', function(payload)
    open = true
    SendNUIMessage({ action = 'open', data = payload, minute = WeatherClient.minute() })
    SetNuiFocus(true, true)
    CreateThread(function()
        while open do
            SendNUIMessage({ action = 'clock', minute = WeatherClient.minute() })
            Wait(500)
        end
    end)
end)

RegisterNetEvent('vr-weather:client:adminState', function(payload)
    if not open then return end
    SendNUIMessage({ action = 'state', data = payload, minute = WeatherClient.minute() })
end)

RegisterNUICallback('action', function(data, cb)
    cb(true)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then return end
    TriggerServerEvent('vr-weather:server:admin', data.name, data.value)
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    close()
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and open then SetNuiFocus(false, false) end
end)
