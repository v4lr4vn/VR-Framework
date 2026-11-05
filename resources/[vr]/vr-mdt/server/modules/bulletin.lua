Bulletin = {}

local DAY = 86400

Db.schema('bulletins', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_bulletins` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `dept` VARCHAR(16) NOT NULL,
        `title` VARCHAR(96) NOT NULL,
        `body` MEDIUMTEXT NOT NULL,
        `pinned` TINYINT(1) NOT NULL DEFAULT 0,
        `author_cid` VARCHAR(64) DEFAULT NULL,
        `author_name` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        `updated_at` INT UNSIGNED NOT NULL,
        `expires_at` INT UNSIGNED DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `dept_list` (`dept`, `pinned`, `created_at`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
]])

local function shape(r)
    return {
        id = r.id,
        title = r.title,
        body = r.body,
        pinned = r.pinned == true or tonumber(r.pinned) == 1,
        authorCid = r.author_cid,
        authorName = r.author_name,
        createdAt = tonumber(r.created_at),
        updatedAt = tonumber(r.updated_at),
        expiresAt = tonumber(r.expires_at),
    }
end

local function find(ctx, id)
    id = V.id(id)
    if not id then return nil end
    local r = Db.single('SELECT * FROM `vr_mdt_bulletins` WHERE `id` = ? AND `dept` = ? LIMIT 1', { id, ctx.dept })
    return r
end

local function changed(ctx, id, action)
    Push.dept(ctx.dept, 'bulletin:changed', { id = id, action = action })
end

function Bulletin.list(dept, page, size)
    local now = U.now()
    local rows = Db.query([[SELECT * FROM `vr_mdt_bulletins` WHERE `dept` = ? AND (`expires_at` IS NULL OR `expires_at` > ?)
        ORDER BY `pinned` DESC, `created_at` DESC, `id` DESC LIMIT ? OFFSET ?]], { dept, now, size + 1, (page - 1) * size })
    if not rows then return nil end
    local out = {}
    for i = 1, math.min(#rows, size) do out[i] = shape(rows[i]) end
    return out, #rows > size
end

Api.register('bulletin.list', nil, function(src, ctx, data)
    local page = V.int(data.page, 1, 500) or 1
    local size = Config.Bulletin.pageSize or 20
    local items, more = Bulletin.list(ctx.dept, page, size)
    if not items then return false, 'server_error' end
    return true, { items = items, page = page, more = more }
end, { rate = 300 })

Api.register('bulletin.save', 'bulletin.post', function(src, ctx, data)
    local title = V.str(data.title, 96, 3)
    local body = V.text(data.body, 8000)
    local pinned = false
    if data.pinned ~= nil then pinned = V.bool(data.pinned) end
    if not title or not body or pinned == nil then return false, 'bad_request' end
    local days = nil
    if data.expiresDays ~= nil and data.expiresDays ~= 0 then
        days = V.int(data.expiresDays, 1, Config.Bulletin.maxExpiryDays or 90)
        if not days then return false, 'bad_request' end
    end
    local now = U.now()
    local expires = days and now + days * DAY or nil
    if data.id ~= nil then
        local row = find(ctx, data.id)
        if not row then return false, 'not_found' end
        if data.keepExpiry == true then expires = tonumber(row.expires_at) end
        local ok = Db.update('UPDATE `vr_mdt_bulletins` SET `title` = ?, `body` = ?, `pinned` = ?, `expires_at` = ?, `updated_at` = ? WHERE `id` = ?', {
            title, body, pinned and 1 or 0, expires, now, row.id,
        })
        if ok == nil then return false, 'save_failed' end
        Audit.log(ctx, 'bulletin.edit', row.id, { title = title, pinned = pinned, author = row.author_name })
        changed(ctx, row.id, 'edit')
        return true, shape(find(ctx, row.id))
    end
    local id = Db.insert([[INSERT INTO `vr_mdt_bulletins` (`dept`, `title`, `body`, `pinned`, `author_cid`, `author_name`, `created_at`, `updated_at`, `expires_at`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)]], { ctx.dept, title, body, pinned and 1 or 0, ctx.cid, ctx.name, now, now, expires })
    if not id then return false, 'save_failed' end
    Audit.log(ctx, 'bulletin.create', id, { title = title, pinned = pinned, expiresDays = days })
    changed(ctx, id, 'create')
    return true, shape(find(ctx, id))
end, { rate = 1000 })

Api.register('bulletin.delete', 'bulletin.post', function(src, ctx, data)
    local row = find(ctx, data.id)
    if not row then return false, 'not_found' end
    if Db.update('DELETE FROM `vr_mdt_bulletins` WHERE `id` = ?', { row.id }) == nil then return false, 'save_failed' end
    Audit.log(ctx, 'bulletin.delete', row.id, { title = row.title, author = row.author_name })
    changed(ctx, row.id, 'delete')
    return true, { id = row.id }
end, { rate = 500 })

Db.ready(function()
    Db.update('DELETE FROM `vr_mdt_bulletins` WHERE `expires_at` IS NOT NULL AND `expires_at` < ?', { U.now() - (Config.Bulletin.purgeExpiredDays or 30) * DAY })
end)
