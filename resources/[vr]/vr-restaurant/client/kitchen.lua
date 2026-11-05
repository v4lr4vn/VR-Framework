-- The kitchen as players use it: opening the storage areas, ordering stock, cooking, the till,
-- and the menu and dish designer in the staff office.

local busy = false

local function pretty(item)
    return (tostring(item):gsub('_', ' '):gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end))
end
Rn.itemName = pretty

local function freshText(row)
    if row.spoiled then return 'Gone off' end
    if row.fresh then return ('%d%% fresh'):format(row.fresh) end
    return nil
end

local function confirm(header, content)
    return lib.alertDialog({ header = header, content = content, centered = true, cancel = true }) == 'confirm'
end

local function stationCall(id, action, a, b)
    local ok, data, extra = Rn.call('stationAct', id, action, a, b)
    if not ok then
        Rn.fail(data, extra)
        return false
    end
    return true, data
end

---------------------------------------------------------------------------
-- Storage areas open as a normal inventory. The only menus are for ordering stock and the counter's prices.
---------------------------------------------------------------------------

local lastOpen = -100000
local function openStash(s)
    -- A double click on the target must not show an error for the second press.
    local t = GetGameTimer()
    if t - lastOpen < 800 then return end
    lastOpen = t
    local ok, res, extra = Rn.call('openStash', s.id)
    if not ok and res ~= 'slow_down' then return Rn.fail(res, extra) end
end

local function orderStock(s)
    local options = {}
    for item, ing in pairs(Config.Ingredients) do
        if ing.price then options[#options + 1] = { label = ('%s · %s each'):format(pretty(item), Rn.money(ing.price)), value = item } end
    end
    table.sort(options, function(a, c) return a.label < c.label end)
    local input = lib.inputDialog('Order stock', {
        { type = 'select', label = 'Ingredient', options = options, required = true, searchable = true },
        { type = 'number', label = ('How many (up to %d). Paid from the business account'):format(Config.Wholesale.maxOrder), default = 10, min = 1, max = Config.Wholesale.maxOrder, required = true },
    })
    if input then
        local ok, res = stationCall(s.id, 'order', input[1], input[2])
        if ok then Rn.notify(('Delivered %d x %s to the fridge for %s'):format(res.count, pretty(res.item), Rn.money(res.cost)), 'success') end
    end
end

local function counterPrices(s)
    local ok, res = stationCall(s.id, 'prices')
    if not ok then return end
    local options = {}
    if #res.rows == 0 then
        options[#options + 1] = { title = 'Nothing on the counter right now', icon = 'fa-solid fa-box', readOnly = true }
    end
    for _, row in ipairs(res.rows) do
        local bits = { row.price and Rn.money(row.price) or 'Not for sale' }
        local fresh = freshText(row)
        if fresh then bits[#bits + 1] = fresh end
        options[#options + 1] = {
            title = ('%dx %s'):format(row.count, row.label), description = table.concat(bits, ' · '),
            icon = row.spoiled and 'fa-solid fa-biohazard' or 'fa-solid fa-tag', readOnly = true,
        }
    end
    local id = ('vr-restaurant:prices:%d'):format(s.id)
    lib.registerContext({ id = id, title = 'Counter prices', options = options })
    lib.showContext(id)
end

---------------------------------------------------------------------------
-- Cooking
---------------------------------------------------------------------------

local cooking = false
local openCook

local function cook(s, r, qty)
    if cooking then return end
    cooking = true
    local ok, res, extra = Rn.call('cookBegin', s.id, r.key, qty or 1)
    if not ok then
        cooking = false
        return Rn.fail(res, extra)
    end
    local done = lib.progressBar({
        duration = res.ms, label = res.qty > 1 and ('Making %dx %s'):format(res.qty, res.label) or ('Making %s'):format(res.label), useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_bbq@male@base', clip = 'base' },
    })
    if not done then
        lib.callback.await('vr-restaurant:cookCancel', false)
        cooking = false
        return Rn.notify('You stopped cooking', 'inform')
    end
    local fin, data, e = Rn.call('cookFinish', s.id, r.key)
    cooking = false
    if not fin then return Rn.fail(data, e) end
    if data.made then
        Rn.notify(('%s done: %s. Put it in the fridge'):format(data.label, data.made), 'success')
    elseif (data.qty or 1) > 1 then
        Rn.notify(('%dx %s are ready'):format(data.qty, data.label), 'success')
    else
        Rn.notify(('%s is ready'):format(data.label), 'success')
    end
end

function openCook(s)
    if busy then return end
    local ok, res, extra = Rn.call('cookList', s.id)
    if not ok then return Rn.fail(res, extra) end
    local options = {}
    if not res.duty then
        options[#options + 1] = { title = 'You are not clocked in', description = 'Use the staff office first', icon = 'fa-solid fa-clock', readOnly = true }
    elseif res.closed then
        options[#options + 1] = { title = 'The business is closed', icon = 'fa-solid fa-ban', readOnly = true }
    end
    if #res.recipes == 0 then
        options[#options + 1] = { title = 'Nothing can be made here yet', icon = 'fa-solid fa-utensils', readOnly = true }
    end
    for _, r in ipairs(res.recipes) do
        local need = {}
        for _, n in ipairs(r.needs) do
            need[#need + 1] = ('%s %d/%d'):format(n.label, math.min(n.have, n.need), n.need)
        end
        local text = #need > 0 and table.concat(need, ' · ') or 'No ingredients needed'
        if r.makes then text = ('Makes %s · %s'):format(r.makes, text) end
        if (r.max or 0) > 1 then text = ('%s · up to %d at once'):format(text, r.max) end
        options[#options + 1] = {
            title = r.prep and ('Prep: %s'):format(r.label) or r.label,
            description = text,
            icon = 'fa-solid fa-utensils',
            disabled = not r.can or not res.duty or res.closed,
            onSelect = function()
                CreateThread(function()
                    local qty = 1
                    if (r.max or 0) > 1 then
                        local input = lib.inputDialog(r.label, {
                            { type = 'number', label = ('How many to make (up to %d). More takes longer'):format(r.max), default = 1, min = 1, max = r.max, required = true },
                        })
                        if not input then return openCook(s) end
                        qty = math.max(1, math.min(r.max, math.floor(tonumber(input[1]) or 1)))
                    end
                    cook(s, r, qty)
                    openCook(s)
                end)
            end,
        }
    end
    local id = ('vr-restaurant:cook:%d'):format(s.id)
    lib.registerContext({ id = id, title = s.label ~= '' and s.label or 'Kitchen', options = options })
    lib.showContext(id)
end

---------------------------------------------------------------------------
-- The till
---------------------------------------------------------------------------

local function openTill(s)
    if busy then return end
    local ok, who, extra = Rn.call('stationAct', s.id, 'customers')
    if not ok then return Rn.fail(who, extra) end
    if #who.players == 0 then return Rn.notify('Nobody is close enough to the till', 'error') end
    local ok2, priced, e2 = Rn.call('stationAct', s.id, 'priced')
    if not ok2 then return Rn.fail(priced, e2) end
    if #priced.items == 0 then return Rn.notify('Nothing has a price yet. A manager sets prices in the staff office', 'error') end
    local people = {}
    for _, p in ipairs(who.players) do people[#people + 1] = { label = ('%s (id %d)'):format(p.name, p.src), value = p.src } end
    local rows = { { type = 'select', label = 'Customer', options = people, required = true } }
    for _, it in ipairs(priced.items) do
        rows[#rows + 1] = { type = 'number', label = ('%s · %s'):format(it.label, Rn.money(it.price)), default = 0, min = 0, max = 20 }
    end
    local input = lib.inputDialog('Ring up an order', rows)
    if not input then return end
    local lines = {}
    for i, it in ipairs(priced.items) do
        local n = tonumber(input[i + 1]) or 0
        if n > 0 then lines[#lines + 1] = { key = it.key, count = n } end
    end
    if #lines == 0 then return Rn.notify('Nothing was added to the order', 'error') end
    Rn.notify('Waiting for the customer to pay', 'inform')
    local sold, res = stationCall(s.id, 'serve', input[1], lines)
    if sold then Rn.notify(('%s paid %s. Put their order on the tray'):format(res.name, Rn.money(res.total)), 'success') end
end

-- A staff member asks you to pay.
local function askToPay(offer)
    if type(offer) ~= 'table' then return false end
    local answered = false
    CreateThread(function()
        Wait((tonumber(offer.seconds) or 30) * 1000)
        if not answered then pcall(lib.closeAlertDialog, 'cancel') end
    end)
    local lines = {}
    for _, l in ipairs(offer.lines or {}) do
        lines[#lines + 1] = ('%dx %s (%s)'):format(l.count, tostring(l.label), Rn.money(l.price))
    end
    local choice = lib.alertDialog({
        header = ('%s'):format(tostring(offer.business or 'Restaurant')),
        content = ('%s asks you to pay for:\n\n%s\n\n**Total: %s**'):format(tostring(offer.by or 'Staff'), table.concat(lines, '\n'), Rn.money(offer.total or 0)),
        centered = true, cancel = true, labels = { confirm = 'Pay', cancel = 'No thanks' },
    })
    answered = true
    return choice == 'confirm'
end

lib.callback.register('vr-restaurant:charge', function(offer)
    local ok, answer = pcall(askToPay, offer)
    if not ok then
        print(('^1[vr-restaurant] could not show the payment offer: %s^0'):format(tostring(answer)))
        return nil
    end
    return answer
end)

---------------------------------------------------------------------------
-- Target options for each kind of area
---------------------------------------------------------------------------

function Rn.stationOptions(s, info, label)
    local base = ('vr-restaurant:station:%d'):format(s.id)
    local staffOnly = function() return not busy and not cooking and Rn.mine == s.business end
    local anyone = function() return not busy and not cooking end
    local function option(suffix, text, icon, can, fn)
        return { name = base .. ':' .. suffix, label = text, icon = icon or info.icon, distance = s.radius + 1.5, canInteract = can, onSelect = function() CreateThread(fn) end }
    end
    if info.cook then
        return { option('use', ('Cook · %s'):format(label), nil, staffOnly, function() openCook(s) end) }
    elseif s.kind == 'fridge' then
        return {
            option('open', ('Open · %s'):format(label), nil, staffOnly, function() openStash(s) end),
            option('order', 'Order stock', 'fa-solid fa-truck-ramp-box', staffOnly, function() orderStock(s) end),
        }
    elseif s.kind == 'hotbox' then
        return { option('open', ('Open · %s'):format(label), nil, staffOnly, function() openStash(s) end) }
    elseif s.kind == 'tray' then
        return { option('open', ('Open · %s'):format(label), nil, anyone, function() openStash(s) end) }
    elseif s.kind == 'counter' then
        return {
            option('open', ('Open · %s'):format(label), nil, anyone, function() openStash(s) end),
            option('prices', 'View prices', 'fa-solid fa-tags', anyone, function() counterPrices(s) end),
        }
    elseif s.kind == 'till' then
        return { option('use', ('Till · %s'):format(label), nil, staffOnly, function() openTill(s) end) }
    end
    return {}
end

---------------------------------------------------------------------------
-- Menu and dish designer (staff office)
---------------------------------------------------------------------------

local MENU = 'vr-restaurant:menu'

local function needsText(needs)
    local out = {}
    for _, n in ipairs(needs) do out[#out + 1] = ('%s x%d'):format(n.label ~= '' and n.label or pretty(n.item), n.need) end
    return table.concat(out, ', ')
end

local function stationName(kind)
    for _, k in ipairs(Config.Stations) do
        if k.id == kind then return k.label end
    end
    return kind
end

local function dishDialog(d, dish)
    local kinds, ingredients = {}, {}
    for _, k in ipairs(Config.Stations) do
        if k.cook then kinds[#kinds + 1] = { label = ('%s (%s)'):format(k.label, k.drinks and 'drink' or 'food'), value = k.id } end
    end
    for item in pairs(Config.Ingredients) do ingredients[#ingredients + 1] = { label = pretty(item), value = item } end
    table.sort(ingredients, function(a, c) return a.label < c.label end)
    local rows = {
        { type = 'input', label = 'Dish name', default = dish and dish.label or '', required = true, max = 32 },
        { type = 'select', label = 'Made at (bar, dispenser and brewing make drinks)', options = kinds, default = dish and dish.station or 'hob', required = true },
    }
    if Config.Images and Config.Images.enabled ~= false then
        rows[#rows + 1] = { type = 'input', label = 'Picture link (optional)', description = 'A direct link to an image, e.g. from imgur or Discord. Leave empty for the default picture', default = dish and dish.image or '', max = Config.Images.maxLength or 250 }
    end
    local imageRow = (Config.Images and Config.Images.enabled ~= false) and #rows or nil
    for i = 1, Config.Cook.maxIngredients do
        local have = dish and dish.needs[i]
        rows[#rows + 1] = { type = 'select', label = ('Ingredient %d'):format(i), options = ingredients, default = have and have.item or nil, clearable = true, searchable = true }
        rows[#rows + 1] = { type = 'number', label = ('Amount %d (1 to %d)'):format(i, Config.Cook.maxPerIngredient), default = have and have.need or 1, min = 1, max = Config.Cook.maxPerIngredient }
    end
    local input = lib.inputDialog(dish and ('Edit %s'):format(dish.label) or 'Design a dish', rows)
    if not input then return nil end
    local items = {}
    local off = imageRow and 1 or 0
    for i = 1, Config.Cook.maxIngredients do
        local item = input[2 + off + i * 2 - 1]
        if item and item ~= '' then items[#items + 1] = { item = item, count = tonumber(input[2 + off + i * 2]) or 1 } end
    end
    return { id = dish and dish.id or nil, label = input[1], station = input[2], items = items, image = imageRow and (input[imageRow] or '') or nil }
end

function Rn.openMenu(id, sub)
    local ok, d, extra = Rn.call('act', id, 'menu')
    if not ok then return Rn.fail(d, extra) end
    local reopen = function(s) CreateThread(function() Rn.openMenu(id, s) end) end
    local act = function(action, a, b)
        local good, data, e = Rn.call('act', id, action, a, b)
        if not good then Rn.fail(data, e) return false end
        return true, data
    end

    -- prices
    local prices = {}
    for _, it in ipairs(d.items) do
        prices[#prices + 1] = {
            title = it.label,
            description = ('%s · %s · %s'):format(it.price > 0 and Rn.money(it.price) or 'Not on the menu', stationName(it.station), needsText(it.needs)),
            icon = it.price > 0 and 'fa-solid fa-tag' or 'fa-regular fa-circle',
            onSelect = function()
                local input = lib.inputDialog(it.label, { { type = 'number', label = ('Price (0 takes it off the menu, up to %s)'):format(Rn.money(d.maxPrice)), default = it.price, min = 0, max = d.maxPrice, required = true } })
                if input then act('price', it.key, input[1]) end
                reopen('prices')
            end,
        }
    end
    if #prices == 0 then
        prices[1] = { title = 'No dishes or drinks yet', description = 'Design your own, or add the starter dishes, under Our dishes', icon = 'fa-solid fa-bowl-food', readOnly = true }
    end
    lib.registerContext({ id = MENU .. ':prices', title = 'Menu prices', menu = MENU, options = prices })

    -- designed dishes
    local dishes = {
        {
            title = 'Design a dish or drink', description = ('%d of %d used. Combine ingredients into your own'):format(#d.dishes, d.maxDishes), icon = 'fa-solid fa-plus',
            onSelect = function()
                local data = dishDialog(d, nil)
                if data and act('dishsave', data) then Rn.notify('Created. Set its price under Menu prices', 'success') end
                reopen('dishes')
            end,
        },
        {
            title = 'Add starter dishes', description = 'Burger, fries, sandwich, tosti and drinks, ready to edit', icon = 'fa-solid fa-wand-magic-sparkles',
            onSelect = function()
                local ok, res = act('starters')
                if ok then Rn.notify(('Added %d dishes. Set their prices under Menu prices'):format(res.added), 'success') end
                reopen('dishes')
            end,
        },
    }
    for _, dish in ipairs(d.dishes) do
        local sub2 = ('%s:dish:%d'):format(MENU, dish.id)
        lib.registerContext({
            id = sub2, title = dish.label, menu = MENU .. ':dishes',
            options = {
                { title = ('%s · %s'):format(dish.kind == 'drink' and 'Drink' or 'Food', stationName(dish.station)), description = needsText(dish.needs), icon = 'fa-solid fa-bowl-food', readOnly = true },
                { title = dish.image ~= '' and 'Has a picture' or 'No picture set', description = dish.image ~= '' and dish.image or 'Add one with Edit', icon = 'fa-solid fa-image', readOnly = true },
                {
                    title = 'Edit', icon = 'fa-solid fa-pen',
                    onSelect = function()
                        local data = dishDialog(d, dish)
                        if data and act('dishsave', data) then Rn.notify('Saved', 'success') end
                        reopen('dishes')
                    end,
                },
                {
                    title = 'Delete', description = 'Ones already made can still be eaten', icon = 'fa-solid fa-trash',
                    onSelect = function()
                        if confirm('Delete ' .. dish.label, 'It comes off the menu and cannot be cooked any more.') then act('dishdel', dish.id) end
                        reopen('dishes')
                    end,
                },
            },
        })
        dishes[#dishes + 1] = { title = dish.label, description = ('%s · %s'):format(stationName(dish.station), needsText(dish.needs)), icon = 'fa-solid fa-bowl-food', menu = sub2, arrow = true }
    end
    lib.registerContext({ id = MENU .. ':dishes', title = 'Our dishes', menu = MENU, options = dishes })

    lib.registerContext({
        id = MENU, title = 'Menu and dishes', menu = 'vr-restaurant:office',
        options = {
            { title = 'Menu prices', description = 'What each of your dishes and drinks sells for', icon = 'fa-solid fa-tags', menu = MENU .. ':prices', arrow = true },
            { title = 'Our dishes and drinks', description = 'Design your own from ingredients', icon = 'fa-solid fa-bowl-food', menu = MENU .. ':dishes', arrow = true },
        },
    })
    lib.showContext(sub and (MENU .. ':' .. sub) or MENU)
end
