Api = {}

local handlers = {}
local last, busy = {}, {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end
local function reg(name, fn, shop) handlers[name] = { fn = fn, shop = shop } end
local function wrap(success, res, extra)
    if not success then return fail(res, extra) end
    return ok(res)
end

reg('pack.open', function(info, d) return wrap(Packs.open(info, d.slot)) end)

reg('card.view', function(info, d)
    if type(d.uid) ~= 'string' or not Core.slots(info.src, Config.Items.card, { uid = d.uid })[1] then return fail('no_card') end
    local c = Copies.get(d.uid)
    if not c then return fail('no_card') end
    return ok({ card = Copies.view(c), meta = Catalog.meta() })
end)

reg('binder.open', function(info, d)
    if not Binders.holds(info.src, d.id) then return fail('no_binder') end
    local v = Binders.view(info, tonumber(d.id))
    if not v then return fail('no_binder') end
    return ok(v)
end)

reg('binder.put', function(info, d) return wrap(Binders.put(info, tonumber(d.id), d.uid, d.slot)) end)
reg('binder.take', function(info, d) return wrap(Binders.take(info, tonumber(d.id), d.slot)) end)
reg('binder.move', function(info, d) return wrap(Binders.move(info, tonumber(d.id), d.from, d.to)) end)
reg('binder.rename', function(info, d) return wrap(Binders.rename(info, tonumber(d.id), d.title)) end)

reg('shop.open', function(info) return ok(Shop.data(info)) end, true)
reg('shop.pack', function(info, d) return wrap(Shop.buyPack(info, d.pack, d.count, d.method)) end, true)
reg('shop.binder', function(info, d) return wrap(Shop.buyBinder(info, d.method)) end, true)
reg('shop.sell', function(info, d) return wrap(Shop.sell(info, d.uids, d.method)) end, true)
reg('shop.grade', function(info, d) return wrap(Shop.grade(info, d.uids, d.tier, d.method)) end, true)
reg('shop.collect', function(info) return wrap(Shop.collect(info)) end, true)

function Api.handle(src, action, data)
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if not Db.ready then return fail('not_ready') end
    local t = GetGameTimer()
    local mine = last[src]
    if not mine then mine = {} last[src] = mine end
    if mine[action] and t - mine[action] < 250 then return fail('slow_down') end
    if busy[src] then return fail('slow_down') end
    mine[action] = t
    local info = Core.info(src)
    if not info then return fail('not_loaded') end
    if h.shop and not Shop.near(src) then return fail('too_far') end
    busy[src] = true
    local success, res = pcall(h.fn, info, type(data) == 'table' and data or {})
    busy[src] = nil
    if not success then
        print(('^1[vr-cards] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    if res.ok and h.shop and action ~= 'shop.open' then
        res.data = res.data or {}
        res.data.shop = Shop.data(info)
    end
    return res
end

AddEventHandler('playerDropped', function()
    last[source] = nil
    busy[source] = nil
end)
