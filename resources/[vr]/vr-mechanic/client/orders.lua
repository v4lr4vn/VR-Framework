Fit = { busy = false }

function Mech.openOrder(id)
    id = tonumber(id)
    if not id then return end
    local res = Mech.api('order.view', { id = id })
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    if Mech.open then Mech.hide() end
    Mech.orderId = id
    Mech.show('order', res.data)
end

function Mech.openBoard()
    local res = Mech.api('order.board', {})
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    if Mech.open then Mech.hide() end
    Mech.show('board', { orders = res.data })
end

local function vehicleFromNet(netId)
    local deadline = GetGameTimer() + 3000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(50) end
    return NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
end

function Fit.run(id, task, all)
    if Fit.busy or (Repair and Repair.busy) then return end
    if IsPedInAnyVehicle(cache.ped, false) then return Mech.notify(Mech.errorText('in_vehicle'), 'error') end
    Fit.busy = true
    local finished = false
    while true do
        local res = Mech.api('order.fitBegin', { id = id, task = task })
        if not res.ok then
            Mech.notify(Mech.errorText(res.error), 'error')
            break
        end
        local d = res.data
        local veh = vehicleFromNet(d.netId)
        if veh == 0 or not DoesEntityExist(veh) then
            Mech.api('order.fitCancel', { token = d.token })
            Mech.notify(Mech.errorText('car_not_here'), 'error')
            break
        end
        local done = Anim.perform(veh, d.work, d.seconds * 1000, ('Fitting %s'):format(d.label:lower()))
        if not done then
            Mech.api('order.fitCancel', { token = d.token })
            Mech.notify('Stopped', 'error')
            break
        end
        local fin = Mech.api('order.fitFinish', { token = d.token })
        if not fin.ok then
            Mech.notify(Mech.errorText(fin.error), 'error')
            break
        end
        Mech.notify(('%s fitted'):format(d.label), 'success')
        if fin.data.done then
            finished = true
            Mech.notify(('Order #%d is finished'):format(id), 'success')
            break
        end
        if not all then break end
        task = fin.data.next
    end
    Fit.busy = false
    if not finished and not Mech.open then Mech.openOrder(id) end
end

RegisterNUICallback('openOrder', function(d, cb)
    cb(true)
    if type(d) == 'table' then Mech.openOrder(d.id) end
end)

RegisterNUICallback('openBoard', function(_, cb)
    cb(true)
    Mech.openBoard()
end)

RegisterNUICallback('fit', function(d, cb)
    cb(true)
    if type(d) ~= 'table' then return end
    Mech.hide()
    Fit.run(tonumber(d.id), d.task, d.all == true)
end)

RegisterNetEvent('vr-mechanic:client:billResult', function(_, accepted, orderId)
    if not orderId or Mech.mode ~= 'order' or Mech.orderId ~= orderId then return end
    Mech.openOrder(orderId)
    if accepted then Mech.notify('Paid. Fit the parts when you are ready', 'success') end
end)

exports('orderSheet', function(_, slot)
    local md = type(slot) == 'table' and slot.metadata or nil
    local id = type(md) == 'table' and tonumber(md.orderId) or nil
    if not id then return Mech.notify('This order sheet is blank', 'error') end
    Mech.openOrder(id)
end)
