local function rateFor(spot)
    return spot.rate or Config.Store.rate
end

local function access(src, spotId, kind)
    local who = Farm.info(src)
    if not who then return nil, nil, 'no_player' end
    local spot = Farm.spot(spotId)
    if not spot or spot.kind ~= (kind or 'store') then return nil, nil, 'bad_request' end
    if not Farm.near(src, spot) then return nil, nil, 'too_far' end
    return who, spot
end

local function label(item)
    return Bridge.inventory.label and Bridge.inventory.label(item) or item
end

-- Everything the store sells, in the order it is shown.
local function goods()
    local out = {}
    for name, crop in pairs(Config.Crops) do
        out[#out + 1] = { item = Farm.seedOf(name), label = (crop.label .. ' seeds'), price = crop.seedPrice, seed = true }
    end
    table.sort(out, function(a, b) return a.price < b.price or (a.price == b.price and a.item < b.item) end)
    local tools = {}
    for item, price in pairs(Config.Store.goods) do
        tools[#tools + 1] = { item = item, label = label(item), price = price }
    end
    table.sort(tools, function(a, b) return a.item < b.item end)
    for i = #tools, 1, -1 do table.insert(out, 1, tools[i]) end
    return out
end

local function priceOf(item)
    if Config.Store.goods[item] then return Config.Store.goods[item] end
    local name = item:match('^(.+)_seed$')
    if name and Config.Crops[name] then return Config.Crops[name].seedPrice end
    return nil
end

-- What this player carries that the store will buy: one row per crop and quality.
local function owned(src, spot)
    local out = {}
    for name, crop in pairs(Config.Crops) do
        for tier = 1, 3 do
            local n = Farm.count(src, name, { quality = tier })
            if n > 0 then
                local q = Config.Quality[tier]
                out[#out + 1] = {
                    item = name, quality = tier, tier = q.label, label = crop.label, count = n,
                    price = math.max(1, math.floor(crop.sell * q.price * rateFor(spot) + 0.5)),
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.price * a.count > b.price * b.count end)
    return out
end

lib.callback.register('vr-farming:store:list', function(src, spotId)
    local who, spot, err = access(src, spotId)
    if not who then return Farm.fail(err) end
    return { ok = true, data = { goods = goods(), sell = owned(src, spot), cash = Bridge.money(src, Config.Account) } }
end)

lib.callback.register('vr-farming:store:buy', function(src, spotId, item, amount)
    if Farm.throttle(src, 'buy', Config.Store.minGapMs) then return Farm.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Farm.fail(err) end
    if type(item) ~= 'string' then return Farm.fail('bad_request') end
    local price = priceOf(item)
    if not price then return Farm.fail('not_sold') end
    amount = Farm.num(amount)
    if not amount then return Farm.fail('bad_request') end
    amount = math.floor(amount)
    if amount < 1 or amount > 200 then return Farm.fail('bad_request') end
    if not Farm.canCarry(src, item, amount) then return Farm.fail('no_room') end
    local total = price * amount
    if not Farm.charge(src, total, 'Farm store') then return Farm.fail('no_money') end
    if not Farm.give(src, item, amount) then
        Farm.pay(src, total, 'Farm store refund')
        return Farm.fail('no_room')
    end
    if item == Config.Items.can and Farm.charges(who.cid) < 1 then Farm.setCharges(who.cid, 0) end
    TriggerEvent('vr-farming:bought', src, who.cid, item, amount, total, spot.id)
    return { ok = true, data = { item = item, count = amount, total = total } }
end)

local function sellRow(src, who, spot, item, tier, amount)
    local crop = Config.Crops[item]
    local q = Config.Quality[tier]
    if not crop or not q then return nil, 'not_wanted' end
    local have = Farm.count(src, item, { quality = tier })
    amount = math.min(amount, have)
    if amount < 1 then return nil, 'not_enough' end
    local price = math.max(1, math.floor(crop.sell * q.price * rateFor(spot) + 0.5))
    if not Farm.take(src, item, amount, { quality = tier }) then return nil, 'not_enough' end
    local total = price * amount
    if not Farm.pay(src, total, 'Farm store') then
        Farm.give(src, item, amount, { quality = tier })
        return nil, 'failed'
    end
    return { item = item, quality = tier, count = amount, total = total }
end

lib.callback.register('vr-farming:store:sell', function(src, spotId, item, tier, amount)
    if Farm.throttle(src, 'sell', Config.Store.minGapMs) then return Farm.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Farm.fail(err) end
    if type(item) ~= 'string' then return Farm.fail('bad_request') end
    tier, amount = math.floor(Farm.num(tier) or 0), Farm.num(amount)
    if not amount or tier < 1 or tier > 3 then return Farm.fail('bad_request') end
    amount = math.floor(amount)
    if amount < 1 then return Farm.fail('bad_request') end
    local sold, why = sellRow(src, who, spot, item, tier, amount)
    if not sold then return Farm.fail(why) end
    TriggerEvent('vr-farming:sold', src, who.cid, item, sold.count, sold.total, spot.id)
    return { ok = true, data = sold }
end)

lib.callback.register('vr-farming:store:sellAll', function(src, spotId)
    if Farm.throttle(src, 'sellall', 1500) then return Farm.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Farm.fail(err) end
    local total, pieces = 0, 0
    for _, row in ipairs(owned(src, spot)) do
        local sold = sellRow(src, who, spot, row.item, row.quality, row.count)
        if sold then
            total = total + sold.total
            pieces = pieces + sold.count
        end
    end
    if pieces == 0 then return Farm.fail('nothing') end
    TriggerEvent('vr-farming:sold', src, who.cid, 'all', pieces, total, spot.id)
    return { ok = true, data = { total = total, pieces = pieces } }
end)
