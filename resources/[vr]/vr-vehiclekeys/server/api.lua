Api = {}

local handlers = {}
local last = {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end

local function reg(name, fn) handlers[name] = fn end

Api.reg, Api.ok, Api.fail = reg, ok, fail

local function target(info, d, dist)
    local veh = Core.vehicle(d.netId)
    if not veh then return nil, 'no_vehicle' end
    if not Core.near(info.src, veh, dist) then return nil, 'too_far' end
    return veh
end

reg('sync', function(info)
    return ok({ held = Keys.snapshot(info.cid) })
end)

reg('toggle', function(info, d)
    local veh, err = target(info, d, Config.Lock.range + 6.0)
    if not veh then return fail(err) end
    if not Keys.forVehicle(info, veh) then return fail('no_keys') end
    local want = d.want
    if type(want) ~= 'boolean' then want = not Keys.isLocked(veh) end
    Keys.setLocked(veh, want)
    return ok({ locked = want })
end)

reg('claim', function(info, d)
    if not Config.Claims.enabled then return fail('disabled') end
    local t = os.time()
    local c = Keys.claims[info.src]
    if not c or t - c.from >= 60 then c = { from = t, n = 0 } Keys.claims[info.src] = c end
    c.n = c.n + 1
    if c.n > Config.Claims.perMinute then return fail('slow_down') end
    local veh, err = target(info, d, Config.Claims.range)
    if not veh then return fail(err) end
    local a, b = Keys.platesOf(veh)
    if not a then return fail('no_vehicle') end
    local owner = Keys.ownerOf(a) or (b and Keys.ownerOf(b)) or nil
    if owner and owner ~= info.cid then return fail('not_yours') end
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver and driver ~= 0 and driver ~= GetPlayerPed(info.src) and IsPedAPlayer(driver) then return fail('occupied') end
    if Keys.forVehicle(info, veh) then return ok({ plate = a, already = true }) end
    Keys.grantTemp(info.cid, a, Config.Keys.tempMinutes)
    Keys.push(info.src)
    if d.how == 'carjack' then Core.alert(info.src, 'carjack') end
    return ok({ plate = a })
end)

reg('list', function(info)
    local out, seen = {}, {}
    local rows = MySQL.query.await('SELECT plate, vehicle FROM player_vehicles WHERE citizenid = ? ORDER BY vehicle, plate', { info.cid }) or {}
    for _, r in ipairs(rows) do
        local p = KU.plate(r.plate)
        if p then
            seen[p] = true
            out[#out + 1] = { plate = p, model = r.vehicle, label = Core.label(r.vehicle), kind = 'owner' }
        end
    end
    local held = Keys.snapshot(info.cid)
    local extra = {}
    for plate, kind in pairs(held) do
        if not seen[plate] and kind ~= 'owner' then extra[#extra + 1] = { plate = plate, kind = kind } end
    end
    table.sort(extra, function(x, y) return x.plate < y.plate end)
    for _, e in ipairs(extra) do
        local model = Keys.modelOf(e.plate)
        out[#out + 1] = { plate = e.plate, model = model, label = model and Core.label(model) or 'Vehicle', kind = e.kind }
    end
    return ok({ vehicles = out })
end)

reg('nearby', function(info)
    local me = Core.coords(info.src)
    local out = {}
    if not me then return ok({ players = out }) end
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and src ~= info.src then
            local other = Core.info(src)
            local c = other and Core.coords(src)
            local dist = c and #(vector3(me.x, me.y, me.z) - vector3(c.x, c.y, c.z))
            if dist and dist <= Config.Lock.shareRange then
                out[#out + 1] = { src = src, name = other.name, dist = math.floor(dist * 10 + 0.5) / 10 }
            end
        end
    end
    table.sort(out, function(a, b) return a.dist < b.dist end)
    return ok({ players = out })
end)

reg('share', function(info, d)
    local plate = KU.plate(d.plate)
    if not plate then return fail('bad_request') end
    if Keys.ownerOf(plate) ~= info.cid then return fail('not_owner') end
    local dst = tonumber(d.target)
    if not dst or dst == info.src then return fail('bad_target') end
    local other = Core.info(dst)
    if not other then return fail('no_player') end
    local a, b = Core.coords(info.src), Core.coords(dst)
    if not a or not b or #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z)) > Config.Lock.shareRange + 1.5 then return fail('too_far') end
    local already = Keys.sharedOf(other.cid)[plate] ~= nil
    if not already and Keys.count(plate) >= Config.Keys.maxShared then return fail('limit') end
    local lend = d.lend == true
    Keys.share(other.cid, plate, other.name, info.name, lend and Config.Keys.lendMinutes or nil)
    Keys.push(dst)
    local label = Core.label(Keys.modelOf(plate))
    Core.notify(dst, ('%s gave you %s keys to the %s (%s)'):format(info.name, lend and 'temporary' or 'a copy of the', label, plate), 'success')
    return ok({ plate = plate, lent = lend, name = other.name })
end)

reg('holders', function(info, d)
    local plate = KU.plate(d.plate)
    if not plate then return fail('bad_request') end
    if Keys.ownerOf(plate) ~= info.cid then return fail('not_owner') end
    return ok({ plate = plate, holders = Keys.holders(plate) })
end)

reg('revoke', function(info, d)
    local plate = KU.plate(d.plate)
    if not plate then return fail('bad_request') end
    local cid = type(d.cid) == 'string' and d.cid or info.cid
    local owner = Keys.ownerOf(plate) == info.cid
    if cid ~= info.cid and not owner then return fail('not_owner') end
    if cid == info.cid and owner then return fail('owner_key') end
    if not Keys.revoke(cid, plate) then return fail('no_key') end
    Keys.pushCid(cid)
    local src = Core.sourceOf(cid)
    if src and cid ~= info.cid then Core.notify(src, ('Your key to %s was taken back'):format(plate), 'inform') end
    return ok({ plate = plate })
end)

reg('breakin.start', function(info, d)
    local kind = d.kind == 'hotwire' and 'hotwire' or 'lockpick'
    local cfg = kind == 'hotwire' and Config.Hotwire or Config.Lockpick
    local veh, err = target(info, d, kind == 'hotwire' and 6.0 or 5.0)
    if not veh then return fail(err) end
    local wait = Keys.cool[info.src .. ':' .. kind]
    if wait and wait > os.time() then return fail('cooldown') end
    local item = Core.firstItem(info.src, cfg.items)
    if not item then return fail('no_item') end
    local ped = GetPlayerPed(info.src)
    if kind == 'lockpick' then
        if GetVehiclePedIsIn(ped, false) ~= 0 then return fail('in_vehicle') end
        if not Keys.isLocked(veh) then return fail('not_locked') end
        if Keys.forVehicle(info, veh) then return fail('have_keys') end
    else
        if GetPedInVehicleSeat(veh, -1) ~= ped then return fail('not_driver') end
        if Keys.forVehicle(info, veh) then return fail('have_keys') end
        local ok2, hot = pcall(function() return Entity(veh).state.vr_hotwired end)
        if ok2 and hot == true then return fail('already') end
    end
    Keys.pending[info.src] = { netId = tonumber(d.netId), kind = kind, item = item, at = GetGameTimer() }
    return ok({ item = item })
end)

reg('breakin.done', function(info, d)
    local p = Keys.pending[info.src]
    Keys.pending[info.src] = nil
    if not p or GetGameTimer() - p.at > 120000 then return fail('no_attempt') end
    local veh = Core.vehicle(p.netId)
    if not veh then return fail('no_vehicle') end
    local cfg = p.kind == 'hotwire' and Config.Hotwire or Config.Lockpick
    local success = d.success == true
    local chance = (success and cfg.breakChance.success or cfg.breakChance.fail) or 0
    local broke = false
    if math.random(100) <= chance then
        broke = Bridge.inventory.remove(info.src, p.item, 1) and true or false
    end
    local alarm = false
    if success then
        if p.kind == 'lockpick' then
            Keys.setLocked(veh, false)
        else
            Entity(veh).state:set('vr_hotwired', true, true)
        end
    else
        alarm = math.random(100) <= (cfg.alarmChance or 0)
        Keys.cool[info.src .. ':' .. p.kind] = os.time() + (cfg.cooldown or 0)
    end
    Core.alert(info.src, p.kind)
    return ok({ success = success, broke = broke, alarm = alarm, kind = p.kind })
end)

reg('locksmith.change', function(info, d)
    local plate = KU.plate(d.plate)
    if not plate then return fail('bad_request') end
    if Keys.ownerOf(plate) ~= info.cid then return fail('not_owner') end
    if not Core.atLocksmith(info.src) then return fail('too_far') end
    local fee = tonumber(Config.Locksmith.fee) or 0
    if fee > 0 and not Bridge.pay(info.src, fee, ('Locksmith: new locks for %s'):format(plate)) then return fail('no_money') end
    local who = Keys.clearPlate(plate)
    Keys.pushAll(who)
    Keys.push(info.src)
    return ok({ plate = plate, fee = fee, removed = #who })
end)

function Api.handle(src, action, data)
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if not Db.ready then return fail('not_ready') end
    local t = GetGameTimer()
    local mine = last[src]
    if not mine then mine = {} last[src] = mine end
    if mine[action] and t - mine[action] < 200 then return fail('slow_down') end
    mine[action] = t
    local info = Core.info(src)
    if not info then return fail('not_loaded') end
    local success, res = pcall(h, info, type(data) == 'table' and data or {})
    if not success then
        print(('^1[vr-vehiclekeys] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end

AddEventHandler('playerDropped', function()
    local src = source
    last[src] = nil
    Keys.claims[src] = nil
    Keys.pending[src] = nil
end)
