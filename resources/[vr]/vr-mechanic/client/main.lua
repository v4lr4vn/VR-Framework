Mech = { open = false, pd = {}, mode = nil, netId = nil, workshop = nil, billToken = nil }

local ERR = {
    not_mechanic = 'Clock in at a workshop first',
    no_vehicle = 'Vehicle not found',
    too_far = 'Get closer',
    in_vehicle = 'Get out of the vehicle first',
    no_item = 'You do not have the part for that',
    not_needed = 'That does not need fixing',
    not_in_workshop = 'Bring the vehicle into your workshop',
    no_work = 'Something went wrong, try again',
    too_fast = 'Take your time with it',
    failed = 'Something went wrong, try again',
    slow_down = 'Slow down a little',
    not_your_vehicle = 'You can only order work for your own vehicle',
    too_many_orders = 'You already have the most open orders allowed',
    cant_carry = 'You cannot carry the order sheet',
    no_order = 'That order no longer exists',
    not_yours = 'This order is for someone else',
    car_not_here = 'Bring the car to the workshop and stand next to it',
    customer_away = 'The customer needs to be at the workshop to pay',
    not_paid = 'The order has not been paid yet',
    already_done = 'That part is already fitted',
    no_task = 'Nothing left to fit',
    bill_pending = 'Wait for your last bill to be answered',
    customer_busy = 'The customer already has a bill open',
}

function Mech.errorText(code)
    return ERR[code] or ERR.failed
end

function Mech.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-mechanic:api', false, action, data)
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Mech.notify(text, kind)
    lib.notify({ title = 'Mechanic', description = text, type = kind or 'inform' })
end

local function loadPlayerData()
    local ok, pd = pcall(function() return exports['vr-core']:GetCoreObject().Functions.GetPlayerData() end)
    if ok and type(pd) == 'table' then Mech.pd = pd end
end

AddEventHandler('VRCore:Player:SetPlayerData', function(pd)
    if type(pd) == 'table' then Mech.pd = pd end
end)

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function()
    Wait(500)
    loadPlayerData()
end)

CreateThread(loadPlayerData)

function Mech.isMechanic()
    return MU.isMechanic(Mech.pd.job)
end

function Mech.inJob()
    local job = Mech.pd.job
    return type(job) == 'table' and Config.Jobs[job.name] == true
end

function Mech.workshopAt(pos)
    local job = Mech.pd.job
    for id, w in pairs(GlobalState.vrWorkshops or {}) do
        if (not job or w.job == job.name) and #(pos - vec3(w.center.x, w.center.y, w.center.z)) <= w.radius then return id, w end
    end
    return nil
end

function Mech.anyWorkshopAt(pos)
    for id, w in pairs(GlobalState.vrWorkshops or {}) do
        if #(pos - vec3(w.center.x, w.center.y, w.center.z)) <= w.radius then return id, w end
    end
    return nil
end

function Mech.vehicleLabel(veh)
    local name = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
    local label = name and GetLabelText(name) or nil
    if not label or label == 'NULL' then label = name end
    return label
end

function Mech.show(mode, data)
    Mech.open = true
    Mech.mode = mode
    SendNUIMessage({ action = 'open', mode = mode, data = data })
    SetNuiFocus(true, true)
end

function Mech.hide()
    if not Mech.open then return end
    local mode = Mech.mode
    Mech.open = false
    Mech.mode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    if mode == 'tune' and Tuning then Tuning.closed() end
    if mode == 'order' then Mech.orderId = nil end
end

function Mech.inspect(veh)
    if not veh or not DoesEntityExist(veh) then return end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local res = Mech.api('inspect', { netId = netId })
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    Mech.netId = netId
    res.data.label = res.data.label or Mech.vehicleLabel(veh)
    res.data.engine = res.data.engine or GetVehicleEngineHealth(veh)
    res.data.body = res.data.body or GetVehicleBodyHealth(veh)
    Mech.show('inspect', res.data)
end

function Mech.openShop(id)
    local res = Mech.api('shop.open', { workshop = id })
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    Mech.workshop = id
    Mech.show('shop', res.data)
end

function Mech.invoice()
    if not Mech.isMechanic() then return Mech.notify(ERR.not_mechanic, 'error') end
    local res = Mech.api('customers', {})
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    Mech.show('invoice', { customers = res.data, max = Config.MaxBill, commission = Config.CommissionPercent, seconds = Config.BillSeconds })
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    local data = type(d.data) == 'table' and d.data or {}
    if d.action:sub(1, 5) == 'shop.' then data.workshop = Mech.workshop end
    local prefix = d.action:match('^(%a+)%.')
    if prefix == 'tune' or prefix == 'design' or d.action == 'inspect' then data.netId = Mech.netId end
    if d.action == 'tune.bill' or d.action == 'tune.self' or d.action == 'tune.quote' or d.action == 'design.quote' or d.action == 'design.order' then
        data.changes = Tuning.normalize(data.changes)
        data.keep = Tuning.keepFor(data.changes)
    end
    local res = Mech.api(d.action, data)
    cb(res)
    if not res.ok then return end
    if d.action == 'tune.bill' then
        Tuning.billed(res.data.token, data.changes)
    elseif d.action == 'tune.self' then
        Tuning.finished(res.data.orderId)
    elseif d.action == 'design.order' then
        Mech.hide()
        Mech.notify(('Order #%d placed. Hand the order sheet to a mechanic. You pay when they start.'):format(res.data.id), 'success')
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    if Mech.mode == 'bill' and Mech.billToken then
        Mech.api('bill.respond', { token = Mech.billToken, accept = false })
        Mech.billToken = nil
    end
    Mech.hide()
end)

RegisterNUICallback('work', function(d, cb)
    cb(true)
    if type(d) ~= 'table' then return end
    local veh = Mech.netId and NetworkDoesNetworkIdExist(Mech.netId) and NetToVeh(Mech.netId) or 0
    Mech.hide()
    if veh ~= 0 and Repair then Repair.run(d.kind, veh, d.part, true) end
end)

RegisterNUICallback('openTune', function(_, cb)
    cb(true)
    local veh = Mech.netId and NetworkDoesNetworkIdExist(Mech.netId) and NetToVeh(Mech.netId) or 0
    Mech.hide()
    if veh ~= 0 and Tuning then Tuning.open(veh) end
end)

RegisterNUICallback('openInvoice', function(_, cb)
    cb(true)
    Mech.hide()
    Mech.invoice()
end)

RegisterNetEvent('vr-mechanic:client:bill', function(bill)
    if type(bill) ~= 'table' or type(bill.token) ~= 'string' then return end
    if Mech.open and Mech.mode ~= 'bill' then Mech.hide() end
    Mech.billToken = bill.token
    Mech.show('bill', bill)
end)

RegisterNetEvent('vr-mechanic:client:billGone', function(token)
    if Mech.billToken ~= token then return end
    Mech.billToken = nil
    if Mech.mode == 'bill' then
        Mech.hide()
        Mech.notify('The bill expired', 'error')
    end
end)

RegisterNUICallback('billAnswer', function(d, cb)
    local token = Mech.billToken
    Mech.billToken = nil
    if not token then return cb({ ok = false, error = 'no_bill' }) end
    local res = Mech.api('bill.respond', { token = token, accept = type(d) == 'table' and d.accept == true, method = type(d) == 'table' and d.method or nil })
    cb(res)
    if res.ok then
        Mech.hide()
        if res.data and res.data.amount then Mech.notify(('Paid $%s'):format(MU.money(res.data.amount)), 'success') end
    end
end)

RegisterCommand('mechbill', function()
    if Mech.open then return end
    Mech.invoice()
end, false)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Mech.open then SetNuiFocus(false, false) end
end)
