local SUB = Config.Radial.id .. '_menu'
local tools = {}
local signature = ''

local function uiReady() return GetResourceState('vr-ui') == 'started' end

local function visible()
    local out = {}
    for _, t in ipairs(tools) do
        if not t.resource or GetResourceState(t.resource) == 'started' then out[#out + 1] = t end
    end
    return out
end

local function apply(force)
    if not uiReady() then return end
    local list = visible()
    local sig = {}
    for i, t in ipairs(list) do sig[i] = t.id end
    sig = table.concat(sig, ',')
    if sig == signature and not force then return end
    signature = sig

    if #list == 0 then
        exports['vr-ui']:removeRadialItem(Config.Radial.id)
        return
    end

    local items = {}
    for i, t in ipairs(list) do
        local command = t.command
        items[i] = {
            label = t.label,
            icon = t.icon,
            onSelect = function() ExecuteCommand(command) end,
        }
    end
    exports['vr-ui']:registerRadial({ id = SUB, label = Config.Radial.label, items = items })
    exports['vr-ui']:addRadialItem({
        id = Config.Radial.id,
        label = Config.Radial.label,
        icon = Config.Radial.icon,
        menu = SUB,
    })
end

RegisterNetEvent('vr-admintools:client:tools', function(list)
    tools = type(list) == 'table' and list or {}
    apply(false)
end)

CreateThread(function()
    Wait(5000)
    while true do
        TriggerServerEvent('vr-admintools:server:sync')
        Wait(math.max(10, Config.RecheckSeconds or 30) * 1000)
    end
end)

-- a creator resource that starts or stops later changes what can be shown
AddEventHandler('onClientResourceStart', function(res)
    if res == 'vr-ui' then
        -- vr-ui restarted: its radial list is empty again
        SetTimeout(1500, function() apply(true) end)
    else
        SetTimeout(500, function() apply(false) end)
    end
end)
AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then SetTimeout(500, function() apply(false) end) end
end)
