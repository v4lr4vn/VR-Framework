Images = {}

local kinds = {
    mugshot = { 'mugshots.take' },
    evidence = { 'evidence.manage' },
    patient = { 'patients.edit' },
    report = { 'reports.create', 'medreports.create' },
    court = { 'court.manage' },
}

local pending = {}

Db.schema('images', [[
    CREATE TABLE IF NOT EXISTS `vr_mdt_images` (
        `id` CHAR(32) NOT NULL,
        `kind` VARCHAR(16) NOT NULL,
        `mime` VARCHAR(16) NOT NULL,
        `data` MEDIUMTEXT NOT NULL,
        `bytes` INT UNSIGNED NOT NULL,
        `created_by` VARCHAR(64) DEFAULT NULL,
        `created_at` INT UNSIGNED NOT NULL,
        PRIMARY KEY (`id`),
        KEY `kind` (`kind`)
    ) ENGINE=InnoDB DEFAULT CHARSET=ascii COLLATE=ascii_bin
]])

local function newId()
    local t = {}
    for i = 1, 32 do t[i] = ('%x'):format(math.random(0, 15)) end
    return table.concat(t)
end

local function parseDataUrl(s)
    if type(s) ~= 'string' or #s > Config.Images.maxBytes * 1.4 then return nil, 'too_large' end
    local mime, b64 = s:match('^data:image/(%a+);base64,([%w%+/=]+)$')
    if not mime or not b64 then return nil, 'bad_request' end
    mime = mime:lower()
    if mime ~= 'jpeg' and mime ~= 'jpg' and mime ~= 'png' and mime ~= 'webp' then return nil, 'bad_request' end
    local bytes = math.floor(#b64 * 3 / 4)
    if bytes > Config.Images.maxBytes then return nil, 'too_large' end
    return { mime = mime == 'jpg' and 'jpeg' or mime, b64 = b64, bytes = bytes }
end

function Images.canUpload(ctx, kind)
    local need = kinds[kind]
    return need ~= nil and Core.can(ctx, need)
end

function Images.store(ctx, kind, dataUrl)
    if not kinds[kind] then return nil, 'bad_request' end
    local img, err = parseDataUrl(dataUrl)
    if not img then return nil, err end
    local id = newId()
    local ok = Db.insert('INSERT INTO `vr_mdt_images` (`id`, `kind`, `mime`, `data`, `bytes`, `created_by`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        id, kind, img.mime, img.b64, img.bytes, ctx and ctx.cid or nil, U.now(),
    })
    if ok == nil then return nil, 'save_failed' end
    return id
end

function Images.get(id)
    id = V.imageId(id)
    if not id then return nil end
    local row = Db.single('SELECT `mime`, `data` FROM `vr_mdt_images` WHERE `id` = ?', { id })
    if not row then return nil end
    return ('data:image/%s;base64,%s'):format(row.mime, row.data)
end

function Images.delete(id)
    id = V.imageId(id)
    if id then Db.update('DELETE FROM `vr_mdt_images` WHERE `id` = ?', { id }) end
end

Api.register('images.prepare', nil, function(src, ctx, data)
    local kind = V.str(data.kind, 16)
    if not kind or not Images.canUpload(ctx, kind) then return false, 'not_allowed' end
    local token = newId()
    pending[token] = { src = src, kind = kind, expires = GetGameTimer() + 60000 }
    return true, { token = token, maxBytes = Config.Images.maxBytes, quality = Config.Images.quality }
end, { rate = 1500 })

RegisterNetEvent('vr-mdt:server:imageUpload', function(token, dataUrl)
    local src = source
    local p = type(token) == 'string' and pending[token]
    if not p or p.src ~= src or p.expires < GetGameTimer() then
        TriggerClientEvent('vr-mdt:client:imageStored', src, token, nil, 'bad_request')
        return
    end
    pending[token] = nil
    local ctx = Core.context(src)
    if not ctx or not Images.canUpload(ctx, p.kind) then
        TriggerClientEvent('vr-mdt:client:imageStored', src, token, nil, 'not_allowed')
        return
    end
    local id, err = Images.store(ctx, p.kind, dataUrl)
    TriggerClientEvent('vr-mdt:client:imageStored', src, token, id, err)
end)

RegisterNetEvent('vr-mdt:server:imageFetch', function(token, id)
    local src = source
    if type(token) ~= 'string' or #token > 40 then return end
    local ctx = Core.context(src)
    local data = ctx and Images.get(id) or nil
    TriggerLatentClientEvent('vr-mdt:client:image', src, 250000, token, data)
end)

CreateThread(function()
    while true do
        Wait(30000)
        local now = GetGameTimer()
        for token, p in pairs(pending) do
            if p.expires < now then pending[token] = nil end
        end
    end
end)
