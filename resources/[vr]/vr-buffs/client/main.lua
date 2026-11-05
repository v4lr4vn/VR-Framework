-- Copy of this player's buffs, sent by the server. Effects run from this copy; nothing here can grant a buff.
local buffs = {}   -- [name] = { ends = <game timer ms>, value = n }

local function remaining(name)
    local b = buffs[name]
    if not b then return 0 end
    local r = b.ends - GetGameTimer()
    if r <= 0 then buffs[name] = nil return 0 end
    return r
end

RegisterNetEvent('vr-buffs:client:sync', function(list)
    if GetInvokingResource() then return end
    local fresh = {}
    if type(list) == 'table' then
        for name, b in pairs(list) do
            if Config.Buffs[name] and type(b) == 'table' and tonumber(b.left) then
                fresh[name] = { ends = GetGameTimer() + tonumber(b.left), value = tonumber(b.value) }
            end
        end
    end
    buffs = fresh
end)

Bridge.on('playerLoaded', function()
    TriggerServerEvent('vr-buffs:server:request')
end)

Bridge.on('playerUnloaded', function()
    buffs = {}
end)

exports('HasBuff', function(name) return remaining(name) > 0 end)

exports('GetBuff', function(name)
    local def = Config.Buffs[name]
    if not def then return nil end
    local r = remaining(name)
    if def.kind == 'icon' then
        return { time = r, buffName = name, iconName = def.icon, iconColor = def.color, progressColor = def.ring,
                 progressValue = r * 100 / def.maxTime, type = 'buff' }
    end
    return { time = r, iconColor = def.color, maxTime = def.maxTime, type = 'enhancement' }
end)

exports('GetBuffNUIData', function()
    local out, any = {}, false
    for name, def in pairs(Config.Buffs) do
        local r = remaining(name)
        if r > 0 then
            any = true
            if def.kind == 'icon' then
                out[name] = { buffName = name, display = true, iconName = def.icon, iconColor = def.color,
                              progressColor = def.ring, progressValue = r * 100 / def.maxTime }
            else
                out[name] = { display = true, enhancementName = name, iconColor = def.color }
            end
        end
    end
    return any and out or nil
end)

-- Effects ------------------------------------------------------------------------------------
local function value(name, effect)
    local b = buffs[name]
    if not b or remaining(name) <= 0 or not b.value then return nil end
    local lim = Config.Limits[effect]
    return math.max(lim.min, math.min(lim.max, b.value))
end

local speedSet = { stamina = false, swimming = false }

CreateThread(function()
    local sinceTick = 0
    while true do
        Wait(500)
        sinceTick = sinceTick + 500
        local ped = PlayerPedId()

        local run = value('stamina', 'stamina')
        if run then
            SetRunSprintMultiplierForPlayer(PlayerId(), run)
            SetPlayerStamina(PlayerId(), GetPlayerStamina(PlayerId()) + math.random(1, 10))
            speedSet.stamina = true
        elseif speedSet.stamina then
            SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
            speedSet.stamina = false
        end

        local swim = value('swimming', 'swimming')
        if swim then
            SetSwimMultiplierForPlayer(PlayerId(), swim)
            SetPlayerStamina(PlayerId(), GetPlayerStamina(PlayerId()) + math.random(1, 10))
            speedSet.swimming = true
        elseif speedSet.swimming then
            SetSwimMultiplierForPlayer(PlayerId(), 1.0)
            speedSet.swimming = false
        end

        if sinceTick >= Config.EffectTick then
            sinceTick = 0
            if not IsEntityDead(ped) then
                local hp = value('super-health', 'health')
                if hp and hp > 0 then
                    local cur, max = GetEntityHealth(ped), GetEntityMaxHealth(ped)
                    if cur > 0 and cur < max then SetEntityHealth(ped, math.min(max, cur + math.floor(hp))) end
                end
                local ar = value('super-armor', 'armor')
                if ar and ar > 0 then
                    local cur = GetPedArmour(ped)
                    if cur < 100 then SetPedArmour(ped, math.min(100, cur + math.floor(ar))) end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if speedSet.stamina then SetRunSprintMultiplierForPlayer(PlayerId(), 1.0) end
    if speedSet.swimming then SetSwimMultiplierForPlayer(PlayerId(), 1.0) end
end)
