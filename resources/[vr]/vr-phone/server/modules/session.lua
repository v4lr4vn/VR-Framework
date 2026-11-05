-- Who is holding which phone right now.
-- A session lives from the first time a player's phone is found until they leave.
local Session = {}
Phone.Session = Session

local sessions = {} -- source -> session
local phones = {}   -- phoneId -> source
local numbers = {}  -- number -> source

-- Other modules ask to hear about a session ending (to save things, for example).
local stopHooks = {}
function Session.onStop(fn) stopHooks[#stopHooks + 1] = fn end

function Session.start(src, row, pinEnabled)
    local current = sessions[src]
    if current and current.phoneId == row.phone_id then
        current.number = row.number
        current.pin = pinEnabled == true
        return current
    end

    Session.stop(src)

    local s = {
        phoneId = row.phone_id,
        number = row.number,
        pin = pinEnabled == true,
        unlocked = false,
        relockAt = 0,
    }
    sessions[src] = s
    phones[s.phoneId] = src
    numbers[s.number] = src
    return s
end

function Session.stop(src)
    local s = sessions[src]
    if not s then return end
    for _, fn in ipairs(stopHooks) do pcall(fn, src, s) end
    -- The phone may have moved to another player, so only clear what still points at this player.
    if phones[s.phoneId] == src then phones[s.phoneId] = nil end
    if numbers[s.number] == src then numbers[s.number] = nil end
    sessions[src] = nil
end

function Session.get(src) return sessions[src] end

-- Calls fn(src, session) for every session.
function Session.each(fn)
    for src, s in pairs(sessions) do fn(src, s) end
end
function Session.srcByNumber(number) return numbers[number] end
function Session.srcByPhoneId(phoneId) return phones[phoneId] end

function Session.setPin(src, enabled)
    local s = sessions[src]
    if s then s.pin = enabled == true end
end

function Session.setUnlocked(src, state)
    local s = sessions[src]
    if not s then return end
    s.unlocked = state == true
    s.relockAt = 0
end

-- True when the screen can be used: no PIN is set, or the PIN was entered and the auto-lock timer has not run out.
function Session.isUnlocked(src)
    local s = sessions[src]
    if not s then return false end
    if not s.pin then return true end
    if not s.unlocked then return false end
    return s.relockAt == 0 or os.time() < s.relockAt
end

-- The phone was put away. Start the auto-lock timer.
function Session.closed(src)
    local s = sessions[src]
    if not s then return end
    local wait = Config.Phone.Lock.autoLockSeconds or 0
    if wait <= 0 then
        s.unlocked = false
        s.relockAt = 0
    else
        s.relockAt = os.time() + wait
    end
end

-- The phone was taken out again. Lock it if the timer ran out, otherwise keep it unlocked.
function Session.opened(src)
    local s = sessions[src]
    if not s then return end
    if s.relockAt ~= 0 and os.time() >= s.relockAt then s.unlocked = false end
    s.relockAt = 0
end
