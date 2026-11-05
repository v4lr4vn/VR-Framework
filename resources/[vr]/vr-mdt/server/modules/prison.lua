Prison = {}

local inmates = {}

Db.schema('prison', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_prison` (
        `cid` VARCHAR(64) NOT NULL,
        `name` VARCHAR(64) NOT NULL,
        `months` INT UNSIGNED NOT NULL,
        `seconds_left` INT UNSIGNED NOT NULL,
        `reason` VARCHAR(255) DEFAULT NULL,
        `report_id` INT UNSIGNED DEFAULT NULL,
        `by_cid` VARCHAR(64) DEFAULT NULL,
        `by_name` VARCHAR(64) DEFAULT NULL,
        `started_at` INT UNSIGNED NOT NULL,
        `released_at` INT UNSIGNED DEFAULT NULL,
        `release_reason` VARCHAR(120) DEFAULT NULL,
        `confiscated` TINYINT(1) NOT NULL DEFAULT 0,
        PRIMARY KEY (`cid`),
        KEY `released_at` (`released_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function perMonth()
    return math.max(1, math.floor(tonumber(Config.Prison.secondsPerMonth) or 60))
end

local function maxMonths()
    return math.max(1, math.floor(tonumber(Config.Prison.maxMonths) or 300))
end

local function monthsLeft(i)
    return math.ceil(i.left / perMonth())
end

local function duration(seconds)
    seconds = math.max(0, math.floor(seconds))
    local h, m, s = seconds // 3600, (seconds % 3600) // 60, seconds % 60
    if h > 0 then return ('%d h %02d min'):format(h, m) end
    if m > 0 then return ('%d min %02d s'):format(m, s) end
    return ('%d s'):format(s)
end

local function liveSrc(i)
    if not i.src then return nil end
    local p = Core.player(i.src)
    if not p or p.cid ~= i.cid then
        i.src = nil
        return nil
    end
    return i.src
end

local function clientState(i, teleport)
    return { active = true, seconds = i.left, months = i.months, left = monthsLeft(i), reason = i.reason, teleport = teleport == true }
end

local function sendState(i, teleport)
    local src = liveSrc(i)
    if src then TriggerClientEvent('vr-mdt:client:prison', src, clientState(i, teleport)) end
end

local function setMeta(src, seconds)
    if Core.player(src) then Bridge.setMeta(src, 'injail', math.max(0, math.ceil(seconds / 60))) end
end

local function keptSlots(src)
    local out = {}
    local keep = {}
    for _, name in ipairs(Config.Prison.keepItems or {}) do keep[name] = true end
    if not next(keep) then return out end
    local ok, items = pcall(Bridge.inventory.items, src)
    for _, s in ipairs(ok and items or {}) do
        if keep[s.name] and (tonumber(s.count) or 0) > 0 then
            out[#out + 1] = { name = s.name, count = s.count, metadata = s.metadata }
        end
    end
    return out
end

local function confiscate(src)
    if Bridge.inventoryName == 'none' then return false end
    local keep = keptSlots(src)
    local ok, done = pcall(Bridge.inventory.confiscate, src)
    if not ok or not done then return false end
    for _, k in ipairs(keep) do
        pcall(Bridge.inventory.add, src, k.name, k.count, k.metadata)
    end
    return true
end

local function giveBack(src)
    if Bridge.inventoryName == 'none' then return false end
    local ok, done = pcall(Bridge.inventory.giveBack, src)
    return ok and done == true
end

local function changed(cid)
    Push.dept('police', 'prison:changed', { cid = cid })
    TriggerEvent('vr-mdt:server:prisonChanged', cid, Prison.status(cid))
end

local function persist(i)
    return Db.update([[INSERT INTO `vr_mdt_prison` (`cid`, `name`, `months`, `seconds_left`, `reason`, `report_id`, `by_cid`, `by_name`, `started_at`, `released_at`, `release_reason`, `confiscated`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?)
        ON DUPLICATE KEY UPDATE `name` = VALUES(`name`), `months` = VALUES(`months`), `seconds_left` = VALUES(`seconds_left`), `reason` = VALUES(`reason`),
        `report_id` = VALUES(`report_id`), `by_cid` = VALUES(`by_cid`), `by_name` = VALUES(`by_name`), `started_at` = VALUES(`started_at`),
        `released_at` = NULL, `release_reason` = NULL, `confiscated` = VALUES(`confiscated`)]],
        { i.cid, i.name, i.months, i.left, i.reason, i.reportId, i.byCid, i.byName, i.since, i.confiscated and 1 or 0 })
end

local function saveLeft(i)
    return Db.update('UPDATE `vr_mdt_prison` SET `months` = ?, `seconds_left` = ?, `confiscated` = ? WHERE `cid` = ? AND `released_at` IS NULL',
        { i.months, math.max(0, i.left), i.confiscated and 1 or 0, i.cid })
end

local function begin(i, src, teleport)
    i.src = src
    if not i.confiscated then i.confiscated = confiscate(src) end
    setMeta(src, i.left)
    saveLeft(i)
    sendState(i, teleport)
end

local function release(i, why, ctx)
    inmates[i.cid] = nil
    local src = liveSrc(i)
    if src then
        if i.confiscated then giveBack(src) end
        setMeta(src, 0)
        TriggerClientEvent('vr-mdt:client:prison', src, { active = false, release = true })
        Core.notify(src, 'You were released from prison.', 'success')
    end
    local pendingReturn = i.confiscated and not src
    Db.update('UPDATE `vr_mdt_prison` SET `seconds_left` = ?, `released_at` = ?, `release_reason` = ?, `confiscated` = ? WHERE `cid` = ?',
        { math.max(0, i.left), U.now(), why, pendingReturn and 1 or 0, i.cid })
    Audit.log(ctx, 'prison.release', i.cid, { reason = why, secondsLeft = math.max(0, i.left), online = src ~= nil })
    changed(i.cid)
end

function Prison.status(cid)
    local i = inmates[cid]
    if not i then return nil end
    return { months = i.months, remaining = math.max(0, i.left), since = i.since, reason = i.reason, monthsLeft = monthsLeft(i), online = i.src ~= nil, reportId = i.reportId }
end

function Prison.jail(ctx, cid, months, reason, reportId)
    cid = V.cid(cid)
    months = V.int(months, 1, maxMonths())
    if not cid or not months then return false, 'bad_request' end
    reason = V.str(reason, 255) or 'Sentenced'
    reportId = reportId ~= nil and V.id(reportId) or nil
    local p = Core.playerByCid(cid)
    local name = p and p.name or Core.nameOf(cid)
    if not name then return false, 'not_found' end
    local current = inmates[cid]
    local i
    if current then
        i = U.copy(current)
        i.months = math.min(current.months + months, maxMonths())
        i.left = math.min(current.left + months * perMonth(), maxMonths() * perMonth())
        i.reason = reason
        i.reportId = reportId or current.reportId
    else
        local prev = Db.single('SELECT `confiscated` FROM `vr_mdt_prison` WHERE `cid` = ?', { cid })
        i = {
            cid = cid, name = name, months = months, left = months * perMonth(), reason = reason, reportId = reportId,
            byCid = ctx and ctx.cid or nil, byName = ctx and ctx.name or 'System', since = U.now(),
            confiscated = prev ~= nil and tonumber(prev.confiscated) == 1,
        }
    end
    if persist(i) == nil then return false, 'save_failed' end
    if current then
        for k, v in pairs(i) do current[k] = v end
        i = current
    end
    inmates[cid] = i
    if p then
        begin(i, p.source, current == nil)
        Core.notify(p.source, current and ('Your sentence was extended by %d months.'):format(months) or ('You were sentenced to %d months.'):format(i.months), 'error')
    end
    Audit.log(ctx, 'prison.jail', cid, { months = months, reason = reason, reportId = reportId, extended = current ~= nil or nil })
    changed(cid)
    return true
end

function Prison.release(ctx, cid, why)
    local i = inmates[V.cid(cid) or '']
    if not i then return false, 'not_in_prison' end
    release(i, why or 'Released', ctx)
    return true
end

function Prison.tick(seconds, save)
    local cids = {}
    for cid, i in pairs(inmates) do
        if i.src then cids[#cids + 1] = cid end
    end
    for _, cid in ipairs(cids) do
        local i = inmates[cid]
        local src = i and liveSrc(i)
        if src then
            i.left = i.left - seconds
            if i.left <= 0 then
                i.left = 0
                release(i, 'Sentence served', nil)
            else
                local ped = GetPlayerPed(src)
                if ped and ped ~= 0 then
                    local c = GetEntityCoords(ped)
                    local centre = Config.Prison.centre
                    if #(vector3(c.x, c.y, c.z) - vector3(centre.x, centre.y, centre.z)) > Config.Prison.radius * 1.25 then sendState(i, true) end
                end
                if save then
                    setMeta(src, i.left)
                    saveLeft(i)
                    sendState(i, false)
                end
            end
        end
    end
end

local function inmateView(i, mugshots)
    return {
        cid = i.cid, name = i.name, months = i.months, remaining = math.max(0, i.left), monthsLeft = monthsLeft(i), since = i.since,
        reason = i.reason, reportId = i.reportId, byName = i.byName, online = i.src ~= nil, mugshot = mugshots[i.cid] and mugshots[i.cid].mugshot or nil,
    }
end

Api.register('prison.list', nil, function(src, ctx)
    if ctx.dept ~= 'police' then return false, 'not_allowed' end
    local released = Db.query([[SELECT `cid`, `name`, `months`, `reason`, `by_name`, `started_at`, `released_at`, `release_reason` FROM `vr_mdt_prison`
        WHERE `released_at` IS NOT NULL ORDER BY `released_at` DESC LIMIT 15]])
    if not released then return false, 'server_error' end
    local cids = {}
    for cid in pairs(inmates) do cids[#cids + 1] = cid end
    for _, r in ipairs(released) do cids[#cids + 1] = r.cid end
    local mugshots = Citizens and Citizens.profiles and Citizens.profiles(cids) or {}
    local list = {}
    for _, i in pairs(inmates) do
        liveSrc(i)
        list[#list + 1] = inmateView(i, mugshots)
    end
    table.sort(list, function(a, b) return a.remaining < b.remaining or (a.remaining == b.remaining and a.name < b.name) end)
    for _, r in ipairs(released) do r.mugshot = mugshots[r.cid] and mugshots[r.cid].mugshot or nil end
    return true, { inmates = list, released = released, secondsPerMonth = perMonth(), maxMonths = maxMonths(), serverTime = U.now() }
end, { rate = 500 })

Api.register('prison.release', 'prison.manage', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local note = data.reason ~= nil and data.reason ~= '' and V.str(data.reason, 80) or nil
    if not cid or (data.reason ~= nil and data.reason ~= '' and not note) then return false, 'bad_request' end
    local i = inmates[cid]
    if not i then return false, 'not_in_prison' end
    local why = ('Released early by %s'):format(ctx.name)
    if note then why = ('%s: %s'):format(why, note) end
    release(i, V.str(why, 120), ctx)
    return true, { cid = cid }
end, { rate = 800 })

Api.register('prison.adjust', 'prison.manage', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local months = V.int(data.months, 1, maxMonths())
    if not cid or not months then return false, 'bad_request' end
    local i = inmates[cid]
    if not i then return false, 'not_in_prison' end
    local before = i.left
    i.left = months * perMonth()
    if months > i.months then i.months = months end
    if saveLeft(i) == nil then return false, 'save_failed' end
    local src = liveSrc(i)
    if src then
        setMeta(src, i.left)
        sendState(i, false)
        Core.notify(src, ('Your sentence was changed: %d months left.'):format(months), 'primary')
    end
    Audit.log(ctx, 'prison.adjust', cid, { from = before, to = i.left, months = months })
    changed(cid)
    local mugshots = Citizens and Citizens.profiles and Citizens.profiles({ cid }) or {}
    return true, inmateView(i, mugshots)
end, { rate = 800 })

local function onLogin(src)
    local p = Core.player(src)
    if not p then return end
    local cid = p.cid
    local i = inmates[cid]
    if i then
        begin(i, src, true)
        Core.notify(src, ('You have %s left in prison.'):format(duration(i.left)), 'primary')
        changed(cid)
        return
    end
    local owed = Db.single('SELECT 1 AS `owed` FROM `vr_mdt_prison` WHERE `cid` = ? AND `released_at` IS NOT NULL AND `confiscated` = 1', { cid })
    if owed then
        giveBack(src)
        setMeta(src, 0)
        Db.update('UPDATE `vr_mdt_prison` SET `confiscated` = 0 WHERE `cid` = ?', { cid })
        TriggerClientEvent('vr-mdt:client:prison', src, { active = false, release = true })
        Core.notify(src, 'You were released from prison while you were away.', 'success')
    end
end
Prison.onLogin = onLogin

local function onLeave(src)
    for cid, i in pairs(inmates) do
        if i.src == src then
            i.src = nil
            CreateThread(function()
                saveLeft(i)
                changed(cid)
            end)
        end
    end
end

Bridge.on('playerLoaded', function(src)
    if not src then return end
    CreateThread(function()
        if Db.isReady() then onLogin(src) end
    end)
end)

Bridge.on('playerUnloaded', function(src)
    onLeave(tonumber(src))
end)

AddEventHandler('playerDropped', function()
    onLeave(source)
end)

Bridge.callback.register('vr-mdt:prison:mine', function(src)
    local p = Core.player(src)
    local i = p and inmates[p.cid]
    if not i then return nil end
    if liveSrc(i) ~= src then begin(i, src, false) end
    return clientState(i, false)
end)

RegisterCommand(Config.Prison.command, function(src)
    if src <= 0 then return end
    local p = Core.player(src)
    local i = p and inmates[p.cid]
    if not i then
        Core.notify(src, "You're not in prison.", 'primary')
        return
    end
    Core.notify(src, ('You have %s left (%d of %d months).'):format(duration(i.left), monthsLeft(i), i.months), 'primary')
end, false)

Db.ready(function()
    local rows = Db.query('SELECT * FROM `vr_mdt_prison` WHERE `released_at` IS NULL') or {}
    for _, r in ipairs(rows) do
        inmates[r.cid] = {
            cid = r.cid, name = r.name, months = tonumber(r.months), left = tonumber(r.seconds_left) or 0, reason = r.reason,
            reportId = r.report_id, byCid = r.by_cid, byName = r.by_name, since = tonumber(r.started_at), confiscated = tonumber(r.confiscated) == 1,
        }
    end
    for _, s in ipairs(GetPlayers()) do
        local src = tonumber(s)
        local p = Core.player(src)
        local i = p and inmates[p.cid]
        if i then begin(i, src, false) end
    end
end)

local runTick = Prison.tick

CreateThread(function()
    local tick = math.max(1, math.floor(tonumber(Config.Prison.tickSeconds) or 10))
    local saveEvery = math.max(tick, math.floor(tonumber(Config.Prison.saveSeconds) or 60))
    local sinceSave = 0
    while true do
        Wait(tick * 1000)
        if Db.isReady() then
            sinceSave = sinceSave + tick
            local save = sinceSave >= saveEvery
            if save then sinceSave = 0 end
            runTick(tick, save)
        end
    end
end)

-- Used by vr-prison (life inside the walls) -------------------------------------------------

exports('PrisonInfo', function()
    return { centre = Config.Prison.centre, radius = Config.Prison.radius, inside = Config.Prison.inside, secondsPerMonth = perMonth() }
end)

exports('PrisonStatus', function(cid)
    cid = V.cid(cid)
    local status = cid and Prison.status(cid)
    if status then status.secondsPerMonth = perMonth() end
    return status
end)

-- Takes time off a sentence. Never leaves less than keepSeconds, returns how many seconds were removed.
exports('PrisonReduce', function(cid, seconds, keepSeconds)
    cid = V.cid(cid)
    local i = cid and inmates[cid]
    seconds = math.floor(tonumber(seconds) or 0)
    if not i or seconds <= 0 then return 0 end
    local keep = math.max(0, math.floor(tonumber(keepSeconds) or 60))
    local newLeft = math.max(math.min(keep, i.left), i.left - seconds)
    local removed = i.left - newLeft
    if removed <= 0 then return 0 end
    i.left = newLeft
    saveLeft(i)
    local src = liveSrc(i)
    if src then
        setMeta(src, i.left)
        sendState(i, false)
    end
    Audit.log(nil, 'prison.reduce', cid, { seconds = removed })
    changed(cid)
    return removed
end)
