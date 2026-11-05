local VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })

local sessions = {}
local cooldowns = { yoga = {}, smoke = {} }

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src] = nil
    cooldowns.yoga[src], cooldowns.smoke[src] = nil, nil
end)

local function notify(src, msg, kind)
    TriggerClientEvent('VRCore:Notify', src, msg, kind or 'primary')
end

local function relieve(src, amount)
    local Player = VRCore.Functions.GetPlayer(src)
    if not Player then return false end
    local current = tonumber(Player.PlayerData.metadata['stress']) or 0
    local value = math.max(0, current - amount)
    Player.Functions.SetMetaData('stress', value)
    TriggerClientEvent('hud:client:UpdateStress', src, value)
    return true
end

exports('Relieve', function(src, amount)
    amount = tonumber(amount)
    if not amount or amount <= 0 then return false end
    return relieve(src, math.min(amount, 50))
end)

local function ready(kind, src, seconds)
    local at = cooldowns[kind][src]
    return not at or (GetGameTimer() - at) >= seconds * 1000
end

local function distanceTo(src, coords)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return math.huge end
    return #(GetEntityCoords(ped) - coords)
end

VRCore.Functions.CreateCallback('vr-wellness:yogaStart', function(src, cb, index)
    local spot = Config.Yoga.spots[tonumber(index) or 0]
    if not spot then return cb(false) end
    if sessions[src] then return cb(false, Config.Text.busy) end
    if not ready('yoga', src, Config.Yoga.cooldown) then return cb(false, Config.Text.tooSoon) end
    if distanceTo(src, spot.coords) > Config.Yoga.radius + 4.0 then return cb(false, Config.Text.tooFar) end
    sessions[src] = { kind = 'yoga', spot = spot, started = GetGameTimer() }
    cb(true)
end)

VRCore.Functions.CreateCallback('vr-wellness:yogaFinish', function(src, cb)
    local s = sessions[src]
    sessions[src] = nil
    if not s or s.kind ~= 'yoga' then return cb(false) end
    if GetGameTimer() - s.started < Config.Yoga.duration - 1500 then return cb(false) end
    if distanceTo(src, s.spot.coords) > Config.Yoga.radius + 6.0 then return cb(false, Config.Text.tooFar) end
    cooldowns.yoga[src] = GetGameTimer()
    relieve(src, Config.Yoga.relief)
    cb(true, Config.Text.relaxed)
end)

VRCore.Functions.CreateUseableItem(Config.Smoking.item, function(src)
    if sessions[src] then return notify(src, Config.Text.busy, 'error') end
    if not ready('smoke', src, Config.Smoking.cooldown) then return notify(src, Config.Text.tooSoon, 'error') end
    if Config.Smoking.needLighter then
        local n = exports['vr-inventory']:Search(src, 'count', Config.Smoking.lighter)
        if not n or n < 1 then return notify(src, Config.Text.noLighter, 'error') end
    end
    sessions[src] = { kind = 'smoke', started = GetGameTimer() }
    TriggerClientEvent('vr-wellness:client:smoke', src)
end)

VRCore.Functions.CreateCallback('vr-wellness:smokeFinish', function(src, cb)
    local s = sessions[src]
    sessions[src] = nil
    if not s or s.kind ~= 'smoke' then return cb(false) end
    if GetGameTimer() - s.started < Config.Smoking.duration - 1500 then return cb(false) end
    local removed = exports['vr-inventory']:RemoveItem(src, Config.Smoking.item, 1)
    if not removed then return cb(false) end
    cooldowns.smoke[src] = GetGameTimer()
    relieve(src, Config.Smoking.relief)
    cb(true, Config.Text.relaxed)
end)

RegisterNetEvent('vr-wellness:server:cancel', function()
    sessions[source] = nil
end)
