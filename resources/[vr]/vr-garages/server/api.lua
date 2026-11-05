Api = {}

local handlers = {}
local last = {}
local I = Config.Impound

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end

local function reg(name, fn) handlers[name] = fn end

Api.reg, Api.ok, Api.fail = reg, ok, fail

local function garageFor(info, id, needNear)
    local def = Garages.get(id)
    if not def then return nil, 'no_garage' end
    if not Garages.access(def, info) then return nil, 'no_access' end
    if needNear ~= false and not Garages.near(def, info.src) then return nil, 'too_far' end
    return def
end

local function isGroupGarage(def)
    return def.type == 'job' or def.type == 'gang'
end

local function usable(row, info, def)
    if def.type == 'job' then return false end
    return row.citizenid == info.cid
end

local function listFor(def, info)
    if def.type == 'job' then return {} end
    local out = {}
    for _, r in ipairs(Vehicles.forOwner(info.cid)) do
        local v = Vehicles.view(r, info, def)
        if def.type == 'impound' then
            if v.status == 'impounded' or v.status == 'lost' or v.status == 'held' then out[#out + 1] = v end
        elseif Garages.categoryOk(def, v.category) then
            v.usable = true
            out[#out + 1] = v
        end
    end
    return out
end

function Api.garageView(def, info)
    return {
        garage = { id = def.id, label = def.label, type = def.type, category = def.category, groupLabel = Garages.groupLabel(def) },
        vehicles = listFor(def, info),
        jobVehicles = isGroupGarage(def) and JobVehicles.list(def, info) or {},
        jobLimit = math.floor(tonumber((Config.JobVehicles or {}).limit) or 1),
        fees = { transfer = Config.TransferFee, recover = I.recoverFee },
        now = os.time(),
    }
end

reg('open', function(info, d)
    local def, err = garageFor(info, d.garage)
    if not def then return fail(err) end
    return ok(Api.garageView(def, info))
end)

reg('takeOut', function(info, d)
    local def, err = garageFor(info, d.garage)
    if not def then return fail(err) end
    if def.type == 'impound' then return fail('use_release') end
    if def.type == 'job' then return fail('job_only') end
    local plate = GU.plate(d.plate)
    if not plate or not Spawn.lock(plate) then return fail('busy') end
    local res
    local success, e = pcall(function()
        local row = Vehicles.get(plate)
        if not row then res = fail('no_vehicle') return end
        if not usable(row, info, def) then res = fail('not_yours') return end
        if not Garages.categoryOk(def, GU.categoryOfType(Core.vehicleType(row.vehicle))) then res = fail('wrong_category') return end
        local status = Vehicles.status(row)
        if status ~= 'stored' then res = fail(status) return end
        local extra = { garage = def.id }
        if row.garage ~= def.id then
            if not d.transfer then res = fail('elsewhere', { fee = Config.TransferFee }) return end
            if not Core.pay(info.src, Config.TransferFee, ('Vehicle transfer %s'):format(plate)) then res = fail('no_money') return end
        end
        local done, netId = Spawn.release(info.src, row, def, d.fallback, extra)
        if not done then
            if row.garage ~= def.id and d.transfer then Vehicles.update(plate, { garage = def.id }) end
            res = fail(netId)
            return
        end
        res = ok({ netId = netId })
    end)
    Spawn.unlock(plate)
    if not success then print(('^1[vr-garages] takeOut: %s^0'):format(tostring(e))) return fail('failed') end
    return res
end)

reg('jobveh.take', function(info, d)
    local def, err = garageFor(info, d.garage)
    if not def then return fail(err) end
    local key = 'job:' .. tostring(info.cid)
    if not Spawn.lock(key) then return fail('busy') end
    local success, done, res = pcall(JobVehicles.take, info, def, d.id, d.fallback)
    Spawn.unlock(key)
    if not success then print(('^1[vr-garages] job vehicle: %s^0'):format(tostring(done))) return fail('failed') end
    if not done then return fail(res) end
    return ok(res)
end)

reg('store', function(info, d)
    local def, err = garageFor(info, d.garage)
    if not def then return fail(err) end
    if def.type == 'impound' then return fail('not_here') end
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return fail('no_vehicle') end
    local tag = JobVehicles.tag(veh)
    if tag then
        local done, res = JobVehicles.store(info, def, veh, tag)
        if not done then return fail(res) end
        return ok(res)
    end
    if def.type == 'job' then return fail('job_only') end
    local plate = GU.plate(GetVehicleNumberPlateText(veh))
    if not plate or not Spawn.lock(plate) then return fail('busy') end
    local res
    local success, e = pcall(function()
        local row = Vehicles.get(plate)
        if not row then res = fail('not_owned') return end
        if row.citizenid ~= info.cid then res = fail('not_yours') return end
        if not Garages.categoryOk(def, GU.categoryOfType(Core.vehicleType(row.vehicle))) then res = fail('wrong_category') return end
        if Core.bankFlagged(plate) then res = fail('bank_flagged') return end
        if #(GetEntityCoords(veh) - def.center) > def.radius + 4.0 then res = fail('too_far') return end
        if Spawn.occupied(veh, false) then res = fail('passengers') return end
        local fields = Spawn.readCondition(veh, row, d)
        fields.state = 1
        fields.garage = def.id
        Vehicles.update(plate, fields)
        Vehicles.spawned[plate] = nil
        FreezeEntityPosition(veh, true)
        SetTimeout(1800, function()
            if DoesEntityExist(veh) then DeleteEntity(veh) end
        end)
        TriggerEvent('vr-garages:server:vehicleStored', plate, row.citizenid, def.id)
        res = ok({ plate = plate })
    end)
    Spawn.unlock(plate)
    if not success then print(('^1[vr-garages] store: %s^0'):format(tostring(e))) return fail('failed') end
    return res
end)

reg('locate', function(info, d)
    local row = Vehicles.get(d.plate)
    if not row or row.citizenid ~= info.cid then return fail('not_yours') end
    local veh = Vehicles.entity(row.plate)
    if not veh then return fail('not_out') end
    local p = GetEntityCoords(veh)
    return ok({ x = p.x, y = p.y, z = p.z })
end)

reg('rename', function(info, d)
    local row = Vehicles.get(d.plate)
    if not row or row.citizenid ~= info.cid then return fail('not_yours') end
    local name = type(d.name) == 'string' and d.name:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', ''):sub(1, 24) or ''
    Vehicles.update(row.plate, { nickname = name ~= '' and name or nil })
    if name == '' then MySQL.update.await('UPDATE player_vehicles SET nickname = NULL WHERE plate = ?', { row.plate }) end
    return ok(true)
end)

reg('impound.release', function(info, d)
    local def, err = garageFor(info, d.garage)
    if not def then return fail(err) end
    if def.type ~= 'impound' then return fail('not_impound') end
    local plate = GU.plate(d.plate)
    if not plate or not Spawn.lock(plate) then return fail('busy') end
    local res
    local success, e = pcall(function()
        local row = Vehicles.get(plate)
        if not row or not usable(row, info, def) then res = fail('not_yours') return end
        local status = Vehicles.status(row)
        local fee
        if status == 'impounded' then
            if row.impound_until > os.time() then res = fail('not_ready', { readyAt = row.impound_until }) return end
            fee = row.depotprice
        elseif status == 'lost' then
            fee = I.recoverFee
        else
            res = fail(status)
            return
        end
        local spot = Spawn.findSpot(def, d.fallback)
        if not spot then res = fail('no_space') return end
        if fee > 0 then
            local paid = Core.pay(info.src, fee, ('Impound release %s'):format(plate), d.method)
            if not paid then res = fail('no_money') return end
        end
        local done, netId = Spawn.release(info.src, row, def, d.fallback, { depotprice = 0, impound_reason = nil, impound_until = 0, impound_by = nil, garage = row.garage })
        if not done then res = fail(netId) return end
        MySQL.update.await('UPDATE player_vehicles SET impound_reason = NULL, impound_by = NULL WHERE plate = ?', { plate })
        TriggerEvent('vr-garages:server:impoundReleased', plate, row.citizenid, fee)
        res = ok({ netId = netId, fee = fee })
    end)
    Spawn.unlock(plate)
    if not success then print(('^1[vr-garages] release: %s^0'):format(tostring(e))) return fail('failed') end
    return res
end)

local function canImpound(info)
    local min = I.jobs[info.job.name]
    if not min or info.job.grade < min then return false end
    return not I.requireDuty or info.job.onduty
end

Api.canImpound = canImpound

function Api.impound(plate, opts)
    opts = opts or {}
    local row = Vehicles.get(plate)
    if not row then return false, 'not_owned' end
    local fields = opts.fields or {}
    fields.state = 2
    fields.garage = opts.garage or Config.DefaultImpound
    fields.depotprice = math.floor(math.max(0, math.min(I.maxFee, tonumber(opts.fee) or I.defaultFee)))
    fields.impound_reason = type(opts.reason) == 'string' and opts.reason:gsub('[%c<>]', ''):sub(1, 128) or 'Impounded'
    fields.impound_until = os.time() + math.floor(math.max(0, math.min(I.maxHoldHours, tonumber(opts.hours) or 0)) * 3600)
    fields.impound_by = opts.by and tostring(opts.by):sub(1, 64) or nil
    fields.impound_at = os.time()
    Vehicles.update(row.plate, fields)
    Vehicles.spawned[row.plate] = nil
    local owner = Core.sourceOf(row.citizenid)
    if owner and not opts.silent then
        Core.notify(owner, ('%s (%s) was impounded: %s'):format(Core.vehicleLabel(row.vehicle), row.plate, fields.impound_reason), 'error')
    end
    TriggerEvent('vr-garages:server:impounded', row.plate, row.citizenid, fields.impound_reason, fields.depotprice)
    return true, row
end

reg('police.impound', function(info, d)
    if not canImpound(info) then return fail('no_access') end
    local veh = NetworkGetEntityFromNetworkId(tonumber(d.netId) or 0)
    if not veh or veh == 0 or not DoesEntityExist(veh) or GetEntityType(veh) ~= 2 then return fail('no_vehicle') end
    local me = Core.coords(info.src)
    if not me or #(me - GetEntityCoords(veh)) > I.distance + 2.0 then return fail('too_far') end
    if Spawn.occupied(veh, true) then return fail('occupied') end
    local plate = GU.plate(GetVehicleNumberPlateText(veh))
    local row = plate and Vehicles.get(plate)
    if row then
        if not Spawn.lock(plate) then return fail('busy') end
        local fields = Spawn.readCondition(veh, row, d)
        Api.impound(plate, { fee = d.fee, reason = d.reason, hours = d.hours, by = info.name, fields = fields })
        Spawn.unlock(plate)
    end
    DeleteEntity(veh)
    return ok({ owned = row ~= nil, plate = plate })
end)

function Api.handle(src, action, data)
    local h = type(action) == 'string' and handlers[action]
    if not h then return fail('bad_request') end
    if not Db.ready then return fail('not_ready') end
    local t = GetGameTimer()
    local mine = last[src]
    if not mine then mine = {} last[src] = mine end
    if mine[action] and t - mine[action] < 250 then return fail('slow_down') end
    mine[action] = t
    local info = Core.info(src)
    if not info then return fail('not_loaded') end
    local success, res = pcall(h, info, type(data) == 'table' and data or {})
    if not success then
        print(('^1[vr-garages] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end

AddEventHandler('playerDropped', function() last[source] = nil end)
