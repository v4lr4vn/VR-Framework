-- The screen's way into Notes, Reminders, Calendar, Mail, Wallet, Maps and Health.
-- Same rules as comms.lua: every callback checks the phone is still in the player's hands and unlocked (Phone.guard),
-- and limits how fast it can be used (Phone.tooFast).
local Notes, Planner, Mail = Phone.Notes, Phone.Planner, Phone.Mail
local Wallet, Places, Health = Phone.Wallet, Phone.Places, Phone.Health
local guard, tooFast = Phone.guard, Phone.tooFast

local function fail(reason) return { ok = false, reason = reason } end

-- ---------------------------------------------------------------- notes

lib.callback.register('vr-phone:notes:list', function(src)
    local s = guard(src, true)
    if not s then return fail() end
    return { ok = true, notes = Notes.list(s.phoneId) }
end)

lib.callback.register('vr-phone:notes:get', function(src, id)
    local s = guard(src, true)
    if not s then return fail() end
    if tooFast(src, 'nget', 100) then return fail('busy') end
    local n = Notes.get(s.phoneId, id)
    if not n then return fail('not_found') end
    return { ok = true, note = n }
end)

lib.callback.register('vr-phone:notes:save', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'nsave', 400) then return fail('busy') end
    local n, why = Notes.save(s.phoneId, data)
    if not n then return fail(why) end
    return { ok = true, note = n }
end)

lib.callback.register('vr-phone:notes:pin', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'npin', 200) then return fail('busy') end
    return { ok = Notes.pin(s.phoneId, data.id, data.on == true) }
end)

lib.callback.register('vr-phone:notes:remove', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'nrem', 200) then return fail('busy') end
    return { ok = Notes.remove(s.phoneId, id) }
end)

-- ---------------------------------------------------------------- reminders and calendar

lib.callback.register('vr-phone:rem:list', function(src)
    local s = guard(src, true)
    if not s then return fail() end
    return { ok = true, reminders = Planner.reminders(s.phoneId) }
end)

lib.callback.register('vr-phone:rem:save', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'rsave', 300) then return fail('busy') end
    local r, why = Planner.saveReminder(s.phoneId, data)
    if not r then return fail(why) end
    return { ok = true, reminder = r }
end)

lib.callback.register('vr-phone:rem:done', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'rdone', 100) then return fail('busy') end
    return { ok = Planner.setDone(s.phoneId, data.id, data.done == true) }
end)

lib.callback.register('vr-phone:rem:remove', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'rrem', 150) then return fail('busy') end
    if type(data) == 'table' and data.clearDone == true then return { ok = true, removed = Planner.clearDone(s.phoneId) } end
    return { ok = Planner.removeReminder(s.phoneId, type(data) == 'table' and data.id or nil) }
end)

lib.callback.register('vr-phone:cal:list', function(src, data)
    local s = guard(src, true)
    if not s then return fail() end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'clist', 150) then return fail('busy') end
    local events, why = Planner.events(s.phoneId, data.from, data.to)
    if not events then return fail(why) end
    return { ok = true, events = events }
end)

lib.callback.register('vr-phone:cal:save', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'csave', 300) then return fail('busy') end
    local e, why = Planner.saveEvent(s.phoneId, data)
    if not e then return fail(why) end
    return { ok = true, event = e }
end)

lib.callback.register('vr-phone:cal:remove', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'crem', 150) then return fail('busy') end
    return { ok = Planner.removeEvent(s.phoneId, id) }
end)

-- The player's game asks which alerts are waiting, and says when one is due. The phone only has to be switched on
-- (a locked phone still alerts, like any notification).
lib.callback.register('vr-phone:due:list', function(src)
    local s = guard(src, false)
    if not s then return fail() end
    if tooFast(src, 'dlist', 5000) then return fail('busy') end
    return { ok = true, due = Planner.pending(s.phoneId) }
end)

lib.callback.register('vr-phone:due:fire', function(src, data)
    local s = guard(src, false)
    if not s or type(data) ~= 'table' then return fail() end
    if tooFast(src, 'dfire', 250) then return fail('busy') end
    local n = Planner.fire(s.phoneId, data.kind, data.id)
    if not n then return { ok = true, sent = false } end
    Phone.Notify.push(src, n)
    return { ok = true, sent = true }
end)

-- ---------------------------------------------------------------- mail

-- Where Mail stands for this phone: signed in or not, and the folder counts.
lib.callback.register('vr-phone:mail:state', function(src)
    local s = guard(src, true)
    if not s then return fail() end
    local acc = Mail.account(s.phoneId)
    if not acc then return { ok = true, account = nil } end
    return { ok = true, account = acc, counts = Mail.counts(acc.id) }
end)

lib.callback.register('vr-phone:mail:create', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'mcreate', 1500) then return fail('busy') end
    local acc, code = Mail.create(s.phoneId, data.address, data.password, data.name or (s.settings and s.settings.profile and s.settings.profile.name))
    if not acc then return fail(code) end
    return { ok = true, account = acc, recovery = code, counts = Mail.counts(acc.id) }
end)

lib.callback.register('vr-phone:mail:login', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'mlogin', 1000) then return fail('busy') end
    local acc, why, secs = Mail.login(s.phoneId, data.address, data.password)
    if not acc then return { ok = false, reason = why, seconds = secs } end
    return { ok = true, account = acc, counts = Mail.counts(acc.id) }
end)

lib.callback.register('vr-phone:mail:reset', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'mreset', 1500) then return fail('busy') end
    local acc, why, secs = Mail.reset(s.phoneId, data.address, data.code, data.password)
    if not acc then return { ok = false, reason = why, seconds = secs } end
    return { ok = true, account = acc, recovery = why, counts = Mail.counts(acc.id) }
end)

lib.callback.register('vr-phone:mail:logout', function(src)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    return { ok = Mail.logout(s.phoneId) }
end)

lib.callback.register('vr-phone:mail:password', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    local acc = Mail.account(s.phoneId)
    if not acc or type(data) ~= 'table' then return fail('no_account') end
    if tooFast(src, 'mpass', 1500) then return fail('busy') end
    local ok, why, secs = Mail.changePassword(acc.id, acc.address, data.old, data.new)
    return { ok = ok, reason = why, seconds = secs }
end)

lib.callback.register('vr-phone:mail:list', function(src, data)
    local s = guard(src, true)
    if not s then return fail() end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'mlist', 150) then return fail('busy') end
    local acc = Mail.account(s.phoneId)
    if not acc then return fail('no_account') end
    local list, more = Mail.list(acc.id, data.folder, data.before)
    if not list then return fail(more) end
    return { ok = true, messages = list, more = more, counts = Mail.counts(acc.id) }
end)

lib.callback.register('vr-phone:mail:get', function(src, id)
    local s = guard(src, true)
    if not s then return fail() end
    if tooFast(src, 'mget', 100) then return fail('busy') end
    local acc = Mail.account(s.phoneId)
    if not acc then return fail('no_account') end
    local m = Mail.get(acc.id, id)
    if not m then return fail('not_found') end
    return { ok = true, message = m, counts = Mail.counts(acc.id) }
end)

-- One minute is long enough for the send limit to run out.
local sent = {}
lib.callback.register('vr-phone:mail:send', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'msend', 800) then return fail('busy') end
    local acc = Mail.account(s.phoneId)
    if not acc then return fail('no_account') end

    local now, per = os.time(), (Config.Phone.Mail and Config.Phone.Mail.perMinute) or 6
    local log = sent[s.phoneId] or {}
    local keep = {}
    for _, t in ipairs(log) do if now - t < 60 then keep[#keep + 1] = t end end
    if #keep >= per then sent[s.phoneId] = keep return fail('rate') end

    local ok, why = Mail.send(acc, data.to, data.subject, data.body)
    if not ok then sent[s.phoneId] = keep return fail(why) end
    keep[#keep + 1] = now
    sent[s.phoneId] = keep
    return { ok = true, counts = Mail.counts(acc.id) }
end)

lib.callback.register('vr-phone:mail:edit', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'medit', 200) then return fail('busy') end
    local acc = Mail.account(s.phoneId)
    if not acc then return fail('no_account') end
    local a, ids, n = data.action, data.ids, 0
    if a == 'read' then n = Mail.mark(acc.id, ids, { read = data.on == true })
    elseif a == 'star' then n = Mail.mark(acc.id, ids, { starred = data.on == true })
    elseif a == 'trash' then n = Mail.trash(acc.id, ids)
    elseif a == 'restore' then n = Mail.restore(acc.id, ids)
    elseif a == 'erase' then n = Mail.erase(acc.id, ids)
    elseif a == 'empty' then n = Mail.emptyTrash(acc.id)
    else return fail('invalid') end
    return { ok = true, changed = n, counts = Mail.counts(acc.id) }
end)

-- ---------------------------------------------------------------- wallet

lib.callback.register('vr-phone:wallet:overview', function(src)
    local s = guard(src, true)
    if not s then return fail() end
    if tooFast(src, 'wover', 300) then return fail('busy') end
    return { ok = true, wallet = Wallet.overview(src, s) }
end)

lib.callback.register('vr-phone:wallet:send', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'wsend', (Config.Phone.Wallet.cooldownSeconds or 3) * 1000) then return fail('busy') end
    return Wallet.send(src, s, data)
end)

lib.callback.register('vr-phone:wallet:request', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'wreq', 1500) then return fail('busy') end
    return Wallet.request(s, data)
end)

lib.callback.register('vr-phone:wallet:respond', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'wresp', (Config.Phone.Wallet.cooldownSeconds or 3) * 1000) then return fail('busy') end
    return Wallet.respond(src, s, data)
end)

lib.callback.register('vr-phone:wallet:cancel', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'wcan', 300) then return fail('busy') end
    return { ok = Wallet.cancel(s, id) }
end)

-- ---------------------------------------------------------------- maps

lib.callback.register('vr-phone:maps:state', function(src)
    local s = guard(src, true)
    if not s then return fail() end
    if tooFast(src, 'mstate', 300) then return fail('busy') end
    return { ok = true, catalog = Places.catalog(), saved = Places.list(s.phoneId) }
end)

lib.callback.register('vr-phone:maps:save', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'msave', 400) then return fail('busy') end
    local place, why = Places.save(s.phoneId, data)
    if not place then return fail(why) end
    return { ok = true, place = place }
end)

lib.callback.register('vr-phone:maps:remove', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'mrem', 200) then return fail('busy') end
    return { ok = Places.remove(s.phoneId, id) }
end)

-- ---------------------------------------------------------------- health

lib.callback.register('vr-phone:health:overview', function(src)
    local s = guard(src, true)
    if not s then return fail() end
    if tooFast(src, 'hover', 500) then return fail('busy') end
    return { ok = true, health = Health.overview(s) }
end)

-- The game reports how far the player walked. Needs only a phone that is switched on (it counts with the phone in the pocket).
RegisterNetEvent('vr-phone:server:health', function(data)
    local src = source
    if tooFast(src, 'hrep', 4000) then return end
    local s = guard(src, false)
    if not s then return end
    Health.report(s, data)
end)
