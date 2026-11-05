local inv = Bridge.inventory

local sessions = {}
local lastPhoto = {}
local hourly = {}

local PREFIXES = {
    'data:image/jpeg;base64,',
    'data:image/png;base64,',
    'data:image/webp;base64,',
}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vr_camera_photos` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `image` MEDIUMTEXT NOT NULL,
            `location` VARCHAR(128) NOT NULL DEFAULT '',
            `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `citizenid` (`citizenid`),
            KEY `created_at` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]])
    local days = tonumber(Config.PhotoRetentionDays) or 0
    if days > 0 then
        MySQL.update.await('DELETE FROM vr_camera_photos WHERE created_at < (NOW() - INTERVAL ? DAY)', { math.floor(days) })
    end
end)

local function notify(src, msg, kind)
    Bridge.notify(src, msg, kind or 'primary')
end

local function hasItem(src, item)
    return inv.count(src, item) > 0
end

local function validImage(data)
    if type(data) ~= 'string' or #data > Config.MaxPhotoBytes then return false end
    for _, prefix in ipairs(PREFIXES) do
        if data:sub(1, #prefix) == prefix then
            local body = #data - #prefix
            return body > 100 and not data:find('[^A-Za-z0-9+/=]', #prefix + 1)
        end
    end
    return false
end

local function cleanLocation(text)
    if type(text) ~= 'string' then return 'Unknown' end
    text = text:gsub('[%c<>]', ''):sub(1, 64)
    text = text:match('^%s*(.-)%s*$')
    return text ~= '' and text or 'Unknown'
end

local function photosThisHour(cid)
    local list, t, out = hourly[cid] or {}, os.time(), {}
    for i = 1, #list do
        if t - list[i] < 3600 then out[#out + 1] = list[i] end
    end
    hourly[cid] = out
    return #out
end

Bridge.useItem(Config.CameraItem, function(source)
    local src = source
    if GetResourceState('screenshot-basic') ~= 'started' then
        notify(src, 'The camera needs screenshot-basic, which is not running on this server', 'error')
        return
    end
    local token = ('%d-%d'):format(math.random(100000, 999999), GetGameTimer())
    sessions[src] = token
    TriggerClientEvent('vr-camera:client:useCamera', src, token)
end)

RegisterNetEvent('vr-camera:server:savePhoto', function(token, image, location)
    local src = source
    if type(token) ~= 'string' or sessions[src] ~= token then return end
    sessions[src] = nil

    local cid = Bridge.cid(src)
    if not cid or not hasItem(src, Config.CameraItem) then return end

    local t = os.time()
    if lastPhoto[src] and t - lastPhoto[src] < Config.PhotoCooldown then return end
    if photosThisHour(cid) >= Config.MaxPhotosPerHour then
        return notify(src, 'Your memory card is full, try again later', 'error')
    end
    if not validImage(image) then
        return notify(src, 'The photo could not be saved', 'error')
    end
    if not inv.canCarry(src, Config.PhotoItem, 1) then
        return notify(src, "You can't carry the photo", 'error')
    end

    location = cleanLocation(location)
    lastPhoto[src] = t
    hourly[cid] = hourly[cid] or {}
    hourly[cid][#hourly[cid] + 1] = t

    local id = MySQL.insert.await('INSERT INTO vr_camera_photos (citizenid, image, location) VALUES (?, ?, ?)', { cid, image, location })
    if not id then return notify(src, 'The photo could not be saved', 'error') end

    local metadata = {
        photo_id = id,
        location = location,
        description = ('Taken at %s'):format(location),
    }
    if not inv.add(src, Config.PhotoItem, 1, metadata) then
        MySQL.update.await('DELETE FROM vr_camera_photos WHERE id = ?', { id })
        return notify(src, "You can't carry the photo", 'error')
    end
end)

RegisterNetEvent('vr-camera:server:closeCamera', function()
    sessions[source] = nil
end)

Bridge.useItem(Config.PhotoItem, function(source, item)
    local src = source
    local metadata = item and (item.metadata or item.info) or {}
    local id = tonumber(metadata.photo_id)
    local row = id and MySQL.single.await('SELECT image, location FROM vr_camera_photos WHERE id = ?', { id })
    if not row then
        TriggerClientEvent('vr-camera:client:usePhoto', src, nil, cleanLocation(metadata.location))
        return
    end
    TriggerLatentClientEvent('vr-camera:client:usePhoto', src, 250000, row.image, row.location)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastPhoto[source] = nil
end)