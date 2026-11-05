-- The list of apps the phone knows about, which ones each phone has installed, and the App Store's installing and removing.
-- Built-in apps come from config/apps.lua. Other scripts add their own with exports['vr-phone']:AddApp (see README).
local Apps = {}
Phone.Apps = Apps

local registry = {}
local order = {}
local cache = {} -- phone id -> { [app id] = { installed = bool, paid = bool } }  (what differs from the app's own default)

local store = Config.Store or {}
local storeApps = store.apps or {}

local ID_PATTERN = '^[a-z][a-z0-9_]+$'

local function add(def)
    if type(def.id) ~= 'string' or registry[def.id] then return false end
    registry[def.id] = def
    order[#order + 1] = def.id
    return true
end

for _, def in ipairs(Config.Apps) do
    local over = storeApps[def.id] or {}
    add({
        id = def.id,
        label = def.label,
        category = def.category or 'Core',
        preinstalled = def.preinstalled == true,
        essential = def.essential == true,
        -- Apps that have no screen yet are not in the store. Config.Store.apps can switch that either way.
        listed = over.listed ~= nil and over.listed ~= false or (over.listed == nil and def.listed ~= false),
        price = math.max(0, math.floor(tonumber(over.price or def.price) or 0)),
        builtin = true,
    })
end

-- What the screen is told about an app. (Functions and the owning resource stay on the server.)
local function public(def)
    return {
        id = def.id, label = def.label, category = def.category, description = def.description,
        preinstalled = def.preinstalled, essential = def.essential, listed = def.listed, price = def.price,
        color = def.color, glyph = def.glyph, image = def.image, url = def.url, custom = def.custom == true,
    }
end

function Apps.exists(id)
    return registry[id] ~= nil
end

function Apps.get(id)
    return registry[id]
end

function Apps.list()
    local out = {}
    for _, id in ipairs(order) do out[#out + 1] = public(registry[id]) end
    return out
end

-- ---------------------------------------------------------------- what each phone has

local function overrides(phoneId)
    local c = cache[phoneId]
    if c then return c end
    c = {}
    local rows = MySQL.query.await('SELECT `app_id`, `installed`, `paid` FROM `vr_ph_apps` WHERE `phone_id` = ?', { phoneId }) or {}
    for _, r in ipairs(rows) do
        c[r.app_id] = { installed = Phone.flag(r.installed), paid = Phone.flag(r.paid) }
    end
    cache[phoneId] = c
    return c
end

local function isInstalled(def, over)
    if def.essential then return true end
    local o = over[def.id]
    if o then return o.installed end
    return def.preinstalled == true
end

-- Ids of the apps installed on a phone, in list order. An app the player removed stays out; a new preinstalled app arrives by itself.
function Apps.installedIds(phoneId)
    local over = overrides(phoneId)
    local out = {}
    for _, id in ipairs(order) do
        if isInstalled(registry[id], over) then out[#out + 1] = id end
    end
    return out
end

function Apps.isInstalled(phoneId, id)
    local def = registry[id]
    return def ~= nil and isInstalled(def, overrides(phoneId))
end

-- A script may keep an app away from some players (a police app for police). A function that errors counts as "not allowed".
local function allowed(def, src, phoneId)
    if type(def.allow) ~= 'function' and type(def.allow) ~= 'table' then return true end
    local ok, result = pcall(def.allow, src, phoneId)
    return ok and result ~= false
end

-- The App Store list for one phone: every app that can be installed or removed.
function Apps.catalogue(src, phoneId)
    local over = overrides(phoneId)
    local out = {}
    for _, id in ipairs(order) do
        local def = registry[id]
        if def.listed and not def.essential and allowed(def, src, phoneId) then
            local o = over[id]
            local item = public(def)
            item.installed = isInstalled(def, over)
            item.owned = (o and o.paid) == true or def.price == 0
            out[#out + 1] = item
        end
    end
    return out, store.featured or {}
end

local function save(phoneId, id, installed, paid)
    MySQL.update.await(
        'INSERT INTO `vr_ph_apps` (`phone_id`, `app_id`, `installed`, `paid`) VALUES (?, ?, ?, ?) ON DUPLICATE KEY UPDATE `installed` = VALUES(`installed`), `paid` = VALUES(`paid`)',
        { phoneId, id, installed and 1 or 0, paid and 1 or 0 }
    )
    local c = overrides(phoneId)
    c[id] = { installed = installed, paid = paid }
end

local function result(phoneId)
    return { ok = true, installed = Apps.installedIds(phoneId), layout = Phone.Settings.getLayout(phoneId) }
end

-- Puts an app on the phone. `free` skips the price and the signal check (a script giving the app).
function Apps.install(src, s, id, free)
    local def = registry[id]
    if not def or not def.listed and not free or def.essential then return { ok = false, reason = 'not_found' } end
    local over = overrides(s.phoneId)
    if isInstalled(def, over) then return result(s.phoneId) end
    if not free then
        if not allowed(def, src, s.phoneId) then return { ok = false, reason = 'not_allowed' } end
        if store.needService ~= false and not Phone.Status.canReceive(s) then return { ok = false, reason = 'no_service' } end
    end

    local paid = (over[id] and over[id].paid) == true
    if def.price > 0 and not paid and not free then
        if Bridge.money(src, 'bank') < def.price then return { ok = false, reason = 'no_funds' } end
        if not Bridge.removeMoney(src, 'bank', def.price, ('App Store: %s'):format(def.label)) then
            return { ok = false, reason = 'no_funds' }
        end
        paid = true
    end
    save(s.phoneId, id, true, paid or free == true)
    return result(s.phoneId)
end

-- Takes an app off the phone. Its data stays, so installing it again brings everything back.
function Apps.uninstall(src, s, id, force)
    local def = registry[id]
    if not def then return { ok = false, reason = 'not_found' } end
    if def.essential or (def.removable == false and not force) then return { ok = false, reason = 'required' } end
    local over = overrides(s.phoneId)
    if not isInstalled(def, over) then return result(s.phoneId) end
    save(s.phoneId, id, false, (over[id] and over[id].paid) == true)
    -- Things an app keeps going in the background stop with it.
    if id == 'music' and Phone.Music then Phone.Music.stop(src, nil) end
    return result(s.phoneId)
end

-- ---------------------------------------------------------------- apps from other scripts

local function appsChanged()
    TriggerClientEvent('vr-phone:client:appsChanged', -1)
end

-- A page from another resource: 'ui/index.html' becomes https://cfx-nui-<resource>/ui/index.html. A full https address is kept.
local function pageUrl(raw, resource)
    if type(raw) ~= 'string' or raw == '' or #raw > 300 then return nil end
    if raw:match('^https://[%w%-%._~:/%?#%[%]@!%$&%(%)%*%+,;=%%]+$') then return raw end
    if raw:find('^%a[%w+.-]*:') or raw:find('%.%.') or raw:sub(1, 1) == '/' then return nil end
    return ('https://cfx-nui-%s/%s'):format(resource, raw)
end

-- exports['vr-phone']:AddApp({ id = 'taxi', label = 'Taxi', url = 'ui/index.html', color = '#f5b301', glyph = 'car' })
-- Returns true, or false and a reason.
function Apps.register(def, resource)
    if type(def) ~= 'table' then return false, 'invalid' end
    if type(def.id) ~= 'string' or #def.id > 32 or not def.id:match(ID_PATTERN) then return false, 'invalid_id' end
    if registry[def.id] then return false, 'exists' end
    local label = Phone.text(def.label, 24)
    if not label then return false, 'invalid_label' end
    local url = pageUrl(def.url, resource)
    if not url then return false, 'invalid_url' end

    local image
    if def.image ~= nil then
        image = pageUrl(def.image, resource)
        if not image then return false, 'invalid_image' end
    end

    add({
        id = def.id,
        label = label,
        category = Phone.text(def.category, 20) or 'Other',
        description = Phone.text(def.description, 240),
        color = Phone.isHex(def.color) and def.color or '#7a5cff',
        glyph = Phone.text(def.glyph, 24) or 'grid',
        image = image,
        url = url,
        preinstalled = def.preinstalled == true,
        removable = def.removable ~= false,
        essential = false,
        listed = def.listed ~= false,
        price = math.max(0, math.floor(tonumber(def.price) or 0)),
        allow = def.allow,
        custom = true,
        resource = resource,
    })
    appsChanged()
    return true
end

-- Only the script that added an app can change or remove it.
function Apps.update(id, patch, resource)
    local def = registry[id]
    if not def or not def.custom or def.resource ~= resource or type(patch) ~= 'table' then return false end
    if patch.label ~= nil then def.label = Phone.text(patch.label, 24) or def.label end
    if patch.description ~= nil then def.description = Phone.text(patch.description, 240) end
    if patch.category ~= nil then def.category = Phone.text(patch.category, 20) or def.category end
    if Phone.isHex(patch.color) then def.color = patch.color end
    if patch.glyph ~= nil then def.glyph = Phone.text(patch.glyph, 24) or def.glyph end
    if patch.listed ~= nil then def.listed = patch.listed ~= false end
    if patch.price ~= nil then def.price = math.max(0, math.floor(tonumber(patch.price) or def.price)) end
    if patch.allow ~= nil then def.allow = patch.allow end
    appsChanged()
    return true
end

function Apps.remove(id, resource)
    local def = registry[id]
    if not def or not def.custom or (resource and def.resource ~= resource) then return false end
    registry[id] = nil
    for i, v in ipairs(order) do
        if v == id then table.remove(order, i) break end
    end
    appsChanged()
    return true
end

-- Apps of a script that stopped are taken away with it.
AddEventHandler('onResourceStop', function(resource)
    local gone = {}
    for id, def in pairs(registry) do
        if def.custom and def.resource == resource then gone[#gone + 1] = id end
    end
    for _, id in ipairs(gone) do Apps.remove(id) end
end)
