local cfg = Config.Jobs.busdriver
local H = {}

local run = 0
local riders = {} -- the people sitting on the bus right now (only this driver sees them)

local function alive(token)
    return run == token and Cj.session and Cj.session.job == 'busdriver'
end

local function bus()
    local s = Cj.session
    local v = s and s.vehicles[1]
    return v and Cj.entity(v.netId, 5) or nil
end

local function hud(view)
    local d = view.data
    if d.phase == 'return' then
        Cj.hudSet(d.route, {
            { label = 'Route', value = 'Complete' },
            { label = 'Passengers carried', value = tostring(d.passengers) },
            { label = 'Shift pay', value = ('$%d'):format(view.pool) },
            { label = 'Next', value = 'Bring the bus back to the depot', state = 'go' },
        })
        return
    end
    Cj.hudSet(d.route, {
        { label = 'Stop', value = ('%d / %d  %s'):format(d.idx, d.of, d.stop and d.stop.label or '') },
        { label = 'On the bus', value = tostring(d.onboard or 0) },
        { label = 'Passengers carried', value = tostring(d.passengers) },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    }, math.floor((d.idx - 1) / d.of * 100))
end

-- The first free passenger seat, or nil when the bus is full.
local function freeSeat(veh)
    local seats = GetVehicleModelNumberOfSeats(GetEntityModel(veh))
    for i = 0, seats - 2 do
        if IsVehicleSeatFree(veh, i) then return i end
    end
    return nil
end

local function forget(ped)
    for i, p in ipairs(riders) do
        if p == ped then table.remove(riders, i) break end
    end
    for i, p in ipairs(Cj.track.peds) do
        if p == ped then table.remove(Cj.track.peds, i) break end
    end
end

-- Someone who got off walks away from the stop and is cleaned up a little later.
local function walkAway(ped)
    forget(ped)
    SetTimeout(3500, function()
        if not DoesEntityExist(ped) then return end
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
        SetPedAsNoLongerNeeded(ped)
        SetTimeout(25000, function()
            if DoesEntityExist(ped) then DeleteEntity(ped) end
        end)
    end)
end

-- People already on the bus get off, one after another.
local function letOff(veh, count)
    count = math.min(count, #riders)
    for i = 1, count do
        local ped = riders[1]
        if not ped or not DoesEntityExist(ped) then
            table.remove(riders, 1)
        else
            TaskLeaveVehicle(ped, veh, 0)
            walkAway(ped)
            Wait(450)
        end
    end
end

-- People waiting at the stop walk to the door and take a seat. Anyone who has not made it by the deadline is seated anyway.
local function takeOn(token, veh, count, ms)
    local group = {}
    local heading = GetEntityHeading(veh)
    for i = 1, count do
        -- The right hand side of the bus is the kerb, by the front door.
        local at = GetOffsetFromEntityInWorldCoords(veh, 4.6 + (i % 2) * 0.9, 2.2 + (i * 0.9), 0.0)
        local z = Cj.ground(at.x, at.y, at.z)
        local model = cfg.passengerModels[math.random(#cfg.passengerModels)]
        local ped = Cj.ped_(model, vec4(at.x, at.y, z + 1.0, (heading + 90.0) % 360.0), { freeze = false, lower = 1.0 })
        if ped then
            SetPedFleeAttributes(ped, 0, false)
            SetPedConfigFlag(ped, 32, false)
            SetPedCanBeDraggedOut(ped, false)
            SetPedKeepTask(ped, true)
            group[#group + 1] = ped
        end
        Wait(250)
    end
    for _, ped in ipairs(group) do
        TaskEnterVehicle(ped, veh, 12000, -2, 1.6, 1, 0)
    end
    local started = GetGameTimer()
    while alive(token) and GetGameTimer() - started < ms do
        local all = true
        for _, ped in ipairs(group) do
            if DoesEntityExist(ped) and GetVehiclePedIsIn(ped, false) ~= veh then all = false end
        end
        if all then break end
        Wait(200)
    end
    for _, ped in ipairs(group) do
        if DoesEntityExist(ped) then
            if GetVehiclePedIsIn(ped, false) ~= veh then
                local seat = freeSeat(veh)
                if seat then
                    TaskWarpPedIntoVehicle(ped, veh, seat)
                else
                    Cj.removePed(ped)
                end
            end
            if DoesEntityExist(ped) and GetVehiclePedIsIn(ped, false) == veh then riders[#riders + 1] = ped end
        end
    end
end

local function stopHere(token, veh, d)
    local ok, info = Cj.act('arrive')
    if not ok then return end
    SetVehicleDoorOpen(veh, 1, false, false)
    SetVehicleDoorOpen(veh, 3, false, false)
    local ms = d.wait * 1000
    Cj.message({ action = 'progress', label = 'Passengers getting off and on', ms = ms })
    local alight, board = info.alight or 0, info.board or 0
    if alight > 0 then CreateThread(function() letOff(veh, alight) end) end
    if board > 0 then CreateThread(function() takeOn(token, veh, board, math.max(2000, ms - 1500)) end) end
    Wait(ms + 300)
    Cj.message({ action = 'progressEnd' })
    local done, res = Cj.act('depart')
    local tries = 0
    while not done and res == 'too_fast' and tries < 6 and alive(token) do
        tries = tries + 1
        Wait(500)
        done, res = Cj.act('depart')
    end
    SetVehicleDoorShut(veh, 1, false)
    SetVehicleDoorShut(veh, 3, false)
    if done then
        local text = {}
        if (res.alighted or 0) > 0 then text[#text + 1] = ('%d got off'):format(res.alighted) end
        if (res.passengers or 0) > 0 then text[#text + 1] = ('%d got on'):format(res.passengers) end
        if #text > 0 then Cj.notify(table.concat(text, ', ') .. (' (%d on the bus)'):format(res.onboard or 0), 'success') end
    end
end

local function loop(token)
    CreateThread(function()
        while alive(token) do
            local view = Cj.session
            local d = view.data
            local veh = bus()
            local sleep = 500
            if d.phase == 'route' and d.stop and veh and GetVehiclePedIsIn(Cj.ped(), false) == veh then
                local c = vec3(d.stop.x, d.stop.y, d.stop.z)
                local dist = #(GetEntityCoords(veh) - c)
                if dist < 60.0 then
                    sleep = 0
                    DrawMarker(1, c.x, c.y, c.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, cfg.stopRange * 1.4, cfg.stopRange * 1.4, 1.2, 245, 166, 35, 90, false, false, 2, false, nil, nil, false)
                end
                if not d.arrived and dist <= cfg.stopRange and GetEntitySpeed(veh) <= cfg.stopSpeed then
                    stopHere(token, veh, d)
                end
            end
            Wait(sleep)
        end
    end)
end

function H.start(view)
    run = run + 1
    riders = {}
    loop(run)
    H.sync(view)
end

function H.sync(view)
    local d = view.data
    hud(view)
    if d.phase == 'route' and d.stop then
        Cj.blip('stop', d.stop, { sprite = 513, colour = 5, route = true, label = d.stop.label })
    else
        Cj.unblip('stop')
        Cj.blip('depot', d.depot, { sprite = 513, colour = 2, route = true, label = 'Return the bus' })
        Cj.finishZone('finish', d.depot, 'Finish shift', cfg.vehicle.returnRadius)
    end
end

function H.stop()
    run = run + 1
    for _, ped in ipairs(riders) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    riders = {}
end

Cj.register('busdriver', H)
