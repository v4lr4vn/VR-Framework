local function resolve(v)
    if type(v) == 'number' then
        local veh = Cars.entity(v)
        if veh then return veh end
        if DoesEntityExist(v) and GetEntityType(v) == 2 then return v end
    end
    return nil
end

local function statusFor(v)
    local veh = resolve(v)
    if veh then return Cars.status(veh) end
    local plate = MU.plate(v)
    if plate and Db.vehicles then
        for _, e in ipairs(GetAllVehicles()) do
            if Cars.plate(e) == plate then return Cars.status(e) end
        end
        local raw = MySQL.scalar.await('SELECT status FROM player_vehicles WHERE plate = ?', { plate })
        local ok, st = pcall(json.decode, raw or '')
        return MU.fullStatus(ok and st or nil)
    end
    return nil
end

local function setStatus(v, status)
    local veh = resolve(v)
    if not veh or type(status) ~= 'table' then return false end
    local cur = Cars.status(veh)
    for k in pairs(Config.Parts) do
        local n = tonumber(status[k])
        if n and n == n then cur[k] = n end
    end
    Cars.setStatus(veh, cur)
    return true
end

local function repair(v, full)
    local veh = resolve(v)
    if not veh then return false end
    local st = {}
    for k in pairs(Config.Parts) do st[k] = 100.0 end
    Cars.setStatus(veh, st)
    if full ~= false then
        Cars.fix(veh, 'full', 1000.0)
        Cars.saveColumns(Cars.plate(veh), { engine = 1000.0, body = 1000.0 })
    end
    return true
end

local function isMechanic(src)
    local info = Core.info(src)
    return info ~= nil and Core.isMechanic(info)
end

local function workshops()
    local out = {}
    for id, w in pairs(Workshops.list) do out[id] = { id = id, label = w.label, job = w.job, center = w.center, counter = w.counter, radius = w.radius } end
    return out
end

exports('GetVehicleStatus', statusFor)
exports('SetVehicleStatus', setStatus)
exports('RepairVehicle', repair)
exports('IsMechanic', isMechanic)
exports('GetWorkshops', workshops)
exports('getVehicleStatus', statusFor)
exports('setVehicleStatus', setStatus)
exports('repairVehicle', repair)
exports('isMechanic', isMechanic)
exports('getWorkshops', workshops)
