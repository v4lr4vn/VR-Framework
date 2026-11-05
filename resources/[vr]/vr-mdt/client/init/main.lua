Mdt = {
    open = false,
    nui = {},
}

local tablet = { prop = nil }

function Mdt.send(message)
    SendNUIMessage(message)
end

function Mdt.callback(name, fn)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = pcall(fn, type(data) == 'table' and data or {})
        if not ok then
            print(('^1[vr-mdt] nui %s: %s^0'):format(name, tostring(result)))
            cb({ ok = false, error = 'server_error' })
            return
        end
        cb(result == nil and { ok = true } or result)
    end)
end

function Mdt.request(action, data)
    return Bridge.callback.await('vr-mdt:req', nil, action, data)
end

function Mdt.playerData()
    return Bridge.playerData() or {}
end

local function deptType()
    local job = Mdt.playerData().job or {}
    return job.type, job.onduty
end

function Mdt.isResponder()
    local t, onduty = deptType()
    return (t == 'leo' or t == 'ems') and onduty == true
end

function Mdt.isDispatcher()
    local t, onduty = deptType()
    return t == 'dispatch' and onduty == true
end

function Mdt.dispatchSpot()
    return DispatchZones.spot(GetEntityCoords(Bridge.cache.ped))
end

local mdtTypes = { leo = true, ems = true, doj = true, dispatch = true }

local function startTabletAnim()
    local ped = Bridge.cache.ped
    if IsPedInAnyVehicle(ped, false) then return end
    local dict, anim = Config.Tablet.animDict, Config.Tablet.anim
    if not pcall(Bridge.requestAnimDict, dict, 2000) then return end
    local model = joaat(Config.Tablet.prop)
    if not pcall(Bridge.requestModel, model, 2000) then return end
    local coords = GetEntityCoords(ped)
    tablet.prop = CreateObject(model, coords.x, coords.y, coords.z + 0.2, false, false, false)
    AttachEntityToEntity(tablet.prop, ped, GetPedBoneIndex(ped, 60309), 0.03, 0.002, -0.0, 10.0, 160.0, 0.0, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(model)
    TaskPlayAnim(ped, dict, anim, 3.0, 3.0, -1, 49, 0, false, false, false)
end

local function stopTabletAnim()
    local ped = Bridge.cache.ped
    if tablet.prop and DoesEntityExist(tablet.prop) then
        DetachEntity(tablet.prop, true, false)
        DeleteEntity(tablet.prop)
    end
    tablet.prop = nil
    StopAnimTask(ped, Config.Tablet.animDict, Config.Tablet.anim, 2.0)
end

function Mdt.pauseTabletProp()
    stopTabletAnim()
end

function Mdt.resumeTabletProp()
    if not Mdt.open then return end
    stopTabletAnim()
    startTabletAnim()
end

function Mdt.openTablet(page, params, console)
    if Mdt.open then return end
    local t, onduty = deptType()
    if not mdtTypes[t] then
        Bridge.notify("You don't have access to the MDT.", 'error')
        return
    end
    if IsPauseMenuActive() or IsPedDeadOrDying(Bridge.cache.ped, true) then return end
    if t == 'dispatch' then
        local spot = Mdt.dispatchSpot()
        if not spot then
            Bridge.notify('The dispatch MDT only works inside the dispatch centre.', 'error')
            return
        end
        if not onduty then
            Bridge.notify((Config.Dispatcher or {}).autoDuty and 'Clocking you in, try again in a second.' or 'Clock in at a dispatch desk first.', 'error')
            return
        end
        console = console or spot == 'console'
    end
    Mdt.open = true
    Mdt.console = console == true
    Mdt.dispatcher = t == 'dispatch'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    Mdt.send({ type = 'open', page = page or (t == 'dispatch' and 'dispatch' or nil), params = params, console = Mdt.console })
    if Mdt.console then
        Bridge.voice.setRadioAnim(false)
    else
        startTabletAnim()
    end
    TriggerServerEvent('vr-mdt:server:tablet', true)
end

function Mdt.closeTablet()
    if not Mdt.open then return end
    Mdt.open = false
    SetNuiFocus(false, false)
    Mdt.send({ type = 'close' })
    if Mdt.console then
        Bridge.voice.setRadioAnim(true)
    else
        stopTabletAnim()
    end
    Mdt.console = false
    TriggerServerEvent('vr-mdt:server:tablet', false)
end

Mdt.callback('close', function()
    Mdt.closeTablet()
end)

Mdt.preRequest = Mdt.preRequest or {}

Mdt.callback('req', function(data)
    if type(data.action) ~= 'string' then return { ok = false, error = 'bad_request' } end
    local payload = data.data
    local pre = Mdt.preRequest[data.action]
    if pre then
        payload = pre(type(payload) == 'table' and payload or {})
        if not payload then return { ok = false, error = 'cancelled' } end
    end
    local res = Mdt.request(data.action, payload)
    if type(res) ~= 'table' then return { ok = false, error = 'server_error' } end
    return res
end)

Mdt.callback('waypoint', function(data)
    local x, y = tonumber(data.x), tonumber(data.y)
    if not x or not y then return { ok = false } end
    SetNewWaypoint(x + 0.0, y + 0.0)
    Bridge.notify('Waypoint set.', 'inform')
    return { ok = true }
end)

Mdt.callback('getWaypoint', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return {} end
    local c = GetBlipInfoIdCoord(blip)
    return { x = c.x, y = c.y, z = c.z }
end)

function Mdt.streetAt(x, y, z)
    local a, b = GetStreetNameAtCoord(x + 0.0, y + 0.0, (z or 30.0) + 0.0)
    local first = GetStreetNameFromHashKey(a)
    local second = b ~= 0 and GetStreetNameFromHashKey(b) or ''
    local zone = GetLabelText(GetNameOfZone(x + 0.0, y + 0.0, (z or 30.0) + 0.0))
    local street = first ~= '' and first or zone
    if second ~= '' then street = ('%s & %s'):format(street, second) end
    if zone ~= '' and zone ~= 'NULL' and street ~= zone then street = ('%s, %s'):format(street, zone) end
    return street
end

Mdt.callback('streets', function(data)
    local out = {}
    for i, c in ipairs(type(data.list) == 'table' and data.list or {}) do
        if i > 60 then break end
        local id, x, y, z = c.id, tonumber(c.x), tonumber(c.y), tonumber(c.z)
        if id and x and y then out[tostring(id)] = Mdt.streetAt(x, y, z) end
    end
    return out
end)

RegisterNetEvent('vr-mdt:client:push', function(name, payload)
    Mdt.send({ type = 'push', name = name, payload = payload })
end)

RegisterCommand(Config.Command, function()
    if Mdt.open then Mdt.closeTablet() else Mdt.openTablet() end
end, false)

Keybinds.add({
    name = 'open',
    label = 'Open the MDT',
    description = ('Police and EMS tablet, same as /%s'):format(Config.Command),
    suggested = Config.Keys.open,
    order = 10,
    onPressed = function()
        if Mdt.open then Mdt.closeTablet() else Mdt.openTablet() end
    end,
})

exports('OpenMDT', function(page, params) Mdt.openTablet(page, params) end)
exports('CloseMDT', function() Mdt.closeTablet() end)
exports('IsOpen', function() return Mdt.open end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Mdt.open then
        SetNuiFocus(false, false)
        stopTabletAnim()
    end
end)

Bridge.on('playerUnloaded', function()
    Mdt.closeTablet()
end)

Bridge.on('jobChanged', function(job)
    if Mdt.open and (not job or not mdtTypes[job.type]) then
        Mdt.closeTablet()
    end
end)

CreateThread(function()
    while true do
        if Mdt.open and (IsPedDeadOrDying(Bridge.cache.ped, true) or IsPauseMenuActive()) then
            Mdt.closeTablet()
        elseif Mdt.open and Mdt.dispatcher and not Mdt.dispatchSpot() then
            Mdt.closeTablet()
            Bridge.notify('You left the dispatch centre.', 'inform')
        end
        Wait(500)
    end
end)
