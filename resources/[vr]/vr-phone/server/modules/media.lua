-- Photos, and the albums that hold them.
--
-- A photo belongs to the phone (like contacts and settings), so it moves with the phone item.
-- The screen resizes every photo before it sends it, so a stored photo is a small JPEG as text (a data URI), plus a tiny
-- thumbnail for the grid. If the server owner has a picture host, Config.Phone.Media.upload can swap the stored photo for a link.
local Media = {}
Phone.Media = Media

local function cfg() return Config.Phone.Media or {} end

local function number(v, default) return tonumber(v) or default end

-- ---------------------------------------------------------------- checking what the screen sent

local JPEG_PREFIX = 'data:image/jpeg;base64,'

-- A JPEG data URI, nothing else. Starts with the JPEG signature ("/9j/" in base64) and holds only base64 characters.
function Media.validImage(value, maxBytes)
    if type(value) ~= 'string' or #value > maxBytes then return false end
    if value:sub(1, #JPEG_PREFIX) ~= JPEG_PREFIX then return false end
    local body = value:sub(#JPEG_PREFIX + 1)
    if #body < 100 or body:sub(1, 4) ~= '/9j/' then return false end
    if body:find('[^A-Za-z0-9+/=]') then return false end
    return true
end

-- ---------------------------------------------------------------- albums

local MAX_ALBUMS = 24

function Media.albums(phoneId)
    local rows = MySQL.query.await(
        'SELECT a.`id`, a.`name`, '
            .. '(SELECT COUNT(*) FROM `vr_ph_media` m WHERE m.`album_id` = a.`id` AND m.`deleted_at` = 0) AS `count` '
            .. 'FROM `vr_ph_albums` a WHERE a.`phone_id` = ? ORDER BY a.`name` LIMIT ' .. MAX_ALBUMS,
        { phoneId }
    ) or {}
    local out = {}
    for i, row in ipairs(rows) do out[i] = { id = row.id, name = row.name, count = tonumber(row.count) or 0 } end
    return out
end

local function ownsAlbum(phoneId, id)
    id = tonumber(id)
    if not id then return nil end
    return MySQL.scalar.await('SELECT `id` FROM `vr_ph_albums` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
end

function Media.createAlbum(phoneId, name)
    name = Phone.text(name, 24)
    if not name then return nil, 'invalid_name' end
    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_albums` WHERE `phone_id` = ?', { phoneId })) or 0
    if count >= MAX_ALBUMS then return nil, 'full' end
    local clash = MySQL.scalar.await('SELECT `id` FROM `vr_ph_albums` WHERE `phone_id` = ? AND `name` = ?', { phoneId, name })
    if clash then return nil, 'duplicate' end
    local id = MySQL.insert.await('INSERT INTO `vr_ph_albums` (`phone_id`, `name`) VALUES (?, ?)', { phoneId, name })
    if not id then return nil, 'failed' end
    return { id = id, name = name, count = 0 }
end

function Media.renameAlbum(phoneId, id, name)
    name = Phone.text(name, 24)
    if not name then return false, 'invalid_name' end
    if not ownsAlbum(phoneId, id) then return false, 'not_found' end
    local clash = MySQL.scalar.await('SELECT `id` FROM `vr_ph_albums` WHERE `phone_id` = ? AND `name` = ? AND `id` <> ?', { phoneId, name, tonumber(id) })
    if clash then return false, 'duplicate' end
    MySQL.update.await('UPDATE `vr_ph_albums` SET `name` = ? WHERE `phone_id` = ? AND `id` = ?', { name, phoneId, tonumber(id) })
    return true
end

-- The photos stay; they just leave the album.
function Media.removeAlbum(phoneId, id)
    if not ownsAlbum(phoneId, id) then return false end
    id = tonumber(id)
    MySQL.update.await('UPDATE `vr_ph_media` SET `album_id` = NULL WHERE `phone_id` = ? AND `album_id` = ?', { phoneId, id })
    MySQL.update.await('DELETE FROM `vr_ph_albums` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
    return true
end

-- ---------------------------------------------------------------- photos

local function shape(row)
    return {
        id = row.id,
        kind = row.kind,
        thumb = row.thumb,
        width = row.width,
        height = row.height,
        favourite = row.favourite == 1 or row.favourite == true,
        album = row.album_id,
        source = row.source,
        at = row.created_at,
        deletedAt = row.deleted_at ~= 0 and row.deleted_at or nil,
    }
end

-- A page of photos, newest first. view: 'all', 'favourites', 'deleted' or 'album' (with albumId).
-- before: the id of the last photo on the previous page. Returns the list and whether there is more.
function Media.list(phoneId, view, before, albumId)
    local size = number(cfg().pageSize, 24)
    local where, args = '`phone_id` = ?', { phoneId }
    if view == 'deleted' then
        where = where .. ' AND `deleted_at` <> 0'
    else
        where = where .. ' AND `deleted_at` = 0'
        if view == 'favourites' then
            where = where .. ' AND `favourite` = 1'
        elseif view == 'album' then
            local id = tonumber(albumId)
            if not id then return nil, 'not_found' end
            where = where .. ' AND `album_id` = ?'
            args[#args + 1] = id
        end
    end
    before = tonumber(before)
    if before then
        where = where .. ' AND `id` < ?'
        args[#args + 1] = before
    end
    local rows = MySQL.query.await(
        'SELECT `id`, `kind`, `thumb`, `width`, `height`, `favourite`, `album_id`, `source`, `created_at`, `deleted_at` '
            .. 'FROM `vr_ph_media` WHERE ' .. where .. ' ORDER BY `id` DESC LIMIT ' .. (size + 1),
        args
    ) or {}
    local more = #rows > size
    local out = {}
    for i = 1, math.min(#rows, size) do out[i] = shape(rows[i]) end
    return out, more
end

-- The full photo: the picture itself (or its link), and what the info sheet shows.
function Media.get(phoneId, id)
    id = tonumber(id)
    if not id then return nil end
    local row = MySQL.single.await(
        'SELECT `id`, `data`, `url`, `bytes`, `width`, `height`, `source`, `created_at` FROM `vr_ph_media` WHERE `phone_id` = ? AND `id` = ?',
        { phoneId, id }
    )
    if not row then return nil end
    return { id = row.id, image = row.url or row.data, bytes = row.bytes, width = row.width, height = row.height, source = row.source, at = row.created_at }
end

function Media.stats(phoneId)
    local row = MySQL.single.await(
        'SELECT COUNT(*) AS `total`, COALESCE(SUM(`bytes`), 0) AS `bytes`, COALESCE(SUM(`deleted_at` <> 0), 0) AS `deleted` FROM `vr_ph_media` WHERE `phone_id` = ?',
        { phoneId }
    ) or {}
    return {
        photos = tonumber(row.total) or 0,
        bytes = tonumber(row.bytes) or 0,
        deleted = tonumber(row.deleted) or 0,
        max = number(cfg().maxPhotos, 120),
    }
end

-- Stores one photo. rec = { data, thumb, width, height, source }.
-- Returns the photo { id, thumb, ... } or nil and a reason: 'invalid_image', 'too_big', 'full', 'failed'.
function Media.add(phoneId, rec, src)
    if type(rec) ~= 'table' then return nil, 'invalid_image' end
    local maxBytes, maxThumb = number(cfg().maxBytes, 450000), number(cfg().maxThumbBytes, 30000)
    if type(rec.data) == 'string' and #rec.data > maxBytes then return nil, 'too_big' end
    if not Media.validImage(rec.data, maxBytes) or not Media.validImage(rec.thumb, maxThumb) then return nil, 'invalid_image' end

    if Media.stats(phoneId).photos >= number(cfg().maxPhotos, 120) then return nil, 'full' end

    local width = Phone.clamp(rec.width, 16, 4096) or 0
    local height = Phone.clamp(rec.height, 16, 4096) or 0
    local source = rec.source == 'share' and 'share' or rec.source == 'script' and 'script' or 'camera'
    local data, url = rec.data, nil

    -- A picture host: the owner's function turns the photo into a link, and only the link is stored.
    local upload = cfg().upload
    if type(upload) == 'function' then
        local ok, link = pcall(upload, src, rec.data)
        if ok and type(link) == 'string' and link:match('^https?://') and #link <= 400 then
            url, data = link, nil
        end
    end

    local at = os.time()
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_media` (`phone_id`, `kind`, `data`, `thumb`, `url`, `width`, `height`, `bytes`, `source`, `created_at`) '
            .. 'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { phoneId, 'photo', data, rec.thumb, url, math.floor(width), math.floor(height), #rec.data, source, at }
    )
    if not id then return nil, 'failed' end
    return { id = id, kind = 'photo', thumb = rec.thumb, width = width, height = height, favourite = false, source = source, at = at }
end

-- An id list from the screen: whole numbers only, at most `limit` of them.
local function ids(list, limit)
    local out, seen = {}, {}
    if type(list) == 'number' then list = { list } end
    if type(list) ~= 'table' then return out end
    for _, v in ipairs(list) do
        local n = tonumber(v)
        if n and n >= 1 and n == math.floor(n) and not seen[n] then
            seen[n] = true
            out[#out + 1] = n
            if #out >= limit then break end
        end
    end
    return out
end
Media.ids = ids

local function marks(list)
    return string.rep('?,', #list):sub(1, -2)
end

local function change(phoneId, list, sql, extra)
    list = ids(list, 100)
    if #list == 0 then return 0 end
    local args = {}
    for _, v in ipairs(extra or {}) do args[#args + 1] = v end
    args[#args + 1] = phoneId
    for _, v in ipairs(list) do args[#args + 1] = v end
    return MySQL.update.await(sql:format(marks(list)), args) or 0
end

function Media.setFavourite(phoneId, list, on)
    return change(phoneId, list, 'UPDATE `vr_ph_media` SET `favourite` = ? WHERE `phone_id` = ? AND `id` IN (%s)', { on and 1 or 0 })
end

-- Delete moves a photo to Recently deleted. It is gone for good after Config.Phone.Media.keepDeletedDays.
function Media.trash(phoneId, list)
    return change(phoneId, list, 'UPDATE `vr_ph_media` SET `deleted_at` = ? WHERE `phone_id` = ? AND `deleted_at` = 0 AND `id` IN (%s)', { os.time() })
end

function Media.restore(phoneId, list)
    return change(phoneId, list, 'UPDATE `vr_ph_media` SET `deleted_at` = 0 WHERE `phone_id` = ? AND `deleted_at` <> 0 AND `id` IN (%s)')
end

-- Only photos already in Recently deleted can be erased by hand.
function Media.erase(phoneId, list)
    return change(phoneId, list, 'DELETE FROM `vr_ph_media` WHERE `phone_id` = ? AND `deleted_at` <> 0 AND `id` IN (%s)')
end

function Media.emptyTrash(phoneId)
    return MySQL.update.await('DELETE FROM `vr_ph_media` WHERE `phone_id` = ? AND `deleted_at` <> 0', { phoneId }) or 0
end

-- albumId nil takes the photos out of their album.
function Media.setAlbum(phoneId, list, albumId)
    if albumId == nil then
        return change(phoneId, list, 'UPDATE `vr_ph_media` SET `album_id` = NULL WHERE `phone_id` = ? AND `deleted_at` = 0 AND `id` IN (%s)')
    end
    if not ownsAlbum(phoneId, albumId) then return 0, 'not_found' end
    return change(phoneId, list, 'UPDATE `vr_ph_media` SET `album_id` = ? WHERE `phone_id` = ? AND `deleted_at` = 0 AND `id` IN (%s)', { tonumber(albumId) })
end

-- Photos that sat in Recently deleted for too long are erased. Runs once on start and then every hour.
function Media.purgeOld()
    local days = number(cfg().keepDeletedDays, 30)
    local cutoff = os.time() - days * 86400
    return MySQL.update.await('DELETE FROM `vr_ph_media` WHERE `deleted_at` <> 0 AND `deleted_at` < ?', { cutoff }) or 0
end

-- Copies photos from one phone to another (nearby share). Returns how many were copied.
function Media.copy(fromPhoneId, list, toPhoneId)
    list = ids(list, number(Config.Phone.Share and Config.Phone.Share.maxItems, 20))
    if #list == 0 then return 0 end
    local room = number(cfg().maxPhotos, 120) - Media.stats(toPhoneId).photos
    if room <= 0 then return 0, 'full' end
    local args = { toPhoneId, os.time(), fromPhoneId }
    for _, v in ipairs(list) do args[#args + 1] = v end
    local limit = math.min(room, #list)
    local copied = MySQL.update.await(
        'INSERT INTO `vr_ph_media` (`phone_id`, `kind`, `data`, `thumb`, `url`, `width`, `height`, `bytes`, `source`, `created_at`) '
            .. "SELECT ?, `kind`, `data`, `thumb`, `url`, `width`, `height`, `bytes`, 'share', ? FROM `vr_ph_media` "
            .. 'WHERE `phone_id` = ? AND `deleted_at` = 0 AND `id` IN (' .. marks(list) .. ') ORDER BY `id` LIMIT ' .. limit,
        args
    ) or 0
    return copied
end

-- Which of these photo ids does the phone really own (and not deleted)? Returns them in order.
function Media.owned(phoneId, list)
    list = ids(list, 100)
    if #list == 0 then return {} end
    local args = { phoneId }
    for _, v in ipairs(list) do args[#args + 1] = v end
    local rows = MySQL.query.await(
        'SELECT `id` FROM `vr_ph_media` WHERE `phone_id` = ? AND `deleted_at` = 0 AND `id` IN (' .. marks(list) .. ') ORDER BY `id`',
        args
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = r.id end
    return out
end

-- ---------------------------------------------------------------- uploads from the screen
-- A photo is too big for one message, so the game sends it in pieces. One upload per player at a time.

local uploads = {} -- source -> { id, parts, bytes, started }
local MAX_PART = 32768

function Media.uploadStart(src, id, total)
    id = Phone.cut(id, 32)
    total = tonumber(total)
    if not id or not total or total < 1 or total > 40 or total ~= math.floor(total) then return false, 'invalid' end
    uploads[src] = { id = id, total = total, parts = {}, bytes = 0, started = os.time() }
    return true
end

function Media.uploadPart(src, id, index, part)
    local u = uploads[src]
    if not u or u.id ~= id then return false, 'no_upload' end
    index = tonumber(index)
    if not index or index < 1 or index > u.total or index ~= math.floor(index) then return false, 'invalid' end
    if type(part) ~= 'string' or #part == 0 or #part > MAX_PART then return false, 'invalid' end
    if os.time() - u.started > 60 then
        uploads[src] = nil
        return false, 'timeout'
    end
    if not u.parts[index] then
        u.bytes = u.bytes + #part
        if u.bytes > number(cfg().maxBytes, 450000) + number(cfg().maxThumbBytes, 30000) + 1024 then
            uploads[src] = nil
            return false, 'too_big'
        end
        u.parts[index] = part
    end
    return true
end

-- Puts the pieces together. Returns { data, thumb } or nil and a reason.
function Media.uploadFinish(src, id)
    local u = uploads[src]
    if not u or u.id ~= id then return nil, 'no_upload' end
    uploads[src] = nil
    for i = 1, u.total do
        if not u.parts[i] then return nil, 'incomplete' end
    end
    local whole = table.concat(u.parts)
    -- The photo and its thumbnail travel together, split by one line break.
    local data, thumb = whole:match('^([^\n]+)\n([^\n]+)$')
    if not data then return nil, 'invalid_image' end
    return { data = data, thumb = thumb }
end

function Media.uploadCancel(src) uploads[src] = nil end

Phone.Session.onStop(function(src) uploads[src] = nil end)

CreateThread(function()
    Phone.DB.waitReady()
    while true do
        Media.purgeOld()
        Wait(3600 * 1000)
    end
end)
