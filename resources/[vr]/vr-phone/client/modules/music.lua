-- Music, the game's side. The server says which phones are playing what; this works out how loud each one is for this player
-- (louder the closer they stand) and hands the result to the phone's web page, which plays it through YouTube's embedded player.
local Music = {}
Phone.Music = Music

local cfg = Config.Phone.Music or {}
local speakers = {}      -- server id -> what the server last said about that phone
local hear = true        -- this player wants to hear other people's phones
local maxPlayers = cfg.maxPlayers or 3
local mode = cfg.player or 'auto'
local webBase = ''
local lastKey = ''

local function loggedIn()
    if Bridge.framework == 'none' then return true end
    return Bridge.playerData() ~= nil
end

-- Where the YouTube player page comes from (see Config.Phone.Music.player).
local function playerUrl()
    if mode == 'nui' then return './player.html' end
    if type(mode) == 'string' and mode:match('^https?://') then return mode end
    local resource = GetCurrentResourceName()
    if webBase ~= '' then return ('https://%s/%s/player'):format(webBase, resource) end
    local endpoint = GetCurrentServerEndpoint()
    if endpoint and endpoint ~= '' then return ('http://%s/%s/player'):format(endpoint, resource) end
    return './player.html'
end

RegisterNetEvent('vr-phone:music:speaker', function(data)
    if type(data) ~= 'table' or type(data.id) ~= 'number' then return end
    if data.stop then
        speakers[data.id] = nil
        return
    end
    if type(data.vid) ~= 'string' then return end
    data.at = GetGameTimer()
    speakers[data.id] = data
end)

-- What this phone's owner sees in the app (queue moves, a song ends).
RegisterNetEvent('vr-phone:client:musicNow', function(now, reason)
    SendNUIMessage({ action = 'musicNow', data = { now = now, reason = reason } })
end)

RegisterNetEvent('vr-phone:client:musicError', function(code, title)
    SendNUIMessage({ action = 'musicError', data = { code = code, title = title } })
end)

local function sync()
    local r = lib.callback.await('vr-phone:music:sync', false)
    if type(r) ~= 'table' or not r.ok then return end
    hear = r.hear ~= false
    mode = r.player or mode
    maxPlayers = r.maxPlayers or maxPlayers
    webBase = type(r.webBase) == 'string' and r.webBase:gsub('^https?://', ''):gsub('/+$', '') or ''
    local fresh = {}
    for _, d in ipairs(r.speakers or {}) do
        if type(d) == 'table' and type(d.id) == 'number' and type(d.vid) == 'string' then
            d.at = GetGameTimer()
            fresh[d.id] = d
        end
    end
    speakers = fresh
end

CreateThread(function()
    while not loggedIn() do Wait(2000) end
    Wait(2500)
    while true do
        sync()
        Wait(45000)
    end
end)

-- Works out how loud everything is, four times a second.
CreateThread(function()
    local me = GetPlayerServerId(PlayerId())
    while true do
        Wait(250)
        local mix, key = {}, {}
        if loggedIn() and next(speakers) then
            local here = GetEntityCoords(PlayerPedId())
            for id, sp in pairs(speakers) do
                local volume, distance
                if id == me then
                    volume, distance = sp.volume, 0.0
                elseif hear and sp.speaker then
                    local player = GetPlayerFromServerId(id)
                    local ped = player ~= -1 and GetPlayerPed(player) or 0
                    if ped ~= 0 and DoesEntityExist(ped) then
                        distance = #(here - GetEntityCoords(ped))
                        volume = Phone.speakerVolume(sp.volume, distance, sp.range)
                    end
                end
                if volume and volume >= 1 then
                    mix[#mix + 1] = {
                        id = id, vid = sp.vid, rev = sp.rev, paused = sp.paused, vol = math.floor(volume + 0.5), d = distance or 0.0,
                        -- Where the song is up to right now (the page only uses it when the song or the position changed).
                        pos = sp.paused and sp.pos or sp.pos + (GetGameTimer() - sp.at) / 1000,
                    }
                end
            end
            table.sort(mix, function(a, b) return a.d < b.d end)
            for i = #mix, maxPlayers + 1, -1 do mix[i] = nil end
        end
        for _, m in ipairs(mix) do key[#key + 1] = ('%d:%s:%s:%s:%d'):format(m.id, m.vid, tostring(m.rev), tostring(m.paused), m.vol) end
        local joined = table.concat(key, ',')
        if joined ~= lastKey then
            lastKey = joined
            SendNUIMessage({ action = 'musicMix', data = { mix = mix, own = me, url = playerUrl() } })
        end
    end
end)

-- The screen changed whether this player hears other people's phones.
function Music.setHear(on)
    hear = on ~= false
end
