Effects = {}

local timers = {}
local gen = {}
local intox = { alcohol = 0, drug = 0 }

local function timed(key, duration, start, stop, tick, tickMs)
    local now = GetGameTimer()
    local running = timers[key] and timers[key] > now
    timers[key] = math.max(timers[key] or 0, now + duration)
    if running then return end
    gen[key] = (gen[key] or 0) + 1
    local run = gen[key]
    CreateThread(function()
        if start then start() end
        while gen[key] == run and timers[key] and GetGameTimer() < timers[key] do
            if tick then tick() end
            Wait(tickMs or 250)
        end
        if gen[key] ~= run then return end
        timers[key] = nil
        if stop then stop() end
    end)
end

local function alive(ped)
    return not IsEntityDead(ped) and GetEntityHealth(ped) > 0
end

local buffs = {
    heal = function(e)
        timed('buff_heal', e.time, nil, nil, function()
            local ped = cache.ped
            if alive(ped) then
                SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + math.floor(e.amount)))
            end
        end, 1000)
    end,
    stamina = function(e)
        timed('buff_stamina', e.time, nil, nil, function()
            RestorePlayerStamina(cache.playerId, 1.0)
        end, 500)
    end,
    armor = function(e)
        timed('buff_armor', e.time, nil, nil, function()
            local ped = cache.ped
            if alive(ped) then SetPedArmour(ped, math.min(100, GetPedArmour(ped) + math.floor(e.amount))) end
        end, 1000)
    end,
}

local function postfx(name, duration, outro)
    timed('fx_' .. name, duration,
        function() AnimpostfxPlay(name, 0, true) end,
        function()
            AnimpostfxStop(name)
            if outro then AnimpostfxPlay(outro, 0, false) end
        end)
end

local screens = {
    turbo = function() postfx('RaceTurbo', 20000) end,
    focus = function() postfx('FocusIn', 20000, 'FocusOut') end,
    rampage = function() postfx('Rampage', 20000) end,
    trevor = function() postfx('DrugsTrevorClownsFight', 30000, 'DrugsTrevorClownsFightOut') end,
    weed = function()
        timed('fx_weed', 45000,
            function()
                SetTimecycleModifier('stoned')
                SetTimecycleModifierStrength(0.6)
                ShakeGameplayCam('DRUNK_SHAKE', 0.4)
            end,
            function()
                ClearTimecycleModifier()
                StopGameplayCamShaking(true)
            end)
    end,
    nightvision = function()
        timed('fx_nightvision', 30000, function() SetNightvision(true) end, function() SetNightvision(false) end)
    end,
    thermal = function()
        timed('fx_thermal', 30000, function() SetSeethrough(true) end, function() SetSeethrough(false) end)
    end,
}

local DRUNK_WALK = { 'move_m@drunk@slightlydrunk', 'move_m@drunk@moderatedrunk', 'move_m@drunk@verydrunk' }

local function drunk()
    local over = intox.alcohol - Config.Intoxication.alcohol.drunk + 1
    local level = math.max(1, math.min(3, over))
    local clipset = DRUNK_WALK[level]
    local duration = math.min(300000, 60000 * over)

    if timers.drunk and timers.drunk > GetGameTimer() then
        timers.drunk = math.max(timers.drunk, GetGameTimer() + duration)
        if lib.requestAnimSet(clipset, 3000) then SetPedMovementClipset(cache.ped, clipset, 1.0) end
        ShakeGameplayCam('DRUNK_SHAKE', 0.5 * level)
        return
    end

    timed('drunk', duration,
        function()
            local ped = cache.ped
            SetPedIsDrunk(ped, true)
            if lib.requestAnimSet(clipset, 3000) then SetPedMovementClipset(ped, clipset, 1.0) end
            SetTimecycleModifier('Drunk')
            SetTimecycleModifierStrength(0.3 * level)
            ShakeGameplayCam('DRUNK_SHAKE', 0.5 * level)
        end,
        function()
            local ped = cache.ped
            SetPedIsDrunk(ped, false)
            ResetPedMovementClipset(ped, 1.0)
            ClearTimecycleModifier()
            StopGameplayCamShaking(true)
        end)
end

local function overdose()
    local ped = cache.ped
    local dmg = Config.Intoxication.overdoseDamage
    if alive(ped) then SetEntityHealth(ped, GetEntityHealth(ped) - math.random(dmg[1], dmg[2])) end
end

CreateThread(function()
    local step = Config.Intoxication.decayMinutes * 60000
    local last = GetGameTimer()
    while true do
        Wait(30000)
        if GetGameTimer() - last >= step then
            last = GetGameTimer()
            intox.alcohol = math.max(0, intox.alcohol - 1)
            intox.drug = math.max(0, intox.drug - 1)
        end
    end
end)

function Effects.Apply(r)
    local ped = cache.ped
    local cfg = Config.Intoxication

    if (r.heal or 0) > 0 and alive(ped) then
        SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + r.heal))
    end
    if (r.armor or 0) > 0 then
        SetPedArmour(ped, math.min(100, GetPedArmour(ped) + r.armor))
    end

    if r.type == 'alcohol' then
        intox.alcohol = intox.alcohol + 1
        if intox.alcohol >= cfg.alcohol.drunk then
            TriggerEvent('evidence:client:SetStatus', 'heavyalcohol', 200)
            drunk()
        elseif intox.alcohol >= cfg.alcohol.tipsy then
            TriggerEvent('evidence:client:SetStatus', 'alcohol', 200)
        end
        if r.canOD and intox.alcohol >= cfg.alcohol.overdose then overdose() end
    elseif r.type == 'drug' then
        intox.drug = intox.drug + 1
        if intox.drug >= cfg.drug.high then postfx('DrugsMichaelAliensFight', 60000, 'DrugsMichaelAliensFightOut') end
        if r.canOD and intox.drug >= cfg.drug.overdose then overdose() end
    end

    if r.screen and screens[r.screen] then screens[r.screen]() end
    if r.effect and buffs[r.effect.name] then buffs[r.effect.name](r.effect) end
    if r.widepupils then TriggerEvent('evidence:client:SetStatus', 'widepupils', 200) end
end

function Effects.StopAll()
    for key in pairs(timers) do
        timers[key] = nil
        gen[key] = (gen[key] or 0) + 1
    end
    local ped = cache.ped
    AnimpostfxStopAll()
    ClearTimecycleModifier()
    StopGameplayCamShaking(true)
    SetNightvision(false)
    SetSeethrough(false)
    SetPedIsDrunk(ped, false)
    ResetPedMovementClipset(ped, 1.0)
end

function Effects.Reset()
    Effects.StopAll()
    intox.alcohol, intox.drug = 0, 0
end

exports('GetIntoxication', function() return { alcohol = intox.alcohol, drug = intox.drug } end)
