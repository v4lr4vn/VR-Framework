-- One door for every notification. Other scripts call the PushNotification export, which ends up here.
--
-- A notification goes through these steps:
--   1. It is checked and cut to size.
--   2. The player's own rules for that app decide if it is allowed, and whether it shows a banner, shows on the lock screen and makes a sound.
--   3. If the phone is off, in airplane mode or out of signal, it waits (up to 25) and arrives when the phone is back.
local Notify = {}
Phone.Notify = Notify

local seq = 0
local MAX_WAITING = 25

local function clean(data)
    if type(data) ~= 'table' then return nil end
    local title = Phone.cut(data.title, 80)
    local message = Phone.cut(data.message, 300)
    -- The phone's own notifications use text keys, so the words come from the player's language file.
    local titleKey = Phone.cut(data.titleKey, 40)
    local messageKey = Phone.cut(data.messageKey, 40)
    if not title and not message and not titleKey and not messageKey then return nil end

    seq = seq + 1
    local out = {
        id = Phone.cut(data.id, 64) or ('n%d_%d'):format(os.time(), seq),
        app = Phone.cut(data.app, 32) or 'system',
        title = title,
        message = message,
        titleKey = titleKey,
        messageKey = messageKey,
        icon = Phone.cut(data.icon, 32),
        sticky = data.sticky == true,
        at = os.time(),
    }
    -- Numbers the screen puts into a translated text, for example { level = 20 }.
    if type(data.data) == 'table' then
        local values = {}
        for k, v in pairs(data.data) do
            if type(k) == 'string' and #k <= 16 and (type(v) == 'number' or type(v) == 'string') then
                values[k] = type(v) == 'string' and v:sub(1, 60) or v
            end
        end
        out.data = values
    end
    return out
end

-- Applies the player's rules for the app. Returns false when the app is blocked.
local function applyRules(n, settings, system)
    local rule = settings.notify.apps[n.app]
    if not system and rule and rule.enabled == false then return false end

    n.banner = system or not (rule and rule.banner == false)
    n.lock = system or not (rule and rule.lock == false)
    n.sound = not (not system and rule and rule.sound == false)
        and settings.quick.silent ~= true
        and settings.sound.notifications ~= false
    return true
end

-- Sends the notifications that waited, once the phone can receive again.
function Notify.flush(src, s)
    local q = s.queue
    if not q or #q == 0 then return end
    s.queue = {}
    for _, n in ipairs(q) do TriggerClientEvent('vr-phone:client:notify', src, n) end
end

-- target: a server id (number), or a phone number (string).
-- opts.system: a notification from the phone itself (battery warnings). It ignores the player's rules and never waits.
-- Returns true plus 'sent' or 'queued'. Returns false plus a reason when it was not delivered.
function Notify.push(target, data, opts)
    local system = type(opts) == 'table' and opts.system == true
    local n = clean(data)
    if not n then return false, 'invalid' end

    -- A number is a server id. A string is a phone number.
    local src
    if type(target) == 'number' then
        src = target
    elseif type(target) == 'string' then
        src = Phone.Session.srcByNumber(target)
    end

    local s = src and Phone.Session.get(src)
    if not s then return false, 'no_phone' end
    if not Phone.Identity.holdsPhone(src) then return false, 'no_phone' end

    Phone.Status.ensure(src, s)
    if not applyRules(n, s.settings, system) then return false, 'blocked' end

    if system then
        if not s.bat.powered then return false, 'off' end
    elseif not Phone.Status.canReceive(s) then
        s.queue = s.queue or {}
        -- Same id again replaces the waiting one.
        for i = #s.queue, 1, -1 do
            if s.queue[i].id == n.id then table.remove(s.queue, i) end
        end
        s.queue[#s.queue + 1] = n
        while #s.queue > MAX_WAITING do table.remove(s.queue, 1) end
        return true, 'queued'
    end

    TriggerClientEvent('vr-phone:client:notify', src, n)
    return true, 'sent'
end
