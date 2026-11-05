-- The screen's way into contacts, messages, calls and voicemail.
-- Every callback checks that the phone is still in the player's hands (Phone.guard) and limits how fast it can be used (Phone.tooFast).
-- Reading things works on a locked phone only for the lock screen; here everything needs the phone unlocked,
-- except answering and hanging up a call, which the cover screen must always be able to do.
local Session = Phone.Session
local Contacts = Phone.Contacts
local Messages = Phone.Messages
local Calls = Phone.Calls
local Voicemail = Phone.Voicemail
local guard, tooFast = Phone.guard, Phone.tooFast

local function text(v, max)
    if type(v) ~= 'string' then return nil end
    return v:sub(1, max)
end

-- The numbers on the app icons. A phone that is locked can still ask: the lock screen shows them too.
lib.callback.register('vr-phone:badges', function(src)
    local s = guard(src, false)
    if not s then return { ok = false } end
    return { ok = true, badges = Phone.badges(s.number) }
end)

-- ---------------------------------------------------------------- contacts

lib.callback.register('vr-phone:contacts:list', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = true, contacts = Contacts.list(s.phoneId) }
end)

lib.callback.register('vr-phone:contacts:save', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    if tooFast(src, 'contact', 200) then return { ok = false, reason = 'busy' } end

    local c, why = Contacts.save(s.phoneId, {
        id = data.id,
        name = text(data.name, 120),
        number = text(data.number, 40),
        favourite = data.favourite,
        blocked = data.blocked,
    })
    if not c then return { ok = false, reason = why } end
    return { ok = true, contact = c }
end)

lib.callback.register('vr-phone:contacts:remove', function(src, id)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if tooFast(src, 'contact', 200) then return { ok = false, reason = 'busy' } end
    return { ok = Contacts.remove(s.phoneId, id) }
end)

-- ---------------------------------------------------------------- messages

lib.callback.register('vr-phone:messages:threads', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = true, threads = Messages.threads(s.number) }
end)

lib.callback.register('vr-phone:messages:history', function(src, data)
    local s = guard(src, true)
    if not s or type(data) ~= 'table' then return { ok = false } end
    if tooFast(src, 'history', 150) then return { ok = false, reason = 'busy' } end
    local list, more = Messages.history(s.number, text(data.number, 40), data.before)
    if not list then return { ok = false, reason = more } end
    return { ok = true, messages = list, more = more }
end)

lib.callback.register('vr-phone:messages:send', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid_body' } end
    if tooFast(src, 'send', 250) then return { ok = false, reason = 'busy' } end

    -- A phone with no service cannot send.
    Phone.Status.ensure(src, s)
    if not Phone.Status.canReceive(s) then return { ok = false, reason = 'no_service' } end

    local m, why = Messages.send(s.number, text(data.number, 40), text(data.body, 2000))
    if not m then return { ok = false, reason = why } end

    Messages.deliver(m)
    return { ok = true, message = { id = m.id, mine = true, body = m.body, at = m.at } }
end)

lib.callback.register('vr-phone:messages:read', function(src, number)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = Messages.markRead(s.number, text(number, 40)), badges = Phone.badges(s.number) }
end)

lib.callback.register('vr-phone:messages:delete', function(src, number)
    local s = guard(src, true)
    if not s then return { ok = false } end
    if tooFast(src, 'thread', 200) then return { ok = false, reason = 'busy' } end
    return { ok = Messages.deleteThread(s.number, text(number, 40)), badges = Phone.badges(s.number) }
end)

-- ---------------------------------------------------------------- calls

lib.callback.register('vr-phone:calls:recent', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = true, calls = Calls.recent(s.number) }
end)

-- The player opened the Phone app: missed calls are no longer new.
lib.callback.register('vr-phone:calls:seen', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    Calls.markSeen(s.number)
    return { ok = true, badges = Phone.badges(s.number) }
end)

lib.callback.register('vr-phone:calls:clear', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    if tooFast(src, 'calls', 300) then return { ok = false, reason = 'busy' } end
    Calls.clear(s.number)
    return { ok = true, badges = Phone.badges(s.number) }
end)

lib.callback.register('vr-phone:call:start', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid_number' } end
    if tooFast(src, 'dial', 800) then return { ok = false, reason = 'busy' } end

    local call, why = Calls.start(src, s, text(data.number, 40))
    if not call then return { ok = false, reason = why } end
    return { ok = true, id = call.id, state = call.state }
end)

-- Answering and hanging up only need a phone that is still held and switched on. The cover screen has to be able to do both,
-- and a ringing call does not wait for the PIN.
lib.callback.register('vr-phone:call:answer', function(src, id)
    local s, reason = guard(src, false)
    if not s then return { ok = false, reason = reason } end
    if tooFast(src, 'answer', 300) then return { ok = false, reason = 'busy' } end
    local ok, why = Calls.answer(src, id)
    return { ok = ok, reason = why }
end)

lib.callback.register('vr-phone:call:end', function(src, id)
    -- A held phone is not needed to put the phone down: a dropped phone still has to stop the call.
    if not Session.get(src) then return { ok = false, reason = 'no_session' } end
    local ok, why = Calls.hangup(src, id)
    return { ok = ok, reason = why }
end)

lib.callback.register('vr-phone:call:voicemail', function(src, data)
    local s, reason = guard(src, false)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'empty' } end
    if tooFast(src, 'vm', 500) then return { ok = false, reason = 'busy' } end
    local ok, why = Calls.leaveVoicemail(src, data.id, text(data.body, 1000))
    return { ok = ok, reason = why }
end)

-- ---------------------------------------------------------------- voicemail

lib.callback.register('vr-phone:voicemail:list', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = true, voicemail = Voicemail.list(s.number) }
end)

lib.callback.register('vr-phone:voicemail:heard', function(src, id)
    local s = guard(src, true)
    if not s then return { ok = false } end
    Voicemail.markHeard(s.number, id)
    return { ok = true, badges = Phone.badges(s.number) }
end)

lib.callback.register('vr-phone:voicemail:remove', function(src, id)
    local s = guard(src, true)
    if not s then return { ok = false } end
    if tooFast(src, 'vm', 200) then return { ok = false, reason = 'busy' } end
    return { ok = Voicemail.remove(s.number, id), badges = Phone.badges(s.number) }
end)

-- ---------------------------------------------------------------- photos and albums

local Media = Phone.Media
local Share = Phone.Share

lib.callback.register('vr-phone:media:list', function(src, data)
    local s = guard(src, true)
    if not s or type(data) ~= 'table' then return { ok = false } end
    if tooFast(src, 'mlist', 150) then return { ok = false, reason = 'busy' } end
    local view = data.view
    if view ~= 'all' and view ~= 'favourites' and view ~= 'deleted' and view ~= 'album' then view = 'all' end
    local items, more = Media.list(s.phoneId, view, data.before, data.album)
    if not items then return { ok = false, reason = more } end
    return { ok = true, items = items, more = more }
end)

lib.callback.register('vr-phone:media:get', function(src, id)
    local s = guard(src, true)
    if not s then return { ok = false } end
    if tooFast(src, 'mget', 100) then return { ok = false, reason = 'busy' } end
    local photo = Media.get(s.phoneId, id)
    if not photo then return { ok = false, reason = 'not_found' } end
    return { ok = true, photo = photo }
end)

lib.callback.register('vr-phone:media:stats', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    return { ok = true, stats = Media.stats(s.phoneId), albums = Media.albums(s.phoneId) }
end)

lib.callback.register('vr-phone:media:album', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    if tooFast(src, 'malbum', 250) then return { ok = false, reason = 'busy' } end
    local action = data.action
    if action == 'create' then
        local album, why = Media.createAlbum(s.phoneId, text(data.name, 60))
        if not album then return { ok = false, reason = why } end
        return { ok = true, album = album }
    elseif action == 'rename' then
        local ok, why = Media.renameAlbum(s.phoneId, data.id, text(data.name, 60))
        return { ok = ok, reason = why }
    elseif action == 'remove' then
        return { ok = Media.removeAlbum(s.phoneId, data.id) }
    end
    return { ok = false, reason = 'invalid' }
end)

-- One door for the things you do to photos you already have.
lib.callback.register('vr-phone:media:edit', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    if tooFast(src, 'medit', 200) then return { ok = false, reason = 'busy' } end
    local action, list = data.action, data.ids
    local changed = 0
    if action == 'favourite' then
        changed = Media.setFavourite(s.phoneId, list, data.on == true)
    elseif action == 'trash' then
        changed = Media.trash(s.phoneId, list)
    elseif action == 'restore' then
        changed = Media.restore(s.phoneId, list)
    elseif action == 'erase' then
        changed = Media.erase(s.phoneId, list)
    elseif action == 'empty' then
        changed = Media.emptyTrash(s.phoneId)
    elseif action == 'album' then
        local n, why = Media.setAlbum(s.phoneId, list, data.album)
        if why then return { ok = false, reason = why } end
        changed = n
    else
        return { ok = false, reason = 'invalid' }
    end
    return { ok = true, changed = changed }
end)

-- A new photo: begin, send the pieces, then save.
lib.callback.register('vr-phone:media:begin', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    -- One photo every couple of seconds is plenty.
    local gap = ((Config.Phone.Media and Config.Phone.Media.cooldownSeconds) or 2) * 1000
    if tooFast(src, 'mnew', gap) then return { ok = false, reason = 'busy' } end
    if Media.stats(s.phoneId).photos >= ((Config.Phone.Media and Config.Phone.Media.maxPhotos) or 120) then
        return { ok = false, reason = 'full' }
    end
    local ok, why = Media.uploadStart(src, text(data.id, 32), data.total)
    return { ok = ok, reason = why }
end)

lib.callback.register('vr-phone:media:part', function(src, data)
    local s = guard(src, true)
    if not s or type(data) ~= 'table' then return { ok = false } end
    local ok, why = Media.uploadPart(src, text(data.id, 32), data.index, data.part)
    return { ok = ok, reason = why }
end)

lib.callback.register('vr-phone:media:save', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    local joined, why = Media.uploadFinish(src, text(data.id, 32))
    if not joined then return { ok = false, reason = why } end
    local photo, err = Media.add(s.phoneId, { data = joined.data, thumb = joined.thumb, width = data.width, height = data.height, source = 'camera' }, src)
    if not photo then return { ok = false, reason = err } end
    return { ok = true, photo = photo }
end)

-- ---------------------------------------------------------------- nearby share

lib.callback.register('vr-phone:share:nearby', function(src)
    local s = guard(src, true)
    if not s then return { ok = false } end
    if tooFast(src, 'snear', 400) then return { ok = false, reason = 'busy' } end
    local s2 = Share.nearby(src, s)
    local bluetooth = s.settings and s.settings.quick.bluetooth == true
    return { ok = true, people = s2, bluetooth = bluetooth }
end)

lib.callback.register('vr-phone:share:send', function(src, data)
    local s, reason = guard(src, true)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    if tooFast(src, 'ssend', 800) then return { ok = false, reason = 'busy' } end
    local ok, result = Share.send(src, s, data.target, data.kind, data.ids)
    if not ok then return { ok = false, reason = result } end
    return { ok = true, id = result }
end)

-- Answering a request needs a switched-on phone, but not the PIN: the sheet asks first, like a call.
lib.callback.register('vr-phone:share:respond', function(src, data)
    local s, reason = guard(src, false)
    if not s then return { ok = false, reason = reason } end
    if type(data) ~= 'table' then return { ok = false, reason = 'invalid' } end
    if tooFast(src, 'sresp', 400) then return { ok = false, reason = 'busy' } end
    local ok, result = Share.respond(src, s, text(data.id, 40), data.accept == true)
    if not ok then return { ok = false, reason = result } end
    return { ok = true, count = result }
end)

lib.callback.register('vr-phone:share:cancel', function(src, id)
    if not Session.get(src) then return { ok = false } end
    return { ok = Share.cancel(src, text(id, 40)) }
end)
