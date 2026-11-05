Bank = { open = false, mode = nil, pd = {} }

function Bank.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-banking:api', false, action, data)
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Bank.notify(text, kind)
    lib.notify({ title = Config.BankName, description = text, type = kind or 'inform' })
end

local function loadPlayerData()
    local pd = Bridge.playerData(true)
    if type(pd) == 'table' then Bank.pd = pd end
end

Bridge.on('playerData', function(pd)
    if type(pd) == 'table' then Bank.pd = pd end
end)

Bridge.on('jobChanged', function() loadPlayerData() end)
Bridge.on('dutyChanged', function() loadPlayerData() end)

Bridge.on('playerLoaded', function()
    SetTimeout(500, loadPlayerData)
end)

CreateThread(loadPlayerData)

function Bank.isCollector()
    local job = Bank.pd.job
    return type(job) == 'table' and job.name == Config.CollectorJob and job.onduty == true
end

local hideHooks = {}

function Bank.onHide(mode, fn)
    hideHooks[mode] = fn
end

function Bank.show(mode, data)
    Bank.open = true
    Bank.mode = mode
    SendNUIMessage({ action = 'open', mode = mode, data = data or {} })
    SetNuiFocus(true, true)
end

function Bank.hide()
    if not Bank.open then return end
    local mode = Bank.mode
    Bank.open = false
    Bank.mode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if hideHooks[mode] then hideHooks[mode]() end
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    cb(Bank.api(d.action, d.data))
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    Bank.hide()
end)

local traceBlip

RegisterNUICallback('trace', function(d, cb)
    cb(true)
    if type(d) ~= 'table' or not tonumber(d.x) or not tonumber(d.y) then return end
    if traceBlip and DoesBlipExist(traceBlip) then RemoveBlip(traceBlip) end
    local x, y, r = tonumber(d.x) + 0.0, tonumber(d.y) + 0.0, (tonumber(d.radius) or 140) + 0.0
    traceBlip = AddBlipForRadius(x, y, 0.0, r)
    SetBlipColour(traceBlip, 47)
    SetBlipAlpha(traceBlip, 110)
    SetNewWaypoint(x, y)
    local mine = traceBlip
    SetTimeout(120000, function()
        if traceBlip == mine and DoesBlipExist(mine) then RemoveBlip(mine) traceBlip = nil end
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Bank.open then SetNuiFocus(false, false) end
    if traceBlip and DoesBlipExist(traceBlip) then RemoveBlip(traceBlip) end
end)
