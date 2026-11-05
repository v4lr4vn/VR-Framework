local trackSeq = 0

local function newTrack(url, kind, title, by)
    trackSeq = trackSeq + 1
    return { id = trackSeq, url = url, kind = kind, title = title, placeholder = true, duration = nil, by = by }
end

local function copyTrack(t)
    local c = newTrack(t.url, t.kind, t.title, t.by)
    c.placeholder, c.duration = t.placeholder, t.duration
    return c
end

local function changed(sys)
    PushSystem(sys)
    PushPanel(sys)
end

function StartTrack(sys, track)
    sys.now = { track = track, startedAt = GetGameTimer(), pausedAt = nil }
    Debug('%s plays %s', sys.id, track.url)
    changed(sys)
end

function NextTrack(sys, reason)
    local finished = sys.now and sys.now.track
    if finished then
        if reason == 'ended' and sys.loop == 'one' then return StartTrack(sys, copyTrack(finished)) end
        if sys.loop == 'all' and reason ~= 'error' and #sys.queue < Config.Limits.queueLength then
            sys.queue[#sys.queue + 1] = copyTrack(finished)
        end
    end
    if #sys.queue == 0 then
        sys.now = nil
        return changed(sys)
    end
    local index = sys.shuffle and math.random(#sys.queue) or 1
    StartTrack(sys, table.remove(sys.queue, index))
end

function StopPlayback(sys)
    sys.now = nil
    changed(sys)
end

local function findQueued(sys, trackId)
    trackId = tonumber(trackId)
    for i, t in ipairs(sys.queue) do
        if t.id == trackId then return i, t end
    end
end

local function playerName(src)
    local Player = GetPlayer(src)
    local c = Player
    if c and c.firstname then return (('%s %s'):format(c.firstname, c.lastname or ''):gsub('%s+$', '')) end
    return GetPlayerName(src) or 'Someone'
end

Actions = {}

function Actions.add(src, sys, data)
    if TooFast(src, 'add', 800) then return false, 'slow_down' end
    if #sys.queue >= Config.Limits.queueLength then return false, 'queue_full' end
    local url, kind, title = DJ.parseLink(data.url)
    if not url then return false, kind end
    local track = newTrack(url, kind, title, playerName(src))
    if data.next then table.insert(sys.queue, 1, track) else sys.queue[#sys.queue + 1] = track end
    if sys.now then PushPanel(sys) else NextTrack(sys, 'skip') end
    return true
end

function Actions.remove(_, sys, data)
    local i = findQueued(sys, data.trackId)
    if not i then return false, 'gone' end
    table.remove(sys.queue, i)
    PushPanel(sys)
    return true
end

function Actions.move(_, sys, data)
    local i, t = findQueued(sys, data.trackId)
    if not i then return false, 'gone' end
    local to = data.to == 'top' and 1 or i + (tonumber(data.dir) == -1 and -1 or 1)
    if to < 1 or to > #sys.queue then return true end
    table.remove(sys.queue, i)
    table.insert(sys.queue, to, t)
    PushPanel(sys)
    return true
end

function Actions.playNow(_, sys, data)
    local i, t = findQueued(sys, data.trackId)
    if not i then return false, 'gone' end
    table.remove(sys.queue, i)
    StartTrack(sys, t)
    return true
end

function Actions.skip(src, sys)
    if TooFast(src, 'skip', 500) then return false, 'slow_down' end
    if not sys.now and #sys.queue == 0 then return false, 'nothing_playing' end
    NextTrack(sys, 'skip')
    return true
end

function Actions.play(_, sys)
    if sys.now then
        if sys.now.pausedAt then
            sys.now.startedAt = sys.now.startedAt + (GetGameTimer() - sys.now.pausedAt)
            sys.now.pausedAt = nil
            changed(sys)
        end
        return true
    end
    if #sys.queue == 0 then return false, 'queue_empty' end
    NextTrack(sys, 'skip')
    return true
end

function Actions.pause(_, sys)
    if not sys.now then return false, 'nothing_playing' end
    if not sys.now.pausedAt then
        sys.now.pausedAt = GetGameTimer()
        changed(sys)
    end
    return true
end

function Actions.stop(_, sys)
    if not sys.now then return true end
    StopPlayback(sys)
    return true
end

function Actions.clear(_, sys)
    sys.queue = {}
    PushPanel(sys)
    return true
end

function Actions.seek(src, sys, data)
    if TooFast(src, 'seek', 300) then return false, 'slow_down' end
    local now = sys.now
    local t = DJ.num(data.time)
    if not now or not t then return false, 'nothing_playing' end
    local d = now.track.duration
    if not d or d <= 0 then return false, 'cant_seek' end
    t = DJ.clamp(t, 0, d - 1)
    local clock = now.pausedAt or GetGameTimer()
    now.startedAt = clock - math.floor(t * 1000)
    changed(sys)
    return true
end

function Actions.volume(src, sys, data)
    if TooFast(src, 'volume', 200) then return false, 'slow_down' end
    local v = DJ.num(data.value)
    if not v then return false, 'bad_value' end
    sys.volume = DJ.clamp(math.floor(v * 100 + 0.5) / 100, 0, 1)
    sys.settingsDirty = GetGameTimer()
    changed(sys)
    return true
end

function Actions.range(src, sys, data)
    if TooFast(src, 'range', 200) then return false, 'slow_down' end
    if data.reset == true then
        sys.range = nil
    else
        local r = ValidRange(data.value)
        if not r then return false, 'bad_value' end
        sys.range = r
    end
    sys.settingsDirty = GetGameTimer()
    changed(sys)
    return true
end

local function saveSettings(sys)
    if sys.kind == 'speakers' then
        MySQL.update('UPDATE `vr_djbooth_systems` SET `volume` = ?, `range_m` = ? WHERE `id` = ?', { sys.volume, sys.range, tonumber(sys.id:sub(2)) })
    elseif sys.kind == 'boombox' then
        MySQL.update('UPDATE `vr_djbooth_boomboxes` SET `volume` = ?, `range_m` = ? WHERE `citizenid` = ?', { sys.volume, sys.range, sys.ownerCid })
    end
end

CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for _, sys in pairs(Systems) do
            if sys.settingsDirty and now - sys.settingsDirty >= 1500 then
                sys.settingsDirty = nil
                saveSettings(sys)
            end
        end
    end
end)

function Actions.loop(_, sys, data)
    local mode = data.mode
    if mode ~= 'off' and mode ~= 'all' and mode ~= 'one' then return false, 'bad_value' end
    sys.loop = mode
    PushPanel(sys)
    return true
end

function Actions.shuffle(_, sys, data)
    sys.shuffle = data.on == true
    PushPanel(sys)
    return true
end

function Actions.rename(_, sys, data)
    if sys.kind ~= 'speakers' then return false, 'not_allowed' end
    local name = DJ.cleanText(data.name, 32)
    if not name then return false, 'bad_name' end
    sys.name = name
    MySQL.update('UPDATE `vr_djbooth_systems` SET `name` = ? WHERE `id` = ?', { name, tonumber(sys.id:sub(2)) })
    changed(sys)
    return true
end

lib.callback.register('vr-djbooth:action', function(src, systemId, action, data)
    if type(systemId) ~= 'string' or type(action) ~= 'string' then return false, 'bad_request' end
    local fn = Actions[action]
    local sys = Systems[systemId]
    if not fn or not sys then return false, 'gone' end
    if TooFast(src, 'action', 120) then return false, 'slow_down' end
    local ok, reason = CanControl(src, sys)
    if not ok then return false, reason end
    if type(data) ~= 'table' then data = {} end
    return fn(src, sys, data)
end)

local function hearing(src, sys)
    return DistanceTo(src, sys) <= SystemRadius(sys) + 15.0
end

local function currentTrack(systemId, trackId)
    local sys = type(systemId) == 'string' and Systems[systemId]
    local now = sys and sys.now
    if not now or now.track.id ~= tonumber(trackId) then return nil end
    return sys, now.track
end

local function trusted(src, sys, track, kind, value, same)
    if CanControl(src, sys) then return true end
    track.votes = track.votes or {}
    local votes = track.votes[kind]
    if not votes then votes = {}; track.votes[kind] = votes end
    votes[src] = value == nil and true or value
    for other, v in pairs(votes) do
        if other ~= src and (not same or same(v, votes[src])) then return true end
    end
    return false
end

local function sameDuration(a, b) return a == b or (a > 0 and b > 0 and math.abs(a - b) <= 2) end

local function applyInfo(src, item)
    if type(item) ~= 'table' then return end
    local sys, track = currentTrack(item.system, item.trackId)
    if not sys or not hearing(src, sys) then return end
    local touched = false
    if track.placeholder then
        local clean = DJ.cleanText(item.title, 100)
        if clean and trusted(src, sys, track, 'title', clean, function(a, b) return a == b end) then
            track.title, track.placeholder, touched = clean, false, true
        end
    end
    if not track.duration then
        local d = DJ.num(item.duration)
        if d and d ~= -1 then
            d = math.floor(d * 10) / 10
            if d < 1 or d > 6 * 3600 or d < Elapsed(sys) - 2 then d = nil end
        end
        if d and trusted(src, sys, track, 'duration', d, sameDuration) then
            track.duration, touched = d, true
        end
    end
    if touched then changed(sys) end
end

RegisterNetEvent('vr-djbooth:server:trackInfo', function(list)
    local src = source
    if type(list) ~= 'table' or TooFast(src, 'info', 1000) then return end
    for i = 1, math.min(#list, 8) do applyInfo(src, list[i]) end
end)

RegisterNetEvent('vr-djbooth:server:trackEnded', function(systemId, trackId)
    local src = source
    if TooFast(src, 'ended', 1000) then return end
    local sys, track = currentTrack(systemId, trackId)
    if not sys or sys.now.pausedAt or not hearing(src, sys) then return end
    local d = track.duration
    if d == -1 or (d and d > 0 and Elapsed(sys) < d - 8) then return end
    if not trusted(src, sys, track, 'ended') then return end
    NextTrack(sys, 'ended')
end)

RegisterNetEvent('vr-djbooth:server:trackError', function(systemId, trackId, code)
    local src = source
    if TooFast(src, 'error', 1000) then return end
    local sys, track = currentTrack(systemId, trackId)
    if not sys or not hearing(src, sys) then return end
    if Elapsed(sys) > 25 then return end
    if not trusted(src, sys, track, 'error') then return end
    Debug('%s could not play %s (%s)', sys.id, track.url, tostring(code))
    for viewer in pairs(Viewers[sys.id] or {}) do
        TriggerClientEvent('vr-djbooth:client:toast', viewer, 'error', ("Couldn't play \"%s\""):format(track.title))
    end
    NextTrack(sys, 'error')
end)

CreateThread(function()
    while true do
        Wait(1000)
        for _, sys in pairs(Systems) do
            local now = sys.now
            if now and not now.pausedAt then
                local d = now.track.duration
                if d and d > 0 and Elapsed(sys) >= d + 1.5 then NextTrack(sys, 'ended') end
            end
        end
    end
end)
