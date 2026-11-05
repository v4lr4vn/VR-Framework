Sales = { offers = {} }

local S = Config.Sales

local function pct(n, p) return math.floor(n * (p or 0) / 100) end

function Sales.isStaff(info)
    return info ~= nil and info.job.name == Config.Job and info.job.onduty
end

function Sales.discount(info)
    return S.discountByGrade[info.job.grade] or S.discountByGrade[#S.discountByGrade] or 0
end

function Sales.range(info, base)
    return math.floor(base * (1 - Sales.discount(info) / 100)), math.floor(base * (1 + S.maxMarkupPercent / 100))
end

function Sales.selfServiceOpen()
    local mode = Config.SelfService.mode
    if mode == 'always' then return true end
    if mode == 'never' then return false end
    return Core.staffOnDuty() == 0
end

function Sales.selfPrice(base)
    return math.floor(base * (1 + (Config.SelfService.markupPercent or 0) / 100))
end

local banking = {}

function banking.quote(src, price, down, term)
    if not Core.started('vr-banking') then return nil end
    local ok, q = pcall(function() return exports['vr-banking']:QuoteFinance(src, price, down, term) end)
    return ok and q or nil
end

function banking.create(src, price, down, term, plate, model)
    local ok, a, b = pcall(function() return exports['vr-banking']:CreateFinance(src, price, down, term, plate, model) end)
    if not ok then return false, 'failed' end
    return a, b
end

function banking.cancel(id)
    pcall(function() exports['vr-banking']:CancelFinance(id) end)
end

Sales.quote = banking.quote

local garages = {}

function garages.plate()
    local ok, plate = pcall(function() return exports['vr-garages']:GeneratePlate() end)
    return ok and plate or nil
end

function garages.add(cid, model, opts)
    local ok, plate, err = pcall(function() return exports['vr-garages']:AddVehicle(cid, model, opts) end)
    if not ok then return nil, tostring(plate) end
    return plate, err
end

function garages.spawn(src, plate, coords)
    local ok, done = pcall(function() return exports['vr-garages']:SpawnOwnedVehicle(src, plate, coords) end)
    return ok and done == true
end

function garages.remove(plate)
    MySQL.update.await('DELETE FROM player_vehicles WHERE plate = ?', { plate })
end

function Sales.execute(buyer, dealer, model, price, opts)
    opts = opts or {}
    if not Core.started('vr-garages') then return false, 'no_garages' end
    local payment = opts.payment
    local color = DU.colorOk(opts.color)
    local fleet
    local paid = {}
    local function refund()
        if paid.kind == 'society' then Core.addSociety(paid.name, paid.amount, 'Vehicle purchase refund')
        elseif paid.kind then Core.give(buyer.src, paid.amount, paid.kind, 'Vehicle purchase refund') end
    end
    local down, term, quote = 0, nil, nil
    if payment == 'finance' then
        quote = banking.quote(buyer.src, price, opts.down, opts.term)
        if not quote then return false, 'no_finance' end
        if not quote.approved then return false, quote.reasons[1] or 'declined', quote end
        down, term = quote.down, quote.term
        if not Core.take(buyer.src, down, 'bank', ('Down payment %s'):format(Core.vehicleLabel(model))) then return false, 'no_money' end
        paid = { kind = 'bank', amount = down }
    elseif payment == 'society' then
        local group = buyer.job
        if not group.isboss or not Core.isJob(group.name) or group.name == 'unemployed' then return false, 'not_boss' end
        if not Core.removeSociety(group.name, price, ('Fleet purchase %s'):format(Core.vehicleLabel(model))) then return false, 'no_money' end
        paid = { kind = 'society', name = group.name, amount = price }
        fleet = 'job:' .. group.name
    else
        local kind = payment == 'cash' and 'cash' or 'bank'
        if not Core.take(buyer.src, price, kind, ('Vehicle purchase %s'):format(Core.vehicleLabel(model))) then return false, 'no_money' end
        paid = { kind = kind, amount = price }
    end
    local plate = garages.plate()
    if not plate then
        print('^1[vr-dealership] sale stopped: vr-garages could not make a plate (GeneratePlate export failed or returned nothing)^0')
        refund()
        return false, 'failed'
    end
    local loanId
    if payment == 'finance' then
        local ok, id = banking.create(buyer.src, price, down, term, plate, model)
        if not ok then refund() return false, id or 'declined' end
        loanId = id
    end
    local props = color and { color1 = color, color2 = color } or nil
    local added, addErr = garages.add(buyer.cid, model, { plate = plate, garage = dealer.garage or Config.DefaultGarage, props = props, fleet = fleet, license = buyer.license })
    if not added then
        print(('^1[vr-dealership] sale stopped: vr-garages AddVehicle refused %s for citizen %s (garage %q): %s^0'):format(tostring(model), tostring(buyer.cid), tostring(dealer.garage or Config.DefaultGarage), tostring(addErr)))
        if loanId then banking.cancel(loanId) end
        refund()
        return false, 'failed'
    end
    local seller = opts.seller
    local share = seller and S.societyPercent or Config.SelfService.societyPercent
    local commission = seller and pct(price, S.commissionPercent) or 0
    if Core.isJob(Config.Job) then Core.addSociety(Config.Job, pct(price, share), ('Sale of %s'):format(plate)) end
    if seller and commission > 0 then
        if not Core.give(seller.src, commission, 'bank', ('Commission %s'):format(plate)) then commission = 0 end
    end
    MySQL.insert('INSERT INTO vr_dealership_sales (dealer, model, plate, price, payment, buyer, buyer_name, seller, seller_name, commission, loan_id, at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { dealer.id, model, plate, price, payment or 'bank', buyer.cid, buyer.name, seller and seller.cid, seller and seller.name, commission, loanId, os.time() })
    local delivered = garages.spawn(buyer.src, plate, dealer.delivery)
    TriggerEvent('vr-dealership:server:sold', { dealer = dealer.id, model = model, plate = plate, price = price, payment = payment, buyer = buyer.cid, seller = seller and seller.cid, loanId = loanId })
    return true, { plate = plate, delivered = delivered, loanId = loanId, commission = commission, down = down, quote = quote }
end

function Sales.offer(seller, dealer, target, d)
    if not Sales.isStaff(seller) then return false, 'not_staff' end
    if not Dealers.near(dealer, seller.src) then return false, 'too_far' end
    target = tonumber(target)
    if not target or target == seller.src then return false, 'no_customer' end
    local buyer = Core.info(target)
    if not buyer then return false, 'no_customer' end
    local a, b = Core.coords(seller.src), Core.coords(target)
    if not a or not b or #(a - b) > S.offerDistance then return false, 'too_far' end
    if not Dealers.sells(dealer, d.model) then return false, 'not_sold_here' end
    local base = math.floor(Core.vehicle(d.model).price)
    local lo, hi = Sales.range(seller, base)
    local price = math.floor(tonumber(d.price) or base)
    if price < lo or price > hi then return false, 'bad_price', { min = lo, max = hi } end
    local payment = d.payment == 'finance' and 'finance' or 'full'
    local quote
    if payment == 'finance' then
        quote = banking.quote(target, price, d.down, d.term)
        if not quote then return false, 'no_finance' end
    end
    local token = ('%d-%d-%d'):format(target, seller.src, math.random(100000, 999999))
    Sales.offers[target] = {
        token = token, seller = seller.src, sellerCid = seller.cid, sellerName = seller.name, dealer = dealer.id,
        model = d.model, price = price, payment = payment, down = quote and quote.down or 0, term = quote and quote.term or nil,
        color = DU.colorOk(d.color), expires = os.time() + S.offerSeconds,
    }
    TriggerClientEvent('vr-dealership:client:offer', target, {
        token = token, dealer = dealer.label, seller = seller.firstName or seller.name, model = d.model, label = Core.vehicleLabel(d.model),
        price = price, base = base, payment = payment, color = DU.colorOk(d.color), seconds = S.offerSeconds,
        finance = quote and { approved = quote.approved, reasons = quote.reasons, down = quote.down, financed = quote.financed, rate = quote.rate,
            installment = quote.installment, term = quote.term, total = quote.total, intervalHours = quote.intervalHours, tier = quote.tier } or nil,
        cash = Core.money(target, 'cash'), bank = Core.money(target, 'bank'), colors = Config.Colors,
    })
    return true, { finance = quote and quote.approved, installment = quote and quote.installment or nil }
end

function Sales.respond(buyer, token, accept, method)
    local o = Sales.offers[buyer.src]
    if not o or o.token ~= token then return false, 'no_offer' end
    Sales.offers[buyer.src] = nil
    local function tell(text, kind) if GetPlayerName(o.seller) then Core.notify(o.seller, text, kind, 'Sales') end end
    if o.expires < os.time() then tell('The offer expired', 'error') return false, 'expired' end
    if not accept then tell(('%s declined the offer'):format(buyer.firstName or buyer.name), 'error') return true, { declined = true } end
    local dealer = Dealers.get(o.dealer)
    local seller = Core.info(o.seller)
    if not dealer or not seller or not Sales.isStaff(seller) then return false, 'no_seller' end
    if not Dealers.near(dealer, buyer.src, 10.0) then return false, 'too_far' end
    local payment = o.payment == 'finance' and 'finance' or (method == 'cash' and 'cash' or 'bank')
    local ok, res, extra = Sales.execute(buyer, dealer, o.model, o.price, { payment = payment, down = o.down, term = o.term, color = o.color, seller = seller })
    if not ok then
        tell(('The sale of the %s failed'):format(Core.vehicleLabel(o.model)), 'error')
        return false, res, extra
    end
    tell(('Sold the %s for $%s. Commission $%s'):format(Core.vehicleLabel(o.model), DU.money(o.price), DU.money(res.commission)), 'success')
    return true, res
end

function Sales.nearbyCustomers(seller, dealer)
    local out = {}
    local me = Core.coords(seller.src)
    if not me then return out end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src ~= seller.src then
            local pos = Core.coords(src)
            if pos and #(pos - me) <= S.offerDistance and #(pos - dealer.center) <= dealer.radius + 4.0 then
                out[#out + 1] = { id = src, distance = math.floor(#(pos - me) * 10) / 10 }
            end
        end
    end
    table.sort(out, function(a, b) return a.distance < b.distance end)
    return out
end
