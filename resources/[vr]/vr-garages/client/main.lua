Garage = { open = false, pd = {}, current = nil }

function Garage.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-garages:api', false, action, data)
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Garage.notify(text, kind)
    lib.notify({ title = 'Garage', description = text, type = kind or 'inform' })
end

local function loadPlayerData()
    local pd = Bridge.playerData(true)
    if type(pd) == 'table' then Garage.pd = pd end
end

Bridge.on('playerData', function(pd)
    if type(pd) ~= 'table' then return end
    Garage.pd = pd
    TriggerEvent('vr-garages:client:groupsChanged')
end)

local function regroup()
    loadPlayerData()
    TriggerEvent('vr-garages:client:groupsChanged')
end

Bridge.on('jobChanged', regroup)
Bridge.on('gangChanged', regroup)
Bridge.on('dutyChanged', regroup)

Bridge.on('playerLoaded', function()
    SetTimeout(500, regroup)
end)

CreateThread(loadPlayerData)

function Garage.show(def, payload)
    Garage.open = true
    Garage.current = def
    SendNUIMessage({ action = 'open', data = payload })
    SetNuiFocus(true, true)
end

function Garage.hide()
    if not Garage.open then return end
    Garage.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function Garage.fallbackSpot(def)
    if not def or not def.center then return nil end
    local found, pos, heading = GetClosestVehicleNodeWithHeading(def.center.x, def.center.y, def.center.z, 1, 3.0, 0)
    if not found then return nil end
    return { x = pos.x, y = pos.y, z = pos.z, w = heading }
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    local data = type(d.data) == 'table' and d.data or {}
    if Garage.current then
        data.garage = Garage.current.id
        if d.action == 'takeOut' or d.action == 'impound.release' or d.action == 'jobveh.take' then data.fallback = Garage.fallbackSpot(Garage.current) end
    end
    local res = Garage.api(d.action, data)
    cb(res)
    if res.ok and (d.action == 'takeOut' or d.action == 'impound.release' or d.action == 'jobveh.take') then
        Garage.hide()
        if d.action == 'jobveh.take' and type(res.data) == 'table' and res.data.sentBack then
            Garage.notify('Your other job vehicle was sent back to the garage', 'inform')
        end
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    Garage.hide()
end)

RegisterNUICallback('waypoint', function(d, cb)
    cb(true)
    if type(d) == 'table' and tonumber(d.x) and tonumber(d.y) then
        SetNewWaypoint(tonumber(d.x) + 0.0, tonumber(d.y) + 0.0)
        Garage.notify('Waypoint set to your vehicle', 'success')
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Garage.open then SetNuiFocus(false, false) end
end)
