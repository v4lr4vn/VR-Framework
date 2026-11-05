-- Health. Counts steps from the player's own walking and running, one row a day. The game reports what the player walked
-- every few seconds and the server decides how much of it can be true (nobody takes more than a few steps a second).
local Health = {}
Phone.Health = Health

local function cfg() return Config.Phone.Health or {} end

function Health.today()
    return os.date('%Y-%m-%d', os.time())
end

local function dayOffset(days)
    return os.date('%Y-%m-%d', os.time() - days * 86400)
end

function Health.goal(s)
    local c = cfg()
    local range = c.goalRange or { 1000, 40000 }
    local g = s.settings and s.settings.health and tonumber(s.settings.health.goal)
    if not g then g = c.stepGoal or 8000 end
    return math.max(range[1], math.min(range[2], math.floor(g)))
end

-- data = { steps, metres, active } since the last report. Returns the totals for today, or nil when nothing was counted.
function Health.report(s, data)
    if type(data) ~= 'table' then return nil end
    local c = cfg()
    local t = os.time()
    local h = s.health
    if not h then
        h = { last = t - (c.reportSeconds or 10) }
        s.health = h
    end
    local elapsed = math.max(1, math.min(t - h.last, 120))
    h.last = t

    local steps = Phone.clamp(data.steps, 0, 100000)
    local metres = Phone.clamp(data.metres, 0, 1000000)
    local active = Phone.clamp(data.active, 0, 100000)
    if not steps or not metres or not active then return nil end

    -- No more steps than a person can take in the time since the last report.
    steps = math.min(math.floor(steps), math.ceil(elapsed * (c.maxStepsPerSecond or 4.0)))
    if steps <= 0 then return nil end
    metres = math.min(math.floor(metres), math.ceil(steps * (c.runStride or 1.1) * 1.25))
    active = math.min(math.floor(active), elapsed)

    MySQL.update.await(
        'INSERT INTO `vr_ph_health_days` (`phone_id`, `day`, `steps`, `metres`, `active`, `updated_at`) VALUES (?, ?, ?, ?, ?, ?) '
            .. 'ON DUPLICATE KEY UPDATE `steps` = `steps` + VALUES(`steps`), `metres` = `metres` + VALUES(`metres`), `active` = `active` + VALUES(`active`), `updated_at` = VALUES(`updated_at`)',
        { s.phoneId, Health.today(), steps, metres, active, t }
    )
    return true
end

-- Today, the last seven days, and how many days in a row the goal was met.
function Health.overview(s)
    local c = cfg()
    local goal = Health.goal(s)
    local rows = MySQL.query.await(
        'SELECT `day`, `steps`, `metres`, `active` FROM `vr_ph_health_days` WHERE `phone_id` = ? AND `day` >= ? ORDER BY `day` DESC',
        { s.phoneId, dayOffset(60) }
    ) or {}
    local byDay = {}
    for _, r in ipairs(rows) do
        byDay[r.day] = { steps = tonumber(r.steps) or 0, metres = tonumber(r.metres) or 0, active = tonumber(r.active) or 0 }
    end

    local week = {}
    for i = 6, 0, -1 do
        local day = dayOffset(i)
        local d = byDay[day] or { steps = 0, metres = 0, active = 0 }
        week[#week + 1] = { day = day, steps = d.steps, metres = d.metres, active = d.active }
    end

    -- A streak counts back from today. Today only breaks it once the day is over, so it is skipped while the goal is not met yet.
    local streak = 0
    for i = 0, 59 do
        local d = byDay[dayOffset(i)]
        if d and d.steps >= goal then
            streak = streak + 1
        elseif i > 0 then
            break
        end
    end

    local today = byDay[Health.today()] or { steps = 0, metres = 0, active = 0 }
    return {
        today = {
            steps = today.steps,
            metres = today.metres,
            active = today.active,
            kcal = math.floor(today.steps * (c.kcalPerStep or 0.045) + 0.5),
        },
        week = week,
        goal = goal,
        streak = streak,
        restingRate = c.restingRate or 64,
    }
end

-- Old days are deleted now and then.
CreateThread(function()
    Phone.DB.waitReady()
    while true do
        MySQL.update.await('DELETE FROM `vr_ph_health_days` WHERE `day` < ?', { dayOffset(cfg().keepDays or 60) })
        Wait(6 * 3600 * 1000)
    end
end)
