Orders = { fitting = {} }

local O = Config.Orders

local function decode(v)
    if type(v) == 'table' then return v end
    if type(v) ~= 'string' or v == '' then return nil end
    local ok, r = pcall(json.decode, v)
    return ok and r or nil
end

local function row(r)
    if not r then return nil end
    return {
        id = tonumber(r.id), source = r.source, status = r.status, plate = r.plate, vehicle = r.vehicle,
        customer = r.customer, customerName = r.customer_name, workshop = r.workshop, job = r.job,
        changes = decode(r.changes) or {}, keep = decode(r.keep) or {}, items = decode(r.items) or {}, tasks = decode(r.tasks) or {},
        total = tonumber(r.total) or 0, mechanic = r.mechanic, mechanicName = r.mechanic_name, created = tonumber(r.created) or 0,
    }
end

function Orders.get(id)
    id = tonumber(id)
    if not id then return nil end
    return row(MySQL.single.await('SELECT * FROM vr_mechanic_orders WHERE id = ?', { id }))
end

function Orders.save(o)
    MySQL.update.await('UPDATE vr_mechanic_orders SET status = ?, tasks = ?, mechanic = ?, mechanic_name = ?, updated = ? WHERE id = ?', {
        o.status, json.encode(o.tasks), o.mechanic, o.mechanicName, os.time(), o.id,
    })
end

function Orders.create(d)
    local tasks = Fitting.tasks(d.quote.changes)
    for _, t in ipairs(tasks) do
        t.price = Fitting.price(t, d.quote.items)
        t.done = false
    end
    local id = MySQL.insert.await([[INSERT INTO vr_mechanic_orders (source, status, plate, vehicle, customer, customer_name, workshop, job, changes, `keep`, items, tasks, total, mechanic, mechanic_name, created, updated)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)]], {
        d.source, d.status, d.plate, d.vehicle, d.customer, d.customerName, d.workshop, d.job,
        json.encode(d.quote.changes), json.encode(d.quote.keep or {}), json.encode(d.quote.items), json.encode(tasks), d.quote.total,
        d.mechanic, d.mechanicName, os.time(), os.time(),
    })
    return tonumber(id)
end

function Orders.openCount(cid)
    return tonumber(MySQL.scalar.await("SELECT COUNT(*) FROM vr_mechanic_orders WHERE customer = ? AND source = 'customer' AND status IN ('open', 'billed')", { cid })) or 0
end

function Orders.expire()
    MySQL.update.await("UPDATE vr_mechanic_orders SET status = 'expired', updated = ? WHERE status = 'open' AND created < ?", { os.time(), os.time() - O.expireDays * 86400 })
end

local function workshopLabel(id)
    local w = Workshops.get(id)
    return w and w.label or nil
end

function Orders.view(o, role)
    local tasks = {}
    for i, t in ipairs(o.tasks) do tasks[i] = { n = t.n or i, id = t.id, label = t.label, work = t.work, price = t.price, done = t.done == true, seconds = t.seconds } end
    return {
        id = o.id, status = o.status, source = o.source, plate = o.plate, vehicle = o.vehicle, customer = o.customerName,
        workshop = workshopLabel(o.workshop), items = o.items, tasks = tasks, total = o.total, created = o.created,
        mechanic = o.mechanicName, role = role, commission = Config.CommissionPercent,
    }
end

function Orders.board(info)
    local rows = MySQL.query.await("SELECT id, status, source, plate, vehicle, customer_name, workshop, total, tasks, created FROM vr_mechanic_orders WHERE job = ? AND status IN ('open', 'billed', 'paid') ORDER BY FIELD(status, 'paid', 'billed', 'open'), id DESC LIMIT 50", { info.job.name }) or {}
    local out = {}
    for i, r in ipairs(rows) do
        local tasks = decode(r.tasks) or {}
        local done = 0
        for _, t in ipairs(tasks) do if t.done then done = done + 1 end end
        out[i] = { id = tonumber(r.id), status = r.status, source = r.source, plate = r.plate, vehicle = r.vehicle, customer = r.customer_name,
            workshop = workshopLabel(r.workshop), total = tonumber(r.total) or 0, tasks = #tasks, done = done, created = tonumber(r.created) or 0 }
    end
    return out
end

function Orders.sheetMeta(o)
    return {
        orderId = o.id,
        plate = o.plate,
        label = ('Order sheet #%d'):format(o.id),
        description = ('%s, plate %s. %d job%s, $%s. Hand it to a mechanic.'):format(o.vehicle or 'Vehicle', o.plate, #o.tasks, #o.tasks == 1 and '' or 's', MU.money(o.total)),
    }
end

function Orders.removeSheet(src, id)
    if not src then return false end
    return Core.removeItem(src, O.item, 1, { orderId = id })
end

function Orders.findVehicle(info, plate)
    local me = Core.coords(info.src)
    if not me then return nil end
    for _, veh in ipairs(GetAllVehicles()) do
        if Cars.plate(veh) == plate and #(me - GetEntityCoords(veh)) <= Config.WorkDistance + 6.0 then return veh end
    end
    return nil
end

local function ownerOf(plate)
    if not Db.vehicles then return nil end
    return MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE plate = ? LIMIT 1', { plate })
end

function Orders.designTarget(info, netId)
    local veh = Cars.entity(netId)
    if not veh then return nil, 'no_vehicle' end
    if not Cars.near(info.src, veh, Config.WorkDistance + 2.0) then return nil, 'too_far' end
    if GetVehiclePedIsIn(GetPlayerPed(info.src), false) ~= 0 then return nil, 'in_vehicle' end
    local w = Workshops.at(GetEntityCoords(veh))
    if not w then return nil, 'not_in_workshop' end
    local plate = Cars.plate(veh)
    if not plate or ownerOf(plate) ~= info.cid then return nil, 'not_your_vehicle' end
    return veh, w, plate
end

function Orders.place(info, d)
    local veh, w, plate = Orders.designTarget(info, d.netId)
    if not veh then return false, w end
    if Orders.openCount(info.cid) >= O.maxOpen then return false, 'too_many_orders', { max = O.maxOpen } end
    local ok, q, extra = Tuning.quote(d.changes, d.keep, true)
    if not ok then return false, q, extra end
    if not Core.canCarry(info.src, O.item, 1) then return false, 'cant_carry' end
    local id = Orders.create({
        source = 'customer', status = 'open', plate = plate, vehicle = Cars.label(veh) or (type(d.label) == 'string' and d.label:sub(1, 40) or nil), customer = info.cid, customerName = info.name,
        workshop = w.id, job = w.job, quote = q,
    })
    if not id then return false, 'failed' end
    local o = Orders.get(id)
    if not Core.addItem(info.src, O.item, 1, Orders.sheetMeta(o)) then
        o.status = 'cancelled'
        Orders.save(o)
        return false, 'cant_carry'
    end
    return true, { id = id, total = q.total }
end

function Orders.role(info, o)
    if Core.isMechanic(info) and info.job.name == o.job then return 'mechanic' end
    if o.customer == info.cid then return 'customer' end
    return nil
end

function Orders.cancel(info, id)
    local o = Orders.get(id)
    if not o then return false, 'no_order' end
    if o.customer ~= info.cid then return false, 'not_yours' end
    if o.status ~= 'open' then return false, 'cannot_cancel' end
    o.status = 'cancelled'
    Orders.save(o)
    Orders.removeSheet(info.src, o.id)
    return true, Orders.view(o, 'customer')
end

function Orders.bill(info, id)
    local o = Orders.get(id)
    if not o then return false, 'no_order' end
    if Orders.role(info, o) ~= 'mechanic' then return false, 'not_mechanic' end
    if o.status ~= 'open' then return false, 'bad_status' end
    local veh = Orders.findVehicle(info, o.plate)
    if not veh then return false, 'car_not_here' end
    local w = Workshops.at(GetEntityCoords(veh), info.job.name)
    if not w then return false, 'not_in_workshop' end
    local target = Core.srcByCid(o.customer)
    if not target then return false, 'customer_away' end
    local ok, res, extra = Bills.create(info, target, {
        kind = 'order', orderId = o.id, amount = o.total, items = o.items, workshop = w.id, workshopLabel = w.label,
        plate = o.plate, vehicle = o.vehicle, maxDistance = O.billDistance, note = ('Order #%d'):format(o.id),
    })
    if not ok then return false, res == 'too_far' and 'customer_away' or res, extra end
    o.status = 'billed'
    Orders.save(o)
    return true, { token = res.token, amount = res.amount, seconds = res.seconds }
end

function Orders.paid(id, mech)
    local o = Orders.get(id)
    if not o then return nil end
    o.status = 'paid'
    o.mechanic = mech.cid
    o.mechanicName = mech.name
    Orders.save(o)
    return o
end

function Orders.unbill(id)
    local o = Orders.get(id)
    if not o or o.status ~= 'billed' then return end
    o.status = o.source == 'customer' and 'open' or 'cancelled'
    Orders.save(o)
end

local function nextTask(o)
    for _, t in ipairs(o.tasks) do
        if not t.done then return t end
    end
    return nil
end

function Orders.fitBegin(info, id, taskId)
    local o = Orders.get(id)
    if not o then return false, 'no_order' end
    if Orders.role(info, o) ~= 'mechanic' then return false, 'not_mechanic' end
    if o.status ~= 'paid' then return false, 'not_paid' end
    local task
    for _, t in ipairs(o.tasks) do
        if t.id == taskId then task = t break end
    end
    task = task or (taskId == nil and nextTask(o)) or nil
    if not task then return false, 'no_task' end
    if task.done then return false, 'already_done' end
    if GetVehiclePedIsIn(GetPlayerPed(info.src), false) ~= 0 then return false, 'in_vehicle' end
    local veh = Orders.findVehicle(info, o.plate)
    if not veh or not Cars.near(info.src, veh, Config.WorkDistance + 1.0) then return false, 'car_not_here' end
    if not Workshops.at(GetEntityCoords(veh), info.job.name) then return false, 'not_in_workshop' end
    local token = ('%d-%d-%d'):format(info.src, o.id, math.random(100000, 999999))
    Orders.fitting[info.src] = { token = token, id = o.id, task = task.id, veh = veh, at = GetGameTimer(), seconds = task.seconds }
    local color
    if task.id == 'paint1' then color = o.changes.color1 elseif task.id == 'paint2' then color = o.changes.color2 end
    return true, { token = token, seconds = task.seconds, work = task.work, label = task.label, netId = NetworkGetNetworkIdFromEntity(veh), color = color }
end

function Orders.fitCancel(info, token)
    local f = Orders.fitting[info.src]
    if f and f.token == token then Orders.fitting[info.src] = nil end
    return true
end

function Orders.fitFinish(info, token)
    local f = Orders.fitting[info.src]
    if not f or f.token ~= token then return false, 'no_work' end
    Orders.fitting[info.src] = nil
    if GetGameTimer() - f.at < f.seconds * 800 then return false, 'too_fast' end
    if not DoesEntityExist(f.veh) or not Cars.near(info.src, f.veh, Config.WorkDistance + 2.0) then return false, 'car_not_here' end
    local o = Orders.get(f.id)
    if not o or o.status ~= 'paid' then return false, 'not_paid' end
    local task
    for _, t in ipairs(o.tasks) do
        if t.id == f.task then task = t break end
    end
    if not task or task.done then return false, 'already_done' end
    Tuning.apply(f.veh, Tuning.propsFor(task, o.changes, o.keep))
    task.done = true
    local nxt = nextTask(o)
    if not nxt then
        o.status = 'done'
        if not Orders.removeSheet(info.src, o.id) then Orders.removeSheet(Core.srcByCid(o.customer), o.id) end
        local cust = Core.srcByCid(o.customer)
        if cust and cust ~= info.src then Core.notify(cust, ('Order #%d on %s is finished'):format(o.id, o.plate), 'success') end
        Db.log('fitted', info, nil, { workshop = o.workshop, plate = o.plate, amount = 0, details = ('Order #%d'):format(o.id) })
    end
    Orders.save(o)
    TriggerEvent('vr-mechanic:server:fitted', o.id, task.id, o.plate, info.src)
    return true, { next = nxt and nxt.id or nil, done = nxt == nil, order = Orders.view(o, 'mechanic') }
end

AddEventHandler('playerDropped', function()
    Orders.fitting[source] = nil
end)
