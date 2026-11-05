-- The battery. The server keeps the level, so players cannot change it.
-- It drains while the phone is in a pocket (a little), while the screen is in use (more) and while some apps are open (more again).
-- It charges in vehicles, indoors, at home, at charging points, from power banks, and when another script calls exports['vr-phone']:SetCharging().
-- Rates are percent per minute and live in config/phone.lua.
local Battery = {}
Phone.Battery = Battery

local cfg = Config.Phone.Battery

function Battery.enabled()
    return cfg.enabled ~= false
end

local function clampLevel(n)
    return math.max(0, math.min(100, n))
end

-- Loads the saved level the first time a phone is needed. A new phone starts at cfg.startLevel.
function Battery.load(s)
    if s.bat then return s.bat end

    local level = clampLevel(tonumber(cfg.startLevel) or 100)
    local known = false
    if Battery.enabled() then
        local row = MySQL.single.await('SELECT `battery` FROM `vr_ph_state` WHERE `phone_id` = ?', { s.phoneId })
        if row and tonumber(row.battery) then
            level = clampLevel(tonumber(row.battery))
            known = true
        end
    else
        level = 100
    end

    s.bat = {
        level = level,
        at = os.time(),        -- when the level was last worked out
        saved = os.time(),
        dirty = not known,     -- a new phone is written to the database soon
        powered = level > 0,
        sources = {},          -- charging sources: name -> percent per minute
        usage = {},            -- percent used since the player logged in: app (or 'standby' / 'home') -> amount
        autoLowPower = false,  -- Low Power Mode was switched on by the battery, not by the player
    }
    return s.bat
end

function Battery.save(s)
    local b = s.bat
    if not b or not Battery.enabled() then return end
    MySQL.update.await(
        'INSERT INTO `vr_ph_state` (`phone_id`, `battery`) VALUES (?, ?) ON DUPLICATE KEY UPDATE `battery` = VALUES(`battery`)',
        { s.phoneId, b.level }
    )
    b.saved = os.time()
    b.dirty = false
end

-- source: a name ('vehicle', 'point', or any name another script picks). rate: percent per minute, or nil to stop.
function Battery.setSource(s, source, rate)
    local b = Battery.load(s)
    rate = tonumber(rate)
    b.sources[source] = (rate and rate > 0) and rate or nil
end

-- The best charging rate right now (0 when not charging).
function Battery.chargeRate(s)
    local best = 0
    if s.bat then
        for _, rate in pairs(s.bat.sources) do
            if rate > best then best = rate end
        end
    end
    return best
end

-- Adds or removes charge at once (a power bank, for example). Returns the new level.
function Battery.add(s, amount)
    local b = Battery.load(s)
    amount = tonumber(amount)
    if not amount then return b.level end
    b.level = clampLevel(b.level + amount)
    if not b.powered and b.level >= (cfg.bootLevel or 2) then b.powered = true end
    if b.level <= 0 then b.powered = false end
    b.dirty = true
    return b.level
end

-- Works out the new level since the last call.
-- ctx: { screen, app, signal ('full'|'low'|'none'), airplane, bluetooth, lowPower }
-- Returns the old and new level.
function Battery.update(s, ctx)
    local b = Battery.load(s)
    local now = os.time()
    local minutes = math.max(0, (now - b.at) / 60)
    b.at = now
    local before = b.level
    if not Battery.enabled() then
        b.level, b.powered = 100, true
        return before, b.level
    end
    if minutes <= 0 then return before, b.level end

    local d = cfg.drain
    local standby, screen = 0, 0
    if b.powered then
        standby = d.idle
        if ctx.bluetooth then standby = standby + d.bluetooth end
        if ctx.signal == 'none' and not ctx.airplane then standby = standby * d.searching end
        if ctx.airplane then standby = standby * d.airplane end

        if ctx.screen then
            screen = d.screen + (d.apps[ctx.app] or 0)
        end
        if ctx.lowPower then
            standby = standby * d.lowPower
            screen = screen * d.lowPower
        end
    end

    local charge = Battery.chargeRate(s)
    local level = b.level - (standby + screen) * minutes + charge * minutes
    b.level = clampLevel(level)

    if b.powered then
        -- Count what was used, for the usage list in Settings.
        local used = math.min(before, (standby + screen) * minutes)
        if used > 0 then
            local share = (standby + screen) > 0 and (screen / (standby + screen)) or 0
            local app = ctx.app or 'home'
            b.usage[app] = (b.usage[app] or 0) + used * share
            b.usage.standby = (b.usage.standby or 0) + used * (1 - share)
        end
        if b.level <= 0 then b.powered = false end
    elseif b.level >= (cfg.bootLevel or 2) then
        b.powered = true
    end

    if math.abs(b.level - before) > 0.0001 then b.dirty = true end
    return before, b.level
end

-- Percent used since login, biggest first: { { app = 'maps', percent = 1.2 }, ... }
function Battery.usageList(s)
    local list = {}
    if s.bat then
        for app, amount in pairs(s.bat.usage) do
            if amount >= 0.005 then list[#list + 1] = { app = app, percent = math.floor(amount * 100 + 0.5) / 100 } end
        end
    end
    table.sort(list, function(a, b) return a.percent > b.percent end)
    for i = 9, #list do list[i] = nil end
    return list
end
