Api = {}

local handlers = {}
local last = {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end
local function reg(name, fn) handlers[name] = fn end

local function dealerFor(info, id, extra)
    local d = Dealers.get(id)
    if not d then return nil, 'no_dealer' end
    if not Dealers.near(d, info.src, extra) then
        local pos = Core.coords(info.src)
        if not pos then
            Core.notify(info.src, 'The server can not see your position. OneSync must be enabled on the server', 'error')
        else
            Core.notify(info.src, ('You are %.0fm from the %s centre, it has to be within %.0fm. Admins can move it with /dealer center %s'):format(#(pos - d.center), d.label, d.radius + (extra or 4.0), d.id), 'error')
        end
        return nil, 'too_far'
    end
    return d
end

local function loansConfig()
    if GetResourceState('vr-banking') ~= 'started' then return { enabled = false } end
    return { enabled = true }
end

reg('open', function(info, data)
    local d, err = dealerFor(info, data.dealer)
    if not d then return fail(err) end
    local staff = Sales.isStaff(info)
    local slots
    if staff and info.job.grade >= Config.Sales.displayGrade then
        slots = {}
        local disp = (GlobalState.vrDealerDisplay or {})[d.id] or {}
        for i = 1, #d.display do slots[i] = disp[tostring(i)] or d.display[i].model end
    end
    return ok({
        dealer = { id = d.id, label = d.label, shop = d.shop },
        catalogue = Dealers.catalogue(d),
        colors = Config.Colors,
        categories = Config.Categories,
        me = {
            name = info.name,
            staff = staff,
            grade = info.job.grade,
            discount = staff and Sales.discount(info) or 0,
            maxMarkup = Config.Sales.maxMarkupPercent,
            commission = Config.Sales.commissionPercent,
            cash = Core.money(info.src, 'cash'),
            bank = Core.money(info.src, 'bank'),
        },
        selfService = { open = Sales.selfServiceOpen(), markup = Config.SelfService.markupPercent, staffOnDuty = Core.staffOnDuty() },
        finance = loansConfig(),
        display = slots,
        testDrive = { seconds = Config.TestDrive.seconds },
    })
end)

reg('quote', function(info, data)
    local d, err = dealerFor(info, data.dealer)
    if not d then return fail(err) end
    if not Dealers.sells(d, data.model) then return fail('not_sold_here') end
    local base = math.floor(Core.vehicle(data.model).price)
    local price = Sales.selfPrice(base)
    if data.target then
        if not Sales.isStaff(info) then return fail('not_staff') end
        local lo, hi = Sales.range(info, base)
        price = math.max(lo, math.min(hi, math.floor(tonumber(data.price) or base)))
        local q = Sales.quote(tonumber(data.target), price, data.down, data.term)
        if not q then return fail('no_finance') end
        return ok({ approved = q.approved, reasons = q.reasons, down = q.down, minDown = q.minDown, installment = q.installment, term = q.term, total = q.total, price = price })
    end
    local q = Sales.quote(info.src, price, data.down, data.term)
    if not q then return fail('no_finance') end
    return ok(q)
end)

reg('buy', function(info, data)
    local d, err = dealerFor(info, data.dealer)
    if not d then return fail(err) end
    if not Dealers.sells(d, data.model) then return fail('not_sold_here') end
    local payment = data.payment
    if payment == 'society' then return fail('not_boss') end
    if not Sales.selfServiceOpen() then return fail('staff_on_duty') end
    local base = math.floor(Core.vehicle(data.model).price)
    local price = payment == 'society' and base or Sales.selfPrice(base)
    local success, res, extra = Sales.execute(info, d, data.model, price, { payment = payment, down = data.down, term = data.term, color = data.color })
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('testdrive', function(info, data)
    local d, err = dealerFor(info, data.dealer)
    if not d then return fail(err) end
    local success, res, extra = TestDrive.start(info, d, data.model)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('customers', function(info, data)
    if not Sales.isStaff(info) then return fail('not_staff') end
    local d, err = dealerFor(info, data.dealer)
    if not d then return fail(err) end
    return ok(Sales.nearbyCustomers(info, d))
end)

reg('offer', function(info, data)
    local d = Dealers.get(data.dealer)
    if not d then return fail('no_dealer') end
    local success, res, extra = Sales.offer(info, d, data.target, data)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('offer.respond', function(info, data)
    local success, res, extra = Sales.respond(info, data.token, data.accept == true, data.method)
    if not success then return fail(res, extra) end
    return ok(res)
end)

reg('display.set', function(info, data)
    if not Sales.isStaff(info) or info.job.grade < Config.Sales.displayGrade then return fail('not_allowed') end
    local d, err = dealerFor(info, data.dealer)
    if not d then return fail(err) end
    local slot = tonumber(data.slot)
    if not slot or not d.display[slot] then return fail('bad_slot') end
    if not Dealers.sells(d, data.model) then return fail('not_sold_here') end
    Dealers.setDisplay(d.id, slot, data.model)
    return ok(true)
end)

reg('sales.mine', function(info, data)
    if not Sales.isStaff(info) then return fail('not_staff') end
    local rows = MySQL.query.await('SELECT model, plate, price, payment, buyer_name, commission, at FROM vr_dealership_sales WHERE seller = ? ORDER BY id DESC LIMIT 15', { info.cid }) or {}
    for _, r in ipairs(rows) do r.label = Core.vehicleLabel(r.model) end
    return ok(rows)
end)

local WHY = {
    not_ready = 'The dealership database is not ready yet',
    no_dealer = 'This dealership is not set up on the server (no dealer data loaded)',
    not_loaded = 'Your character is not loaded',
    no_garages = 'vr-garages is not running, the sale can not finish',
    failed = 'The sale failed on the server, see the server console',
}

local function explain(src, action, res)
    if type(res) == 'table' and res.ok == false and WHY[res.error] and (action == 'buy' or action == 'open' or action == 'testdrive') then
        print(('^1[vr-dealership] %s for %s failed: %s. Run /dealercheck^0'):format(action, GetPlayerName(src) or src, res.error))
        Core.notify(src, WHY[res.error], 'error')
    end
    return res
end

function Api.handle(src, action, data)
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if not Db.ready then return explain(src, action, fail('not_ready')) end
    local t = GetGameTimer()
    local mine = last[src]
    if not mine then mine = {} last[src] = mine end
    if mine[action] and t - mine[action] < 300 then return fail('slow_down') end
    mine[action] = t
    local info = Core.info(src)
    if not info then return explain(src, action, fail('not_loaded')) end
    local success, res = pcall(h, info, type(data) == 'table' and data or {})
    if not success then
        print(('^1[vr-dealership] %s: %s^0'):format(action, tostring(res)))
        return explain(src, action, fail('failed'))
    end
    return explain(src, action, res)
end

AddEventHandler('playerDropped', function()
    last[source] = nil
    Sales.offers[source] = nil
end)
