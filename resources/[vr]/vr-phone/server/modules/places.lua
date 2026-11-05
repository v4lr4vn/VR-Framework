-- Maps: the places a player has saved, and the list of places everyone can find.
local Places = {}
Phone.Places = Places

local function cfg() return Config.Phone.Maps or {} end

local ICONS = {}
for _, id in ipairs({ 'pin', 'home', 'work', 'star', 'heart', 'food', 'bag', 'fuel', 'cross', 'shield', 'bank', 'plane', 'anchor', 'wrench' }) do ICONS[id] = true end

-- The game world is about 9000 metres across. Anything far outside it is not a place on the map.
local LIMIT_X, LIMIT_Y = 6000.0, 10000.0

local function icon(v)
    if type(v) == 'string' and ICONS[v] then return v end
    return 'pin'
end

local function toPlace(r)
    return { id = r.id, name = r.name, x = tonumber(r.x) or 0.0, y = tonumber(r.y) or 0.0, z = tonumber(r.z) or 0.0, icon = r.icon }
end

function Places.list(phoneId)
    local rows = MySQL.query.await(
        'SELECT `id`, `name`, `x`, `y`, `z`, `icon` FROM `vr_ph_places` WHERE `phone_id` = ? ORDER BY `id` DESC LIMIT ' .. (cfg().maxPlaces or 50),
        { phoneId }
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = toPlace(r) end
    return out
end

-- The places from the config, with a number each so the screen can refer to them.
function Places.catalog()
    local out = {}
    for i, p in ipairs(cfg().places or {}) do
        out[#out + 1] = { id = 'c' .. i, name = p.label, category = p.category or 'places', icon = icon(p.icon), x = p.x + 0.0, y = p.y + 0.0, z = (p.z or 0.0) + 0.0 }
    end
    return out
end

-- data = { id?, name, x, y, z?, icon? }. Returns the place, or nil and a reason.
function Places.save(phoneId, data)
    local name = Phone.text(data.name, cfg().nameLength or 40)
    if not name then return nil, 'empty' end
    local x = Phone.clamp(data.x, -LIMIT_X, LIMIT_X)
    local y = Phone.clamp(data.y, -LIMIT_Y, LIMIT_Y)
    local z = Phone.clamp(data.z or 0.0, -500.0, 3000.0)
    if not x or not y or not z then return nil, 'invalid_place' end

    if data.id ~= nil then
        local id = tonumber(data.id)
        if not id then return nil, 'not_found' end
        MySQL.update.await('UPDATE `vr_ph_places` SET `name` = ?, `icon` = ? WHERE `phone_id` = ? AND `id` = ?', { name, icon(data.icon), phoneId, id })
        local r = MySQL.single.await('SELECT `id`, `name`, `x`, `y`, `z`, `icon` FROM `vr_ph_places` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
        if not r then return nil, 'not_found' end
        return toPlace(r)
    end

    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_places` WHERE `phone_id` = ?', { phoneId })) or 0
    if count >= (cfg().maxPlaces or 50) then return nil, 'full' end
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_places` (`phone_id`, `name`, `x`, `y`, `z`, `icon`, `created_at`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { phoneId, name, x, y, z, icon(data.icon), os.time() }
    )
    if not id then return nil, 'failed' end
    return { id = id, name = name, x = x, y = y, z = z, icon = icon(data.icon) }
end

function Places.remove(phoneId, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_places` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) or 0) > 0
end
