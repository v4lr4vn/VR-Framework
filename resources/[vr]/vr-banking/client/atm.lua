local DICT = 'amb@prop_human_atm@male@idle_a'
local ENTER = 'amb@prop_human_atm@male@enter'
local EXIT = 'amb@prop_human_atm@male@exit'

local function playAtm(entity)
    local ped = cache.ped or PlayerPedId()
    TaskTurnPedToFaceEntity(ped, entity, 800)
    Wait(800)
    lib.requestAnimDict(ENTER)
    lib.requestAnimDict(DICT)
    TaskPlayAnim(ped, ENTER, 'enter', 4.0, -4.0, -1, 0, 0.0, false, false, false)
    Wait(1200)
    if Bank.mode == 'atm' then TaskPlayAnim(ped, DICT, 'idle_a', 4.0, -4.0, -1, 1, 0.0, false, false, false) end
end

Bank.onHide('atm', function()
    Bank.api('atm.end', {})
    local ped = cache.ped or PlayerPedId()
    lib.requestAnimDict(EXIT)
    TaskPlayAnim(ped, EXIT, 'exit', 4.0, -4.0, -1, 0, 0.0, false, false, false)
    SetTimeout(1500, function()
        if Bank.mode ~= 'atm' then StopAnimTask(ped, EXIT, 'exit', 1.0) end
    end)
    StopAnimTask(ped, DICT, 'idle_a', 1.0)
end)

local function useAtm(entity)
    if Bank.open or not entity or entity == 0 then return end
    local pos = GetEntityCoords(entity)
    local res = Bank.api('atm.cards', { x = pos.x, y = pos.y, z = pos.z })
    if not res.ok then return Bank.notify('This ATM is not responding', 'error') end
    if #res.data.cards == 0 then
        Bank.api('atm.end', {})
        return Bank.notify('You need a bank card. Order one at any bank branch.', 'error')
    end
    Bank.show('atm', res.data)
    CreateThread(function() playAtm(entity) end)
end

CreateThread(function()
    local models = {}
    for i, m in ipairs(Config.Atm.models) do models[i] = joaat(m) end
    Bridge.target.addModel(models, {
        {
            name = 'vr-banking:atm',
            label = 'Use ATM',
            icon = 'fa-solid fa-credit-card',
            distance = 1.6,
            onSelect = function(data) useAtm(type(data) == 'table' and data.entity or data) end,
        },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    local models = {}
    for i, m in ipairs(Config.Atm.models) do models[i] = joaat(m) end
    pcall(function() Bridge.target.removeModel(models, 'vr-banking:atm') end)
end)
