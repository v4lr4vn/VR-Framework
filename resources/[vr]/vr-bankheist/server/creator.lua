local function fail(code) return { ok = false, error = code } end

local function here(src)
    local p = Bridge.coords(src)
    if not p then return nil end
    local ped = GetPlayerPed(src)
    local h = ped and ped ~= 0 and GetEntityHeading(ped) or 0.0
    return { x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0, w = h + 0.0 }
end

local function spot(src, d)
    local at = type(d.at) == 'table' and d.at or nil
    if at then
        local x, y, z = BH.num(at.x), BH.num(at.y), BH.num(at.z)
        local me = Bridge.coords(src)
        if x and y and z and me and #(vector3(x, y, z) - vector3(me.x, me.y, me.z)) <= 150.0 then
            return { x = x + 0.0, y = y + 0.0, z = z + 0.0, w = (BH.num(at.w) or 0.0) + 0.0 }
        end
    end
    return nil
end

local function dropMade(el)
    for _, name in ipairs(el.made or {}) do Core.dropDoor(name) end
    el.made = {}
end

local function overview()
    local out = {}
    for _, bank in ipairs(Banks.all()) do
        local counts = {}
        for _, el in ipairs(bank.elements) do counts[el.type] = (counts[el.type] or 0) + 1 end
        out[#out + 1] = { id = bank.id, name = bank.name, label = bank.label, enabled = bank.enabled, count = #bank.elements, counts = counts, state = Heist.status(bank).state }
    end
    return out
end

local function detail(bank)
    return { bank = Banks.view(bank), status = Heist.status(bank), banks = overview() }
end

local function done(bank)
    Banks.save(bank)
    Banks.push()
    Heist.pushAll()
    return { ok = true, data = detail(bank) }
end

local handlers = {}

handlers.open = function(src, d)
    local doors, present = Core.doorList()
    local out = { banks = overview(), schema = BH.describe(), doors = doors, doorlock = present }
    local bank = Banks.get(d.id)
    if bank then
        out.bank = Banks.view(bank)
        out.status = Heist.status(bank)
    end
    return { ok = true, data = out }
end

handlers.bank = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local doors, present = Core.doorList()
    local data = detail(bank)
    data.doors = doors
    data.doorlock = present
    return { ok = true, data = data }
end

handlers.create = function(src, d)
    local p = here(src)
    if not p then return fail('no_position') end
    if #Banks.all() >= 40 then return fail('limit') end
    local bank, err = Banks.create(d.name, p)
    if not bank then return fail(err) end
    Banks.push()
    Heist.pushAll()
    return { ok = true, data = detail(bank) }
end

handlers.delete = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    Heist.reset(bank)
    for _, el in ipairs(bank.elements) do
        if el.type == 'door' then dropMade(el) end
    end
    Banks.delete(bank)
    Banks.push()
    return { ok = true, data = { banks = overview() } }
end

handlers.bankset = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local ok, err = BH.patchBank(bank, d.patch)
    if not ok then return fail(err) end
    return done(bank)
end

handlers.bankhere = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local p = spot(src, d) or here(src)
    if not p then return fail('no_position') end
    bank.center = { x = p.x, y = p.y, z = p.z }
    return done(bank)
end

handlers.add = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    if type(d.type) ~= 'string' or not BH.types[d.type] then return fail('bad_type') end
    if #bank.elements >= 80 then return fail('limit') end
    local p = spot(src, d) or here(src)
    if not p then return fail('no_position') end
    local el = BH.newElement(bank, d.type, p)
    bank.elements[#bank.elements + 1] = el
    if type(d.patch) == 'table' then BH.patchElement(bank, el, d.patch) end
    local res = done(bank)
    res.data.added = el.id
    return res
end

handlers.update = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local el = BH.byId(bank, math.floor(tonumber(d.el) or -1))
    if not el then return fail('bad_element') end
    local patch = type(d.patch) == 'table' and d.patch or {}
    patch.made = nil
    local before = {}
    for _, name in ipairs(el.doors or {}) do before[name] = true end
    local ok, err = BH.patchElement(bank, el, patch)
    if not ok then return fail(err) end
    if el.type == 'door' and type(patch.doors) == 'table' then
        local keep = {}
        for _, name in ipairs(el.doors) do keep[name] = true end
        local made = {}
        for _, name in ipairs(el.made or {}) do
            if before[name] and not keep[name] then
                Core.dropDoor(name)
            elseif keep[name] then
                made[#made + 1] = name
            end
        end
        el.made = made
    end
    if el.type == 'door' and type(patch.doors) == 'table' and #el.doors > 0 then
        local list = Core.doorList()
        for _, door in ipairs(list) do
            if door.name == el.doors[1] then
                el.x, el.y, el.z = door.x + 0.0, door.y + 0.0, door.z + 0.0
                break
            end
        end
    end
    return done(bank)
end

local function partOf(raw)
    if type(raw) ~= 'table' then return nil end
    local c = type(raw.coords) == 'table' and raw.coords or {}
    local x, y, z = BH.num(c.x), BH.num(c.y), BH.num(c.z)
    local model = BH.num(raw.model)
    if not (x and y and z and model) then return nil end
    return { model = math.floor(model), coords = { x = x + 0.0, y = y + 0.0, z = z + 0.0 }, heading = (BH.num(raw.heading) or 0.0) + 0.0 }
end

handlers.doorpick = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local el = BH.byId(bank, math.floor(tonumber(d.el) or -1))
    if not el or el.type ~= 'door' then return fail('bad_element') end
    if not Core.doors() then return fail('no_doorlock') end
    el.made = el.made or {}
    el.doors = el.doors or {}
    if #el.doors >= 6 then return fail('limit') end
    local name
    if d.existing ~= nil then
        name = Core.doorName(math.floor(tonumber(d.existing) or -1))
        if not name then return fail('bad_door') end
        for _, n in ipairs(el.doors) do
            if n == name then return fail('door_added') end
        end
    else
        local data
        if type(d.parts) == 'table' and #d.parts == 2 then
            local a, b = partOf(d.parts[1]), partOf(d.parts[2])
            if not a or not b then return fail('bad_door') end
            data = { doors = { a, b } }
        else
            local one = partOf(type(d.parts) == 'table' and d.parts[1] or nil)
            if not one then return fail('bad_door') end
            data = one
        end
        local n = 1
        repeat
            name = ('bh-%s-%d-%d'):format(bank.name, el.id, n)
            n = n + 1
        until not Core.doorId(name)
        local id, err = Core.makeDoor(name, data)
        if not id then return fail(err or 'door_failed') end
        el.made[#el.made + 1] = name
        local c = data.coords or data.doors[1].coords
        el.x, el.y, el.z = c.x, c.y, c.z
    end
    el.doors[#el.doors + 1] = name
    Core.setDoor(name, true)
    return done(bank)
end

handlers.move = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local el = BH.byId(bank, math.floor(tonumber(d.el) or -1))
    if not el then return fail('bad_element') end
    local p = spot(src, d) or here(src)
    if not p then return fail('no_position') end
    el.x, el.y, el.z, el.w = p.x, p.y, p.z, p.w
    return done(bank)
end

handlers.remove = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    local id = math.floor(tonumber(d.el) or -1)
    local idx
    for i, el in ipairs(bank.elements) do
        if el.id == id then idx = i end
    end
    if not idx then return fail('bad_element') end
    local gone = bank.elements[idx]
    if gone.type == 'door' then dropMade(gone) end
    table.remove(bank.elements, idx)
    for _, el in ipairs(bank.elements) do
        if el.needs == id then el.needs = nil end
    end
    Heist.reset(bank)
    return done(bank)
end

handlers.reset = function(src, d)
    local bank = Banks.get(d.id)
    if not bank then return fail('bad_bank') end
    Heist.reset(bank)
    return { ok = true, data = detail(bank) }
end

local limits = { doorpick = 500, open = 300, bank = 150, create = 600, delete = 600, bankset = 150, bankhere = 250, add = 200, update = 100, move = 200, remove = 200, reset = 400 }

lib.callback.register('vr-bankheist:creator', function(src, action, data)
    if not Core.admin(src) then return fail('not_admin') end
    if not Banks.loaded then return fail('not_ready') end
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if Core.throttle(src, 'creator:' .. action, limits[action] or 200) then return fail('slow_down') end
    local ok, res = pcall(h, src, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[vr-bankheist] creator %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end)

RegisterCommand('heistreset', function(src, args)
    if src > 0 and not Core.admin(src) then return end
    local bank = Banks.find(args[1] or '')
    if not bank then return Core.notify(src, 'Use /heistreset <bank name>', 'error') end
    Heist.reset(bank)
    Core.notify(src, ('%s was reset'):format(bank.label), 'success')
end, false)

RegisterCommand('heistdoors', function(src, args)
    if src > 0 and not Core.admin(src) then return end
    local bank = Banks.find(args[1] or '')
    if not bank then return Core.notify(src, 'Use /heistdoors <bank name> [open|lock]', 'error') end
    local mode = args[2]
    if mode == 'open' or mode == 'lock' then
        for _, el in ipairs(bank.elements) do
            if el.type == 'door' then Heist.setDoors(el, mode == 'lock') end
        end
    end
    for _, line in ipairs(Heist.diagnose(bank)) do
        print(('[vr-bankheist] %s'):format(line))
        if src > 0 then TriggerClientEvent('chat:addMessage', src, { args = { 'bankheist', line } }) end
    end
end, false)
