-- Which phone is this player holding?
--
-- A phone is an inventory item with a unique ID stored in its metadata. Its data (number, PIN, settings)
-- belongs to that ID, so lending, selling or stealing the item moves the data with it.
--
-- If the inventory cannot store the ID on the item, the phone is tied to the character instead
-- (ID 'own:<citizenid>'). Once the inventory can store IDs, that phone claims the item automatically.
local Identity = {}
Phone.Identity = Identity

local cfg = Config.Phone

math.randomseed(os.time() + GetGameTimer())

local function ownerKey(src)
    local p = Bridge.player(src)
    if p and p.cid then return p.cid, p end
    local license = GetPlayerIdentifierByType(src, 'license')
    if license then return license, nil end
    return nil, nil
end

-- First phone item the player holds, or nil.
local function findItem(src)
    if not cfg.RequireItem then return nil end
    local inv = Bridge.inventory
    if not inv or not inv.items then return nil end
    local ok, items = pcall(inv.items, src)
    if not ok or type(items) ~= 'table' then return nil end
    for _, it in ipairs(items) do
        if it.name == cfg.ItemName and (tonumber(it.count) or 1) > 0 then return it end
    end
    return nil
end

local function readId(item)
    local meta = item and item.metadata
    local id = type(meta) == 'table' and meta[cfg.MetadataKey] or nil
    if type(id) == 'string' and id ~= '' and #id <= 64 then return id end
    return nil
end

local function newId()
    return ('ph_%x%04x%04x'):format(os.time(), GetGameTimer() % 0x10000, math.random(0, 0xFFFF))
end

-- Writes the ID onto the item. Works with ox-style inventories (SetMetadata). Returns true on success.
local function stamp(src, item, id)
    local res = Bridge.inventoryResource
    if not res or GetResourceState(res) ~= 'started' or not item.slot then return false end
    local meta = type(item.metadata) == 'table' and Phone.deepCopy(item.metadata) or {}
    meta[cfg.MetadataKey] = id
    local ok = pcall(function() return exports[res]:SetMetadata(src, item.slot, meta) end)
    return ok
end

local function fetch(id)
    return MySQL.single.await('SELECT * FROM `vr_ph_phones` WHERE `phone_id` = ?', { id })
end

local function generateNumber()
    local fmt = cfg.Number.format or '555-####'
    return (fmt:gsub('#', function() return tostring(math.random(0, 9)) end))
end

local function numberTaken(number)
    return MySQL.scalar.await('SELECT 1 FROM `vr_ph_phones` WHERE `number` = ? LIMIT 1', { number }) ~= nil
end

-- Creates the phone row. The character's own number is tried first so other scripts that use it keep working.
local function createRow(id, cid, player)
    local tries = cfg.Number.tries or 25
    local own = player and type(player.phone) == 'string' and player.phone ~= '' and #player.phone <= 20 and player.phone or nil
    for attempt = 1, tries do
        local number = (attempt == 1 and own) or generateNumber()
        if not numberTaken(number) then
            MySQL.insert.await('INSERT IGNORE INTO `vr_ph_phones` (`phone_id`, `owner_cid`, `number`) VALUES (?, ?, ?)', { id, cid, number })
            local row = fetch(id)
            if row then return row end
        end
    end
    return nil
end

-- Finds the player's phone. With makeIfMissing = false it only looks (nothing is made or written).
-- Returns the phone row, or nil and a reason: 'no_phone', 'no_identity' or 'not_ready'.
function Identity.resolve(src, makeIfMissing)
    if not Phone.DB.ready then return nil, 'not_ready' end

    local item = findItem(src)
    if cfg.RequireItem and not item then return nil, 'no_phone' end

    local cid, player = ownerKey(src)
    if not cid then return nil, 'no_identity' end
    local own = 'own:' .. cid

    local id = readId(item)
    if id then
        local row = fetch(id)
        if row then return row end
        if not makeIfMissing then return nil, 'no_phone' end
        row = createRow(id, cid, player)
        if row then return row end
        return nil, 'no_phone'
    end

    -- The item has no ID yet.
    local ownRow = fetch(own)
    if not makeIfMissing then
        if ownRow then return ownRow end
        return nil, 'no_phone'
    end

    if item then
        id = ownRow and own or newId()
        -- If the inventory cannot carry the ID, the phone stays with the character.
        if not stamp(src, item, id) then id = own end
    else
        -- No item to carry an ID (RequireItem = false): one phone per character.
        id = own
    end
    local row = fetch(id) or createRow(id, cid, player)
    if row then return row end
    return nil, 'no_phone'
end

-- Cheap check used before delivering notifications: does the player still hold a phone?
function Identity.holdsPhone(src)
    if not cfg.RequireItem then return true end
    return findItem(src) ~= nil
end

-- The phone that has this number, as { phone_id, number }, or nil.
function Identity.byNumber(number)
    return MySQL.single.await('SELECT `phone_id`, `number` FROM `vr_ph_phones` WHERE `number` = ?', { number })
end
