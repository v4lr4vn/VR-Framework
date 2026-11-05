local MAX_STEP, WINDOW, MAX_EVENTS = 25, 10000, 20
local recent = {}

local function limited(src)
    local now = GetGameTimer()
    local r = recent[src]
    if not r or now - r.start > WINDOW then
        recent[src] = { start = now, count = 1 }
        return false
    end
    r.count = r.count + 1
    return r.count > MAX_EVENTS
end

AddEventHandler('playerDropped', function() recent[source] = nil end)

local function amountOf(v)
    v = tonumber(v)
    if not v or v ~= v or v <= 0 or v == math.huge then return nil end
    return math.min(v, MAX_STEP)
end

local function police(p)
    local job = p.job or {}
    return job.name == 'police' or job.type == 'leo'
end

local function change(src, delta)
    local current = tonumber(Bridge.getMeta(src, 'stress')) or 0
    local value = math.max(0, math.min(100, current + delta))
    if value == current then return end
    Bridge.setMeta(src, 'stress', value)
    TriggerClientEvent('hud:client:UpdateStress', src, value)
    Bridge.notify(src, delta > 0 and Config.Notify.stressUp or Config.Notify.stressDown, delta > 0 and 'error' or 'success')
end

RegisterNetEvent('hud:server:GainStress', function(amount)
    local src = source
    amount = amountOf(amount)
    if not amount or limited(src) then return end
    local p = Bridge.player(src)
    if not p or (Config.Stress.policeImmune and police(p)) then return end
    change(src, amount)
end)

exports('RelieveStress', function(src, amount)
    src = tonumber(src)
    amount = amountOf(amount)
    if not src or not amount then return false end
    if not Bridge.player(src) then return false end
    change(src, -amount)
    return true
end)

RegisterCommand('cash', function(source)
    if source > 0 and Bridge.player(source) then TriggerClientEvent('hud:client:ShowAccounts', source, 'cash', Bridge.money(source, 'cash')) end
end, false)

RegisterCommand('bank', function(source)
    if source > 0 and Bridge.player(source) then TriggerClientEvent('hud:client:ShowAccounts', source, 'bank', Bridge.money(source, 'bank')) end
end, false)
