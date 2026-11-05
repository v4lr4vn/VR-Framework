-- What the game knows that the Maps and Health apps need: where the player is, how healthy they are, and how far they have walked.
local World = {}
Phone.World = World

local cfg = Config.Phone.Health or {}

local function loggedIn()
    if Bridge.framework == 'none' then return true end
    return Bridge.playerData() ~= nil
end

-- ---------------------------------------------------------------- where the player is

local function postal()
    if GetResourceState('vr-hud') ~= 'started' then return nil end
    local ok, code = pcall(function() return exports['vr-hud']:getPostal() end)
    return ok and code or nil
end

-- The waypoint on the game map, as { x, y }, or nil.
function World.waypoint()
    if not IsWaypointActive() then return nil end
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    local c = GetBlipInfoIdCoord(blip)
    return { x = c.x + 0.0, y = c.y + 0.0 }
end

function World.position()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local street = GetStreetNameAtCoord(pos.x, pos.y, pos.z)
    local zone = GetNameOfZone(pos.x, pos.y, pos.z)
    local label = GetLabelText(zone)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local speed = (vehicle ~= 0 and GetEntitySpeed(vehicle) or GetEntitySpeed(ped)) * 3.6
    return {
        x = pos.x + 0.0,
        y = pos.y + 0.0,
        z = pos.z + 0.0,
        -- The game turns anticlockwise from north. A compass turns clockwise.
        bearing = (360.0 - GetEntityHeading(ped)) % 360.0,
        street = street ~= 0 and GetStreetNameFromHashKey(street) or '',
        zone = (label ~= 'NULL' and label) or zone,
        postal = postal(),
        speed = speed,
        driving = vehicle ~= 0,
        waypoint = World.waypoint(),
    }
end

function World.go(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x ~= x or y ~= y then return false end
    SetNewWaypoint(x + 0.0, y + 0.0)
    return true
end

function World.stop()
    SetWaypointOff()
end

-- ---------------------------------------------------------------- how the player is

local function percent(v)
    return math.max(0, math.min(100, math.floor((tonumber(v) or 0) + 0.5)))
end

function World.vitals()
    local ped = PlayerPedId()
    local maxHealth = math.max(1, GetEntityMaxHealth(ped) - 100)
    local health = percent((GetEntityHealth(ped) - 100) / maxHealth * 100)
    local needs = {}
    if Bridge.framework ~= 'none' and Bridge.needs then
        local ok, n = pcall(Bridge.needs)
        if ok and type(n) == 'table' then needs = n end
    end

    local state = 'rest'
    if IsPedInAnyVehicle(ped, false) then state = 'vehicle'
    elseif IsPedSwimming(ped) then state = 'swim'
    elseif IsPedSprinting(ped) then state = 'sprint'
    elseif IsPedRunning(ped) then state = 'run'
    elseif IsPedWalking(ped) then state = 'walk' end

    return {
        health = health,
        armour = percent(GetPedArmour(ped)),
        hunger = percent(needs.hunger),
        thirst = percent(needs.thirst),
        stress = percent(needs.stress),
        state = state,
        steps = World.flushSteps(),
    }
end

-- ---------------------------------------------------------------- steps

-- The player walks around with the phone in their pocket, so steps are counted the whole time they are in the world.
-- The game only reports to the server every few seconds, and the server decides how much of it is believable.
local pending = { steps = 0.0, metres = 0.0, active = 0.0 }

CreateThread(function()
    local last
    local walk, run = cfg.walkStride or 0.75, cfg.runStride or 1.1
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if loggedIn() and not IsEntityDead(ped) then
            local pos = GetEntityCoords(ped)
            if last and IsPedOnFoot(ped) and not IsPedFalling(ped) and not IsPedRagdoll(ped) and not IsPedSwimming(ped) then
                local dx, dy = pos.x - last.x, pos.y - last.y
                local dist = math.sqrt(dx * dx + dy * dy)
                -- Tiny moves are standing still. Big jumps are a teleport or a respawn, not walking.
                if dist > 0.15 and dist < 6.0 then
                    local stride = (IsPedRunning(ped) or IsPedSprinting(ped)) and run or walk
                    pending.steps = pending.steps + dist / stride
                    pending.metres = pending.metres + dist
                    pending.active = pending.active + 0.5
                end
            end
            last = pos
        else
            last = nil
        end
    end
end)

local lastSent = 0

-- Sends what has been walked since the last report. Returns the number of steps sent (0 when there was nothing to send yet).
-- The server refuses reports that come closer than 4 seconds apart, so this keeps its own gap.
local function flush()
    local now = GetGameTimer()
    if now - lastSent < 4200 then return 0 end
    local steps = math.floor(pending.steps)
    if steps < 1 or not loggedIn() then return 0 end
    local metres, active = math.floor(pending.metres), math.floor(pending.active)
    -- What is left over (a part of a step) carries on to the next report.
    pending.steps = pending.steps - steps
    pending.metres = pending.metres - metres
    pending.active = pending.active - active
    lastSent = now
    TriggerServerEvent('vr-phone:server:health', { steps = steps, metres = metres, active = active })
    return steps
end

-- The Health app asks for the latest numbers while it is open, so its step count keeps up: anything walked is sent at once
-- and the app is told how many steps are still on their way to the server.
function World.flushSteps()
    local sent = flush()
    return { sent = sent, pending = math.floor(pending.steps) }
end

CreateThread(function()
    local every = math.max(5, cfg.reportSeconds or 10) * 1000
    while true do
        Wait(every)
        flush()
    end
end)
