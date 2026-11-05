Work = { pending = {} }

local function spec(kind, part)
    if kind == 'part' then
        local p = Config.Parts[part]
        if not p then return nil end
        return { item = p.item, seconds = p.seconds, label = p.label, mechanic = true }
    elseif kind == 'engine' then
        local r = Config.Repairs.engineBlock
        return { item = r.item, seconds = r.seconds, label = r.label, mechanic = true }
    elseif kind == 'body' then
        local r = Config.Repairs.bodywork
        return { item = r.item, seconds = r.seconds, label = r.label, mechanic = true }
    elseif kind == 'kit' then
        local r = Config.Repairs.repairKit
        return { item = r.item, seconds = r.seconds, label = 'Repair kit', mechanic = not r.anyone, engine = r.engineHealth }
    end
    return nil
end

local function health(fn, veh)
    local ok, v = pcall(fn, veh)
    return ok and tonumber(v) or nil
end

function Work.begin(info, d)
    local s = spec(d.kind, d.part)
    if not s then return false, 'bad_request' end
    if s.mechanic and not Core.isMechanic(info) then return false, 'not_mechanic' end
    local veh = Cars.entity(d.netId)
    if not veh then return false, 'no_vehicle' end
    if not Cars.near(info.src, veh) then return false, 'too_far' end
    if GetVehiclePedIsIn(GetPlayerPed(info.src), false) ~= 0 then return false, 'in_vehicle' end
    if Core.count(info.src, s.item) < 1 then return false, 'no_item', { item = s.item } end
    if d.kind == 'part' and Cars.status(veh)[d.part] >= 99.5 then return false, 'not_needed' end
    if d.kind == 'engine' then
        local e = health(GetVehicleEngineHealth, veh)
        if e and e >= 999.0 then return false, 'not_needed' end
    elseif d.kind == 'body' then
        local b = health(GetVehicleBodyHealth, veh)
        if b and b >= 999.0 then return false, 'not_needed' end
    elseif d.kind == 'kit' then
        local e = health(GetVehicleEngineHealth, veh)
        if e and e >= s.engine then return false, 'not_needed' end
    end
    local token = ('%d-%d'):format(info.src, math.random(100000, 999999))
    Work.pending[info.src] = { token = token, kind = d.kind, part = d.part, veh = veh, item = s.item, seconds = s.seconds, at = GetGameTimer(), engine = s.engine }
    return true, { token = token, seconds = s.seconds, label = s.label }
end

function Work.cancel(info, token)
    local p = Work.pending[info.src]
    if p and p.token == token then Work.pending[info.src] = nil end
    return true
end

function Work.finish(info, token)
    local p = Work.pending[info.src]
    if not p or p.token ~= token then return false, 'no_work' end
    Work.pending[info.src] = nil
    if GetGameTimer() - p.at < p.seconds * 800 then return false, 'too_fast' end
    local veh = p.veh
    if not DoesEntityExist(veh) then return false, 'no_vehicle' end
    if not Cars.near(info.src, veh, Config.WorkDistance + 2.0) then return false, 'too_far' end
    if not Core.removeItem(info.src, p.item, 1) then return false, 'no_item', { item = p.item } end
    local plate = Cars.plate(veh)
    if p.kind == 'part' then
        local st = Cars.status(veh)
        st[p.part] = 100.0
        Cars.setStatus(veh, st)
        if p.part == 'tyres' then Cars.fix(veh, 'tyres', nil, info.src) end
    elseif p.kind == 'engine' then
        Cars.fix(veh, 'engine', 1000.0, info.src)
        Cars.saveColumns(plate, { engine = 1000.0 })
    elseif p.kind == 'body' then
        Cars.fix(veh, 'body', 1000.0, info.src)
        Cars.saveColumns(plate, { body = 1000.0 })
    elseif p.kind == 'kit' then
        Cars.fix(veh, 'engine', p.engine, info.src)
    end
    TriggerEvent('vr-mechanic:server:repaired', plate, p.kind, p.part, info.src)
    return true, { plate = plate, status = Cars.status(veh) }
end

AddEventHandler('playerDropped', function()
    Work.pending[source] = nil
end)
