-- The screen's way into Music. Same rules as comms.lua: every callback checks the phone is still in the player's hands.
local Music = Phone.Music
local guard, tooFast = Phone.guard, Phone.tooFast

local function fail(reason) return { ok = false, reason = reason } end

-- Starting a song and adding one need signal (it is streamed). Pausing and the like do not.
local function needService(s)
    local cfg = Config.Phone.Music or {}
    if cfg.needService == false then return true end
    return Phone.Status.canReceive(s)
end

local function stateFor(src, s)
    if not s.settings then s.settings = Phone.Settings.get(s.phoneId) end
    return {
        ok = true,
        library = Music.library(s.phoneId),
        now = Music.view(src),
        prefs = s.settings.music,
    }
end

lib.callback.register('vr-phone:music:state', function(src)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'mstate', 300) then return fail('busy') end
    return stateFor(src, s)
end)

lib.callback.register('vr-phone:music:add', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'madd', 1200) then return fail('busy') end
    if not needService(s) then return fail('no_service') end
    local t, why, existed = Music.add(s.phoneId, data.link)
    if not t then return fail(why or 'failed') end
    if data.play == true then
        local ok, e = Music.play(src, s, t.id)
        if not ok then return fail(e) end
    end
    return { ok = true, track = t, existed = existed == true }
end)

lib.callback.register('vr-phone:music:remove', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'mrem', 200) then return fail('busy') end
    return { ok = Music.remove(s.phoneId, id) }
end)

lib.callback.register('vr-phone:music:play', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'mplay', 400) then return fail('busy') end
    if not needService(s) then return fail('no_service') end
    local ok, why = Music.play(src, s, data.id, data.all == true, data.shuffle == true)
    if not ok then return fail(why) end
    return { ok = true, now = Music.view(src) }
end)

lib.callback.register('vr-phone:music:queue', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' then return fail('invalid') end
    if tooFast(src, 'mqueue', 250) then return fail('busy') end
    if data.remove then
        if not Music.unqueue(src, data.remove) then return fail('not_found') end
    else
        if not needService(s) then return fail('no_service') end
        local ok, why = Music.queue(src, s, data.id)
        if not ok then return fail(why) end
    end
    return { ok = true, now = Music.view(src) }
end)

lib.callback.register('vr-phone:music:control', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(data) ~= 'table' or type(data.action) ~= 'string' then return fail('invalid') end
    if tooFast(src, 'mctl', 150) then return fail('busy') end
    local ok, why = Music.control(src, s, data.action, data.value)
    if not ok then return fail(why) end
    return { ok = true, now = Music.view(src) }
end)

lib.callback.register('vr-phone:music:setup', function(src, data)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'msetup', 120) then return fail('busy') end
    local p = Music.setup(src, s, data)
    if not p then return fail('invalid') end
    return { ok = true, prefs = p, now = Music.view(src) }
end)

-- From the player's own game while a song plays: it ended, its length, or YouTube refused it. These only need the phone switched on.
lib.callback.register('vr-phone:music:report', function(src, data)
    local s = guard(src, false)
    if not s or type(data) ~= 'table' or type(data.vid) ~= 'string' then return { ok = false } end
    if data.kind == 'ended' then return { ok = Music.ended(src, s, data.vid) } end
    if data.kind == 'duration' then return { ok = Music.duration(src, s, data.vid, data.seconds) } end
    if data.kind == 'failed' then
        if tooFast(src, 'mfail', 500) then return { ok = false } end
        return { ok = Music.failed(src, s, data.vid, data.code) }
    end
    return { ok = false }
end)

-- A game that just loaded in (or came back) asks what is playing around it and how this player wants to listen.
lib.callback.register('vr-phone:music:sync', function(src)
    local s = guard(src, false)
    local hear = true
    if s then
        if not s.settings then s.settings = Phone.Settings.get(s.phoneId) end
        hear = (s.settings.music or {}).hear ~= false
    end
    if tooFast(src, 'msync', 2000) then return { ok = false } end
    return {
        ok = true,
        speakers = Music.snapshot(src),
        hear = hear,
        player = (Config.Phone.Music or {}).player or 'auto',
        webBase = GetConvar('web_baseUrl', ''),
        maxPlayers = (Config.Phone.Music or {}).maxPlayers or 3,
    }
end)

-- The player page: a small web page that holds YouTube's embedded player. The phone's screen puts it in a hidden frame.
-- YouTube refuses to play for a page that has no web address, so this is served from the server's own address.
SetHttpHandler(function(req, res)
    if req.path ~= '/player' and req.path ~= '/player.html' then
        res.writeHead(404)
        return res.send('')
    end
    local page = LoadResourceFile(GetCurrentResourceName(), 'html/player.html')
    if not page then
        res.writeHead(404)
        return res.send('')
    end
    res.writeHead(200, { ['Content-Type'] = 'text/html; charset=utf-8', ['Cache-Control'] = 'no-store', ['Referrer-Policy'] = 'strict-origin-when-cross-origin' })
    res.send(page)
end)
