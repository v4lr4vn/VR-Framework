local uploadType = require('config').mugshotsUpload:lower()

if uploadType ~= 'database' and uploadType ~= 'local' then return end

MySQL.ready(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `vr_mugshots` (
        `id` varchar(120) NOT NULL,
        `citizenid` varchar(50) NULL,
        `image` mediumtext NOT NULL,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`id`),
        KEY `citizenid` (`citizenid`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])
    pcall(function()
        exports['vr-core']:GetCoreObject({ 'Functions' }).Functions.RegisterCharacterTable('vr_mugshots', 'citizenid')
    end)
end)

local MAX_LENGTH = 256 * 1024
local PREFIXES = {
    'data:image/webp;base64,UklGR',
    'data:image/png;base64,iVBORw0KGgo',
}

local function validImage(image)
    if type(image) ~= 'string' or #image > MAX_LENGTH then return false end
    for i = 1, #PREFIXES do
        local prefix = PREFIXES[i]
        if image:sub(1, #prefix) == prefix then
            local header = #prefix - #prefix:match(',(.*)$')
            return not image:find('[^A-Za-z0-9+/=]', header + 1)
        end
    end
    return false
end

local function saveMugshot(result, identifier, itemName)
    local image = type(result) == 'table' and result.base64
    if not validImage(image) then return nil end

    local id = ('%s_%s'):format(identifier, itemName):gsub('[^%w_%-]', '_')
    MySQL.query.await([[INSERT INTO vr_mugshots (id, citizenid, image) VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE image = VALUES(image), citizenid = VALUES(citizenid)]], { id, identifier, image })
    return 'db:' .. id
end

function ResolveStoredMugshot(reference)
    local id = type(reference) == 'string' and reference:match('^db:([%w_%-]+)$')
    if not id then return nil end
    return MySQL.scalar.await('SELECT image FROM vr_mugshots WHERE id = ?', { id })
end

return saveMugshot
