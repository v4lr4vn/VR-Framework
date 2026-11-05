Farm = { spots = {}, plants = {}, ready = false, loaded = false }

local KINDS = { field = true, store = true, well = true }
local last = {}
local waiting = {}

local SPOTS = [[CREATE TABLE IF NOT EXISTS `vr_farm_spots` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(16) NOT NULL,
    `label` VARCHAR(48) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `w` DOUBLE NOT NULL DEFAULT 0,
    `radius` DOUBLE NOT NULL DEFAULT 20,
    `ped` VARCHAR(48) NOT NULL DEFAULT '',
    `rate` DOUBLE NOT NULL DEFAULT 0,
    `points` TEXT NULL,
    `min_z` DOUBLE NOT NULL DEFAULT 0,
    `max_z` DOUBLE NOT NULL DEFAULT 0,
    `crops` VARCHAR(512) NOT NULL DEFAULT '',
    `irrigated` TINYINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Tables made by the first version get the new columns. One statement, a no-op when they exist.
local SPOTS_UPGRADE = [[ALTER TABLE `vr_farm_spots`
    ADD COLUMN IF NOT EXISTS `points` TEXT NULL,
    ADD COLUMN IF NOT EXISTS `min_z` DOUBLE NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `max_z` DOUBLE NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS `crops` VARCHAR(512) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS `irrigated` TINYINT NOT NULL DEFAULT 0]]

local PLANTS = [[CREATE TABLE IF NOT EXISTS `vr_farm_plants` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `field` INT UNSIGNED NOT NULL,
    `crop` VARCHAR(32) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `owner` VARCHAR(64) NOT NULL,
    `owner_name` VARCHAR(64) NOT NULL DEFAULT '',
    `planted` INT UNSIGNED NOT NULL,
    `last` INT UNSIGNED NOT NULL,
    `progress` DOUBLE NOT NULL DEFAULT 0,
    `water` DOUBLE NOT NULL DEFAULT 0,
    `dry` DOUBLE NOT NULL DEFAULT 0,
    `fert` TINYINT NOT NULL DEFAULT 0,
    `ready_at` INT UNSIGNED NOT NULL DEFAULT 0,
    `dead_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `owner` (`owner`),
    KEY `field` (`field`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local CANS = [[CREATE TABLE IF NOT EXISTS `vr_farm_cans` (
    `cid` VARCHAR(64) NOT NULL,
    `charges` INT NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Farm.fail(code, data)
    return { ok = false, error = code, data = data }
end

function Farm.info(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return { src = src, cid = p.cid, name = p.name or 'Citizen' }
end

function Farm.notify(src, text, kind)
    Bridge.notify(src, text, kind or 'inform', nil, 'Farming')
end

function Farm.throttle(src, key, ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return false end
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

function Farm.admin(src)
    if not src or src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

function Farm.num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

function Farm.count(src, item, metadata)
    return tonumber(Bridge.inventory.count(src, item, metadata)) or 0
end

function Farm.take(src, item, count, metadata)
    return Bridge.inventory.remove(src, item, count, metadata) ~= false
end

function Farm.give(src, item, count, metadata)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return true end
    return Bridge.inventory.add(src, item, count, metadata) ~= false
end

function Farm.canCarry(src, item, count, metadata)
    if not Bridge.inventory.canCarry then return true end
    return Bridge.inventory.canCarry(src, item, count, metadata) ~= false
end

function Farm.pay(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.addMoney(src, Config.Account, amount, reason or 'Farming') == true
end

function Farm.charge(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.removeMoney(src, Config.Account, amount, reason or 'Farming') == true
end

function Farm.spot(id)
    return Farm.spots[tonumber(id) or -1]
end

function Farm.distance(src, x, y, z)
    local p = Bridge.coords(src)
    if not p then return nil end
    local dx, dy, dz = p.x - x, p.y - y, p.z - z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Farm.near(src, spot)
    local d = Farm.distance(src, spot.x, spot.y, spot.z)
    return d ~= nil and d <= Config.Reach + 2.0
end

function Farm.view(spot)
    return {
        id = spot.id, kind = spot.kind, label = spot.label, x = spot.x, y = spot.y, z = spot.z, w = spot.w,
        radius = spot.radius, ped = spot.ped, rate = spot.rate,
        points = spot.points, minZ = spot.minZ, maxZ = spot.maxZ, crops = spot.crops, irrigated = spot.irrigated == true,
    }
end

local function inPoly(x, y, points)
    local inside = false
    local j = #points
    for i = 1, #points do
        local a, b = points[i], points[j]
        if (a.y > y) ~= (b.y > y) and x < (b.x - a.x) * (y - a.y) / (b.y - a.y) + a.x then inside = not inside end
        j = i
    end
    return inside
end

-- True when a point is inside a field, whether it is drawn corner by corner or round.
function Farm.inField(spot, x, y, z)
    if spot.points and #spot.points >= 3 then
        if z and spot.minZ and spot.maxZ and spot.maxZ > spot.minZ and (z < spot.minZ or z > spot.maxZ) then return false end
        return inPoly(x, y, spot.points)
    end
    local dx, dy = x - spot.x, y - spot.y
    local r = spot.radius or 20.0
    return dx * dx + dy * dy <= r * r
end

-- Whether a field lets this crop grow. No list means every crop.
function Farm.allows(spot, crop)
    if not spot.crops or #spot.crops == 0 then return true end
    for _, c in ipairs(spot.crops) do
        if c == crop then return true end
    end
    return false
end

function Farm.cropNames(list)
    local out = {}
    for _, c in ipairs(list or {}) do out[#out + 1] = Config.Crops[c] and Config.Crops[c].label or c end
    return table.concat(out, ', ')
end

-- Turns the corners an admin walked into a field shape. Returns nil and a reason when it is not usable.
function Farm.shape(points)
    if type(points) ~= 'table' or #points < 3 then return nil, 'few_corners' end
    if #points > 40 then return nil, 'many_corners' end
    local pts, sx, sy, sz = {}, 0.0, 0.0, 0.0
    local minX, maxX, minY, maxY, low, high
    for _, p in ipairs(points) do
        local x, y, z = type(p) == 'table' and Farm.num(p.x), type(p) == 'table' and Farm.num(p.y), type(p) == 'table' and Farm.num(p.z)
        if not (x and y and z) or math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 3000 then return nil, 'bad_corner' end
        pts[#pts + 1] = { x = x + 0.0, y = y + 0.0 }
        sx, sy, sz = sx + x, sy + y, sz + z
        minX, maxX = minX and math.min(minX, x) or x, maxX and math.max(maxX, x) or x
        minY, maxY = minY and math.min(minY, y) or y, maxY and math.max(maxY, y) or y
        low, high = low and math.min(low, z) or z, high and math.max(high, z) or z
    end
    if maxX - minX > 500.0 or maxY - minY > 500.0 then return nil, 'too_big' end
    local area = 0.0
    for i = 1, #pts do
        local a, b = pts[i], pts[i % #pts + 1]
        area = area + (a.x * b.y - b.x * a.y)
    end
    if math.abs(area) / 2.0 < 4.0 then return nil, 'too_small' end
    local n = #pts
    local cx, cy = sx / n, sy / n
    local reach = 0.0
    for _, p in ipairs(pts) do
        reach = math.max(reach, math.sqrt((p.x - cx) ^ 2 + (p.y - cy) ^ 2))
    end
    local depth = Config.FieldDepth
    return {
        points = pts, x = cx + 0.0, y = cy + 0.0, z = sz / n + 0.0, radius = reach + 0.0,
        minZ = low - depth.below, maxZ = high + depth.above,
    }
end

local function cropsToText(list)
    return list and #list > 0 and table.concat(list, ',') or ''
end

local function cropsFromText(text)
    local out = {}
    for name in tostring(text or ''):gmatch('[^,]+') do
        if Config.Crops[name] then out[#out + 1] = name end
    end
    return #out > 0 and out or nil
end

function Farm.list()
    local out = {}
    for _, spot in pairs(Farm.spots) do out[#out + 1] = Farm.view(spot) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Farm.push(to)
    TriggerClientEvent('vr-farming:client:spots', to or -1, Farm.list())
end

function Farm.onReady(fn)
    if Farm.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

function Farm.clean(data, base)
    local out = base or {}
    if data.label ~= nil then
        if type(data.label) ~= 'string' then return nil, 'bad_value' end
        local label = data.label:gsub('[%c]', ''):sub(1, 48)
        if #label < 2 then return nil, 'bad_value' end
        out.label = label
    end
    if data.ped ~= nil then
        if data.ped == false or data.ped == '' then
            out.ped = false
        elseif type(data.ped) == 'string' then
            local ped = data.ped:gsub('[^%w_]', ''):sub(1, 48)
            out.ped = ped ~= '' and ped or false
        else
            return nil, 'bad_value'
        end
    end
    if data.rate ~= nil then
        if data.rate == false or data.rate == 0 then
            out.rate = false
        else
            local rate = Farm.num(data.rate)
            if not rate then return nil, 'bad_value' end
            out.rate = math.max(0.05, math.min(2.0, rate))
        end
    end
    if data.crops ~= nil then
        if data.crops == false or (type(data.crops) == 'table' and #data.crops == 0) then
            out.crops = false
        elseif type(data.crops) == 'table' then
            local seen, list = {}, {}
            for _, name in ipairs(data.crops) do
                if type(name) ~= 'string' or not Config.Crops[name] then return nil, 'bad_value' end
                if not seen[name] then
                    seen[name] = true
                    list[#list + 1] = name
                end
            end
            table.sort(list)
            out.crops = list
        else
            return nil, 'bad_value'
        end
    end
    if data.irrigated ~= nil then
        if type(data.irrigated) ~= 'boolean' then return nil, 'bad_value' end
        out.irrigated = data.irrigated
    end
    if data.radius ~= nil then
        local radius = Farm.num(data.radius)
        if not radius then return nil, 'bad_value' end
        out.radius = math.max(3.0, math.min(120.0, radius))
    end
    return out
end

function Farm.save(spot)
    MySQL.query('UPDATE vr_farm_spots SET kind = ?, label = ?, x = ?, y = ?, z = ?, w = ?, radius = ?, ped = ?, rate = ?, points = ?, min_z = ?, max_z = ?, crops = ?, irrigated = ? WHERE id = ?', {
        spot.kind, spot.label, spot.x, spot.y, spot.z, spot.w, spot.radius or 20.0, spot.ped or '', spot.rate or 0,
        spot.points and json.encode(spot.points) or '', spot.minZ or 0, spot.maxZ or 0, cropsToText(spot.crops), spot.irrigated and 1 or 0, spot.id,
    })
end

function Farm.create(kind, label, pos, radius, shape)
    local id = MySQL.insert.await('INSERT INTO vr_farm_spots (kind, label, x, y, z, w, radius) VALUES (?, ?, ?, ?, ?, ?, ?)', { kind, label, pos.x, pos.y, pos.z, pos.w, radius or 20.0 })
    if not id then return nil end
    local spot = { id = id, kind = kind, label = label, x = pos.x, y = pos.y, z = pos.z, w = pos.w, radius = radius or 20.0 }
    if shape then
        spot.points, spot.minZ, spot.maxZ = shape.points, shape.minZ, shape.maxZ
        spot.x, spot.y, spot.z, spot.radius = shape.x, shape.y, shape.z, shape.radius
    end
    Farm.spots[id] = spot
    return spot
end

function Farm.delete(spot)
    MySQL.query('DELETE FROM vr_farm_spots WHERE id = ?', { spot.id })
    Farm.spots[spot.id] = nil
end

-- Seed item for a crop.
function Farm.seedOf(crop) return crop .. '_seed' end

MySQL.ready(function()
    local ok, err = pcall(function()
        MySQL.query.await(SPOTS)
        pcall(function() MySQL.query.await(SPOTS_UPGRADE) end)
        MySQL.query.await(PLANTS)
        MySQL.query.await(CANS)
    end)
    if not ok then print(('^1[vr-farming] schema: %s^0'):format(tostring(err))) end
    local rows = {}
    if ok then rows = MySQL.query.await('SELECT id, kind, label, x, y, z, w, radius, ped, rate, points, min_z, max_z, crops, irrigated FROM vr_farm_spots') or {} end
    for _, r in ipairs(rows) do
        if KINDS[r.kind] then
            Farm.spots[r.id] = {
                id = r.id, kind = r.kind, label = r.label, x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, w = (r.w or 0.0) + 0.0,
                radius = (tonumber(r.radius) or 20.0) + 0.0,
                ped = (r.ped and r.ped ~= '') and r.ped or nil,
                rate = (tonumber(r.rate) or 0) > 0 and tonumber(r.rate) or nil,
                crops = cropsFromText(r.crops),
                irrigated = (tonumber(r.irrigated) or 0) == 1,
            }
            local spot = Farm.spots[r.id]
            if type(r.points) == 'string' and r.points ~= '' then
                local good, pts = pcall(json.decode, r.points)
                if good and type(pts) == 'table' and #pts >= 3 then
                    spot.points = {}
                    for i, p in ipairs(pts) do spot.points[i] = { x = (tonumber(p.x) or 0) + 0.0, y = (tonumber(p.y) or 0) + 0.0 } end
                    spot.minZ, spot.maxZ = (tonumber(r.min_z) or 0) + 0.0, (tonumber(r.max_z) or 0) + 0.0
                end
            end
        end
    end
    if ok and Farm.loadPlants then Farm.loadPlants() end
    Farm.ready = true
    Farm.loaded = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
    Farm.push()
end)

lib.callback.register('vr-farming:spots', function()
    if not Farm.loaded then return {} end
    return Farm.list()
end)

Bridge.on('playerLoaded', function(src)
    if Farm.loaded then Farm.push(src) end
end)
