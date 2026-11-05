-- The kitchen: recipes and designed dishes, the menu, cooking, the till and wholesale orders.
-- Storage areas (fridge, hot box, tray, counter) are inventory stashes, see storage.lua.

local inv = Bridge.inventory
Rest.menu = {}
Rest.dishes = {}

local function now() return os.time() end

local function kindInfo(id) return Rest.kindInfo(id) end

local perm = Rest.perm
local dishKey, isIngredient, itemLabel = Rest.dishKey, Rest.isIngredient, Rest.itemLabel
local context, needDuty = Rest.context, Rest.needDuty

---------------------------------------------------------------------------
-- Names and keys
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Schema and loading
---------------------------------------------------------------------------

local MENU = [[CREATE TABLE IF NOT EXISTS `vr_rest_menu` (
    `business` INT UNSIGNED NOT NULL,
    `dish` VARCHAR(40) NOT NULL,
    `price` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`business`, `dish`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local DISHES = [[CREATE TABLE IF NOT EXISTS `vr_rest_dishes` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `business` INT UNSIGNED NOT NULL,
    `label` VARCHAR(32) NOT NULL,
    `station` VARCHAR(16) NOT NULL,
    `items` TEXT NOT NULL,
    `image` VARCHAR(255) NOT NULL DEFAULT '',
    PRIMARY KEY (`id`),
    KEY `business` (`business`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local function decode(text)
    local ok, v = pcall(json.decode, text or '{}')
    return (ok and type(v) == 'table') and v or {}
end

Rest.onReady(function()
    local ok, err = pcall(function()
        MySQL.query.await(MENU)
        MySQL.query.await(DISHES)
        MySQL.query.await("ALTER TABLE `vr_rest_dishes` ADD COLUMN IF NOT EXISTS `image` VARCHAR(255) NOT NULL DEFAULT ''")
    end)
    if not ok then print(('^1[vr-restaurant] kitchen schema: %s^0'):format(tostring(err))) return end
    for _, r in ipairs(MySQL.query.await('SELECT business, dish, price FROM vr_rest_menu') or {}) do
        Rest.menu[r.business] = Rest.menu[r.business] or {}
        Rest.menu[r.business][r.dish] = tonumber(r.price) or 0
    end
    for _, r in ipairs(MySQL.query.await('SELECT id, business, label, station, items, image FROM vr_rest_dishes') or {}) do
        Rest.dishes[r.business] = Rest.dishes[r.business] or {}
        Rest.dishes[r.business][r.id] = { id = r.id, business = r.business, label = r.label, station = r.station, items = decode(r.items), image = r.image or '' }
    end
end)

---------------------------------------------------------------------------
-- Recipes and dishes
---------------------------------------------------------------------------

local function cookKind(kind)
    local k = kindInfo(kind)
    return k ~= nil and k.cook == true
end

local function nutritionOf(items)
    local h, t = 0, 0
    for item, n in pairs(items) do
        local ing = Config.Ingredients[item]
        if ing then
            h = h + (ing.hunger or 0) * n
            t = t + (ing.thirst or 0) * n
        end
    end
    return math.min(60, h), math.min(60, t)
end

-- Whether a dish is food or a drink depends on where it is made: bar, dispenser and brewing make drinks.
local function dishKind(items, station)
    local h, t = nutritionOf(items)
    local k = kindInfo(station)
    return (k and k.drinks) and 'drink' or 'food', h, t
end

local function dishOf(b, key)
    local id = type(key) == 'string' and tonumber(key:match('^d(%d+)$'))
    local d = id and Rest.dishes[b.id] and Rest.dishes[b.id][id]
    return d
end

-- Everything one recipe needs to be made: a prep step (one ingredient into another) or a designed dish.
local function defOf(b, key)
    local r = type(key) == 'string' and Config.Recipes[key]
    if r then
        local ing = Config.Ingredients[r.out] or {}
        return { key = key, label = r.label, station = r.station, needs = r.needs, ms = r.ms, life = ing.life, item = r.out, count = r.count or 1, prep = true, custom = false }
    end
    local d = dishOf(b, key)
    if d then
        local n = 0
        for _ in pairs(d.items) do n = n + 1 end
        return {
            key = key, label = d.label, station = d.station, needs = d.items, custom = true, id = d.id,
            ms = Config.Cook.baseMs + Config.Cook.extraMs * n, life = Config.Cook.dishLifeMinutes, item = 'rd_' .. d.id, image = d.image,
        }
    end
end
Rest.dishDef = defOf

local function needsList(needs)
    local out = {}
    for item, n in pairs(needs) do out[#out + 1] = { item = item, need = n, label = itemLabel(item) } end
    table.sort(out, function(a, c) return a.item < c.item end)
    return out
end

local function recipesAt(b, kind)
    local out = {}
    for key, r in pairs(Config.Recipes) do
        if r.station == kind then out[#out + 1] = defOf(b, key) end
    end
    for _, d in pairs(Rest.dishes[b.id] or {}) do
        if d.station == kind then out[#out + 1] = defOf(b, 'd' .. d.id) end
    end
    table.sort(out, function(a, c) return a.label:lower() < c.label:lower() end)
    return out
end

local function register(d)
    local kind, h, t = dishKind(d.items, d.station)
    local ok = RestConsume and RestConsume.save('rd_' .. d.id, { type = kind, label = d.label, hunger = h > 0 and h or nil, thirst = t > 0 and t or nil, time = { 4000, 5000 } })
    return ok
end


-- A picture link for a dish: '' clears it, nil means the link is not allowed.
function Rest.imageUrl(text)
    local cfg = Config.Images or {}
    if text == nil then return '' end
    if type(text) ~= 'string' then return nil end
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if text == '' then return '' end
    if cfg.enabled == false then return nil end
    if #text > (cfg.maxLength or 250) then return nil end
    if text:find('[%c%s"\'<>\\]') then return nil end
    local host, rest = text:match('^https://([%w%.%-]+)(/[^#]*)$')
    if not host then return nil end
    host = host:lower()
    if not cfg.allowAny then
        local good = false
        for _, h in ipairs(cfg.hosts or {}) do
            h = h:lower()
            if host == h or (#host > #h and host:sub(-#h - 1) == '.' .. h) then good = true break end
        end
        if not good then return nil end
    end
    local path = rest:match('^([^?]*)')
    local ext = path:match('%.(%w+)$')
    if not ext then return nil end
    ext = ext:lower()
    for _, e in ipairs(cfg.extensions or {}) do if e == ext then return text end end
    return nil
end

local function cleanDish(b, data, existing)
    if type(data) ~= 'table' then return nil, 'bad_request' end
    local label = Rest.text(data.label, 2, 32)
    if not label then return nil, 'bad_value' end
    for _, d in pairs(Rest.dishes[b.id] or {}) do
        if d ~= existing and d.label:lower() == label:lower() then return nil, 'name_taken' end
    end
    for _, r in pairs(Config.Recipes) do
        if r.label:lower() == label:lower() then return nil, 'name_taken' end
    end
    if type(data.station) ~= 'string' or not cookKind(data.station) then return nil, 'bad_value' end
    local items, n = {}, 0
    for _, line in ipairs(type(data.items) == 'table' and data.items or {}) do
        if type(line) ~= 'table' or type(line.item) ~= 'string' or not Config.Ingredients[line.item] then return nil, 'bad_value' end
        local count = Rest.int(line.count, 1, Config.Cook.maxPerIngredient)
        if not count or items[line.item] then return nil, 'bad_value' end
        items[line.item] = count
        n = n + 1
        if n > Config.Cook.maxIngredients then return nil, 'too_many_ingredients' end
    end
    if n == 0 then return nil, 'bad_value' end
    local kind, h, t = dishKind(items, data.station)
    if (kind == 'drink' and t <= 0) or (kind == 'food' and h <= 0) then return nil, 'no_nutrition', { kind = kind } end
    local image
    if data.image == nil and existing then image = existing.image or '' else image = Rest.imageUrl(data.image) end
    if image == nil then return nil, 'bad_image' end
    return { label = label, station = data.station, items = items, image = image }
end

local ACT = Rest.ACT

ACT.menu = function(who, b, role)
    if not perm(role, 'menu') then return nil, 'no_permission' end
    local out = { dishes = {}, maxDishes = Config.Cook.maxDishes, maxPrice = Config.Cook.maxPrice }
    local prices = Rest.menu[b.id] or {}
    for _, d in pairs(Rest.dishes[b.id] or {}) do
        local key = 'd' .. d.id
        local kind = dishKind(d.items, d.station)
        out.dishes[#out.dishes + 1] = { key = key, label = d.label, station = d.station, price = prices[key] or 0, custom = true, id = d.id, kind = kind, needs = needsList(d.items), image = d.image or '' }
    end
    table.sort(out.dishes, function(a, c) return a.label:lower() < c.label:lower() end)
    out.items = out.dishes
    return out
end

ACT.price = function(who, b, role, key, price)
    if not perm(role, 'menu') then return nil, 'no_permission' end
    if not defOf(b, key) then return nil, 'not_found' end
    local p = Rest.int(price, 0, Config.Cook.maxPrice)
    if not p then return nil, 'bad_value', { max = Config.Cook.maxPrice } end
    Rest.menu[b.id] = Rest.menu[b.id] or {}
    if p == 0 then
        Rest.menu[b.id][key] = nil
        MySQL.query('DELETE FROM vr_rest_menu WHERE business = ? AND dish = ?', { b.id, key })
    else
        Rest.menu[b.id][key] = p
        MySQL.query('INSERT INTO vr_rest_menu (business, dish, price) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE price = VALUES(price)', { b.id, key, p })
    end
    return { key = key, price = p }
end

ACT.dishsave = function(who, b, role, data)
    if not perm(role, 'menu') then return nil, 'no_permission' end
    local existing = type(data) == 'table' and data.id and Rest.dishes[b.id] and Rest.dishes[b.id][tonumber(data.id) or -1] or nil
    if type(data) == 'table' and data.id and not existing then return nil, 'not_found' end
    local count = 0
    for _ in pairs(Rest.dishes[b.id] or {}) do count = count + 1 end
    if not existing and count >= Config.Cook.maxDishes then return nil, 'too_many_dishes' end
    local clean, err = cleanDish(b, data, existing)
    if not clean then return nil, err end
    Rest.dishes[b.id] = Rest.dishes[b.id] or {}
    if existing then
        existing.label, existing.station, existing.items, existing.image = clean.label, clean.station, clean.items, clean.image
        MySQL.query('UPDATE vr_rest_dishes SET label = ?, station = ?, items = ?, image = ? WHERE id = ?', { existing.label, existing.station, json.encode(existing.items), existing.image, existing.id })
        register(existing)
        return { id = existing.id, key = 'd' .. existing.id }
    end
    local id = MySQL.insert.await('INSERT INTO vr_rest_dishes (business, label, station, items, image) VALUES (?, ?, ?, ?, ?)', { b.id, clean.label, clean.station, json.encode(clean.items), clean.image })
    if not id then return nil, 'failed' end
    local d = { id = id, business = b.id, label = clean.label, station = clean.station, items = clean.items, image = clean.image }
    Rest.dishes[b.id][id] = d
    if not register(d) then
        Rest.dishes[b.id][id] = nil
        MySQL.query('DELETE FROM vr_rest_dishes WHERE id = ?', { id })
        return nil, 'failed'
    end
    return { id = id, key = 'd' .. id }
end

ACT.dishdel = function(who, b, role, id)
    if not perm(role, 'menu') then return nil, 'no_permission' end
    local d = Rest.dishes[b.id] and Rest.dishes[b.id][tonumber(id) or -1]
    if not d then return nil, 'not_found' end
    Rest.dishes[b.id][d.id] = nil
    MySQL.query('DELETE FROM vr_rest_dishes WHERE id = ?', { d.id })
    if Rest.menu[b.id] then
        Rest.menu[b.id]['d' .. d.id] = nil
        MySQL.query('DELETE FROM vr_rest_menu WHERE business = ? AND dish = ?', { b.id, 'd' .. d.id })
    end
    return { id = d.id }
end

---------------------------------------------------------------------------
-- Adds the starter dishes the business does not have yet.
ACT.starters = function(who, b, role)
    if not perm(role, 'menu') then return nil, 'no_permission' end
    local have = {}
    for _, d in pairs(Rest.dishes[b.id] or {}) do have[d.label:lower()] = true end
    local added, skipped = 0, 0
    for _, st in ipairs(Config.Starters or {}) do
        if have[st.label:lower()] then
            skipped = skipped + 1
        else
            local lines = {}
            for item, n in pairs(st.items) do lines[#lines + 1] = { item = item, count = n } end
            table.sort(lines, function(a, c) return a.item < c.item end)
            local data, err = ACT.dishsave(who, b, role, { label = st.label, station = st.station, items = lines })
            if data then
                added = added + 1
            elseif err == 'too_many_dishes' then
                if added == 0 then return nil, err end
                break
            else
                skipped = skipped + 1
            end
        end
    end
    if added == 0 then return nil, 'nothing_to_add' end
    return { added = added, skipped = skipped }
end

---------------------------------------------------------------------------
-- Ordering stock, the counter's prices and the till
---------------------------------------------------------------------------

local SA = {}

-- Wholesale stock goes straight into the fridge being used. Paid from the business account.
SA.order = function(who, s, b, role, item, count)
    if s.kind ~= 'fridge' then return nil, 'bad_request' end
    if not perm(role, 'money') then return nil, 'no_permission' end
    local ing = type(item) == 'string' and Config.Ingredients[item]
    if not ing or not ing.price then return nil, 'not_found' end
    count = Rest.int(count, 1, Config.Wholesale.maxOrder)
    if not count then return nil, 'bad_value', { max = Config.Wholesale.maxOrder } end
    local cost = ing.price * count
    if Rest.bank.balance(b) < cost then return nil, 'not_enough_in_account' end
    local meta = {}
    if ing.life then meta.durability = Rest.expiryFor(ing.life) meta.degrade = ing.life end
    if not inv.canCarry(Rest.stashId(s.id), item, count, meta) then return nil, 'storage_full' end
    if not Rest.bank.remove(b, cost) then return nil, 'not_enough_in_account' end
    if not Rest.deliver(s, item, count, meta) then
        Rest.bank.add(b, cost)
        return nil, 'storage_full'
    end
    return { item = item, count = count, cost = cost }
end

-- What is on the counter and what it costs. Anyone standing at an open counter can look.
SA.prices = function(who, s, b, role)
    if s.kind ~= 'counter' then return nil, 'bad_request' end
    if Rest.isClosed(b) and not Rest.staffAllowed(s, role) then return nil, 'closed' end
    return { rows = Rest.counterPrices(s, b) }
end

-- Players near a till who could be charged.
SA.customers = function(who, s, b, role)
    if s.kind ~= 'till' then return nil, 'bad_request' end
    if not perm(role, 'till') then return nil, 'no_permission' end
    local blocked = needDuty(who, b)
    if blocked then return nil, blocked end
    local out = {}
    for _, other in ipairs(Bridge.sources()) do
        if other ~= who.src then
            local p = Rest.info(other)
            local d = p and Rest.distance(other, s.x, s.y, s.z)
            if p and d and d <= Config.Till.range then out[#out + 1] = { src = other, name = p.name } end
        end
    end
    table.sort(out, function(a, c) return a.name < c.name end)
    return { players = out }
end

-- What the till can sell: everything on the menu with a price.
SA.priced = function(who, s, b, role)
    if s.kind ~= 'till' then return nil, 'bad_request' end
    if not perm(role, 'till') then return nil, 'no_permission' end
    local out = {}
    for key, price in pairs(Rest.menu[b.id] or {}) do
        local def = defOf(b, key)
        if def and price > 0 then out[#out + 1] = { key = key, label = def.label, price = price } end
    end
    table.sort(out, function(a, c) return a.label:lower() < c.label:lower() end)
    return { items = out }
end

local charging = {}

local serveInner

SA.serve = function(who, s, b, role, target, lines)
    local data, err, extra = serveInner(who, s, b, role, target, lines)
    if not data and err and err ~= 'declined' and err ~= 'no_answer' then
        print(('^3[vr-restaurant] till: %s could not ring up an order: %s^0'):format(who.name, tostring(err)))
    end
    return data, err, extra
end

serveInner = function(who, s, b, role, target, lines)
    if s.kind ~= 'till' then return nil, 'bad_request' end
    if not perm(role, 'till') then return nil, 'no_permission' end
    local blocked = needDuty(who, b)
    if blocked then return nil, blocked end
    target = Rest.int(target, 1, 65535)
    if not target or target == who.src then return nil, 'bad_value' end
    local other = Rest.info(target)
    if not other then return nil, 'not_found' end
    local d = Rest.distance(target, s.x, s.y, s.z)
    if not d or d > Config.Till.range then return nil, 'too_far' end
    if type(lines) ~= 'table' or #lines == 0 or #lines > Config.Till.maxLines then return nil, 'bad_value' end
    local prices = Rest.menu[b.id] or {}
    local total, shown = 0, {}
    for _, line in ipairs(lines) do
        local key = type(line) == 'table' and line.key
        local count = type(line) == 'table' and Rest.int(line.count, 1, 50)
        local def = key and defOf(b, key)
        if not def or not count then return nil, 'bad_value' end
        local price = prices[key]
        if not price or price <= 0 then return nil, 'not_priced' end
        total = total + price * count
        shown[#shown + 1] = { label = def.label, count = count, price = price }
    end
    if total > Config.Till.maxTotal then return nil, 'bad_value' end
    if charging[target] then return nil, 'busy' end
    charging[target] = true
    local accepted = lib.callback.await('vr-restaurant:charge', target, { business = b.label, by = who.name, lines = shown, total = total, seconds = Config.Till.askSeconds })
    charging[target] = nil
    -- nil means the customer's game never answered (no offer box was shown); false means they said no
    if accepted == nil then
        print(('^3[vr-restaurant] till: %s (id %d) did not answer the payment offer from %s. Check their F8 console^0'):format(other.name, target, who.name))
        return nil, 'no_answer'
    end
    if accepted ~= true then return nil, 'declined' end
    if not Bridge.pay(target, total, ('%s: order'):format(b.label)) then
        Rest.notify(target, 'You could not afford that', 'error')
        return nil, 'customer_no_money'
    end
    Rest.bank.add(b, total)
    Rest.notify(target, ('Paid $%d to %s'):format(total, b.label), 'success')
    return { total = total, name = other.name }
end

lib.callback.register('vr-restaurant:stationAct', function(src, sid, action, a, c)
    if Rest.throttle(src, 'station', Config.Cook.minGapMs) then return Rest.fail('slow_down') end
    local who, s, b, role = context(src, sid)
    if not who then return Rest.fail(s) end
    local fn = type(action) == 'string' and SA[action]
    if not fn then return Rest.fail('bad_request') end
    local data, err, extra = fn(who, s, b, role, a, c)
    if not data then return Rest.fail(err or 'failed', extra) end
    return { ok = true, data = data }
end)

---------------------------------------------------------------------------
-- Cooking
---------------------------------------------------------------------------

local cooking = {}

-- How long a batch takes: the first one in full, each extra one a share of that.
local function batchMs(def, qty)
    local ms = def.ms * (1 + Config.Cook.batchFactor * (qty - 1))
    return math.floor(math.min(ms, Config.Cook.maxMs))
end

-- How many can be made from what is in the fridges.
local function mostMakeable(b, def)
    local most = Config.Cook.maxBatch
    for item, n in pairs(def.needs) do
        most = math.min(most, math.floor(Rest.stockOf(b, item) / n))
    end
    return math.max(0, most)
end

local function canCook(src, sid, key, qty)
    local who, s, b, role = context(src, sid)
    if not who then return nil, s end
    if not cookKind(s.kind) then return nil, 'bad_request' end
    if not perm(role, 'cook') then return nil, 'no_permission' end
    local blocked = needDuty(who, b)
    if blocked then return nil, blocked end
    local def = defOf(b, key)
    if not def or def.station ~= s.kind then return nil, 'not_found' end
    qty = Rest.int(qty or 1, 1, Config.Cook.maxBatch)
    if not qty then return nil, 'bad_value', { max = Config.Cook.maxBatch } end
    for item, n in pairs(def.needs) do
        if Rest.stockOf(b, item) < n * qty then return nil, 'missing_ingredients', { item = item, label = itemLabel(item) } end
    end
    return { who = who, s = s, b = b, def = def, qty = qty }
end

lib.callback.register('vr-restaurant:cookList', function(src, sid)
    local who, s, b, role = context(src, sid)
    if not who then return Rest.fail(s) end
    if not cookKind(s.kind) then return Rest.fail('bad_request') end
    if not perm(role, 'cook') then return Rest.fail('no_permission') end
    local out = {}
    for _, def in ipairs(recipesAt(b, s.kind)) do
        local lines = {}
        for _, l in ipairs(needsList(def.needs)) do
            lines[#lines + 1] = { item = l.item, label = l.label, need = l.need, have = Rest.stockOf(b, l.item) }
        end
        local most = mostMakeable(b, def)
        out[#out + 1] = {
            key = def.key, label = def.label, ms = def.ms, custom = def.custom, prep = def.prep,
            makes = def.prep and ('%dx %s'):format(def.count, itemLabel(def.item)) or nil,
            needs = lines, can = most >= 1, max = most, price = (Rest.menu[b.id] or {})[def.key],
        }
    end
    return { ok = true, data = { recipes = out, duty = Rest.duty[who.cid] == b.id, closed = Rest.isClosed(b) and true or false, maxBatch = Config.Cook.maxBatch } }
end)

lib.callback.register('vr-restaurant:cookBegin', function(src, sid, key, qty)
    if Rest.throttle(src, 'cook', Config.Cook.minGapMs) then return Rest.fail('slow_down') end
    local ok, err, extra = canCook(src, sid, key, qty)
    if not ok then return Rest.fail(err, extra) end
    local ms = batchMs(ok.def, ok.qty)
    cooking[src] = { sid = tonumber(sid), key = key, qty = ok.qty, at = GetGameTimer(), ms = ms }
    return { ok = true, data = { ms = ms, label = ok.def.label, qty = ok.qty } }
end)

lib.callback.register('vr-restaurant:cookFinish', function(src, sid, key)
    local job = cooking[src]
    cooking[src] = nil
    if not job or job.sid ~= tonumber(sid) or job.key ~= key then return Rest.fail('bad_request') end
    if GetGameTimer() - job.at < job.ms * 0.8 then return Rest.fail('bad_request') end
    local ok, err, extra = canCook(src, sid, key, job.qty)
    if not ok then return Rest.fail(err, extra) end
    local def, b, qty = ok.def, ok.b, ok.qty
    local meta = def.prep and {} or { dish = def.key, business = b.id }
    if def.image and def.image ~= '' and Config.Images and Config.Images.enabled ~= false then meta.imageurl = def.image end
    if def.life then
        meta.durability = Rest.expiryFor(def.life)
        meta.degrade = def.life
    end
    local given
    if def.prep then
        local total = def.count * qty
        given = inv.canCarry(src, def.item, total, meta) and inv.add(src, def.item, total, meta)
    else
        given = RestConsume and RestConsume.give(src, def.item, qty, meta)
    end
    if not given then return Rest.fail('no_room') end
    for item, n in pairs(def.needs) do Rest.takeStock(b, item, n * qty) end
    Rest.addMess(b.id, (def.prep and Config.Cook.prepMess or Config.Cook.mess) * (1 + (qty - 1) * 0.5))
    return { ok = true, data = { label = def.label, qty = qty, made = def.prep and ('%dx %s'):format(def.count * qty, itemLabel(def.item)) or nil } }
end)

lib.callback.register('vr-restaurant:cookCancel', function(src)
    cooking[src] = nil
    return true
end)

AddEventHandler('playerDropped', function() cooking[source] = nil charging[source] = nil end)
