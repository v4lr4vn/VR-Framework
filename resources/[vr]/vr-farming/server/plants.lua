local plants = Farm.plants
local pending = {}
local dirty = {}
local cans = {}
local ACTIONS = {}

local function stamp() return os.time() end

local function cropOf(p) return Config.Crops[p.crop] end

local function tscale() return Growth.scale() end

function Farm.plantView(p)
    local dead = p.deadAt ~= nil
    return {
        id = p.id, crop = p.crop, x = p.x, y = p.y, z = p.z,
        stage = dead and 0 or Growth.stage(p, cropOf(p)),
        thirsty = (not dead and not p.readyAt and p.water <= 0) or false,
        dead = dead,
        fert = p.fert == true,
    }
end

local function signature(v)
    return ('%d:%s:%s:%s'):format(v.stage, tostring(v.thirsty), tostring(v.dead), tostring(v.fert))
end

-- Tells every client about a plant if what they would see has changed.
local function touch(p, force)
    local v = Farm.plantView(p)
    local sig = signature(v)
    if force or p.shown ~= sig then
        p.shown = sig
        TriggerClientEvent('vr-farming:client:plant', -1, v)
    end
end

local function drop(p)
    plants[p.id] = nil
    dirty[p.id] = nil
    MySQL.query('DELETE FROM vr_farm_plants WHERE id = ?', { p.id })
    TriggerClientEvent('vr-farming:client:plantGone', -1, p.id)
end
Farm.dropPlant = drop

function Farm.loadPlants()
    local rows = MySQL.query.await('SELECT id, field, crop, x, y, z, owner, owner_name, planted, `last`, progress, water, dry, fert, ready_at, dead_at FROM vr_farm_plants') or {}
    local t = stamp()
    local skipped = 0
    for _, r in ipairs(rows) do
        if Config.Crops[r.crop] then
            -- Time the server was off does not count, so a restart never kills the crops.
            plants[r.id] = {
                id = r.id, field = r.field, crop = r.crop, x = r.x + 0.0, y = r.y + 0.0, z = r.z + 0.0,
                owner = r.owner, ownerName = r.owner_name, planted = r.planted, last = t,
                progress = (tonumber(r.progress) or 0) + 0.0, water = (tonumber(r.water) or 0) + 0.0,
                dry = (tonumber(r.dry) or 0) + 0.0, fert = (tonumber(r.fert) or 0) == 1,
                readyAt = (tonumber(r.ready_at) or 0) > 0 and tonumber(r.ready_at) or nil,
                deadAt = (tonumber(r.dead_at) or 0) > 0 and tonumber(r.dead_at) or nil,
            }
            plants[r.id].shown = signature(Farm.plantView(plants[r.id]))
        else
            skipped = skipped + 1
        end
    end
    if skipped > 0 then print(('^3[vr-farming] %d saved plants use a crop that is not in the config and were left alone^0'):format(skipped)) end
end

local function flush()
    local list = {}
    for id in pairs(dirty) do
        local p = plants[id]
        if p then list[#list + 1] = p end
    end
    dirty = {}
    local i = 1
    while i <= #list do
        local params, marks = {}, {}
        for j = i, math.min(i + 39, #list) do
            local p = list[j]
            marks[#marks + 1] = '(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
            for _, v in ipairs({ p.id, p.field, p.crop, p.x, p.y, p.z, p.owner, p.ownerName or '', p.planted, p.last, p.progress, p.water, p.dry, p.fert and 1 or 0, p.readyAt or 0, p.deadAt or 0 }) do
                params[#params + 1] = v
            end
        end
        MySQL.query('INSERT INTO vr_farm_plants (id, field, crop, x, y, z, owner, owner_name, planted, `last`, progress, water, dry, fert, ready_at, dead_at) VALUES '
            .. table.concat(marks, ',')
            .. ' ON DUPLICATE KEY UPDATE `last` = VALUES(`last`), progress = VALUES(progress), water = VALUES(water), dry = VALUES(dry), fert = VALUES(fert), ready_at = VALUES(ready_at), dead_at = VALUES(dead_at)', params)
        i = i + 40
    end
end
Farm.flush = flush

-- Brings one plant up to date and applies death and wither. Returns false when it was removed.
local function irrigated(p)
    local spot = Farm.spots[p.field]
    return spot ~= nil and spot.irrigated == true
end

local function update(p, t)
    local c = cropOf(p)
    if Growth.advance(p, c, t, irrigated(p)) and not p.deadAt then dirty[p.id] = true end
    local r = Config.Rules
    if not p.deadAt then
        if Growth.health(p) <= 0 then
            p.deadAt = t
            dirty[p.id] = true
        elseif p.readyAt and t - p.readyAt > r.witherMinutes * 60 * tscale() then
            p.deadAt = t
            dirty[p.id] = true
        end
    elseif t - p.deadAt > r.deadClearMinutes * 60 * tscale() then
        drop(p)
        return false
    end
    return true
end

CreateThread(function()
    local sinceSave = 0
    while true do
        Wait(Config.Rules.tickSeconds * 1000)
        if Farm.loaded then
            local t = stamp()
            for _, p in pairs(plants) do
                if update(p, t) then touch(p) end
            end
            sinceSave = sinceSave + Config.Rules.tickSeconds
            if sinceSave >= Config.Rules.saveSeconds then
                sinceSave = 0
                flush()
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then pcall(flush) end
end)

lib.callback.register('vr-farming:plants', function()
    local out = {}
    for _, p in pairs(plants) do out[#out + 1] = Farm.plantView(p) end
    return out
end)

-- Watering can charges, kept per character.
local function charges(cid)
    if cans[cid] == nil then
        cans[cid] = tonumber(MySQL.scalar.await('SELECT charges FROM vr_farm_cans WHERE cid = ?', { cid })) or 0
    end
    return cans[cid]
end

local function setCharges(cid, n)
    cans[cid] = n
    MySQL.query('INSERT INTO vr_farm_cans (cid, charges) VALUES (?, ?) ON DUPLICATE KEY UPDATE charges = VALUES(charges)', { cid, n })
end
Farm.charges, Farm.setCharges = charges, setCharges

-- The field a point is in that lets this crop grow. If it is in a field that does not allow the crop,
-- returns nil and that field so the player can be told what does grow there.
local function fieldAt(x, y, z, crop)
    local refused
    local ids = {}
    for id, spot in pairs(Farm.spots) do
        if spot.kind == 'field' then ids[#ids + 1] = id end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local spot = Farm.spots[id]
        if Farm.inField(spot, x, y, z) then
            if Farm.allows(spot, crop) then return spot end
            refused = refused or spot
        end
    end
    return nil, refused
end

local function plantFor(src, id, reach)
    local p = plants[tonumber(id) or -1]
    if not p then return nil, 'gone' end
    local d = Farm.distance(src, p.x, p.y, p.z)
    if not d or d > (reach or Config.Reach + 1.5) then return nil, 'too_far' end
    return p
end

---------------------------------------------------------------------------
-- Actions. Every action has a check that runs when it starts and again when
-- it finishes, and a run that does the work. Nothing is trusted from the client.
---------------------------------------------------------------------------

ACTIONS.plant = {
    check = function(who, crop, pos)
        if type(crop) ~= 'string' or not Config.Crops[crop] then return nil, 'bad_request' end
        if type(pos) ~= 'table' then return nil, 'bad_request' end
        local x, y, z = Farm.num(pos.x), Farm.num(pos.y), Farm.num(pos.z)
        if not (x and y and z) then return nil, 'bad_request' end
        local d = Farm.distance(who.src, x, y, z)
        if not d or d > 6.0 then return nil, 'too_far' end
        if Farm.count(who.src, Farm.seedOf(crop)) < 1 then return nil, 'no_seed' end
        local field, refused = fieldAt(x, y, z, crop)
        if not field then
            if refused then return nil, 'wrong_crop', { allowed = Farm.cropNames(refused.crops), field = refused.label } end
            return nil, 'not_field'
        end
        local r = Config.Rules
        local mine, inField = 0, 0
        local min2 = r.spacing * r.spacing
        for _, p in pairs(plants) do
            if p.owner == who.cid then mine = mine + 1 end
            if p.field == field.id then
                inField = inField + 1
                local dx, dy = p.x - x, p.y - y
                if dx * dx + dy * dy < min2 then return nil, 'too_close' end
            end
        end
        if mine >= r.maxPlantsPerPlayer then return nil, 'too_many' end
        if inField >= r.maxPlantsPerField then return nil, 'field_full' end
        return { crop = crop, x = x + 0.0, y = y + 0.0, z = z + 0.0, field = field.id }
    end,
    run = function(who, ctx)
        if not Farm.take(who.src, Farm.seedOf(ctx.crop), 1) then return Farm.fail('no_seed') end
        local t = stamp()
        local id = MySQL.insert.await('INSERT INTO vr_farm_plants (field, crop, x, y, z, owner, owner_name, planted, `last`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', { ctx.field, ctx.crop, ctx.x, ctx.y, ctx.z, who.cid, who.name, t, t })
        if not id then
            Farm.give(who.src, Farm.seedOf(ctx.crop), 1)
            return Farm.fail('failed')
        end
        local p = { id = id, field = ctx.field, crop = ctx.crop, x = ctx.x, y = ctx.y, z = ctx.z, owner = who.cid, ownerName = who.name, planted = t, last = t, progress = 0.0, water = 0.0, dry = 0.0, fert = false }
        if irrigated(p) then p.water = 100.0 end
        plants[id] = p
        touch(p, true)
        return { ok = true, data = { id = id, label = Config.Crops[ctx.crop].label } }
    end,
}

ACTIONS.water = {
    check = function(who, id)
        local p, err = plantFor(who.src, id)
        if not p then return nil, err end
        update(p, stamp())
        if p.deadAt then return nil, 'is_dead' end
        if p.readyAt then return nil, 'is_ready' end
        if irrigated(p) then return nil, 'irrigated' end
        if p.water > 80.0 then return nil, 'is_wet' end
        if Farm.count(who.src, Config.Items.can) < 1 then return nil, 'no_can' end
        if charges(who.cid) < 1 then return nil, 'empty_can' end
        return { id = p.id }
    end,
    run = function(who, ctx)
        local p = plants[ctx.id]
        if not p then return Farm.fail('gone') end
        update(p, stamp())
        local left = charges(who.cid) - 1
        setCharges(who.cid, left)
        p.water = 100.0
        dirty[p.id] = true
        touch(p)
        return { ok = true, data = { left = left } }
    end,
}

ACTIONS.fertilise = {
    check = function(who, id)
        local p, err = plantFor(who.src, id)
        if not p then return nil, err end
        update(p, stamp())
        if p.deadAt then return nil, 'is_dead' end
        if p.readyAt then return nil, 'is_ready' end
        if p.fert then return nil, 'is_fed' end
        if Farm.count(who.src, Config.Items.fertiliser) < 1 then return nil, 'no_fertiliser' end
        return { id = p.id }
    end,
    run = function(who, ctx)
        local p = plants[ctx.id]
        if not p then return Farm.fail('gone') end
        if not Farm.take(who.src, Config.Items.fertiliser, 1) then return Farm.fail('no_fertiliser') end
        update(p, stamp())
        p.fert = true
        dirty[p.id] = true
        touch(p)
        return { ok = true, data = {} }
    end,
}

local function mayHarvest(who, p, t)
    if p.owner == who.cid then return true end
    return p.readyAt ~= nil and t - p.readyAt >= Config.Rules.protectMinutes * 60 * tscale()
end

ACTIONS.harvest = {
    check = function(who, id)
        local p, err = plantFor(who.src, id)
        if not p then return nil, err end
        local t = stamp()
        update(p, t)
        if p.deadAt then return nil, 'is_dead' end
        if not p.readyAt then return nil, 'not_ripe' end
        if not mayHarvest(who, p, t) then return nil, 'not_yours' end
        return { id = p.id }
    end,
    run = function(who, ctx)
        local p = plants[ctx.id]
        if not p then return Farm.fail('gone') end
        local c = cropOf(p)
        local count, tier = Growth.harvest(p, c)
        if not Farm.canCarry(who.src, p.crop, count, { quality = tier }) then return Farm.fail('no_room') end
        if not Farm.give(who.src, p.crop, count, { quality = tier }) then return Farm.fail('no_room') end
        local seeds = 0
        local r = Config.Rules
        if math.random() < r.seedBack then
            seeds = Growth.roll(r.seedBackAmount)
            if not Farm.give(who.src, Farm.seedOf(p.crop), seeds) then seeds = 0 end
        end
        if c.regrow then
            p.progress = Growth.growSeconds(c) * c.regrow
            p.readyAt = nil
            p.fert = false
            p.last = stamp()
            dirty[p.id] = true
            touch(p)
        else
            drop(p)
        end
        return { ok = true, data = { item = p.crop, label = c.label, count = count, quality = tier, tier = Config.Quality[tier].label, seeds = seeds, regrows = c.regrow ~= nil } }
    end,
}

ACTIONS.uproot = {
    check = function(who, id)
        local p, err = plantFor(who.src, id)
        if not p then return nil, err end
        update(p, stamp())
        if not (p.owner == who.cid or p.deadAt) then return nil, 'not_yours' end
        return { id = p.id }
    end,
    run = function(who, ctx)
        local p = plants[ctx.id]
        if not p then return Farm.fail('gone') end
        drop(p)
        return { ok = true, data = {} }
    end,
}

ACTIONS.refill = {
    check = function(who, id)
        local spot = Farm.spot(id)
        if not spot or spot.kind ~= 'well' then return nil, 'bad_request' end
        if not Farm.near(who.src, spot) then return nil, 'too_far' end
        if Farm.count(who.src, Config.Items.can) < 1 then return nil, 'no_can' end
        if charges(who.cid) >= Config.Rules.canCapacity then return nil, 'can_full' end
        return { id = spot.id }
    end,
    run = function(who, ctx)
        setCharges(who.cid, Config.Rules.canCapacity)
        return { ok = true, data = { left = Config.Rules.canCapacity } }
    end,
}

lib.callback.register('vr-farming:begin', function(src, action, a, b)
    if Farm.throttle(src, 'begin', Config.Rules.minGapMs) then return Farm.fail('slow_down') end
    local who = Farm.info(src)
    if not who then return Farm.fail('no_player') end
    local handler = type(action) == 'string' and ACTIONS[action]
    if not handler then return Farm.fail('bad_request') end
    local ctx, err, extra = handler.check(who, a, b)
    if not ctx then return Farm.fail(err or 'failed', extra) end
    local seconds = Config.Rules.seconds[action] or 3.0
    pending[src] = { action = action, at = GetGameTimer(), seconds = seconds }
    return { ok = true, data = { seconds = seconds, charges = action == 'water' and charges(who.cid) or nil } }
end)

lib.callback.register('vr-farming:finish', function(src, action, a, b)
    local job = pending[src]
    pending[src] = nil
    local who = Farm.info(src)
    if not who then return Farm.fail('no_player') end
    local handler = type(action) == 'string' and ACTIONS[action]
    if not handler or not job or job.action ~= action then return Farm.fail('bad_request') end
    local took = (GetGameTimer() - job.at) / 1000.0
    if took < job.seconds * 0.8 then return Farm.fail('too_fast') end
    if took > job.seconds + 120.0 then return Farm.fail('bad_request') end
    local ctx, err, extra = handler.check(who, a, b)
    if not ctx then return Farm.fail(err or 'failed', extra) end
    return handler.run(who, ctx)
end)

lib.callback.register('vr-farming:cancel', function(src)
    pending[src] = nil
    return true
end)

AddEventHandler('playerDropped', function() pending[tonumber(source)] = nil end)

lib.callback.register('vr-farming:inspect', function(src, id)
    local who = Farm.info(src)
    if not who then return Farm.fail('no_player') end
    local p, err = plantFor(who.src, id, Config.Reach + 4.0)
    if not p then return Farm.fail(err) end
    local t = stamp()
    update(p, t)
    local c = cropOf(p)
    local health = math.floor(Growth.health(p) + 0.5)
    local out = {
        label = c.label,
        stage = p.deadAt and 0 or Growth.stage(p, c),
        water = math.floor(p.water + 0.5),
        irrigated = irrigated(p),
        health = health,
        fert = p.fert == true,
        dead = p.deadAt ~= nil,
        ripe = p.readyAt ~= nil,
        mine = p.owner == who.cid,
        owner = p.ownerName,
        regrow = c.regrow ~= nil,
        quality = Config.Quality[Growth.tier(Growth.health(p))].label,
    }
    if p.readyAt and not p.deadAt then
        out.free = mayHarvest(who, p, t)
        out.protectLeft = math.max(0, math.floor(p.readyAt + Config.Rules.protectMinutes * 60 * tscale() - t))
        out.witherLeft = math.max(0, math.floor(p.readyAt + Config.Rules.witherMinutes * 60 * tscale() - t))
    elseif not p.deadAt then
        out.remaining = math.floor(Growth.remaining(p, c))
        out.dryFor = p.water <= 0 and math.floor(math.max(0, Config.Rules.graceMinutes * 60 * tscale() - p.dry)) or nil
    end
    out.charges = charges(who.cid)
    return { ok = true, data = out }
end)

-- Charges for the HUD of the can menu.
lib.callback.register('vr-farming:can', function(src)
    local who = Farm.info(src)
    if not who then return Farm.fail('no_player') end
    return { ok = true, data = { charges = charges(who.cid), capacity = Config.Rules.canCapacity } }
end)

Farm.onReady(function()
    for name in pairs(Config.Crops) do
        local item = Farm.seedOf(name)
        local tries = 0
        while tries < 20 and not Bridge.useItem(item, function(src)
            if Farm.info(src) then TriggerClientEvent('vr-farming:client:useSeed', src, name) end
        end) do
            tries = tries + 1
            Wait(1000)
        end
    end
end)

exports('GetCropInfo', function(name) return Config.Crops[name] end)
exports('GetQuality', function(tier) return Config.Quality[tonumber(tier) or 0] end)

-- Brings every plant in a field up to date (used just before its irrigation is switched on or off).
function Farm.settle(fieldId)
    local t = stamp()
    for _, p in pairs(plants) do
        if p.field == fieldId then update(p, t) end
    end
end

-- Tells clients what the plants in a field look like now (a thirsty plant stops being thirsty at once).
function Farm.refresh(fieldId)
    local t = stamp()
    for _, p in pairs(plants) do
        if p.field == fieldId then
            if update(p, t) ~= false then
                if irrigated(p) and not p.deadAt then p.water = 100.0 end
                dirty[p.id] = true
                touch(p)
            end
        end
    end
end
