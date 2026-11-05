Api = {}

local handlers = {}
local last = {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end
local function reg(name, fn) handlers[name] = fn end

local function itemCounts(src)
    local out, seen = {}, {}
    for _, p in pairs(Config.Parts) do seen[p.item] = true end
    for _, r in pairs(Config.Repairs) do seen[r.item] = true end
    for item in pairs(seen) do out[item] = Core.count(src, item) end
    return out
end

local function vehicleFor(info, netId, extra)
    local veh = Cars.entity(netId)
    if not veh then return nil, 'no_vehicle' end
    if not Cars.near(info.src, veh, Config.WorkDistance + (extra or 2.0)) then return nil, 'too_far' end
    return veh
end

local function partsView()
    local out = {}
    for key, p in pairs(Config.Parts) do out[#out + 1] = { key = key, label = p.label, item = p.item, icon = p.icon } end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function health(fn, veh)
    local s, v = pcall(fn, veh)
    return s and tonumber(v) or nil
end

local function workshopOf(info, veh)
    return Workshops.at(GetEntityCoords(veh), info.job.name)
end

reg('inspect', function(info, d)
    if not Core.isMechanic(info) then return fail('not_mechanic') end
    local veh, err = vehicleFor(info, d.netId)
    if not veh then return fail(err) end
    local w = workshopOf(info, veh)
    return ok({
        plate = Cars.plate(veh),
        label = Cars.label(veh),
        status = Cars.status(veh),
        mileage = Cars.mileage(veh),
        engine = health(GetVehicleEngineHealth, veh),
        body = health(GetVehicleBodyHealth, veh),
        parts = partsView(),
        repairs = { engine = Config.Repairs.engineBlock.item, body = Config.Repairs.bodywork.item },
        items = itemCounts(info.src),
        workshop = w and w.label or nil,
        canTune = w ~= nil,
        warnAt = Config.Wear.warnAt,
    })
end)

reg('work.begin', function(info, d)
    local success, res, extra = Work.begin(info, d)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('work.finish', function(info, d)
    local success, res, extra = Work.finish(info, d.token)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('work.cancel', function(info, d)
    Work.cancel(info, d.token)
    return ok(true)
end)

reg('customers', function(info)
    if not Core.isMechanic(info) then return fail('not_mechanic') end
    return ok(Bills.nearby(info))
end)

reg('tune.open', function(info, d)
    if not Core.isMechanic(info) then return fail('not_mechanic') end
    local veh, err = vehicleFor(info, d.netId)
    if not veh then return fail(err) end
    local w = workshopOf(info, veh)
    if not w then return fail('not_in_workshop') end
    local pending = Bills.pendingFor(info.src)
    return ok({
        workshop = { id = w.id, label = w.label },
        plate = Cars.plate(veh),
        label = Cars.label(veh),
        prices = Config.Tuning.prices,
        performance = Config.Tuning.performance,
        bodyMods = Config.Tuning.bodyMods,
        commission = Config.CommissionPercent,
        customers = Bills.nearby(info),
        pending = pending and { token = pending.token, amount = pending.amount } or nil,
        me = {
            cash = Core.money(info.src, 'cash'),
            bank = Core.money(info.src, 'bank'),
            company = Shop.companyAllowed(info) and { label = info.job.label, balance = Core.societyBalance(info.job.name) } or nil,
        },
    })
end)

reg('tune.quote', function(info, d)
    if not Core.isMechanic(info) then return fail('not_mechanic') end
    local success, q, extra = Tuning.quote(d.changes, d.keep)
    if not success then return fail(q, extra) end
    return ok({ items = q.items, total = q.total })
end)

local function tuneTarget(info, d)
    if not Core.isMechanic(info) then return nil, 'not_mechanic' end
    local veh, err = vehicleFor(info, d.netId)
    if not veh then return nil, err end
    local w = workshopOf(info, veh)
    if not w then return nil, 'not_in_workshop' end
    local success, q, extra = Tuning.quote(d.changes, d.keep)
    if not success then return nil, q, extra end
    return veh, w, q
end

reg('tune.bill', function(info, d)
    local veh, w, q = tuneTarget(info, d)
    if not veh then return fail(w, q) end
    if q.total < 1 then return fail('nothing_to_bill') end
    local target = Core.info(tonumber(d.target))
    if not target or target.src == info.src then return fail('no_customer') end
    if Bills.pendingFor(info.src) then return fail('bill_pending') end
    local plate, label = Cars.plate(veh), Cars.label(veh)
    local id = Orders.create({
        source = 'mechanic', status = 'billed', plate = plate, vehicle = label, customer = target.cid, customerName = target.name,
        workshop = w.id, job = info.job.name, quote = q,
    })
    local success, res, extra = Bills.create(info, target.src, {
        kind = 'order', orderId = id, amount = q.total, items = q.items, workshop = w.id, workshopLabel = w.label, plate = plate, vehicle = label,
    })
    if not success then
        local o = Orders.get(id)
        if o then o.status = 'cancelled' Orders.save(o) end
        return fail(res, extra)
    end
    res.orderId = id
    return ok(res)
end)

reg('tune.self', function(info, d)
    local veh, w, q = tuneTarget(info, d)
    if not veh then return fail(w, q) end
    local method = d.method
    if q.total > 0 then
        if method == 'company' then
            if not Shop.companyAllowed(info) then return fail('not_allowed') end
            if Core.societyBalance(info.job.name) < q.total or not Core.removeSociety(info.job.name, q.total, 'mechanic-tuning') then return fail('no_company_money') end
        else
            method = method == 'cash' and 'cash' or 'bank'
            if not Core.take(info.src, q.total, method, 'mechanic-tuning') then return fail('no_money') end
            Core.addSociety(info.job.name, q.total, 'mechanic-tuning')
        end
    end
    local plate = Cars.plate(veh)
    local id = Orders.create({
        source = 'mechanic', status = 'paid', plate = plate, vehicle = Cars.label(veh), customer = info.cid, customerName = info.name,
        workshop = w.id, job = info.job.name, quote = q, mechanic = info.cid, mechanicName = info.name,
    })
    Db.log('tune', info, info, { workshop = w.id, plate = plate, amount = q.total, details = ('Order #%d'):format(id) })
    return ok({ total = q.total, plate = plate, orderId = id })
end)

reg('design.open', function(info, d)
    local veh, w, plate = Orders.designTarget(info, d.netId)
    if not veh then return fail(w) end
    if Orders.openCount(info.cid) >= Config.Orders.maxOpen then return fail('too_many_orders', { max = Config.Orders.maxOpen }) end
    return ok({
        design = true,
        workshop = { id = w.id, label = w.label },
        plate = plate,
        label = Cars.label(veh),
        prices = Config.Tuning.prices,
        performance = {},
        bodyMods = Config.Tuning.bodyMods,
    })
end)

reg('design.quote', function(info, d)
    local success, q, extra = Tuning.quote(d.changes, d.keep, true)
    if not success then return fail(q, extra) end
    return ok({ items = q.items, total = q.total })
end)

reg('design.order', function(info, d)
    local success, res, extra = Orders.place(info, d)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('order.view', function(info, d)
    local o = Orders.get(d.id)
    if not o then return fail('no_order') end
    local role = Orders.role(info, o)
    if not role then return fail('not_yours') end
    return ok(Orders.view(o, role))
end)

reg('order.cancel', function(info, d)
    local success, res, extra = Orders.cancel(info, d.id)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('order.board', function(info)
    if not Core.isMechanic(info) then return fail('not_mechanic') end
    return ok(Orders.board(info))
end)

reg('order.bill', function(info, d)
    local success, res, extra = Orders.bill(info, d.id)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('order.fitBegin', function(info, d)
    local success, res, extra = Orders.fitBegin(info, d.id, d.task)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('order.fitFinish', function(info, d)
    local success, res, extra = Orders.fitFinish(info, d.token)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('order.fitCancel', function(info, d)
    Orders.fitCancel(info, d.token)
    return ok(true)
end)

reg('bill.labour', function(info, d)
    local note = type(d.note) == 'string' and d.note:sub(1, 120) or ''
    local success, res, extra = Bills.create(info, d.target, {
        kind = 'labour', amount = d.amount, note = note ~= '' and note or nil,
        items = { { label = note ~= '' and note or 'Labour', price = math.floor(tonumber(d.amount) or 0) } },
    })
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('bill.respond', function(info, d)
    local success, res, extra = Bills.respond(info, d.token, d.accept == true, d.method)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('shop.open', function(info, d)
    if not Core.isMechanic(info) then return fail('not_mechanic') end
    local w = Workshops.atCounter(info.src, d.workshop)
    if not w then return fail('too_far') end
    if w.job ~= info.job.name then return fail('not_mechanic') end
    return ok(Shop.data(info, w))
end)

reg('shop.buy', function(info, d)
    local w = Workshops.atCounter(info.src, d.workshop)
    if not w then return fail('too_far') end
    local success, res, extra = Shop.buy(info, w, d.item, d.count, d.payment)
    if not success then return fail(res, extra) end
    res.me = Shop.data(info, w).me
    return ok(res)
end)

function Api.handle(src, action, data)
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if not Db.ready then return fail('not_ready') end
    local t = GetGameTimer()
    local mine = last[src]
    if not mine then mine = {} last[src] = mine end
    if mine[action] and t - mine[action] < 200 then return fail('slow_down') end
    mine[action] = t
    local info = Core.info(src)
    if not info then return fail('not_loaded') end
    local success, res = pcall(h, info, type(data) == 'table' and data or {})
    if not success then
        print(('^1[vr-mechanic] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end

AddEventHandler('playerDropped', function()
    local src = source
    last[src] = nil
    Bills.dropped(src)
end)
