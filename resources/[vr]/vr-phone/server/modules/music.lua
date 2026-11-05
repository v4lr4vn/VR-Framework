-- Music. A phone plays one YouTube video at a time, with a queue. The server keeps what is playing and where it is up to,
-- and tells every player's game, which plays it (louder when close) through YouTube's own embedded player.
-- Nothing is downloaded or stored here: only the video id, the title and the length of the songs a player saved.
local Session = Phone.Session
local Settings = Phone.Settings
local Status = Phone.Status

local Music = {}
Phone.Music = Music

local cfg = Config.Phone.Music or {}

local playing = {}  -- src -> { track, queue, history, pos, since, paused, rev, volume, range, speaker }
local adding = {}   -- phone id -> true while a link is being looked up
local oembed = {}   -- video id -> { title, author, at }
local revision = 0

local MAX_SECONDS = 43200 -- a 12 hour video is the longest a song can be

-- ---------------------------------------------------------------- links

-- The 11 character video id inside a YouTube link, or nil when the text is not a link to one video.
function Music.videoId(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' or #text > 300 then return nil end
    local function ok(id) return id and #id == 11 and id:match('^[%w_-]+$') and id or nil end
    if text:match('^[%w_-]+$') then return ok(text) end

    local host, path = text:match('^[Hh][Tt][Tt][Pp][Ss]?://([^/%?#]+)([^#]*)')
    if not host then return nil end
    host = host:lower():gsub(':%d+$', '')
    host = host:gsub('^www%.', ''):gsub('^m%.', ''):gsub('^music%.', '')
    if host == 'youtu.be' then return ok(path:match('^/([%w_-]+)')) end
    if host == 'youtube.com' or host == 'youtube-nocookie.com' then
        local query = path:match('^/watch/?%?(.*)$')
        if query then return ok(('&' .. query):match('&v=([%w_-]+)')) end
        return ok(path:match('^/shorts/([%w_-]+)') or path:match('^/embed/([%w_-]+)') or path:match('^/live/([%w_-]+)') or path:match('^/v/([%w_-]+)'))
    end
    return nil
end

local function clean(text, max)
    if type(text) ~= 'string' then return '' end
    text = text:gsub('[%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #text > max then text = text:sub(1, max) end
    return text
end

-- Asks YouTube for the title and the channel name (the "oEmbed" page everyone may use). Returns { title, author },
-- or nil and a reason: 'not_found' (no such video), 'unavailable' (private, or the owner does not allow playing it on other pages).
-- When YouTube cannot be reached the song is still saved, with a plain title.
local function lookup(id)
    local hit = oembed[id]
    if hit and os.time() - hit.at < 3600 then return hit end
    local url = 'https://www.youtube.com/oembed?format=json&url=' .. 'https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3D' .. id
    local p = promise.new()
    PerformHttpRequest(url, function(status, body) p:resolve({ status = status, body = body }) end, 'GET', '', { ['User-Agent'] = 'vr-phone' })
    local r = Citizen.Await(p)
    if r.status == 200 and type(r.body) == 'string' then
        local ok, data = pcall(json.decode, r.body)
        if ok and type(data) == 'table' and type(data.title) == 'string' then
            local info = { title = clean(data.title, cfg.titleLength or 120), author = clean(data.author_name, 100), at = os.time() }
            oembed[id] = info
            return info
        end
    elseif r.status == 404 then
        return nil, 'not_found'
    elseif r.status == 401 or r.status == 403 then
        return nil, 'unavailable'
    end
    return { title = 'YouTube video', author = '', at = os.time() - 3300 } -- try again in 5 minutes
end

-- ---------------------------------------------------------------- the library

local function row(r)
    return { id = r.id, vid = r.video_id, title = r.title, author = r.author, seconds = r.seconds }
end

function Music.library(phoneId)
    local rows = MySQL.query.await('SELECT `id`, `video_id`, `title`, `author`, `seconds` FROM `vr_ph_music_tracks` WHERE `phone_id` = ? ORDER BY `id` DESC', { phoneId }) or {}
    local out = {}
    for i, r in ipairs(rows) do out[i] = row(r) end
    return out
end

local function track(phoneId, id)
    id = math.floor(tonumber(id) or 0)
    if id < 1 then return nil end
    local r = MySQL.single.await('SELECT `id`, `video_id`, `title`, `author`, `seconds` FROM `vr_ph_music_tracks` WHERE `id` = ? AND `phone_id` = ?', { id, phoneId })
    return r and row(r) or nil
end

-- Saves a song from a link. Returns the song, or nil and a reason.
function Music.add(phoneId, link)
    local vid = Music.videoId(link)
    if not vid then return nil, 'bad_link' end
    if adding[phoneId] then return nil, 'busy' end

    local have = MySQL.single.await('SELECT `id`, `video_id`, `title`, `author`, `seconds` FROM `vr_ph_music_tracks` WHERE `phone_id` = ? AND `video_id` = ?', { phoneId, vid })
    if have then return row(have), nil, true end
    local count = MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_music_tracks` WHERE `phone_id` = ?', { phoneId }) or 0
    if count >= (cfg.maxLibrary or 100) then return nil, 'library_full' end

    adding[phoneId] = true
    local info, why = lookup(vid)
    adding[phoneId] = nil
    if not info then return nil, why end

    MySQL.insert.await(
        'INSERT INTO `vr_ph_music_tracks` (`phone_id`, `video_id`, `title`, `author`, `created_at`) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE `title` = VALUES(`title`)',
        { phoneId, vid, info.title ~= '' and info.title or 'YouTube video', info.author or '', os.time() }
    )
    local saved = MySQL.single.await('SELECT `id`, `video_id`, `title`, `author`, `seconds` FROM `vr_ph_music_tracks` WHERE `phone_id` = ? AND `video_id` = ?', { phoneId, vid })
    return saved and row(saved) or nil, saved and nil or 'failed'
end

function Music.remove(phoneId, id)
    id = math.floor(tonumber(id) or 0)
    if id < 1 then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_music_tracks` WHERE `id` = ? AND `phone_id` = ?', { id, phoneId }) or 0) > 0
end

-- ---------------------------------------------------------------- what is playing

local function prefs(s)
    if not s.settings then s.settings = Settings.get(s.phoneId) end
    return s.settings.music or {}
end

local function position(st)
    if st.paused then return st.pos end
    return st.pos + (GetGameTimer() - st.since) / 1000
end

local function limit(st, pos)
    local top = st.track.seconds or MAX_SECONDS
    return math.max(0, math.min(top, pos))
end

-- What the owner's screen needs.
function Music.view(src)
    local st = playing[src]
    if not st then return nil end
    local queue = {}
    for i, t in ipairs(st.queue) do queue[i] = { id = t.id, vid = t.vid, title = t.title, author = t.author, seconds = t.seconds } end
    return {
        id = st.track.id, vid = st.track.vid, title = st.track.title, author = st.track.author, seconds = st.track.seconds,
        pos = position(st), paused = st.paused, speaker = st.speaker, volume = st.volume, range = st.range,
        queue = queue, rev = st.rev, canPrev = #st.history > 0,
    }
end

-- What every game needs to play it.
local function shared(src, st)
    return { id = src, vid = st.track.vid, pos = position(st), paused = st.paused, volume = st.volume, range = st.range, speaker = st.speaker, rev = st.rev }
end

-- Sends the state out. `moved` is true when the song or its position changed (so everyone's player must catch up).
local function announce(src, st, moved)
    if moved then
        revision = revision + 1
        st.rev = revision
    end
    if st.speaker then
        TriggerClientEvent('vr-phone:music:speaker', -1, shared(src, st))
    else
        TriggerClientEvent('vr-phone:music:speaker', -1, { id = src, stop = true })
        TriggerClientEvent('vr-phone:music:speaker', src, shared(src, st))
    end
    TriggerClientEvent('vr-phone:client:musicNow', src, Music.view(src))
end

function Music.stop(src, reason)
    local st = playing[src]
    if not st then return false end
    playing[src] = nil
    TriggerClientEvent('vr-phone:music:speaker', -1, { id = src, stop = true })
    TriggerClientEvent('vr-phone:client:musicNow', src, nil, reason)
    return true
end

local function begin(src, s, t, keep)
    local p = prefs(s)
    local st = keep or { queue = {}, history = {} }
    if keep and st.track then
        st.history[#st.history + 1] = st.track
        if #st.history > 20 then table.remove(st.history, 1) end
    end
    st.track = { id = t.id, vid = t.vid, title = t.title, author = t.author, seconds = t.seconds }
    st.pos, st.since, st.paused = 0, GetGameTimer(), false
    st.volume = math.floor(tonumber(p.volume) or cfg.volume or 60)
    st.range = tonumber(p.range) or cfg.range or 8.0
    st.speaker = p.speaker ~= false
    playing[src] = st
    announce(src, st, true)
    return st
end

-- Plays a saved song now. all: queue the rest of the library after it (shuffle: in a random order).
function Music.play(src, s, id, all, shuffle)
    local t = track(s.phoneId, id)
    if not t then return false, 'not_found' end
    local st = begin(src, s, t, playing[src])
    st.queue = {}
    if all then
        local rest = {}
        for _, other in ipairs(Music.library(s.phoneId)) do
            if other.id ~= t.id then rest[#rest + 1] = other end
        end
        if shuffle then
            for i = #rest, 2, -1 do
                local j = math.random(i)
                rest[i], rest[j] = rest[j], rest[i]
            end
        end
        for i = 1, math.min(#rest, (cfg.maxQueue or 30)) do st.queue[#st.queue + 1] = rest[i] end
    end
    announce(src, st, false)
    return true
end

function Music.queue(src, s, id)
    local st = playing[src]
    local t = track(s.phoneId, id)
    if not t then return false, 'not_found' end
    if not st then return Music.play(src, s, id) end
    if #st.queue >= (cfg.maxQueue or 30) then return false, 'queue_full' end
    st.queue[#st.queue + 1] = t
    announce(src, st, false)
    return true
end

function Music.unqueue(src, index)
    local st = playing[src]
    index = math.floor(tonumber(index) or 0)
    if not st or not st.queue[index] then return false end
    table.remove(st.queue, index)
    announce(src, st, false)
    return true
end

-- On to the next song, or the end of the music when nothing is queued.
function Music.advance(src, s)
    local st = playing[src]
    if not st then return false end
    local nxt = table.remove(st.queue, 1)
    if not nxt then return Music.stop(src, 'end') end
    begin(src, s, nxt, st)
    return true
end

function Music.previous(src, s)
    local st = playing[src]
    if not st then return false end
    if position(st) > 4 or #st.history == 0 then
        st.pos, st.since = 0, GetGameTimer()
        announce(src, st, true)
        return true
    end
    local back = table.remove(st.history)
    table.insert(st.queue, 1, st.track)
    -- begin() would put the song we are leaving into the history again, so do it by hand
    st.track = back
    st.pos, st.since, st.paused = 0, GetGameTimer(), false
    announce(src, st, true)
    return true
end

function Music.control(src, s, action, value)
    local st = playing[src]
    if not st then return false, 'nothing_playing' end
    if action == 'pause' then
        if not st.paused then
            st.pos = limit(st, position(st))
            st.paused = true
            announce(src, st, true)
        end
    elseif action == 'resume' then
        if st.paused then
            st.paused, st.since = false, GetGameTimer()
            announce(src, st, true)
        end
    elseif action == 'seek' then
        local to = tonumber(value)
        if not to or to ~= to then return false, 'invalid' end
        st.pos, st.since = limit(st, to), GetGameTimer()
        announce(src, st, true)
    elseif action == 'next' then
        Music.advance(src, s)
    elseif action == 'prev' then
        Music.previous(src, s)
    elseif action == 'stop' then
        Music.stop(src)
    else
        return false, 'invalid'
    end
    return true
end

-- Volume, speaker and range apply to what is playing now and are remembered for the next song.
function Music.setup(src, s, patch)
    if type(patch) ~= 'table' then return nil end
    local saved = Settings.save(s.phoneId, { music = {
        volume = patch.volume, speaker = patch.speaker, range = patch.range, hear = patch.hear,
    } })
    s.settings = saved
    local p = saved.music or {}
    local st = playing[src]
    if st then
        st.volume = math.floor(tonumber(p.volume) or st.volume)
        st.range = tonumber(p.range) or st.range
        st.speaker = p.speaker ~= false
        announce(src, st, false)
    end
    return p
end

-- The owner's game says the song reached its end.
function Music.ended(src, s, vid)
    local st = playing[src]
    if not st or st.track.vid ~= vid then return false end
    local pos = position(st)
    -- Not before the end (a wrong report from a game must not skip songs).
    if pos < 8 or (st.track.seconds and pos < st.track.seconds - 8) then return false end
    return Music.advance(src, s)
end

-- The owner's game found out how long the video is.
function Music.duration(src, s, vid, seconds)
    local st = playing[src]
    seconds = math.floor(tonumber(seconds) or 0)
    if not st or st.track.vid ~= vid or seconds < 1 or seconds > MAX_SECONDS then return false end
    if st.track.seconds then return false end
    st.track.seconds = seconds
    MySQL.update.await('UPDATE `vr_ph_music_tracks` SET `seconds` = ? WHERE `phone_id` = ? AND `video_id` = ? AND `seconds` IS NULL', { seconds, s.phoneId, vid })
    TriggerClientEvent('vr-phone:client:musicNow', src, Music.view(src))
    return true
end

-- The owner's game could not play the video (YouTube refused it). Move on and say why.
function Music.failed(src, s, vid, code)
    local st = playing[src]
    if not st or st.track.vid ~= vid then return false end
    code = clean(tostring(code or ''), 12)
    TriggerClientEvent('vr-phone:client:musicError', src, code, st.track.title)
    return Music.advance(src, s)
end

-- Everything a game needs to catch up when it joins or after the player was out of reach.
function Music.snapshot(src)
    local out = {}
    for id, st in pairs(playing) do
        if st.speaker and id ~= src then out[#out + 1] = shared(id, st) end
    end
    local mine = playing[src]
    if mine then out[#out + 1] = shared(src, mine) end
    return out
end

function Music.playing(src) return playing[src] ~= nil end

-- ---------------------------------------------------------------- keeping it honest

-- Once a song has run its length the owner's game normally says so. This is for when it does not (it closed, it lagged).
-- A dead phone, no service or a phone no longer in hand stops the music too.
CreateThread(function()
    while true do
        Wait(2000)
        for src, st in pairs(playing) do
            local s = Session.get(src)
            if not s then
                Music.stop(src)
            elseif st.track.seconds and not st.paused and position(st) >= st.track.seconds + 4 then
                Music.advance(src, s)
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        for src in pairs(playing) do
            local s = Session.get(src)
            if s then
                local dead = s.bat and not s.bat.powered
                local noService = cfg.needService ~= false and s.bat and s.settings and not Status.canReceive(s)
                if dead or noService then Music.stop(src, dead and 'no_power' or 'no_service') end
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    if playing[src] then
        playing[src] = nil
        TriggerClientEvent('vr-phone:music:speaker', -1, { id = src, stop = true })
    end
end)
