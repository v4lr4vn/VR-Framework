-- Per-phone settings and the home screen layout. Both are saved on the server, so they follow the phone.
-- Everything a player sends is checked against a short list of allowed keys and values first.
local Settings = {}
Phone.Settings = Settings

local MAX_DOCK = 5
local MAX_ITEMS = 120
local MAX_LAYOUT_BYTES = 8192

local wallpapers = {}
for _, id in ipairs(Config.Phone.Wallpapers) do wallpapers[id] = true end

local function defaults()
    local theme = Config.Phone.Theme
    return {
        theme = { accent = theme.accent, dark = theme.darkMode == true, scale = theme.scale },
        wallpaper = { home = 'aurora', lock = 'dusk' },
        lock = { showPreviews = true, clock = 'stack' },
        frame = { color = '#2b2a33' },
        general = { time24 = true, timeSource = Config.Phone.TimeSource == 'game' and 'game' or 'pc' },
        profile = { name = '' },
        quick = { airplane = false, bluetooth = false, silent = false, brightness = 1, audio = 'phone' },
        battery = { lowPower = false, autoLowPower = true, showPercent = true },
        perf = { reduceMotion = false },
        notify = { style = 'list', apps = {} },
        sound = { volume = 0.6, notifications = true, touch = true, ringtone = 'default' },
        health = { goal = (Config.Phone.Health or {}).stepGoal or 8000, imperial = false },
        music = { volume = (Config.Phone.Music or {}).volume or 60, speaker = true, range = (Config.Phone.Music or {}).range or 8.0, hear = true },
    }
end

-- Each rule returns the clean value, or nil when the value is not allowed.
local function bool(v) if type(v) == 'boolean' then return v end end
local function hex(v) if Phone.isHex(v) then return v:lower() end end
local function range(lo, hi) return function(v) return Phone.clamp(v, lo, hi) end end
local function oneOf(set) return function(v) if type(v) == 'string' and set[v] then return v end end end

local sanitize -- defined below. perApp needs it.

local function text(max)
    return function(v)
        if type(v) ~= 'string' then return nil end
        -- Control characters have no place in a name.
        v = v:gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
        if #v > max then v = v:sub(1, max) end
        return v
    end
end

local function slug(max)
    return function(v)
        if type(v) == 'string' and #v >= 1 and #v <= max and v:match('^[%w_%-]+$') then return v end
    end
end

-- Per-app notification rules: { [appId] = { enabled, banner, lock, sound } }. Unknown keys are dropped.
local appRule = { enabled = bool, banner = bool, lock = bool, sound = bool }
local MAX_APP_RULES = 60

local function perApp(v)
    if type(v) ~= 'table' then return nil end
    local out, count = {}, 0
    for id, rule in pairs(v) do
        if count >= MAX_APP_RULES then break end
        if type(id) == 'string' and slug(32)(id) then
            local clean = sanitize(rule, appRule)
            if next(clean) then
                out[id] = clean
                count = count + 1
            end
        end
    end
    return out
end

local schema = {
    theme = { accent = hex, dark = bool, scale = range(0.6, 1.2) },
    wallpaper = { home = oneOf(wallpapers), lock = oneOf(wallpapers) },
    lock = { showPreviews = bool, clock = oneOf({ stack = true, row = true, mono = true }) },
    frame = { color = hex },
    general = { time24 = bool, timeSource = oneOf({ pc = true, game = true }) },
    profile = { name = text(24) },
    quick = {
        airplane = bool,
        bluetooth = bool,
        silent = bool,
        brightness = range(0.25, 1),
        audio = oneOf({ phone = true, speaker = true, bluetooth = true }),
    },
    battery = { lowPower = bool, autoLowPower = bool, showPercent = bool },
    perf = { reduceMotion = bool },
    notify = { style = oneOf({ list = true, stack = true, count = true }), apps = perApp },
    sound = { volume = range(0, 1), notifications = bool, touch = bool, ringtone = slug(32) },
    health = { goal = range(1000, 40000), imperial = bool },
    music = {
        volume = range(0, 100),
        speaker = bool,
        hear = bool,
        -- the nearest of the distances the config allows
        range = function(v)
            v = tonumber(v)
            if not v then return nil end
            local best
            for _, choice in ipairs((Config.Phone.Music or {}).rangeChoices or { 5.0, 8.0, 10.0 }) do
                if not best or math.abs(choice - v) < math.abs(best - v) then best = choice end
            end
            return best
        end,
    },
}

function sanitize(patch, rules)
    local out = {}
    if type(patch) ~= 'table' then return out end
    for key, rule in pairs(rules) do
        local value = patch[key]
        if value ~= nil then
            if type(rule) == 'table' then
                local nested = sanitize(value, rule)
                if next(nested) then out[key] = nested end
            else
                local clean = rule(value)
                if clean ~= nil then out[key] = clean end
            end
        end
    end
    return out
end

local function decode(text)
    if type(text) ~= 'string' or text == '' then return nil end
    local ok, value = pcall(json.decode, text)
    if ok and type(value) == 'table' then return value end
    return nil
end

local function row(phoneId)
    return MySQL.single.await('SELECT `settings`, `layout` FROM `vr_ph_settings` WHERE `phone_id` = ?', { phoneId })
end

function Settings.get(phoneId)
    local r = row(phoneId)
    local stored = r and decode(r.settings) or {}
    -- Run stored values through the rules again, so old or hand-edited rows cannot break the screen.
    return Phone.deepMerge(defaults(), sanitize(stored, schema))
end

-- Merges a partial change into the saved settings. Returns the full settings.
function Settings.save(phoneId, patch)
    local clean = sanitize(patch, schema)
    local merged = Phone.deepMerge(Settings.get(phoneId), clean)
    MySQL.update.await(
        'INSERT INTO `vr_ph_settings` (`phone_id`, `settings`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `settings` = VALUES(`settings`)',
        { phoneId, json.encode(merged) }
    )
    return merged
end

-- Layout: { dock = { 'phone', ... }, items = { 'app', { folder = 'Name', apps = { ... } }, ... } }
-- Items are one flat list. The screen cuts it into pages to fit the fold state.

local function defaultLayout(order)
    local inDock, dock, items = {}, {}, {}
    local available = {}
    for _, id in ipairs(order) do available[id] = true end
    for _, id in ipairs(Config.Phone.Home.dock) do
        if available[id] and #dock < MAX_DOCK then
            dock[#dock + 1] = id
            inDock[id] = true
        end
    end
    for _, id in ipairs(order) do
        if not inDock[id] then items[#items + 1] = id end
    end
    return { dock = dock, items = items }
end

-- Drops unknown or uninstalled apps and repeats, then appends any installed app that is not placed yet.
local function reconcile(layout, order)
    local available, seen = {}, {}
    for _, id in ipairs(order) do available[id] = true end

    local function claim(id)
        if type(id) ~= 'string' or not available[id] or seen[id] then return false end
        seen[id] = true
        return true
    end

    local dock, items = {}, {}
    for _, id in ipairs(type(layout.dock) == 'table' and layout.dock or {}) do
        if #dock < MAX_DOCK and claim(id) then dock[#dock + 1] = id end
    end
    for _, item in ipairs(type(layout.items) == 'table' and layout.items or {}) do
        if #items >= MAX_ITEMS then break end
        if type(item) == 'table' then
            local name = Phone.cut(item.folder, 20)
            local inner = {}
            for _, id in ipairs(type(item.apps) == 'table' and item.apps or {}) do
                if claim(id) then
                    -- A folder without a usable name is dissolved: its apps become loose icons.
                    if name then inner[#inner + 1] = id else items[#items + 1] = id end
                end
            end
            if name and #inner > 0 then items[#items + 1] = { folder = name, apps = inner } end
        elseif claim(item) then
            items[#items + 1] = item
        end
    end
    for _, id in ipairs(order) do
        if claim(id) then items[#items + 1] = id end
    end
    return { dock = dock, items = items }
end

function Settings.getLayout(phoneId)
    local order = Phone.Apps.installedIds(phoneId)
    local r = row(phoneId)
    local stored = r and decode(r.layout)
    if not stored then return defaultLayout(order) end
    return reconcile(stored, order)
end

function Settings.saveLayout(phoneId, layout)
    if type(layout) ~= 'table' then return nil, 'invalid_layout' end
    local encoded = json.encode(layout)
    if #encoded > MAX_LAYOUT_BYTES then return nil, 'too_big' end

    local clean = reconcile(layout, Phone.Apps.installedIds(phoneId))
    MySQL.update.await(
        'INSERT INTO `vr_ph_settings` (`phone_id`, `layout`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `layout` = VALUES(`layout`)',
        { phoneId, json.encode(clean) }
    )
    return clean
end
