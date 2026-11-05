-- Server owns every buff. Clients only receive a copy to show icons and apply movement/health effects.
-- active[citizenid][buff] = { ends = <ms on the server timer>, value = <effect strength or nil> }
local active = {}

local function now() return GetGameTimer() end

local function hudUp() return GetResourceState(Config.Hud) == 'started' end

-- The online source of a player given as a server id or a citizen id (nil when offline).
local function sourceOf(id)
    if type(id) == 'number' then return Bridge.cid(id) and id or nil end
    if type(id) == 'string' and id ~= '' then return Bridge.source(id) end
end

local function cidOf(id)
    if type(id) == 'string' and id ~= '' then return id end
    return type(id) == 'number' and Bridge.cid(id) or nil
end

local function clampValue(effect, value)
    local lim = Config.Limits[effect]
    value = tonumber(value)
    if not lim or not value or value ~= value then return nil end
    return math.max(lim.min, math.min(lim.max, value))
end

local function left(entry) return math.max(0, entry.ends - now()) end

-- What a client needs: remaining time and strength per buff.
local function snapshot(cid)
    local out = {}
    for name, e in pairs(active[cid] or {}) do
        out[name] = { left = left(e), value = e.value }
    end
    return out
end

local function sendCopy(src, cid)
    if src then TriggerClientEvent('vr-buffs:client:sync', src, snapshot(cid)) end
end

local function hudShow(src, name, remaining)
    if not src or not hudUp() then return end
    local def = Config.Buffs[name]
    if def.kind == 'icon' then
        TriggerClientEvent('hud:client:BuffEffect', src, {
            buffName = name, display = true, iconName = def.icon, iconColor = def.color,
            progressColor = def.ring, progressValue = remaining * 100 / def.maxTime,
        })
    else
        TriggerClientEvent('hud:client:EnhancementEffect', src, { display = true, enhancementName = name, iconColor = def.color })
    end
end

local function hudProgress(src, name, remaining)
    if not src or not hudUp() then return end
    local def = Config.Buffs[name]
    if def.kind == 'icon' then
        TriggerClientEvent('hud:client:BuffEffect', src, { buffName = name, progressValue = remaining * 100 / def.maxTime })
    end
end

local function hudHide(src, name)
    if not src or not hudUp() then return end
    if Config.Buffs[name].kind == 'icon' then
        TriggerClientEvent('hud:client:BuffEffect', src, { display = false, buffName = name })
    else
        TriggerClientEvent('hud:client:EnhancementEffect', src, { display = false, enhancementName = name })
    end
end

local function drop(cid, name)
    local set = active[cid]
    if not set or not set[name] then return false end
    set[name] = nil
    if next(set) == nil then active[cid] = nil end
    local src = sourceOf(cid)
    hudHide(src, name)
    sendCopy(src, cid)
    return true
end

-- AddBuff(source, citizenid, name, ms, value)  either of the first two may be nil.
local function add(src, cid, name, time, value)
    local def = type(name) == 'string' and Config.Buffs[name] or nil
    if not def then return false end
    cid = (type(cid) == 'string' and cid ~= '') and cid or cidOf(tonumber(src))
    if not cid then return false end
    if not tonumber(src) then src = sourceOf(cid) end

    local ms
    if time == nil then ms = def.maxTime else
        ms = tonumber(time)
        if not ms or ms ~= ms or ms <= 0 then return false end
        ms = math.min(math.floor(ms), def.maxTime)
    end
    if def.effect then
        value = clampValue(def.effect, value)
    end

    active[cid] = active[cid] or {}
    local entry = active[cid][name]
    local fresh = entry == nil or left(entry) <= 0
    if fresh then
        entry = { ends = now() + ms }
        active[cid][name] = entry
    else
        entry.ends = math.min(entry.ends + ms, now() + def.maxTime)
    end
    if value then entry.value = value end

    if fresh then hudShow(tonumber(src), name, left(entry)) end
    sendCopy(tonumber(src), cid)
    return true
end
exports('AddBuff', add)

exports('RemoveBuff', function(id, name)
    local cid = cidOf(id)
    return cid ~= nil and type(name) == 'string' and Config.Buffs[name] ~= nil and drop(cid, name)
end)

exports('HasBuff', function(id, name)
    local cid = cidOf(id)
    local e = cid and active[cid] and active[cid][name]
    return e ~= nil and left(e) > 0
end)

exports('GetBuffTime', function(id, name)
    local cid = cidOf(id)
    local e = cid and active[cid] and active[cid][name]
    return e and left(e) or 0
end)

-- Effect buffs: exports with the player's source first.
local function effectBuff(name)
    return function(src, time, value)
        src = tonumber(src)
        local cid = src and Bridge.cid(src)
        if not cid then return false end
        local def = Config.Buffs[name]
        local v = clampValue(def.effect, value)
        if not v then return false end
        return add(src, cid, name, time, v)
    end
end
exports('AddHealthBuff', effectBuff('super-health'))
exports('AddArmorBuff', effectBuff('super-armor'))
exports('AddStressBuff', effectBuff('super-stress'))
exports('StaminaBuffEffect', effectBuff('stamina'))
exports('SwimmingBuffEffect', effectBuff('swimming'))

-- A client asks for its own buffs after it has loaded. Read only.
RegisterNetEvent('vr-buffs:server:request', function()
    local src = source
    local cid = Bridge.cid(src)
    if not cid then return end
    sendCopy(src, cid)
    for name, e in pairs(active[cid] or {}) do hudShow(src, name, left(e)) end
end)

-- Expiry, hud rings and stress relief.
CreateThread(function()
    local sinceHud, sinceEffect = 0, 0
    while true do
        Wait(1000)
        sinceHud, sinceEffect = sinceHud + 1000, sinceEffect + 1000
        local doHud, doEffect = sinceHud >= Config.HudTick, sinceEffect >= Config.EffectTick
        if doHud then sinceHud = 0 end
        if doEffect then sinceEffect = 0 end

        for cid, set in pairs(active) do
            local src = sourceOf(cid)
            for name, e in pairs(set) do
                local remaining = left(e)
                if remaining <= 0 then
                    drop(cid, name)
                elseif doHud then
                    hudProgress(src, name, remaining)
                end
            end
            if doEffect and src and active[cid] then
                local e = active[cid]['super-stress']
                if e and e.value and e.value > 0 then
                    local cur = tonumber(Bridge.getMeta(src, 'stress')) or 0
                    local new = math.max(0, cur - e.value)
                    if new ~= cur then
                        Bridge.setMeta(src, 'stress', new)
                        TriggerClientEvent('hud:client:UpdateStress', src, new)
                    end
                end
            end
        end
    end
end)

Bridge.on('playerLoaded', function(src)
    local cid = Bridge.cid(src)
    if not cid then return end
    SetTimeout(3000, function()
        if not active[cid] or sourceOf(cid) ~= src then return end
        sendCopy(src, cid)
        for name, e in pairs(active[cid]) do hudShow(src, name, left(e)) end
    end)
end)
