local function rateFor(spot)
    return spot.rate or Config.Pawn.rate
end

local function priceOf(spot, item)
    local base = Config.Pawn.items[item]
    if not base then return nil end
    return math.max(1, math.floor(base * rateFor(spot) + 0.5))
end

local function access(src, spotId)
    local who = Fence.info(src)
    if not who then return nil, nil, 'no_player' end
    local spot = Fence.spot(spotId)
    if not spot or spot.kind ~= 'pawn' then return nil, nil, 'bad_request' end
    if not Fence.near(src, spot) then return nil, nil, 'too_far' end
    return who, spot
end

local function owned(src, spot)
    local out = {}
    for item in pairs(Config.Pawn.items) do
        local n = Fence.count(src, item)
        if n > 0 then
            out[#out + 1] = { item = item, label = Bridge.inventory.label and Bridge.inventory.label(item) or item, count = n, price = priceOf(spot, item) }
        end
    end
    table.sort(out, function(a, b) return a.price * a.count > b.price * b.count end)
    return out
end

lib.callback.register('vr-fence:pawn:list', function(src, spotId)
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    return { ok = true, data = { items = owned(src, spot) } }
end)

lib.callback.register('vr-fence:pawn:sell', function(src, spotId, item, amount)
    if Fence.throttle(src, 'psell', Config.Pawn.minGapMs) then return Fence.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    if type(item) ~= 'string' then return Fence.fail('bad_request') end
    local price = priceOf(spot, item)
    if not price then return Fence.fail('not_wanted') end
    amount = Fence.num(amount)
    if not amount then return Fence.fail('bad_request') end
    amount = math.floor(amount)
    if amount < 1 then return Fence.fail('bad_request') end
    local have = Fence.count(src, item)
    if have < amount then return Fence.fail('not_enough') end
    if not Fence.take(src, item, amount) then return Fence.fail('not_enough') end
    local total = price * amount
    if not Fence.pay(src, total) then
        Fence.give(src, item, amount)
        return Fence.fail('failed')
    end
    TriggerEvent('vr-fence:sold', src, who.cid, item, amount, total, spot.id)
    return { ok = true, data = { item = item, count = amount, total = total } }
end)

lib.callback.register('vr-fence:pawn:sellAll', function(src, spotId)
    if Fence.throttle(src, 'psellall', 1500) then return Fence.fail('slow_down') end
    local who, spot, err = access(src, spotId)
    if not who then return Fence.fail(err) end
    local sold, total, pieces = {}, 0, 0
    for _, row in ipairs(owned(src, spot)) do
        local have = Fence.count(src, row.item)
        if have > 0 and Fence.take(src, row.item, have) then
            local value = row.price * have
            if Fence.pay(src, value) then
                total = total + value
                pieces = pieces + have
                sold[#sold + 1] = { item = row.item, count = have, total = value }
            else
                Fence.give(src, row.item, have)
            end
        end
    end
    if pieces == 0 then return Fence.fail('nothing') end
    TriggerEvent('vr-fence:sold', src, who.cid, 'all', pieces, total, spot.id)
    return { ok = true, data = { total = total, pieces = pieces, sold = sold } }
end)
