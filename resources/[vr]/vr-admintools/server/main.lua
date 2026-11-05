-- Decides who sees the Admin tab. The tab is only a shortcut: every command it runs still does
-- its own permission check, so a hacked client gains nothing by faking the answer.

local tools = {}
local order = {}
local lastAsk = {}

local function add(t)
    if type(t) ~= 'table' or type(t.id) ~= 'string' or type(t.command) ~= 'string' then return false end
    if not tools[t.id] then order[#order + 1] = t.id end
    tools[t.id] = {
        id = t.id,
        label = tostring(t.label or t.id),
        icon = tostring(t.icon or 'wrench'),
        command = t.command,
        resource = t.resource,
    }
    return true
end

for _, t in ipairs(Config.Tools or {}) do add(t) end

local function allowedFor(src)
    if not src or src <= 0 then return nil end
    local admin = Bridge.isAdmin(src) == true
    local out = {}
    for _, id in ipairs(order) do
        local t = tools[id]
        if admin or IsPlayerAceAllowed(tostring(src), 'command.' .. t.command) then out[#out + 1] = t end
    end
    return out
end

local function push(src)
    local list = allowedFor(src)
    if not list then return end
    TriggerClientEvent('vr-admintools:client:tools', src, list)
end

RegisterNetEvent('vr-admintools:server:sync', function()
    local src = source
    local now = GetGameTimer()
    if lastAsk[src] and now - lastAsk[src] < 4000 then return end
    lastAsk[src] = now
    push(src)
end)

AddEventHandler('playerDropped', function() lastAsk[tonumber(source)] = nil end)

-- push straight after a character loads so the tab is there without waiting for the poll
Bridge.on('playerLoaded', function(src)
    SetTimeout(3000, function() if GetPlayerName(src) then push(src) end end)
end)

-- other resources can add their own launcher (for example a custom creator)
exports('AddTool', function(t)
    if not add(t) then return false end
    for _, src in ipairs(GetPlayers()) do push(tonumber(src)) end
    return true
end)
