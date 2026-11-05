-- PIN lock. The PIN is never stored. The database keeps a salted SHA-256 and does the comparing itself.
-- Wrong guesses are counted per phone and lock it out for longer each time.
local Security = {}
Phone.Security = Security

local lock = Config.Phone.Lock

local thresholds = {}
for count in pairs(lock.lockouts) do thresholds[#thresholds + 1] = count end
table.sort(thresholds)

local function lockoutSeconds(fails)
    local seconds = 0
    for _, count in ipairs(thresholds) do
        if fails >= count then seconds = lock.lockouts[count] end
    end
    return seconds
end

local allowedLengths = {}
for _, n in ipairs(lock.pinLengths) do allowedLengths[n] = true end

local function validPin(pin)
    return type(pin) == 'string' and pin:match('^%d+$') ~= nil and allowedLengths[#pin] == true
end

local function randomSalt()
    local out = {}
    for i = 1, 16 do out[i] = ('%x'):format(math.random(0, 15)) end
    return table.concat(out)
end

-- One PIN check at a time per phone, so parallel guesses cannot dodge the counter.
local busy = {}

-- What the screen needs to know. `row` is a vr_ph_phones row.
function Security.status(row)
    local left = (row.locked_until or 0) - os.time()
    return {
        enabled = row.pin_hash ~= nil,
        length = row.pin_length,
        lockedFor = left > 0 and left or 0,
    }
end

-- Returns true when the PIN is right (or none is set).
-- Otherwise returns false, a reason ('wrong', 'locked', 'busy', 'no_phone') and the seconds left on a lockout.
function Security.verify(phoneId, pin)
    if busy[phoneId] then return false, 'busy', 0 end
    busy[phoneId] = true

    local ok, a, b, c = pcall(function()
        local row = MySQL.single.await('SELECT `pin_hash`, `fail_count`, `locked_until` FROM `vr_ph_phones` WHERE `phone_id` = ?', { phoneId })
        if not row then return false, 'no_phone', 0 end
        if not row.pin_hash then return true end

        local now = os.time()
        if row.locked_until > now then return false, 'locked', row.locked_until - now end

        local match = false
        if validPin(pin) then
            local result = MySQL.scalar.await('SELECT `pin_hash` = SHA2(CONCAT(`pin_salt`, ?), 256) FROM `vr_ph_phones` WHERE `phone_id` = ?', { pin, phoneId })
            match = result == 1 or result == true
        end

        if match then
            MySQL.update.await('UPDATE `vr_ph_phones` SET `fail_count` = 0, `locked_until` = 0 WHERE `phone_id` = ?', { phoneId })
            return true
        end

        local fails = row.fail_count + 1
        local seconds = lockoutSeconds(fails)
        MySQL.update.await('UPDATE `vr_ph_phones` SET `fail_count` = ?, `locked_until` = ? WHERE `phone_id` = ?', { fails, seconds > 0 and (now + seconds) or 0, phoneId })
        return false, seconds > 0 and 'locked' or 'wrong', seconds
    end)

    busy[phoneId] = nil
    if not ok then
        print(('^1[vr-phone] PIN check failed: %s^0'):format(tostring(a)))
        return false, 'error', 0
    end
    return a, b, c
end

-- Sets or changes the PIN. When one is already set, the old one must be right.
function Security.setPin(phoneId, newPin, oldPin)
    if not validPin(newPin) then return false, 'invalid_pin', 0 end

    local row = MySQL.single.await('SELECT `pin_hash` FROM `vr_ph_phones` WHERE `phone_id` = ?', { phoneId })
    if not row then return false, 'no_phone', 0 end

    if row.pin_hash then
        local ok, reason, wait = Security.verify(phoneId, oldPin)
        if not ok then return false, reason, wait end
    end

    local salt = randomSalt()
    MySQL.update.await('UPDATE `vr_ph_phones` SET `pin_salt` = ?, `pin_hash` = SHA2(CONCAT(?, ?), 256), `pin_length` = ?, `fail_count` = 0, `locked_until` = 0 WHERE `phone_id` = ?', { salt, salt, newPin, #newPin, phoneId })
    return true, nil, 0
end

-- Turns the PIN off. The current PIN must be right.
function Security.removePin(phoneId, pin)
    local ok, reason, wait = Security.verify(phoneId, pin)
    if not ok then return false, reason, wait end
    MySQL.update.await('UPDATE `vr_ph_phones` SET `pin_hash` = NULL, `pin_salt` = NULL, `pin_length` = NULL, `fail_count` = 0, `locked_until` = 0 WHERE `phone_id` = ?', { phoneId })
    return true, nil, 0
end
