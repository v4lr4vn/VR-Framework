Bills = { offers = {} }

local function tell(src, text, kind)
    if src and GetPlayerName(src) then Core.notify(src, text, kind) end
end

local function result(o, accepted)
    if not accepted and o.orderId then Orders.unbill(o.orderId) end
    if GetPlayerName(o.mechanic) then TriggerClientEvent('vr-mechanic:client:billResult', o.mechanic, o.token, accepted, o.orderId) end
end

function Bills.nearby(info)
    local out = {}
    local me = Core.coords(info.src)
    if not me then return out end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src ~= info.src then
            local pos = Core.coords(src)
            if pos and #(pos - me) <= Config.BillDistance then
                out[#out + 1] = { id = src, distance = math.floor(#(pos - me) * 10) / 10 }
            end
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end

function Bills.pendingFor(mechanicSrc)
    for _, o in pairs(Bills.offers) do
        if o.mechanic == mechanicSrc then return o end
    end
    return nil
end

function Bills.create(mech, target, o)
    if not Core.isMechanic(mech) then return false, 'not_mechanic' end
    target = tonumber(target)
    if not target or target == mech.src then return false, 'no_customer' end
    local customer = Core.info(target)
    if not customer then return false, 'no_customer' end
    local reach = o.maxDistance or Config.BillDistance
    local a, b = Core.coords(mech.src), Core.coords(target)
    if not a or not b or #(a - b) > reach then return false, 'too_far' end
    local amount = math.floor(tonumber(o.amount) or 0)
    if amount < 1 or amount > Config.MaxBill then return false, 'bad_amount', { max = Config.MaxBill } end
    local current = Bills.offers[target]
    if current and current.expires >= os.time() then return false, 'customer_busy' end
    if Bills.pendingFor(mech.src) then return false, 'bill_pending' end
    local token = ('%d-%d-%d'):format(target, mech.src, math.random(100000, 999999))
    Bills.offers[target] = {
        token = token, target = target, mechanic = mech.src, kind = o.kind, amount = amount, items = o.items, note = o.note,
        orderId = o.orderId, reach = reach, workshop = o.workshop, plate = o.plate, expires = os.time() + Config.BillSeconds,
    }
    TriggerClientEvent('vr-mechanic:client:bill', target, {
        token = token, kind = o.kind, mechanic = mech.firstName or mech.name, business = mech.job.label, workshop = o.workshopLabel,
        items = o.items, note = o.note, amount = amount, vehicle = o.vehicle, plate = o.plate, seconds = Config.BillSeconds,
        cash = Core.money(target, 'cash'), bank = Core.money(target, 'bank'),
    })
    return true, { token = token, amount = amount, seconds = Config.BillSeconds }
end

local function pay(customer, mech, amount, method)
    if not Core.take(customer.src, amount, method, 'mechanic-bill') then return false end
    local commission = math.floor(amount * Config.CommissionPercent / 100)
    Core.give(mech.src, commission, 'bank', 'mechanic-commission')
    Core.addSociety(mech.job.name, amount - commission, 'mechanic-bill')
    return true, commission
end

function Bills.respond(customer, token, accept, method)
    local o = Bills.offers[customer.src]
    if not o or o.token ~= token then return false, 'no_bill' end
    Bills.offers[customer.src] = nil
    if o.expires < os.time() then
        tell(o.mechanic, 'The bill expired', 'error')
        result(o, false)
        return false, 'expired'
    end
    if not accept then
        tell(o.mechanic, ('%s declined the bill'):format(customer.firstName or customer.name), 'error')
        result(o, false)
        return true, { declined = true }
    end
    local mech = Core.info(o.mechanic)
    if not mech or not Core.isMechanic(mech) then result(o, false) return false, 'no_mechanic' end
    local a, b = Core.coords(mech.src), Core.coords(customer.src)
    if not a or not b or #(a - b) > (o.reach or Config.BillDistance) + 4.0 then result(o, false) return false, 'too_far' end
    method = method == 'cash' and 'cash' or 'bank'
    local paid, commission = pay(customer, mech, o.amount, method)
    if not paid then
        tell(o.mechanic, ('%s could not pay the bill'):format(customer.firstName or customer.name), 'error')
        result(o, false)
        return false, 'no_money'
    end
    if o.orderId then Orders.paid(o.orderId, mech) end
    Db.log(o.kind, mech, customer, {
        workshop = o.workshop, plate = o.plate, amount = o.amount, commission = commission,
        details = o.orderId and ('Order #%d'):format(o.orderId) or o.note,
    })
    tell(o.mechanic, ('Paid $%s. Your commission: $%s%s'):format(MU.money(o.amount), MU.money(commission), o.orderId and '. Time to fit the parts' or ''), 'success')
    result(o, true)
    TriggerEvent('vr-mechanic:server:billPaid', o.kind, mech.src, customer.src, o.amount, o.plate)
    return true, { amount = o.amount, kind = o.kind, orderId = o.orderId }
end

function Bills.tick()
    local now = os.time()
    for target, o in pairs(Bills.offers) do
        if o.expires < now then
            Bills.offers[target] = nil
            tell(o.mechanic, 'The bill expired', 'error')
            result(o, false)
            if GetPlayerName(target) then TriggerClientEvent('vr-mechanic:client:billGone', target, o.token) end
        end
    end
end

function Bills.dropped(src)
    local o = Bills.offers[src]
    if o then
        Bills.offers[src] = nil
        result(o, false)
        tell(o.mechanic, 'The customer left', 'error')
    end
    for target, x in pairs(Bills.offers) do
        if x.mechanic == src then
            Bills.offers[target] = nil
            if x.orderId then Orders.unbill(x.orderId) end
            if GetPlayerName(target) then TriggerClientEvent('vr-mechanic:client:billGone', target, x.token) end
        end
    end
end
