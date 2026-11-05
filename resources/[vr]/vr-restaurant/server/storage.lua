-- Storage areas: fridge, hot box, tray and self-serve counter. Each one is a real vr-inventory stash
-- (`rest_<station id>`), so players use the normal inventory screen. This file registers the stashes,
-- enforces who may put what in and take what out (inventory hooks), slows spoiling inside them,
-- and answers the stock questions the kitchen asks.

local inv = Bridge.inventory
local RES = Bridge.inventoryResource or 'vr-inventory'
local PATTERN = '^rest_%d+$'

local function now() return os.time() end

function Rest.copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = Rest.copy(v) end
    return out
end

---------------------------------------------------------------------------
-- What counts as what
---------------------------------------------------------------------------

function Rest.dishKey(item, meta)
    if type(meta) == 'table' and type(meta.dish) == 'string' then return meta.dish end
    return nil
end

function Rest.isDish(item, meta)
    if Rest.dishKey(item, meta) then return true end
    if Config.Consumables[item] then return true end
    if item == Config.BaseItems.food or item == Config.BaseItems.drink then return true end
    return type(meta) == 'table' and meta.consumable ~= nil
end

function Rest.isIngredient(item) return Config.Ingredients[item] ~= nil end

function Rest.itemLabel(item, meta)
    if type(meta) == 'table' and type(meta.label) == 'string' and meta.label ~= '' then return meta.label end
    local ok, label = pcall(inv.label, item)
    return (ok and label) or item
end

local function accepts(cfg, slot)
    if type(slot) ~= 'table' or type(slot.name) ~= 'string' then return false end
    if cfg.accepts == 'ingredient' then return Rest.isIngredient(slot.name) end
    if cfg.accepts == 'dish' then return Rest.isDish(slot.name, slot.metadata) end
    return false
end

-- Items that go off carry an absolute time in their durability.
local function expiry(slot)
    local d = tonumber(type(slot.metadata) == 'table' and slot.metadata.durability)
    if d and d > 100 then return d end
    return nil
end

local function gone(slot)
    local d = expiry(slot)
    return d ~= nil and d <= now()
end
Rest.expired = gone

-- When something made now goes off, rounded so batches made close together are identical and stack.
function Rest.expiryFor(lifeMinutes)
    local q = math.max(1, Config.Storage.stackSeconds or 1)
    return math.floor((now() + lifeMinutes * 60) / q + 0.5) * q
end

local function stashId(sid) return ('rest_%d'):format(sid) end
Rest.stashId = stashId

local function sidOf(id)
    local n = tostring(id or ''):match('^rest_(%d+)$')
    return n and tonumber(n) or nil
end

---------------------------------------------------------------------------
-- Who may do what at a station
---------------------------------------------------------------------------

function Rest.perm(role, p) return role ~= nil and role.perms[p] == true end

function Rest.context(src, sid)
    if not Rest.loaded then return nil, 'not_ready' end
    local who = Rest.info(src)
    if not who then return nil, 'no_player' end
    local s = Rest.stations[tonumber(sid) or -1]
    if not s then return nil, 'not_found' end
    local b = Rest.biz[s.business]
    if not b then return nil, 'not_found' end
    local d = Rest.distance(src, s.x, s.y, s.z)
    if not d or d > s.radius + 3.0 then return nil, 'too_far' end
    return who, s, b, Rest.role(b, who.cid)
end

function Rest.needDuty(who, b)
    if Rest.duty[who.cid] ~= b.id then return 'not_on_duty' end
    if Rest.isClosed(b) then return 'closed' end
    return nil
end

-- The fridge and hot box need the cook permission; the tray and counter take cook or till.
function Rest.staffAllowed(s, role)
    if not role then return false end
    if s.kind == 'tray' or s.kind == 'counter' then return Rest.perm(role, 'cook') or Rest.perm(role, 'till') end
    return Rest.perm(role, 'cook')
end

-- 'staff' (on duty), 'customer' (tray and counter while open), or nothing and the reason.
local function access(who, s, b, role, cfg)
    local staff = Rest.staffAllowed(s, role)
    if staff and Rest.duty[who.cid] == b.id then
        if Rest.isClosed(b) then return nil, 'closed' end
        return 'staff'
    end
    if cfg.staffOnly then return nil, staff and 'not_on_duty' or 'no_permission' end
    if Rest.isClosed(b) then return nil, 'closed' end
    return 'customer'
end

---------------------------------------------------------------------------
-- Rules enforced on the inventory screen
---------------------------------------------------------------------------

local TEXT = {
    no_permission = 'You cannot use that',
    not_on_duty = 'Clock in first',
    closed = 'We are closed',
    too_far = 'You are too far away',
    only_ingredients = 'Only ingredients go in the fridge',
    only_dishes = 'Only prepared food and drinks go in there',
    not_priced = 'That has no price yet',
    spoiled = 'That has gone off',
    no_money = 'You cannot afford that',
    not_found = 'That is not available',
}

local told = {}
AddEventHandler('playerDropped', function() told[source] = nil end)
local function refuse(src, code)
    local t = GetGameTimer()
    if not told[src] or t - told[src] > 1500 then
        told[src] = t
        Rest.notify(src, TEXT[code] or 'You cannot do that', 'error')
    end
    return false
end

-- Returns nil when the move is fine, otherwise the reason.
local function judge(p)
    local fromSid, toSid = sidOf(p.fromInventory), sidOf(p.toInventory)
    local sid = fromSid or toSid
    local s = sid and Rest.stations[sid]
    if not s then return 'not_found' end
    local cfg = Config.Storage[s.kind]
    local b = Rest.biz[s.business]
    if not cfg or not b then return 'not_found' end
    local who = Rest.info(p.source)
    if not who then return 'no_permission' end
    local d = Rest.distance(p.source, s.x, s.y, s.z)
    if not d or d > s.radius + 3.5 then return 'too_far' end
    local mode, err = access(who, s, b, Rest.role(b, who.cid), cfg)
    if not mode then return err end

    if fromSid and toSid then
        -- Tidying inside one stash: staff only, and never between two different stashes.
        if fromSid ~= toSid then return 'no_permission' end
        if mode == 'staff' then return nil end
        return 'no_permission'
    end

    local count = math.max(1, math.floor(tonumber(p.count) or 1))
    local entering, leaving, leavingCount
    if toSid then
        entering = p.fromSlot
        if p.action == 'swap' and type(p.toSlot) == 'table' then leaving, leavingCount = p.toSlot, p.toSlot.count end
    else
        leaving, leavingCount = p.fromSlot, count
        if p.action == 'swap' and type(p.toSlot) == 'table' then
            entering = p.toSlot
            leavingCount = type(p.fromSlot) == 'table' and p.fromSlot.count or count
        end
    end

    if entering then
        if mode ~= 'staff' then return 'no_permission' end
        if not accepts(cfg, entering) then return cfg.accepts == 'ingredient' and 'only_ingredients' or 'only_dishes' end
    end

    if leaving and mode == 'customer' then
        if s.kind ~= 'counter' then return nil end
        if gone(leaving) then return 'spoiled' end
        local key = Rest.dishKey(leaving.name, leaving.metadata)
        local price = key and Rest.menu[b.id] and Rest.menu[b.id][key]
        if not price or price <= 0 then return 'not_priced' end
        local total = price * (tonumber(leavingCount) or 1)
        if not Bridge.pay(p.source, total, ('%s: %s'):format(b.label, Rest.itemLabel(leaving.name, leaving.metadata))) then return 'no_money' end
        Rest.bank.add(b, total)
        Rest.notify(p.source, ('Paid $%d'):format(total), 'success')
    end
    return nil
end

-- A hook that fails must refuse, not wave things through (the inventory ignores hooks that error).
local function onSwap(p)
    local ok, reason = pcall(judge, p)
    if not ok then
        print(('^1[vr-restaurant] storage rule failed: %s^0'):format(tostring(reason)))
        return false
    end
    if reason then return refuse(p.source, reason) end
    return true
end

local function onOpen(p)
    local ok, reason = pcall(function()
        local sid = sidOf(p.inventoryId)
        local s = sid and Rest.stations[sid]
        local cfg = s and Config.Storage[s.kind]
        local b = s and Rest.biz[s.business]
        if not cfg or not b then return 'not_found' end
        local who = Rest.info(p.source)
        if not who then return 'no_permission' end
        local d = Rest.distance(p.source, s.x, s.y, s.z)
        if not d or d > s.radius + 3.5 then return 'too_far' end
        local mode, err = access(who, s, b, Rest.role(b, who.cid), cfg)
        if not mode then return err end
        return nil
    end)
    if not ok then return false end
    if reason then return refuse(p.source, reason) end
    return true
end

---------------------------------------------------------------------------
-- Registering stashes and hooks with the inventory
---------------------------------------------------------------------------

local hooked = false

local function inventoryUp() return GetResourceState(RES) == 'started' end

local function registerHooks()
    if hooked or not inventoryUp() then return hooked end
    local ok, err = pcall(function()
        exports[RES]:registerHook('swapItems', onSwap, { inventoryFilter = { PATTERN } })
        exports[RES]:registerHook('openInventory', onOpen, { inventoryFilter = { PATTERN } })
    end)
    if not ok then print(('^1[vr-restaurant] could not add the storage rules to the inventory: %s^0'):format(tostring(err))) return false end
    hooked = true
    return true
end

local registered = {}

-- Makes the stash for a station known to the inventory. Safe to repeat.
function Rest.syncStash(s)
    local cfg = Config.Storage[s.kind]
    if not cfg or not inventoryUp() then return false end
    local label = s.label ~= '' and s.label or ((Rest.kindInfo(s.kind) or {}).label or s.kind)
    local ok = inv.registerStash(stashId(s.id), label, cfg.slots, cfg.weight, nil, nil, nil)
    if ok then registered[s.id] = true end
    return ok
end

-- A station was removed or turned into something that stores nothing.
function Rest.dropStorage(sid)
    registered[sid] = nil
    if inventoryUp() then pcall(function() exports[RES]:ClearInventory(stashId(sid)) end) end
end

-- A business was removed: its menu and designed dishes go with it.
function Rest.dropKitchen(id)
    MySQL.query.await('DELETE FROM vr_rest_menu WHERE business = ?', { id })
    MySQL.query.await('DELETE FROM vr_rest_dishes WHERE business = ?', { id })
    Rest.menu[id] = nil
    Rest.dishes[id] = nil
end

AddEventHandler('onResourceStart', function(resource)
    if resource ~= RES then return end
    hooked = false
    registered = {}
    CreateThread(function()
        Wait(1500)
        if registerHooks() then
            for _, s in pairs(Rest.stations) do Rest.syncStash(s) end
        end
    end)
end)

---------------------------------------------------------------------------
-- Stock, for cooking and ordering
---------------------------------------------------------------------------

-- Fresh slots holding `item` across every fridge of a business, soonest to go off first.
local function fridgeSlots(b, item)
    local out = {}
    for _, s in pairs(b.stations) do
        if s.kind == 'fridge' then
            for _, slot in ipairs(inv.stashItems(stashId(s.id)) or {}) do
                if slot.name == item and slot.count > 0 and not gone(slot) then
                    out[#out + 1] = { sid = s.id, slot = slot, due = expiry(slot) or math.huge }
                end
            end
        end
    end
    table.sort(out, function(a, c)
        if a.due ~= c.due then return a.due < c.due end
        if a.sid ~= c.sid then return a.sid < c.sid end
        return a.slot.slot < c.slot.slot
    end)
    return out
end

function Rest.stockOf(b, item)
    local n = 0
    for _, e in ipairs(fridgeSlots(b, item)) do n = n + e.slot.count end
    return n
end

function Rest.takeStock(b, item, n)
    for _, e in ipairs(fridgeSlots(b, item)) do
        if n <= 0 then break end
        local take = math.min(n, e.slot.count)
        if inv.stashRemove(stashId(e.sid), item, take, nil, e.slot.slot) then n = n - take end
    end
    return n <= 0
end

-- Puts an ordered delivery into one fridge. False if it does not all fit.
function Rest.deliver(s, item, count, meta)
    local id = stashId(s.id)
    if not inv.canCarry(id, item, count, meta) then return false end
    return inv.stashAdd(id, item, count, meta) == true
end

exports('GetStock', function(id, item)
    local b = Rest.biz[tonumber(id) or -1]
    return b and Rest.stockOf(b, item) or 0
end)

---------------------------------------------------------------------------
-- Things keep longer in the fridge and hot box
---------------------------------------------------------------------------

-- An item's time to go off is a fixed moment. While it sits in a fridge, that moment is pushed back
-- by the share of the time the fridge saves, so it ages more slowly in there.
-- The time saved is collected and handed out in whole steps (Config.Storage.stackSeconds), the same for
-- every item in the stash, so items that stacked together keep stacking.
local lastTick = {}
local saved = {}

local function freshen(s, secs)
    local cfg = Config.Storage[s.kind]
    if not cfg or cfg.mult <= 1 then return end
    saved[s.id] = (saved[s.id] or 0) + secs * (1 - 1 / cfg.mult)
    local step = math.max(1, Config.Storage.stackSeconds or 1)
    if saved[s.id] < step then return end
    local shift = math.floor(saved[s.id] / step) * step
    saved[s.id] = saved[s.id] - shift
    local id = stashId(s.id)
    for _, slot in ipairs(inv.stashItems(id) or {}) do
        local d = expiry(slot)
        if d and d > now() then
            local meta = Rest.copy(slot.metadata)
            meta.durability = d + shift
            inv.setMetadata(id, slot.slot, meta)
        end
    end
end

Rest.freshen = freshen

CreateThread(function()
    while true do
        Wait(Config.Storage.tickSeconds * 1000)
        if Rest.loaded and inventoryUp() then
            local t = now()
            for sid, s in pairs(Rest.stations) do
                local cfg = Config.Storage[s.kind]
                if cfg and cfg.mult > 1 then
                    local since = lastTick[sid] or (t - Config.Storage.tickSeconds)
                    lastTick[sid] = t
                    local ok, err = pcall(freshen, s, t - since)
                    if not ok then print(('^1[vr-restaurant] keeping food fresh failed: %s^0'):format(tostring(err))) end
                end
            end
        end
    end
end)

---------------------------------------------------------------------------
-- Opening a stash, and the counter's price list
---------------------------------------------------------------------------

lib.callback.register('vr-restaurant:openStash', function(src, sid)
    if Rest.throttle(src, 'stash', 300) then return Rest.fail('slow_down') end
    local who, s, b, role = Rest.context(src, sid)
    if not who then return Rest.fail(s) end
    local cfg = Config.Storage[s.kind]
    if not cfg then return Rest.fail('bad_request') end
    local mode, err = access(who, s, b, role, cfg)
    if not mode then return Rest.fail(err) end
    if not inventoryUp() then return Rest.fail('failed') end
    registerHooks()
    if not Rest.syncStash(s) then return Rest.fail('failed') end
    if not inv.openStash(src, stashId(s.id)) then return Rest.fail('failed') end
    return { ok = true, data = { mode = mode } }
end)

-- What is on a counter and what it costs, for anyone standing at it.
function Rest.counterPrices(s, b)
    local rows = {}
    for _, slot in ipairs(inv.stashItems(stashId(s.id)) or {}) do
        local key = Rest.dishKey(slot.name, slot.metadata)
        local price = key and Rest.menu[b.id] and Rest.menu[b.id][key] or nil
        local freshness
        local d, degrade = expiry(slot), tonumber(slot.metadata and slot.metadata.degrade)
        if d and degrade and degrade > 0 then
            freshness = math.max(0, math.min(100, math.floor((d - now()) / (degrade * 60) * 100 + 0.5)))
        end
        rows[#rows + 1] = {
            label = Rest.itemLabel(slot.name, slot.metadata), count = slot.count, price = price,
            fresh = freshness, spoiled = gone(slot),
        }
    end
    table.sort(rows, function(a, c) return a.label:lower() < c.label:lower() end)
    return rows
end

---------------------------------------------------------------------------
-- Start up: hooks, stashes, and moving things out of the old storage tables
---------------------------------------------------------------------------

local OLD = [[CREATE TABLE IF NOT EXISTS `vr_rest_storage` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `station` INT UNSIGNED NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `count` INT UNSIGNED NOT NULL,
    `meta` TEXT NOT NULL,
    `since` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`id`),
    KEY `station` (`station`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Version 1.2.0 kept stock in its own table. Anything left there goes into the real stash.
local function migrate()
    local ok, rows = pcall(function()
        MySQL.query.await(OLD)
        return MySQL.query.await('SELECT id, station, item, `count`, meta, since FROM vr_rest_storage') or {}
    end)
    if not ok or #rows == 0 then return end
    local moved, kept = 0, 0
    for _, r in ipairs(rows) do
        local s = Rest.stations[r.station]
        local cfg = s and Config.Storage[s.kind]
        local done = true
        if cfg then
            local jok, meta = pcall(json.decode, r.meta or '{}')
            meta = (jok and type(meta) == 'table') and meta or {}
            local d = tonumber(meta.durability)
            if d and d > 100 and cfg.mult > 1 then
                meta.durability = math.floor(d + (now() - (tonumber(r.since) or now())) * (1 - 1 / cfg.mult))
            end
            Rest.syncStash(s)
            done = Rest.deliver(s, r.item, tonumber(r.count) or 0, meta)
        end
        if done then
            MySQL.query.await('DELETE FROM vr_rest_storage WHERE id = ?', { r.id })
            moved = moved + 1
        else
            kept = kept + 1
        end
    end
    print(('[vr-restaurant] moved %d old stock rows into the new stashes%s'):format(moved, kept > 0 and (', %d did not fit and were kept'):format(kept) or ''))
end

Rest.onReady(function()
    if not inventoryUp() then
        local tries = 0
        while not inventoryUp() and tries < 120 do
            tries = tries + 1
            Wait(1000)
        end
        if not inventoryUp() then print('^1[vr-restaurant] the inventory did not start, storage areas will not work^0') return end
        Wait(1000)
    end
    registerHooks()
    for _, s in pairs(Rest.stations) do Rest.syncStash(s) end
    migrate()
end)
