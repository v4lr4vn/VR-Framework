Core = {}

function Core.player(src)
    src = tonumber(src)
    if not src then return nil end
    return Bridge.player(src)
end

function Core.online(cid)
    if type(cid) ~= 'string' then return nil end
    return Bridge.playerByCid(cid)
end

function Core.sourceOf(cid)
    if type(cid) ~= 'string' then return nil end
    return Bridge.source(cid)
end

function Core.license(cid)
    return Bridge.chars.license(cid)
end

function Core.info(src)
    local p = Core.player(src)
    if not p then return nil end
    local job, gang = p.job or {}, p.gang or {}
    return {
        src = tonumber(src),
        cid = p.cid,
        license = Bridge.license(src),
        name = p.name,
        job = { name = job.name, label = job.label, grade = tonumber(job.grade) or 0, isboss = job.isboss == true, onduty = job.onduty == true },
        gang = { name = gang.name, label = gang.label, grade = tonumber(gang.grade) or 0, isboss = gang.isboss == true },
    }
end

function Core.pay(src, amount, reason, method)
    return Bridge.pay(src, amount, reason, method)
end

function Core.vehicle(model)
    return Bridge.vehicleData(model)
end

function Core.vehicleLabel(model)
    return Bridge.vehicleLabel(model)
end

function Core.vehicleType(model)
    local v = Core.vehicle(model)
    return v and v.type or 'automobile'
end

function Core.isJob(name) return Bridge.isJob(name) end
function Core.isGang(name) return Bridge.isGang(name) end

function Core.groupLabel(kind, name)
    return Bridge.groupLabel(name, kind == 'gang' and 'gang' or 'job')
end

function Core.notify(src, text, kind)
    if not src then return end
    Bridge.notify(src, text, kind or 'inform', nil, 'Garage')
end

function Core.coords(src)
    return Bridge.coords(src)
end

function Core.bankHeld(plate)
    if GetResourceState('vr-banking') ~= 'started' then return false end
    local ok, held = pcall(function() return exports['vr-banking']:IsVehicleHeld(plate) end)
    return ok and held == true
end

function Core.bankFlagged(plate)
    if GetResourceState('vr-banking') ~= 'started' then return false end
    local ok, flagged = pcall(function() return exports['vr-banking']:IsVehicleFlagged(plate) end)
    return ok and flagged == true
end
