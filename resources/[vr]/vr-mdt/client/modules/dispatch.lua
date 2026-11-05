local blips = {}
local latest = nil
local respondBind = nil
local mutedUntil = 0

local function dropBlip(id)
    local b = blips[id]
    if not b then return end
    for _, h in ipairs(b.handles) do
        if DoesBlipExist(h) then RemoveBlip(h) end
    end
    blips[id] = nil
end

local function addBlip(call)
    dropBlip(call.id)
    local c = call.coords
    local style = call.blip or {}
    local radius = AddBlipForRadius(c.x + 0.0, c.y + 0.0, c.z + 0.0, 60.0)
    SetBlipColour(radius, style.color or 1)
    SetBlipAlpha(radius, 90)
    SetBlipHighDetail(radius, true)
    local icon = AddBlipForCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    SetBlipSprite(icon, style.sprite or 280)
    SetBlipColour(icon, style.color or 1)
    SetBlipScale(icon, style.scale or 1.0)
    SetBlipAsShortRange(icon, false)
    SetBlipFlashes(icon, style.flash == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('%s %s'):format(call.code or '', call.title or 'Call'))
    EndTextCommandSetBlipName(icon)
    blips[call.id] = { handles = { radius, icon }, expires = GetGameTimer() + Config.Dispatch.blipSeconds * 1000 }
end

local function playAlertSound(priority)
    if priority == 1 then
        PlaySoundFrontend(-1, 'Event_Start_Text', 'GTAO_FM_Events_Soundset', false)
    else
        PlaySoundFrontend(-1, 'Lose_1st', 'GTAO_FM_Events_Soundset', false)
    end
end

local function customSound(call)
    local sounds = Config.CallSounds
    local entry = sounds and call.code and sounds[call.code]
    if type(entry) ~= 'table' or type(entry.file) ~= 'string' then return false end
    local resource = GetCurrentResourceName()
    if not LoadResourceFile(resource, entry.file) then return false end
    Mdt.send({ type = 'playSound', url = ('https://cfx-nui-%s/%s'):format(resource, entry.file), volume = entry.volume or 0.7 })
    return true
end

RegisterNetEvent('vr-mdt:client:alert', function(call)
    if type(call) ~= 'table' or not call.coords then return end
    if not Mdt.isResponder() and not Mdt.isDispatcher() then return end
    local street = call.street or Mdt.streetAt(call.coords.x, call.coords.y, call.coords.z)
    latest = call
    addBlip(call)
    if GetGameTimer() >= mutedUntil and not customSound(call) then playAlertSound(call.priority) end
    local key = ''
    if not Mdt.isDispatcher() and respondBind then key = respondBind:getCurrentKey() end
    Mdt.send({ type = 'alert', call = call, street = street, seconds = Config.Dispatch.alertSeconds, key = key })
end)

RegisterNetEvent('vr-mdt:client:assigned', function(call)
    if type(call) ~= 'table' or not call.coords then return end
    latest = call
    addBlip(call)
    SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0)
end)

local function respond()
    if not latest or not Mdt.isResponder() then return end
    local call = latest
    local res = Mdt.request('dispatch.attach', { id = call.id })
    if type(res) ~= 'table' or not res.ok then
        Bridge.notify("Couldn't respond to that call.", 'error')
        return
    end
    SetNewWaypoint(call.coords.x + 0.0, call.coords.y + 0.0)
    Mdt.send({ type = 'alertResponded', id = call.id })
    Bridge.notify(('Responding to %s %s.'):format(call.code or '', call.title or ''), 'success')
end

RegisterCommand('mdtrespond', respond, false)
respondBind = Keybinds.add({
    name = 'respond',
    label = 'Respond to the latest call',
    description = 'Attach yourself to the newest dispatch call and set a waypoint',
    suggested = Config.Keys.respond,
    order = 11,
    onPressed = respond,
})

RegisterCommand('mdtmute', function()
    if mutedUntil > GetGameTimer() then
        mutedUntil = 0
        Bridge.notify('Dispatch sounds on.', 'inform')
    else
        mutedUntil = GetGameTimer() + 30 * 60 * 1000
        Bridge.notify('Dispatch sounds muted for 30 minutes.', 'inform')
    end
end, false)

RegisterCommand('mdtclearalerts', function()
    Mdt.send({ type = 'alertsClear' })
    for id in pairs(blips) do dropBlip(id) end
end, false)

AddEventHandler('vr-mdt:client:callPushed', function(call)
    if call and call.status == 'closed' then dropBlip(call.id) end
end)

RegisterNetEvent('vr-mdt:client:push', function(name, payload)
    if name == 'dispatch:call' and type(payload) == 'table' and payload.status == 'closed' then
        dropBlip(payload.id)
    elseif name == 'dispatch:remove' and type(payload) == 'table' then
        dropBlip(payload.id)
    end
end)

local function emergency(kind, anonymous)
    return function(_, args)
        local text = table.concat(args or {}, ' ')
        if text:match('^%s*$') then
            Bridge.notify(('Usage: /%s%s [what is happening]'):format(kind, anonymous and 'a' or ''), 'error')
            return
        end
        local c = GetEntityCoords(Bridge.cache.ped)
        local street = Mdt.streetAt(c.x, c.y, c.z)
        TriggerServerEvent('vr-mdt:server:emergency', kind, anonymous, text, street)
        if not IsPedInAnyVehicle(Bridge.cache.ped, false) and not IsEntityDead(Bridge.cache.ped) then
            CreateThread(function()
                local dict = 'cellphone@'
                if pcall(Bridge.requestAnimDict, dict, 1500) then
                    TaskPlayAnim(Bridge.cache.ped, dict, 'cellphone_call_listen_base', 3.0, 3.0, 4000, 49, 0, false, false, false)
                end
            end)
        end
    end
end

RegisterCommand('911', emergency('911', false), false)
RegisterCommand('911a', emergency('911', true), false)
RegisterCommand('311', emergency('311', false), false)
RegisterCommand('311a', emergency('311', true), false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/911', 'Call the police', { { name = 'message', help = 'What is happening' } })
    TriggerEvent('chat:addSuggestion', '/911a', 'Call the police anonymously', { { name = 'message', help = 'What is happening' } })
    TriggerEvent('chat:addSuggestion', '/311', 'Call EMS', { { name = 'message', help = 'What is happening' } })
    TriggerEvent('chat:addSuggestion', '/311a', 'Call EMS anonymously', { { name = 'message', help = 'What is happening' } })
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for id, b in pairs(blips) do
            if b.expires < now then dropBlip(id) end
        end
        if next(blips) and not Mdt.isResponder() and not Mdt.isDispatcher() then
            for id in pairs(blips) do dropBlip(id) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(blips) do dropBlip(id) end
end)
