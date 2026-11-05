-- The screen's way into Veil and Hearth. Same rules as comms.lua: Phone.guard (the phone is in the player's hands and unlocked)
-- and Phone.tooFast on everything that changes something. Both apps need signal (Config.Phone.Veil/Hearth.needService).
local Veil, Hearth = Phone.Veil, Phone.Hearth
local guard, tooFast = Phone.guard, Phone.tooFast

local function fail(reason, extra)
    local r = { ok = false, reason = reason }
    if extra then r.wait = extra end
    return r
end

-- Opens a callback for an app: checks the phone and the signal, then runs fn(src, s, data).
local function open(name, app, fn, ms, key)
    lib.callback.register(name, function(src, data)
        local s, reason = guard(src, true)
        if not s then return fail(reason) end
        local cfg = Config.Phone[app] or {}
        if cfg.needService ~= false and not Phone.Status.canReceive(s) then return fail('no_service') end
        if ms and tooFast(src, key or name, ms) then return fail('busy') end
        if type(data) ~= 'table' then data = {} end
        return fn(src, s, data)
    end)
end

-- ---------------------------------------------------------------- Veil

-- Everything the app shows when it opens. Without an alias there is nothing else to show yet.
local function veilState(s)
    local alias = Veil.alias(s.phoneId)
    if not alias then
        return { ok = true, alias = false, rules = { min = Config.Phone.Veil.aliasMin or 3, max = Config.Phone.Veil.aliasMax or 16 } }
    end
    local rooms, discover = Veil.rooms(s.phoneId)
    return {
        ok = true, alias = alias, rooms = rooms, discover = discover, dms = Veil.dms(s.phoneId), blocks = Veil.blocks(s.phoneId),
        maxMessage = Config.Phone.Veil.maxMessage or 300,
    }
end

open('vr-phone:veil:state', 'Veil', function(_, s) return veilState(s) end, 300)

open('vr-phone:veil:alias', 'Veil', function(_, s, d)
    local alias, why, wait = Veil.setAlias(s.phoneId, d.alias)
    if not alias then return fail(why, wait) end
    return { ok = true, alias = alias }
end, 800)

open('vr-phone:veil:join', 'Veil', function(_, s, d)
    local ref = d.id ~= nil and tonumber(d.id) or d.name
    local id, why = Veil.join(s.phoneId, ref, d.pass)
    if not id then return fail(why) end
    return veilState(s)
end, 800)

open('vr-phone:veil:leave', 'Veil', function(_, s, d)
    Veil.leave(s.phoneId, d.id)
    return veilState(s)
end, 500)

open('vr-phone:veil:create', 'Veil', function(_, s, d)
    if not Veil.alias(s.phoneId) then return fail('no_alias') end
    local id, why = Veil.create(s.phoneId, d.name, d.topic, d.pass)
    if not id then return fail(why) end
    local st = veilState(s)
    st.room = id
    return st
end, 1500)

open('vr-phone:veil:history', 'Veil', function(_, s, d)
    local list, more = Veil.history(s.phoneId, d.id, d.before)
    if not list then return fail(more or 'failed') end
    if not d.before then Veil.readRoom(s.phoneId, d.id) end
    return { ok = true, messages = list, more = more == true }
end, 250, 'veilhist')

open('vr-phone:veil:say', 'Veil', function(_, s, d)
    local alias = Veil.alias(s.phoneId)
    if not alias then return fail('no_alias') end
    local m, why = Veil.say(s.phoneId, alias, d.id, d.body)
    if not m then return fail(why) end
    return { ok = true, message = m }
end, 600, 'veilsay')

open('vr-phone:veil:read', 'Veil', function(_, s, d)
    if d.alias then Veil.readDm(s.phoneId, d.alias) else Veil.readRoom(s.phoneId, d.id) end
    return { ok = true }
end, 150, 'veilread')

open('vr-phone:veil:thread', 'Veil', function(_, s, d)
    local list, more = Veil.thread(s.phoneId, d.alias, d.before)
    if not list then return fail(more or 'failed') end
    if not d.before then Veil.readDm(s.phoneId, d.alias) end
    return { ok = true, messages = list, more = more == true }
end, 250, 'veilthread')

open('vr-phone:veil:dm', 'Veil', function(_, s, d)
    local alias = Veil.alias(s.phoneId)
    if not alias then return fail('no_alias') end
    local m, why = Veil.dm(s.phoneId, alias, d.alias, d.body)
    if not m then return fail(why) end
    return { ok = true, message = m }
end, 600, 'veilsay')

open('vr-phone:veil:block', 'Veil', function(_, s, d)
    local ok, why = Veil.block(s.phoneId, d.alias)
    if not ok then return fail(why) end
    return { ok = true, blocks = Veil.blocks(s.phoneId) }
end, 500)

open('vr-phone:veil:unblock', 'Veil', function(_, s, d)
    local ok, why = Veil.unblock(s.phoneId, d.alias)
    if not ok then return fail(why) end
    return { ok = true, blocks = Veil.blocks(s.phoneId) }
end, 500)

-- ---------------------------------------------------------------- Hearth

local function hearthState(src, s)
    local p = Hearth.profile(s.phoneId)
    if not p then return { ok = true, profile = false, suggest = Hearth.suggest(src) } end
    Hearth.touch(s.phoneId)
    local cfg = Config.Phone.Hearth
    return {
        ok = true, profile = p, matches = Hearth.matches(s.phoneId), tags = cfg.tags or {},
        limits = { bio = cfg.bioMax or 240, name = cfg.nameMax or 20, tags = cfg.maxTags or 5, photos = cfg.maxPhotos or 3, message = cfg.maxMessage or 300 },
    }
end

open('vr-phone:hearth:state', 'Hearth', function(src, s) return hearthState(src, s) end, 300)

open('vr-phone:hearth:create', 'Hearth', function(src, s, d)
    local p, why = Hearth.create(src, s.phoneId, d)
    if not p then return fail(why) end
    return hearthState(src, s)
end, 1500)

open('vr-phone:hearth:update', 'Hearth', function(src, s, d)
    local p, why = Hearth.update(s.phoneId, d)
    if not p then return fail(why) end
    return hearthState(src, s)
end, 800)

open('vr-phone:hearth:remove', 'Hearth', function(src, s)
    Hearth.remove(s.phoneId)
    return hearthState(src, s)
end, 1500)

open('vr-phone:hearth:deck', 'Hearth', function(_, s)
    local deck, left = Hearth.deck(s.phoneId)
    if not deck then return fail(left) end
    return { ok = true, deck = deck, left = left }
end, 400)

open('vr-phone:hearth:swipe', 'Hearth', function(_, s, d)
    local r, why = Hearth.swipe(s.phoneId, d.id, d.like == true)
    if not r then return fail(why) end
    return { ok = true, matched = r.matched, match = r.match, left = r.left }
end, 200)

open('vr-phone:hearth:photo', 'Hearth', function(_, s, d)
    local image = Hearth.photo(s.phoneId, d.id, d.index)
    if not image then return fail('not_found') end
    return { ok = true, image = image }
end, 100, 'hearthphoto')

open('vr-phone:hearth:matches', 'Hearth', function(_, s)
    local list, why = Hearth.matches(s.phoneId)
    if not list then return fail(why) end
    return { ok = true, matches = list }
end, 300)

open('vr-phone:hearth:thread', 'Hearth', function(_, s, d)
    local list, more = Hearth.thread(s.phoneId, d.id, d.before)
    if not list then return fail(more or 'failed') end
    if not d.before then Hearth.read(s.phoneId, d.id) end
    return { ok = true, messages = list, more = more == true }
end, 250, 'hearththread')

open('vr-phone:hearth:say', 'Hearth', function(_, s, d)
    local m, why = Hearth.say(s.phoneId, d.id, d.body)
    if not m then return fail(why) end
    return { ok = true, message = m }
end, 600, 'hearthsay')

open('vr-phone:hearth:read', 'Hearth', function(_, s, d)
    Hearth.read(s.phoneId, d.id)
    return { ok = true }
end, 150, 'hearthread')

open('vr-phone:hearth:unmatch', 'Hearth', function(_, s, d)
    local ok, why = Hearth.unmatch(s.phoneId, d.id)
    if not ok then return fail(why) end
    return { ok = true }
end, 500)
