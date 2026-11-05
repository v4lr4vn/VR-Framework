local cfg = Config.Jobs.fisherman
local H = {}

local run = 0
local casting = false
local hint = false

local function alive(token)
    return run == token and Cj.session and Cj.session.job == 'fisherman'
end

local function spotAt(here)
    for _, s in ipairs(Cj.session.data.spots) do
        if #(vec2(here.x, here.y) - vec2(s.x, s.y)) <= s.r then return s end
    end
    return nil
end

local function waterAhead(ped)
    local c = GetEntityCoords(ped)
    local f = GetEntityForwardVector(ped)
    for dist = 3.0, 9.0, 3.0 do
        local ok = GetWaterHeight(c.x + f.x * dist, c.y + f.y * dist, c.z)
        if ok then return true end
    end
    return false
end

local function stopCast(ped, notifyServer)
    casting = false
    ClearPedTasks(ped)
    if notifyServer then Cj.act('stopcast') end
    Cj.message({ action = 'progressEnd' })
end

local function cast()
    if casting then return end
    local ped = Cj.ped()
    if IsPedInAnyVehicle(ped, false) then return end
    local ok, res = Cj.act('cast')
    if not ok then return Cj.fail(res) end
    casting = true
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_FISHING', 0, true)
    local ms = math.floor((res.wait or 8) * 1000)
    Cj.message({ action = 'progress', label = res.baited and 'Waiting for a bite (baited)' or 'Waiting for a bite', ms = ms })
    local started = GetGameTimer()
    while GetGameTimer() - started < ms do
        if IsControlJustPressed(0, 73) or IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) then
            stopCast(ped, true)
            Cj.notify('You reeled in', 'inform')
            return
        end
        Wait(0)
    end
    Cj.message({ action = 'progressEnd' })
    PlaySoundFrontend(-1, 'Beep_Green', 'DLC_HEIST_HACKING_SNAKE_SOUNDSET', true)
    local won = Cj.skill({ label = 'Reel it in', zone = 0.24, speed = 1.0, rounds = 1 })
    local done, out = Cj.act('reel', { success = won })
    stopCast(ped, false)
    if not done then return Cj.fail(out) end
    if out.lost then return Cj.notify('It got away', 'error') end
    Cj.notify(('Caught %dx %s%s'):format(out.amount, out.label, out.crit and ' (a big one!)' or ''), 'success')
end

local function loop(token)
    CreateThread(function()
        while alive(token) do
            local ped = Cj.ped()
            local here = GetEntityCoords(ped)
            local spot = Cj.session.data.spots and spotAt(here)
            local ready = spot and not casting and not IsPedInAnyVehicle(ped, false) and not IsPedSwimming(ped) and waterAhead(ped)
            if ready then
                if not hint then
                    hint = true
                    Bridge.textUI.show('[E] Cast line')
                end
                if IsControlJustPressed(0, 38) then CreateThread(cast) end
                Wait(0)
            else
                if hint then
                    hint = false
                    Bridge.textUI.hide()
                end
                Wait(spot and 250 or 700)
            end
        end
        if hint then
            hint = false
            Bridge.textUI.hide()
        end
    end)
end

local function hud(view)
    local d = view.data
    local lines = {}
    if d.needs then
        for _, n in ipairs(d.needs) do
            lines[#lines + 1] = { label = n.label, value = ('%d / %d'):format(n.have, n.need), state = n.have >= n.need and 'go' or nil }
        end
    else
        lines[#lines + 1] = { label = 'Mode', value = 'Free fishing' }
    end
    lines[#lines + 1] = { label = 'Caught', value = tostring(d.total) }
    lines[#lines + 1] = { label = 'Bait', value = tostring(d.baitCount) }
    if d.ready then lines[#lines + 1] = { label = 'Next', value = 'Take your catch to the market', state = 'go' } end
    Cj.hudSet(d.contract or 'Fishing', lines)
end

function H.start(view)
    run = run + 1
    casting = false
    for i, s in ipairs(view.data.spots) do
        Cj.blip('spot' .. i, s, { sprite = 68, colour = 3, scale = 0.7, label = s.label, radius = s.r })
    end
    loop(run)
    H.sync(view)
end

function H.sync(view)
    hud(view)
    if view.data.ready then
        Cj.blip('market', view.data.depot, { sprite = 317, colour = 2, route = true, label = 'Fish market' })
        Cj.finishZone('finish', view.data.depot, 'Hand in the contract', 40.0)
    end
end

function H.stop()
    run = run + 1
    if casting then stopCast(Cj.ped(), false) end
end

Cj.register('fisherman', H)
