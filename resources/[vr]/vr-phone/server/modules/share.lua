-- Nearby share: send photos or contacts to a player standing close by, who accepts or turns it down.
--
-- Both phones need Bluetooth on (Config.Phone.Share.requireBluetooth) and power. The server works out who is near, so the screen
-- cannot ask to send to someone who is far away. A request lives for Config.Phone.Share.timeoutSeconds.
local Share = {}
Phone.Share = Share

local Session = Phone.Session

local function cfg() return Config.Phone.Share or {} end
local function range() return tonumber(cfg().range) or 10.0 end

local pending = {} -- request id -> request
local seq = 0
local MAX_OUT = 3  -- open requests one player can have at once

local function coordsOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function distance(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- What other players see for this phone: the name its owner chose in Settings, or "Phone" and the end of the number.
local function label(s)
    local name = s.settings and s.settings.profile and s.settings.profile.name
    if type(name) == 'string' and name ~= '' then return name end
    return 'Phone ' .. tostring(s.number):sub(-3)
end

local function bluetoothOn(s)
    if cfg().requireBluetooth == false then return true end
    return s.settings ~= nil and s.settings.quick.bluetooth == true
end

-- Can this phone take part in sharing right now?
local function ready(src, s)
    Phone.Status.ensure(src, s)
    return s.bat ~= nil and s.bat.powered and bluetoothOn(s)
end

-- Phones close enough to send to, nearest first: { { id = <server id>, name = '...', distance = 3.2 } }.
function Share.nearby(src, s)
    if not ready(src, s) then return {} end
    local here = coordsOf(src)
    if not here then return {} end
    local out = {}
    Session.each(function(other, os_)
        if other ~= src and os_.phoneId ~= s.phoneId and ready(other, os_) then
            local there = coordsOf(other)
            if there then
                local d = distance(here, there)
                if d <= range() then out[#out + 1] = { id = other, name = label(os_), distance = math.floor(d * 10) / 10 } end
            end
        end
    end)
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

local function outgoing(src)
    local n = 0
    for _, r in pairs(pending) do
        if r.from == src then n = n + 1 end
    end
    return n
end

local function finish(r, state, count)
    if not pending[r.id] then return end
    pending[r.id] = nil
    TriggerClientEvent('vr-phone:client:shareResult', r.from, { id = r.id, state = state, count = count or 0, name = r.toName })
    if state == 'timeout' or state == 'cancelled' then
        TriggerClientEvent('vr-phone:client:shareClosed', r.to, { id = r.id })
    end
end

-- Shares things with `target` (a server id from Share.nearby). kind: 'photo' or 'contact'. list: ids.
-- Returns { ok = true, id = ... } or { ok = false, reason = ... }.
function Share.send(src, s, target, kind, list)
    if kind ~= 'photo' and kind ~= 'contact' then return false, 'invalid' end
    target = tonumber(target)
    if not target or target == src then return false, 'invalid' end
    local to = Session.get(target)
    if not to then return false, 'gone' end

    -- Recheck distance and Bluetooth on the server, whatever the screen showed.
    local found
    for _, p in ipairs(Share.nearby(src, s)) do
        if p.id == target then found = p end
    end
    if not found then return false, 'gone' end
    if outgoing(src) >= MAX_OUT then return false, 'busy' end
    for _, r in pairs(pending) do
        if r.from == src and r.to == target then return false, 'busy' end
    end

    local maxItems = tonumber(cfg().maxItems) or 20
    local ids, preview
    if kind == 'photo' then
        ids = Phone.Media.owned(s.phoneId, Phone.Media.ids(list, maxItems))
        if #ids == 0 then return false, 'nothing' end
        local row = MySQL.scalar.await('SELECT `thumb` FROM `vr_ph_media` WHERE `phone_id` = ? AND `id` = ?', { s.phoneId, ids[1] })
        preview = row
    else
        ids = {}
        for _, v in ipairs(Phone.Media.ids(list, maxItems)) do ids[#ids + 1] = v end
        if #ids == 0 then return false, 'nothing' end
        local marks = string.rep('?,', #ids):sub(1, -2)
        local args = { s.phoneId }
        for _, v in ipairs(ids) do args[#args + 1] = v end
        local rows = MySQL.query.await('SELECT `id`, `name`, `number` FROM `vr_ph_contacts` WHERE `phone_id` = ? AND `id` IN (' .. marks .. ')', args) or {}
        if #rows == 0 then return false, 'nothing' end
        ids = rows
        preview = rows[1].name
    end

    seq = seq + 1
    local id = ('sh%d_%d'):format(os.time(), seq)
    local r = {
        id = id, from = src, to = target, kind = kind, ids = ids,
        fromPhone = s.phoneId, toName = found.name, expires = os.time() + (tonumber(cfg().timeoutSeconds) or 60),
    }
    pending[id] = r

    TriggerClientEvent('vr-phone:client:share', target, {
        id = id, name = label(s), kind = kind, count = #ids, preview = preview,
        seconds = tonumber(cfg().timeoutSeconds) or 60,
    })
    -- If the phone is away the screen is not looking, so a banner tells the player a request is waiting.
    Phone.Notify.push(target, { app = 'system', titleKey = 'share.noteTitle', messageKey = 'share.noteText', data = { name = label(s) } }, { system = true })

    CreateThread(function()
        Wait((tonumber(cfg().timeoutSeconds) or 60) * 1000)
        if pending[id] then finish(r, 'timeout') end
    end)
    return true, id
end

-- The receiver's answer. Returns true or false and a reason.
function Share.respond(src, s, id, accept)
    local r = pending[id]
    if not r or r.to ~= src then return false, 'gone' end
    if not accept then
        finish(r, 'rejected')
        return true
    end

    -- The two players must still be close, and the sender's phone must still be the same phone.
    local from = Session.get(r.from)
    local a, b = coordsOf(r.from), coordsOf(src)
    if not from or from.phoneId ~= r.fromPhone or not a or not b or distance(a, b) > range() + 5.0 then
        finish(r, 'failed')
        return false, 'gone'
    end

    local count = 0
    if r.kind == 'photo' then
        local copied, why = Phone.Media.copy(r.fromPhone, r.ids, s.phoneId)
        count = copied
        if copied == 0 then
            finish(r, 'failed')
            return false, why or 'failed'
        end
    else
        for _, c in ipairs(r.ids) do
            local saved = Phone.Contacts.save(s.phoneId, { name = c.name, number = c.number })
            if saved then count = count + 1 end
        end
        if count == 0 then
            finish(r, 'failed')
            return false, 'duplicate'
        end
    end
    finish(r, 'accepted', count)
    return true, count
end

-- The sender took the request back.
function Share.cancel(src, id)
    local r = pending[id]
    if not r or r.from ~= src then return false end
    finish(r, 'cancelled')
    return true
end

-- A player leaving ends every request they were part of.
Session.onStop(function(src)
    for _, r in pairs(pending) do
        if r.from == src then
            pending[r.id] = nil
            TriggerClientEvent('vr-phone:client:shareClosed', r.to, { id = r.id })
        elseif r.to == src then
            finish(r, 'rejected')
        end
    end
end)
