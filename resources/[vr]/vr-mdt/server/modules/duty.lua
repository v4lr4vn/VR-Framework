Duty = {}

local queue = {}
local working = false
local cidBySrc = {}

local DAY = 86400

Db.schema('duty', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_duty` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `cid` VARCHAR(64) NOT NULL,
        `dept` VARCHAR(16) NOT NULL,
        `started_at` INT UNSIGNED NOT NULL,
        `ended_at` INT UNSIGNED DEFAULT NULL,
        `seen_at` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `cid_open` (`cid`, `ended_at`),
        KEY `dept_ended` (`dept`, `ended_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function liveState(src)
    local p = Core.player(src)
    if not p then return nil end
    local job = p.job or {}
    local dept = Core.deptOf(job)
    if dept and job.onduty == true then return p.cid, dept end
    return p.cid, nil
end

local function announce(cid, dept, onduty)
    if not dept then return end
    Push.dept(dept, 'roster:duty', { cid = cid, onduty = onduty }, function(ctx) return Core.can(ctx, 'roster.view') end)
end

local function apply(job)
    local open = Db.query('SELECT `id`, `dept` FROM `vr_mdt_duty` WHERE `cid` = ? AND `ended_at` IS NULL ORDER BY `id`', { job.cid })
    if not open then return end
    if job.dept and #open == 1 and open[1].dept == job.dept then return end
    if #open > 0 then
        Db.update('UPDATE `vr_mdt_duty` SET `ended_at` = GREATEST(`started_at`, ?) WHERE `cid` = ? AND `ended_at` IS NULL', { job.at, job.cid })
        for _, row in ipairs(open) do
            if row.dept ~= job.dept then announce(job.cid, row.dept, false) end
        end
    end
    if job.dept then
        Db.insert('INSERT INTO `vr_mdt_duty` (`cid`, `dept`, `started_at`, `seen_at`) VALUES (?, ?, ?, ?)', { job.cid, job.dept, job.at, job.at })
        announce(job.cid, job.dept, true)
    end
end

local function drain()
    while #queue > 0 do
        local job = table.remove(queue, 1)
        local ok, err = pcall(apply, job)
        if not ok then print(('^1[vr-mdt] duty: %s^0'):format(tostring(err))) end
    end
    working = false
end

local function enqueue(cid, dept)
    if not cid or not Db.isReady() then return end
    queue[#queue + 1] = { cid = cid, dept = dept, at = U.now() }
    if working then return end
    working = true
    CreateThread(drain)
end

function Duty.sync(src)
    src = tonumber(src)
    if not src then return end
    local cid, dept = liveState(src)
    if not cid then return end
    cidBySrc[src] = cid
    enqueue(cid, dept)
end

function Duty.stop(cid)
    enqueue(cid, nil)
end

local function forget(src)
    src = tonumber(src)
    if not src then return end
    local p = Core.player(src)
    local cid = p and p.cid or cidBySrc[src]
    cidBySrc[src] = nil
    Duty.stop(cid)
end

function Duty.hours(dept, days, cids)
    local now = U.now()
    local since = now - days * DAY
    local rows = Db.query([[SELECT `cid`, CAST(SUM(GREATEST(0, CAST(LEAST(COALESCE(`ended_at`, ?), ?) AS SIGNED) - CAST(GREATEST(`started_at`, ?) AS SIGNED))) AS SIGNED) AS `secs`
        FROM `vr_mdt_duty` WHERE `dept` = ? AND (`ended_at` IS NULL OR `ended_at` > ?) GROUP BY `cid`]], { now, now, since, dept, since }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        if not cids or cids[r.cid] then out[r.cid] = tonumber(r.secs) or 0 end
    end
    return out
end

function Duty.lastSeen(dept)
    local now = U.now()
    local rows = Db.query('SELECT `cid`, MAX(COALESCE(`ended_at`, ?)) AS `last` FROM `vr_mdt_duty` WHERE `dept` = ? GROUP BY `cid`', { now, dept }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[r.cid] = tonumber(r.last) end
    return out
end

function Duty.secondsFor(cid, dept, days)
    local now = U.now()
    local since = now - days * DAY
    local n = Db.scalar([[SELECT CAST(COALESCE(SUM(GREATEST(0, CAST(LEAST(COALESCE(`ended_at`, ?), ?) AS SIGNED) - CAST(GREATEST(`started_at`, ?) AS SIGNED))), 0) AS SIGNED)
        FROM `vr_mdt_duty` WHERE `cid` = ? AND `dept` = ? AND (`ended_at` IS NULL OR `ended_at` > ?)]], { now, now, since, cid, dept, since })
    return tonumber(n) or 0
end

function Duty.sessions(cid, dept, limit)
    local now = U.now()
    local rows = Db.query('SELECT `id`, `started_at`, `ended_at` FROM `vr_mdt_duty` WHERE `cid` = ? AND `dept` = ? ORDER BY `id` DESC LIMIT ?', { cid, dept, limit }) or {}
    local out = {}
    for _, r in ipairs(rows) do
        local started, ended = tonumber(r.started_at), tonumber(r.ended_at)
        out[#out + 1] = { id = r.id, startedAt = started, endedAt = ended, seconds = math.max(0, (ended or now) - started), running = ended == nil }
    end
    return out
end

function Duty.isOpen(cid)
    return (tonumber(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_duty` WHERE `cid` = ? AND `ended_at` IS NULL', { cid })) or 0) > 0
end

Bridge.on('dutyChanged', function(src)
    Duty.sync(src)
end)

Bridge.on('jobChanged', function(src)
    Duty.sync(src)
end)

Bridge.on('playerLoaded', function(src)
    Duty.sync(src)
end)

Bridge.on('playerUnloaded', function(src)
    forget(src)
end)

AddEventHandler('playerDropped', function()
    forget(source)
end)

CreateThread(function()
    while true do
        Wait((Config.Roster.heartbeatSeconds or 60) * 1000)
        if Db.isReady() then
            Db.update('UPDATE `vr_mdt_duty` SET `seen_at` = ? WHERE `ended_at` IS NULL', { U.now() })
        end
    end
end)

Db.ready(function()
    Db.update('UPDATE `vr_mdt_duty` SET `ended_at` = GREATEST(`started_at`, COALESCE(`seen_at`, `started_at`)) WHERE `ended_at` IS NULL')
    Db.update('DELETE FROM `vr_mdt_duty` WHERE `ended_at` < ?', { U.now() - (Config.Roster.keepDutyDays or 120) * DAY })
    for _, src in ipairs(GetPlayers()) do Duty.sync(src) end
end)
