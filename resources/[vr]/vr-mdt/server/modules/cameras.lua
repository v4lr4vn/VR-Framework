Cameras = {}

local watching = {}

Db.schema('cameras', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_cameras` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `label` VARCHAR(64) NOT NULL,
        `location` VARCHAR(48) NOT NULL,
        `x` DOUBLE NOT NULL,
        `y` DOUBLE NOT NULL,
        `z` DOUBLE NOT NULL,
        `heading` DOUBLE NOT NULL,
        `pitch` DOUBLE NOT NULL,
        `fov` DOUBLE NOT NULL,
        `created_by` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `location` (`location`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function limits()
    local c = Config.Cameras
    return { yaw = c.yawRange, pitch = c.pitchRange, fovMin = c.fov.min, fovMax = c.fov.max, pitchMin = c.pitch.min, pitchMax = c.pitch.max }
end

local function toCam(r)
    return {
        id = r.id,
        label = r.label,
        location = r.location,
        x = U.round(tonumber(r.x) or 0, 2),
        y = U.round(tonumber(r.y) or 0, 2),
        z = U.round(tonumber(r.z) or 0, 2),
        heading = U.round(tonumber(r.heading) or 0, 1),
        pitch = U.round(tonumber(r.pitch) or 0, 1),
        fov = U.round(tonumber(r.fov) or 0, 1),
        createdBy = r.created_by,
        createdAt = r.created_at,
    }
end

local function normHeading(h)
    h = (tonumber(h) or 0) % 360
    if h < 0 then h = h + 360 end
    return U.round(h, 1)
end

local function insertCamera(c, cid)
    return Db.insert('INSERT INTO `vr_mdt_cameras` (`label`, `location`, `x`, `y`, `z`, `heading`, `pitch`, `fov`, `created_by`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)', {
        c.label, c.location, c.x, c.y, c.z, c.heading, c.pitch, c.fov, cid, U.now(),
    })
end

local function cleanDefault(d)
    if type(d) ~= 'table' then return nil end
    local pos = V.vec(d.coords)
    local label = V.str(d.label, 64)
    local location = V.str(d.location, 48)
    if not pos or not label or not location then return nil end
    local cfg = Config.Cameras
    return {
        label = label,
        location = location,
        x = pos.x, y = pos.y, z = pos.z,
        heading = normHeading(d.heading),
        pitch = V.num(d.pitch, cfg.pitch.min, cfg.pitch.max) or cfg.pitch.default,
        fov = V.num(d.fov, cfg.fov.min, cfg.fov.max) or cfg.fov.default,
    }
end

function Cameras.seed()
    local count = tonumber(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_cameras`'))
    if count == nil or count > 0 then return 0 end
    local seeded = tonumber(Db.scalar("SELECT COUNT(*) FROM `vr_mdt_audit` WHERE `action` = 'cameras.seed'"))
    if seeded == nil or seeded > 0 then return 0 end
    local n = 0
    for _, d in ipairs(Config.Cameras.defaults or {}) do
        local c = cleanDefault(d)
        if c and insertCamera(c, nil) then n = n + 1 end
    end
    Audit.log(nil, 'cameras.seed', nil, { count = n })
    return n
end

function Cameras.list()
    local rows = Db.query(('SELECT * FROM `vr_mdt_cameras` ORDER BY `location` ASC, `label` ASC, `id` ASC LIMIT %d'):format(Config.Cameras.max)) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = toCam(r) end
    return out
end

function Cameras.get(id)
    id = V.id(id)
    local row = id and Db.single('SELECT * FROM `vr_mdt_cameras` WHERE `id` = ? LIMIT 1', { id })
    return row and toCam(row) or nil
end

function Cameras.nearest(coords, radius)
    local c = V.vec(coords)
    if not c then return {} end
    radius = V.num(radius, 1, 5000) or 150.0
    local out = {}
    for _, cam in ipairs(Cameras.list()) do
        local dx, dy, dz = cam.x - c.x, cam.y - c.y, cam.z - c.z
        local d = math.sqrt(dx * dx + dy * dy + dz * dz)
        if d <= radius then
            cam.distance = U.round(d, 1)
            out[#out + 1] = cam
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

local function pushChanged(payload)
    Push.dept('police', 'cameras:changed', payload, function(c)
        return Core.can(c, 'cameras.view')
    end)
end

Api.register('cameras.list', 'cameras.view', function(src, ctx)
    return true, { cameras = Cameras.list(), canManage = Core.can(ctx, 'cameras.manage'), limits = limits() }
end, { rate = 400 })

Api.register('cameras.add', 'cameras.manage', function(src, ctx, data)
    local cfg = Config.Cameras
    local label = V.str(data.label, 64, 2)
    local location = V.str(data.location, 48, 2)
    if not label or not location then return false, 'bad_request' end
    local pitch = cfg.pitch.default
    if data.pitch ~= nil then
        pitch = V.num(data.pitch, cfg.pitch.min, cfg.pitch.max)
        if not pitch then return false, 'bad_request' end
    end
    local fov = cfg.fov.default
    if data.fov ~= nil then
        fov = V.num(data.fov, cfg.fov.min, cfg.fov.max)
        if not fov then return false, 'bad_request' end
    end
    local count = tonumber(Db.scalar('SELECT COUNT(*) FROM `vr_mdt_cameras`')) or 0
    if count >= cfg.max then return false, 'too_many' end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false, 'no_ped' end
    local pos = V.vec(GetEntityCoords(ped))
    if not pos then return false, 'no_ped' end
    local x, y, z, heading
    local at = data.at ~= nil and V.vec(data.at) or nil
    if data.at ~= nil then
        if not at then return false, 'bad_request' end
        local dx, dy, dz = at.x - pos.x, at.y - pos.y, at.z - pos.z
        if dx * dx + dy * dy + dz * dz > (cfg.aimRange or 80.0) ^ 2 + 3600 then return false, 'too_far' end
        x, y, z = at.x, at.y, at.z
        heading = tonumber(data.heading)
        if heading == nil or heading ~= heading or math.abs(heading) > 100000 then return false, 'bad_request' end
    else
        x, y, z = pos.x, pos.y, pos.z + cfg.mountHeight
        heading = GetEntityHeading(ped)
    end
    local cam = {
        label = label,
        location = location,
        x = U.round(x, 2),
        y = U.round(y, 2),
        z = U.round(z, 2),
        heading = normHeading(heading),
        pitch = U.round(pitch, 1),
        fov = U.round(fov, 1),
    }
    local id = insertCamera(cam, ctx.cid)
    if not id then return false, 'save_failed' end
    Audit.log(ctx, 'cameras.add', id, { label = label, location = location, x = cam.x, y = cam.y, z = cam.z })
    pushChanged({ id = id })
    return true, Cameras.get(id)
end, { rate = 1000 })

Api.register('cameras.remove', 'cameras.manage', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local cam = Cameras.get(id)
    if not cam then return false, 'not_found' end
    local done = Db.update('DELETE FROM `vr_mdt_cameras` WHERE `id` = ?', { id })
    if done == nil then return false, 'save_failed' end
    Audit.log(ctx, 'cameras.remove', id, { label = cam.label, location = cam.location })
    pushChanged({ id = id, removed = true })
    return true, { id = id }
end, { rate = 800 })

Api.register('cameras.view', 'cameras.view', function(src, ctx, data)
    local id = V.id(data.id)
    if not id then return false, 'bad_request' end
    local cam = Cameras.get(id)
    if not cam then return false, 'not_found' end
    cam.limits = limits()
    return true, cam
end, { rate = 300 })

local function onDutyOfficer(cid)
    local p = Core.playerByCid(cid)
    if not p then return nil end
    local c = Core.context(p.source)
    if not c or c.dept ~= 'police' then return nil end
    return c
end

local function pedInfo(target)
    local ped = GetPlayerPed(target.src)
    if not ped or ped == 0 then return nil end
    local pos = V.vec(GetEntityCoords(ped))
    if not pos then return nil end
    return { coords = U.vec(pos), heading = U.round(GetEntityHeading(ped) or 0, 1) }
end

function Cameras.watching(src)
    return watching[src]
end

Api.register('bodycams.list', 'bodycams.view', function(src, ctx)
    local out = {}
    for _, c in ipairs(Core.onlineInDept('police')) do
        if c.cid ~= ctx.cid then
            local unit = Units and Units.get and Units.get(c.cid) or nil
            out[#out + 1] = {
                cid = c.cid,
                name = c.name,
                callsign = c.callsign,
                gradeName = c.gradeName,
                status = unit and unit.status or 'available',
                callId = unit and unit.callId or nil,
            }
        end
    end
    table.sort(out, function(a, b) return (a.callsign or a.name) < (b.callsign or b.name) end)
    return true, out
end, { rate = 500 })

Api.register('bodycams.start', 'bodycams.view', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    if cid == ctx.cid then return false, 'cant_self' end
    local target = onDutyOfficer(cid)
    if not target then return false, 'unit_unavailable' end
    local info = pedInfo(target)
    if not info then return false, 'unit_unavailable' end
    watching[src] = { cid = cid, since = U.now() }
    Audit.log(ctx, 'bodycams.start', cid, { callsign = target.callsign, name = target.name })
    return true, {
        cid = cid,
        name = target.name,
        callsign = target.callsign,
        serverId = target.src,
        coords = info.coords,
        heading = info.heading,
        refresh = Config.Cameras.bodycam.refreshMs,
    }
end, { rate = 1000 })

Api.register('bodycams.pos', 'bodycams.view', function(src, ctx, data)
    local cid = V.cid(data.cid)
    if not cid then return false, 'bad_request' end
    local w = watching[src]
    if not w or w.cid ~= cid then return false, 'not_allowed' end
    local target = onDutyOfficer(cid)
    local info = target and pedInfo(target)
    if not info then
        watching[src] = nil
        return false, 'unit_unavailable'
    end
    info.serverId = target.src
    return true, info
end, { rate = 900 })

Api.register('bodycams.stop', nil, function(src)
    watching[src] = nil
    return true, true
end, { rate = 200 })

AddEventHandler('playerDropped', function()
    watching[source] = nil
end)

Db.ready(function()
    Cameras.seed()
end)
