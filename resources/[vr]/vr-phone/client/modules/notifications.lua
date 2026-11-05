-- Notifications and app requests that arrive from the server.

RegisterNetEvent('vr-phone:client:notify', function(n)
    if type(n) ~= 'table' then return end
    SendNUIMessage({ action = 'notify', data = n })
end)

RegisterNetEvent('vr-phone:client:openApp', function(appId)
    if type(appId) ~= 'string' then return end
    Phone.openApp(appId)
end)

-- Battery, signal and charging from the server. The screen keeps the latest values, even while the phone is away.
RegisterNetEvent('vr-phone:client:status', function(status)
    SendNUIMessage({ action = 'status', data = status })
end)

-- A setting the server changed by itself (Low Power Mode switching on at 20%).
RegisterNetEvent('vr-phone:client:settings', function(patch)
    SendNUIMessage({ action = 'settings', data = patch })
end)

-- Nearby share. Someone wants to send you something, and later the answer to a request you sent.
RegisterNetEvent('vr-phone:client:share', function(req)
    if type(req) ~= 'table' then return end
    SendNUIMessage({ action = 'share', data = req })
end)

RegisterNetEvent('vr-phone:client:shareResult', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({ action = 'shareResult', data = result })
end)

RegisterNetEvent('vr-phone:client:shareClosed', function(result)
    if type(result) ~= 'table' then return end
    SendNUIMessage({ action = 'shareClosed', data = result })
end)

-- Another script added or took away an app, or gave the player one. The open phone asks for the new list.
RegisterNetEvent('vr-phone:client:appsChanged', function()
    if not Phone.State.open then return end
    local r = lib.callback.await('vr-phone:apps:sync', false)
    if type(r) == 'table' and r.ok then SendNUIMessage({ action = 'apps', data = r }) end
end)

-- A live message or match from Veil or Hearth. The screen decides whether it is on that screen right now.
RegisterNetEvent('vr-phone:client:social', function(data)
    if type(data) ~= 'table' then return end
    SendNUIMessage({ action = 'social', data = data })
end)
