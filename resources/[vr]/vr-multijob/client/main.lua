Menu = { open = false }

local ERRORS = {
    not_ready = 'The job menu is not ready yet, try again in a moment',
    no_character = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    slow_down = 'Slow down a little',
    failed = 'Something went wrong, try again',
}

function Menu.errorText(code)
    return ERRORS[code] or ERRORS.failed
end

function Menu.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-multijob:api', false, action, data or {})
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Menu.notify(text, kind)
    lib.notify({ title = 'Job menu', description = text, type = kind or 'inform' })
end

function Menu.show()
    if Menu.open then return end
    if not Bridge.loggedIn() then return end
    local res = Menu.api('list')
    if not res.ok then return Menu.notify(Menu.errorText(res.error), 'error') end
    Menu.open = true
    SendNUIMessage({ action = 'open', data = res.data })
    SetNuiFocus(true, true)
end

function Menu.hide()
    if not Menu.open then return end
    Menu.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function Menu.refresh()
    if not Menu.open then return end
    local res = Menu.api('list')
    if res.ok then SendNUIMessage({ action = 'update', data = res.data }) end
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    cb(Menu.api(d.action, type(d.data) == 'table' and d.data or {}))
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    Menu.hide()
end)

RegisterCommand('jobmenu', function() Menu.show() end, false)

lib.addKeybind({
    name = 'jobmenu',
    description = 'Open the job menu',
    defaultKey = 'J',
    onPressed = function() Menu.show() end,
})

Bridge.on('jobChanged', function() Menu.refresh() end)
Bridge.on('dutyChanged', function() Menu.refresh() end)
Bridge.on('playerUnloaded', function() Menu.hide() end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Menu.open then SetNuiFocus(false, false) end
end)
