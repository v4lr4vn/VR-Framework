Fence = { spots = {}, ready = false, loaded = false }

local KINDS = { launder = true, pawn = true }
local last = {}
local waiting = {}

local TABLE = [[CREATE TABLE IF NOT EXISTS `vr_fence_spots` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `kind` VARCHAR(16) NOT NULL,
    `label` VARCHAR(48) NOT NULL,
    `x` DOUBLE NOT NULL,
    `y` DOUBLE NOT NULL,
    `z` DOUBLE NOT NULL,
    `w` DOUBLE NOT NULL DEFAULT 0,
    `ped` VARCHAR(48) NOT NULL DEFAULT '',
    `rate` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local JOBS = [[CREATE TABLE IF NOT EXISTS `vr_fence_jobs` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cid` VARCHAR(64) NOT NULL,
    `spot` INT UNSIGNED NOT NULL,
    `amount` INT UNSIGNED NOT NULL,
    `paid` INT UNSIGNED NOT NULL,
    `created` INT UNSIGNED NOT NULL,
    `ready` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Fence.fail(code, data)
    return { ok = false, error = code, data = data }
end

function Fence.info(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return { src = src, cid = p.cid, name = p.name or 'Citizen' }
end

function Fence.notify(src, text, kind)
    Bridge.notify(src, text, kind or 'inform', nil, 'Fence')
end

function Fence.throttle(src, key, ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return false end
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

function Fence.admin(src)
    if not src or src <= 0 then return false end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

function Fence.num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

function Fence.count(src, item)
    return tonumber(Bridge.inventory.count(src, item)) or 0
end

function Fence.take(src, item, count)
    return Bridge.inventory.remove(src, item, count) ~= false
end

function Fence.give(src, item, count)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return true end
    return Bridge.inventory.add(src, item, count) ~= false
end

function Fence.pay(src, amount)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.addMoney(src, Config.Account, amount, 'Fence') == true
end

function Fence.spot(id)
    return Fence.spots[tonumber(id) or -1]
end

function Fence.near(src, spot)
    local p = Bridge.coords(src)
    if not p or not spot then return false end
    local dx, dy, dz = p.x - spot.x, p.y - spot.y, p.z - spot.z
    return dx * dx + dy * dy + dz * dz <= (Config.Reach + 2.0) ^ 2
end

function Fence.view(spot)
    return { id = spot.id, kind = spot.kind, label = spot.label, x = spot.x, y = spot.y, z = spot.z, w = spot.w, ped = spot.ped, rate = spot.rate }
end

function Fence.list()
    local out = {}
    for _, spot in pairs(Fence.spots) do out[#out + 1] = Fence.view(spot) end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

function Fence.push(to)
    TriggerClientEvent('vr-fence:client:spots', to or -1, Fence.list())
end

function Fence.onReady(fn)
    if Fence.ready then
        CreateThread(fn)
    else
        waiting[#waiting + 1] = fn
    end
end

function Fence.clean(kind, data, base)
    local out = base or {}
    if kind then
        if not KINDS[kind] then return nil, 'bad_kind' end
        out.kind = kind
    end
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
            local rate = Fence.num(data.rate)
            if not rate then return nil, 'bad_value' end
            out.rate = math.max(0.05, math.min(1.5, rate))
        end
    end
    return out
end

function Fence.save(spot)
    MySQL.query('UPDATE vr_fence_spots SET kind = ?, label = ?, x = ?, y = ?, z = ?, w = ?, ped = ?, rate = ? WHERE id = ?', { spot.kind, spot.label, spot.x, spot.y, spot.z, spot.w, spot.ped or '', spot.rate or 0, spot.id })
end

function Fence.create(kind, label, pos)
    local id = MySQL.insert.await('INSERT INTO vr_fence_spots (kind, label, x, y, z, w) VALUES (?, ?, ?, ?, ?, ?)', { kind, label, pos.x, pos.y, pos.z, pos.w })
    if not id then return nil end
    local spot = { id = id, kind = kind, label = label, x = pos.x, y = pos.y, z = pos.z, w = pos.w }
    Fence.spots[id] = spot
    return spot
end

function Fence.delete(spot)
    MySQL.query('DELETE FROM vr_fence_spots WHERE id = ?', { spot.id })
    Fence.spots[spot.id] = nil
end

MySQL.ready(function()
    local ok, err = pcall(function() MySQL.query.await(TABLE) MySQL.query.await(JOBS) end)
    if not ok then print(('^1[vr-fence] schema: %s^0'):format(tostring(err))) end
    local rows = {}
    if ok then rows = MySQL.query.await('SELECT id, kind, label, x, y, z, w, ped, rate FROM vr_fence_spots') or {} end
    for _, r in ipairs(rows) do
        if KINDS[r.kind] then
            Fence.spots[r.id] = { id = r.id, kind = r.kind, label = r.label, x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0, w = (r.w or 0.0) + 0.0, ped = (r.ped and r.ped ~= '') and r.ped or nil, rate = (tonumber(r.rate) or 0) > 0 and tonumber(r.rate) or nil }
        end
    end
    Fence.ready = true
    Fence.loaded = true
    for i = 1, #waiting do CreateThread(waiting[i]) end
    waiting = {}
    Fence.push()
end)

lib.callback.register('vr-fence:spots', function()
    if not Fence.loaded then return {} end
    return Fence.list()
end)

Bridge.on('playerLoaded', function(src)
    if Fence.loaded then Fence.push(src) end
end)
