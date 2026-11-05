local cfg = Config.Jobs.taxi
local H = {}

local run = 0
local passenger
local phase
local metre = 0.0

local function alive(token)
    return run == token and Cj.session and Cj.session.job == 'taxi'
end

local function cab()
    local s = Cj.session
    local v = s and s.vehicles[1]
    return v and Cj.entity(v.netId, 5) or nil
end

local function dropPassenger()
    local p = passenger
    passenger = nil
    if not p or not DoesEntityExist(p) then return end
    local veh = GetVehiclePedIsIn(p, false)
    if veh ~= 0 then TaskLeaveVehicle(p, veh, 0) end
    SetTimeout(4500, function()
        if DoesEntityExist(p) then
            TaskWanderStandard(p, 10.0, 10)
            SetPedAsNoLongerNeeded(p)
            SetTimeout(30000, function()
                if DoesEntityExist(p) then DeleteEntity(p) end
            end)
        end
    end)
    for i, e in ipairs(Cj.track.peds) do
        if e == p then table.remove(Cj.track.peds, i) break end
    end
end

local function spawnPassenger(fare)
    if passenger and DoesEntityExist(passenger) then return end
    local c = fare.from
    local z = Cj.ground(c.x, c.y, c.z)
    passenger = Cj.ped_(fare.model, vec4(c.x + 2.0, c.y + 2.0, z + 1.0, 0.0), { freeze = false, lower = 1.0 })
    if passenger then
        SetPedKeepTask(passenger, true)
        TaskStartScenarioInPlace(passenger, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    end
end

-- Fares are paid into the bank as each one is finished, so the panel shows what has been earned so far.
local function hud(view)
    local d = view.data
    local lines = {}
    if d.fare then
        local f = d.fare
        lines[#lines + 1] = { label = 'Fare', value = f.phase == 'pickup' and 'Pick up the passenger' or 'Take them to their stop', state = 'go' }
        lines[#lines + 1] = { label = 'Trip', value = ('%.1f km'):format(f.distance / 1000) }
        lines[#lines + 1] = { label = 'This fare', value = ('about $%d'):format(f.estimate or 0) }
    else
        lines[#lines + 1] = { label = 'Fare', value = 'Waiting for a call', state = 'wait' }
    end
    lines[#lines + 1] = { label = 'Fares done', value = tostring(d.completed or 0) }
    if d.last then lines[#lines + 1] = { label = 'Last fare', value = ('$%d'):format(d.last) } end
    lines[#lines + 1] = { label = 'Earned this shift', value = ('$%d'):format(d.earned or 0), state = (d.earned or 0) > 0 and 'go' or nil }
    Cj.hudSet('Taxi', lines)
end

-- A marker on the ground where the passenger waits or wants to get out.
local function marker(c, r, g, b)
    DrawMarker(1, c.x, c.y, c.z - 0.95, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, cfg.pickupRange * 1.3, cfg.pickupRange * 1.3, 1.2, r, g, b, 80, false, false, 2, false, nil, nil, false)
end

local function board(token, veh, fare)
    local ped = passenger
    if not ped or not DoesEntityExist(ped) then return end
    ClearPedTasks(ped)
    TaskEnterVehicle(ped, veh, 8000, 2, 1.0, 1, 0)
    local t = GetGameTimer()
    while alive(token) and GetVehiclePedIsIn(ped, false) ~= veh and GetGameTimer() - t < 9000 do Wait(200) end
    if alive(token) and GetVehiclePedIsIn(ped, false) ~= veh then
        TaskWarpPedIntoVehicle(ped, veh, 2)
    end
end

local function loop(token)
    CreateThread(function()
        local lastCall = 0
        while alive(token) do
            local view = Cj.session
            local fare = view.data.fare
            local veh = cab()
            local inCab = veh and GetVehiclePedIsIn(Cj.ped(), false) == veh
            local wait = 400
            if not fare then
                if phase ~= 'idle' then
                    phase = 'idle'
                    Cj.unblip('fare')
                    dropPassenger()
                end
                if GetGameTimer() - lastCall > 4000 then
                    lastCall = GetGameTimer()
                    local ok, res = Cj.act('call')
                    if ok and res.fare then
                        Cj.notify('New fare. Check your map', 'inform')
                    end
                end
                Wait(1000)
            elseif fare.phase == 'pickup' then
                phase = 'pickup'
                Cj.blip('fare', fare.from, { sprite = 280, colour = 5, route = true, label = 'Passenger' })
                spawnPassenger(fare)
                if veh and #(GetEntityCoords(veh) - vec3(fare.from.x, fare.from.y, fare.from.z)) < 80.0 then
                    marker(fare.from, 245, 200, 35)
                    wait = 0
                end
                if inCab and #(GetEntityCoords(veh) - vec3(fare.from.x, fare.from.y, fare.from.z)) <= cfg.pickupRange and GetEntitySpeed(veh) < 3.0 then
                    local ok, err = Cj.act('pickup')
                    if ok then
                        board(token, veh, fare)
                        metre = 0.0
                        PlaySoundFrontend(-1, 'CONFIRM_BEEP', 'HUD_MINI_GAME_SOUNDSET', true)
                    elseif err ~= 'too_far' and err ~= 'refused' then
                        Cj.fail(err)
                        Wait(1000)
                    end
                end
                Wait(wait)
            elseif fare.phase == 'ride' then
                if phase ~= 'ride' then
                    phase = 'ride'
                    Cj.blip('fare', fare.to, { sprite = 280, colour = 2, route = true, label = 'Drop-off' })
                end
                if veh and #(GetEntityCoords(veh) - vec3(fare.to.x, fare.to.y, fare.to.z)) < 80.0 then
                    marker(fare.to, 60, 200, 110)
                    wait = 0
                end
                if inCab and #(GetEntityCoords(veh) - vec3(fare.to.x, fare.to.y, fare.to.z)) <= cfg.dropRange and GetEntitySpeed(veh) < 3.0 then
                    local ok, res = Cj.act('drop')
                    if ok then
                        Cj.notify(('Fare paid: $%d%s. Earned this shift: $%d'):format(res.paid or 0, (res.tip or 0) > 0 and (' (tip $%d included)'):format(res.tip) or '', res.earned or 0), 'success')
                        PlaySoundFrontend(-1, 'ROBBERY_MONEY_TOTAL', 'HUD_FRONTEND_CUSTOM_SOUNDSET', true)
                        dropPassenger()
                        phase = 'idle'
                        Cj.unblip('fare')
                    elseif res ~= 'too_far' and res ~= 'refused' then
                        Cj.fail(res)
                        Wait(1500)
                    end
                end
                Wait(wait)
            else
                Wait(800)
            end
        end
    end)
end

function H.start(view)
    run = run + 1
    phase = nil
    local token = run
    CreateThread(function()
        local veh = cab()
        if veh then
            Cj.target(veh, {
                { name = 'vr-civjobs:cancelfare', label = 'Cancel this fare', icon = 'fa-solid fa-ban', distance = 3.0,
                    canInteract = function() return Cj.session and Cj.session.data.fare ~= nil end,
                    onSelect = function()
                        local ok, err = Cj.act('cancel')
                        if not ok then return Cj.fail(err) end
                        dropPassenger()
                        Cj.unblip('fare')
                    end },
            })
        end
    end)
    hud(view)
    loop(token)
end

function H.sync(view)
    hud(view)
end

function H.stop()
    run = run + 1
    dropPassenger()
    phase = nil
end

Cj.register('taxi', H)
