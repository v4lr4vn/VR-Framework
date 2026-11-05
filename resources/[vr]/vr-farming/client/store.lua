Fm.actions.store = function(spot)
    local ok, data = Fm.call('store:list', spot.id)
    if not ok then return Fm.fail(data) end
    local id = ('vr-farming:store:%d'):format(spot.id)
    local sellTotal = 0
    for _, row in ipairs(data.sell or {}) do sellTotal = sellTotal + row.price * row.count end

    local buyId = id .. ':buy'
    local buy = {}
    for _, g in ipairs(data.goods or {}) do
        buy[#buy + 1] = {
            title = g.label,
            description = Fm.money(g.price) .. ' each',
            icon = g.seed and 'fa-solid fa-seedling' or 'fa-solid fa-toolbox',
            onSelect = function()
                local input = lib.inputDialog(g.label, {
                    { type = 'number', label = 'How many', description = Fm.money(g.price) .. ' each', default = 1, min = 1, max = 200, required = true },
                })
                if not input or not input[1] then return end
                local amount = math.floor(tonumber(input[1]) or 0)
                if amount < 1 then return end
                local good, res = Fm.call('store:buy', spot.id, g.item, amount)
                if not good then return Fm.fail(res) end
                Fm.notify(('Bought %dx %s for %s'):format(res.count, g.label, Fm.money(res.total)), 'success')
            end,
        }
    end
    lib.registerContext({ id = buyId, title = 'Buy', menu = id, options = buy })

    local options = {
        { title = 'Buy seeds and tools', description = ('You have %s'):format(Fm.money(data.cash or 0)), icon = 'fa-solid fa-cart-shopping', menu = buyId },
        {
            title = sellTotal > 0 and ('Sell everything · %s'):format(Fm.money(sellTotal)) or 'Sell everything',
            description = sellTotal > 0 and nil or 'You have no crops',
            icon = 'fa-solid fa-hand-holding-dollar',
            disabled = sellTotal == 0,
            onSelect = function()
                local good, res = Fm.call('store:sellAll', spot.id)
                if not good then return Fm.fail(res) end
                Fm.notify(('Sold %d items for %s'):format(res.pieces, Fm.money(res.total)), 'success')
            end,
        },
    }
    for _, row in ipairs(data.sell or {}) do
        options[#options + 1] = {
            title = ('%s · %s · %d'):format(row.label, row.tier, row.count),
            description = Fm.money(row.price) .. ' each',
            icon = 'fa-solid fa-wheat-awn',
            onSelect = function()
                local amount = row.count
                if row.count > 1 then
                    local input = lib.inputDialog(row.label, {
                        { type = 'number', label = 'How many', description = Fm.money(row.price) .. ' each', default = row.count, min = 1, max = row.count, required = true },
                    })
                    if not input or not input[1] then return end
                    amount = math.floor(tonumber(input[1]) or 0)
                end
                if amount < 1 then return end
                local good, res = Fm.call('store:sell', spot.id, row.item, row.quality, amount)
                if not good then return Fm.fail(res) end
                Fm.notify(('Sold %dx %s for %s'):format(res.count, row.label, Fm.money(res.total)), 'success')
            end,
        }
    end
    lib.registerContext({ id = id, title = spot.label, options = options })
    lib.showContext(id)
end
