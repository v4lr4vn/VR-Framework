Hall = { open = false, desk = nil }

local ERRORS = {
    not_ready = 'City Hall is not open yet, try again in a moment',
    no_character = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    too_far = 'You walked away from the desk',
    slow_down = 'Slow down a little',
    failed = 'Something went wrong, try again',
}

function Hall.errorText(code)
    return ERRORS[code] or ERRORS.failed
end

function Hall.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-cityhall:api', false, action, data or {})
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Hall.notify(text, kind)
    lib.notify({ title = 'City Hall', description = text, type = kind or 'inform' })
end

function Hall.show(desk)
    local res = Hall.api('open', {})
    if not res.ok then return Hall.notify(Hall.errorText(res.error), 'error') end
    Hall.open = true
    Hall.desk = desk
    SendNUIMessage({ action = 'open', data = res.data })
    SetNuiFocus(true, true)
end

function Hall.hide()
    if not Hall.open then return end
    Hall.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    cb(Hall.api(d.action, type(d.data) == 'table' and d.data or {}))
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    Hall.hide()
end)

CreateThread(function()
    while true do
        Wait(1000)
        if Hall.open then
            local desk = Hall.desk
            local pos = GetEntityCoords(cache.ped or PlayerPedId())
            if desk and #(pos - vec3(desk.coords.x, desk.coords.y, desk.coords.z)) > (Config.DeskRange or 6.0) + 2.0 then Hall.hide() end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Hall.open then SetNuiFocus(false, false) end
end)
