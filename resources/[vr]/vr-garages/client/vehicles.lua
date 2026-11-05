local ERR = {
    no_garage = 'This garage no longer exists',
    no_access = 'You cannot use this garage',
    too_far = 'Get closer to the garage',
    no_vehicle = 'Vehicle not found',
    not_owned = 'This vehicle is not registered to anyone',
    not_yours = 'This is not your vehicle',
    job_only = 'Job garages only hand out job vehicles. Personal cars go in a public garage.',
    wrong_category = 'That vehicle cannot be parked here',
    passengers = 'Everyone else needs to get out first',
    busy = 'Please wait a moment',
    not_here = 'You cannot park here',
    failed = 'Something went wrong, try again',
    slow_down = 'Slow down a little',
    occupied = 'Someone is still in the vehicle',
    not_loaded = 'Character not loaded',
    bank_flagged = 'The bank has flagged this vehicle for repossession. Clear your debt at a bank branch first.',
    job_garage = 'Job vehicles go back to their own job garage',
    low_grade = 'Your rank is too low for that vehicle',
    limit = 'You already have a job vehicle out. Park it first.',
}

function Garage.jobTag(veh)
    if not veh or veh == 0 then return nil end
    local ok, t = pcall(function() return Entity(veh).state.vr_jobveh end)
    return ok and type(t) == 'table' and t or nil
end

function Garage.errorText(code)
    return ERR[code] or 'Something went wrong, try again'
end

local function fuelOf(veh)
    return Bridge.vehicle.getFuel(veh)
end

function Garage.condition(veh)
    return {
        props = lib.getVehicleProperties(veh),
        fuel = fuelOf(veh),
        engine = GetVehicleEngineHealth(veh),
        body = GetVehicleBodyHealth(veh),
    }
end

local storing = false

function Garage.store(def, veh)
    if storing then return end
    for seat = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
        if GetPedInVehicleSeat(veh, seat) ~= 0 then return Garage.notify(ERR.passengers, 'error') end
    end
    storing = true
    local job = Garage.jobTag(veh) ~= nil
    local data = job and {} or Garage.condition(veh)
    data.garage = def.id
    data.netId = NetworkGetNetworkIdFromEntity(veh)
    local res = Garage.api('store', data)
    if res.ok then
        SetVehicleEngineOn(veh, false, true, true)
        TaskLeaveVehicle(cache.ped, veh, 0)
        if res.data.job then
            Garage.notify('Job vehicle returned', 'success')
        else
            Garage.notify(('%s parked'):format(res.data.plate), 'success')
        end
    else
        Garage.notify(Garage.errorText(res.error), 'error')
    end
    storing = false
    SetTimeout(2000, Garage.prompt)
end

RegisterNetEvent('vr-garages:client:spawned', function(netId, d)
    if type(d) ~= 'table' then return end
    local deadline = GetGameTimer() + 8000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(50) end
    local veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    while (veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do
        Wait(50)
        veh = NetworkDoesNetworkIdExist(netId) and NetToVeh(netId) or 0
    end
    if veh == 0 then return end
    local until_ = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < until_ do
        NetworkRequestControlOfEntity(veh)
        Wait(25)
    end
    if GetVehicleClass(veh) ~= 14 then SetVehicleOnGroundProperly(veh) end
    SetVehicleNumberPlateText(veh, d.plate)
    Bridge.vehicle.setFuel(veh, (tonumber(d.fuel) or 100) + 0.0)
    SetVehicleEngineHealth(veh, (tonumber(d.engine) or 1000) + 0.0)
    SetVehicleBodyHealth(veh, (tonumber(d.body) or 1000) + 0.0)
    SetVehicleDirtLevel(veh, 0.0)
    Bridge.vehicle.giveKeys(veh, d.plate)
    if type(d.job) == 'table' then Garage.applyJob(veh, d.job) end
    TriggerEvent('vr-garages:client:vehicleOut', veh, d.plate)
    if d.warp then TaskWarpPedIntoVehicle(cache.ped, veh, -1) end
    if type(d.job) == 'table' and d.job.menu then
        SetTimeout(600, function() Garage.setupMenu(veh, d.job.label) end)
    end
end)

local PERFORMANCE = { 11, 12, 13, 15, 16 }

local function liveryKind(veh)
    local n = GetVehicleLiveryCount(veh)
    if n and n > 0 then return 'livery', n end
    SetVehicleModKit(veh, 0)
    n = GetNumVehicleMods(veh, 48)
    if n and n > 0 then return 'mod', n end
    return nil, 0
end

local function setLivery(veh, kind, i)
    if kind == 'livery' then
        SetVehicleLivery(veh, i)
    elseif kind == 'mod' then
        SetVehicleModKit(veh, 0)
        SetVehicleMod(veh, 48, i, false)
    end
end

local function liveryName(veh, kind, i)
    local key = kind == 'livery' and GetLiveryName(veh, i) or GetModTextLabel(veh, 48, i)
    local text = type(key) == 'string' and key ~= '' and GetLabelText(key) or nil
    if not text or text == '' or text == 'NULL' then text = ('Livery %d'):format(i + 1) end
    return text
end

function Garage.applyJob(veh, job)
    SetVehicleModKit(veh, 0)
    if job.maxMods then
        for _, m in ipairs(PERFORMANCE) do
            local n = GetNumVehicleMods(veh, m)
            if n and n > 0 then SetVehicleMod(veh, m, n - 1, false) end
        end
        ToggleVehicleMod(veh, 18, true)
    end
    if tonumber(job.livery) then
        local kind, count = liveryKind(veh)
        local i = math.floor(tonumber(job.livery))
        if kind and i >= 0 and i < count then setLivery(veh, kind, i) end
    end
    if type(job.extras) == 'table' then
        for _, e in ipairs(job.extras) do
            local id = tonumber(e.id)
            if id and DoesExtraExist(veh, id) then SetVehicleExtra(veh, id, not e.on) end
        end
    end
end

function Garage.setupMenu(veh, title)
    if not veh or not DoesEntityExist(veh) then return end
    local kind, count = liveryKind(veh)
    local options = {}
    if count > 1 then
        local names = {}
        for i = 0, count - 1 do names[#names + 1] = liveryName(veh, kind, i) end
        local current = kind == 'livery' and GetVehicleLivery(veh) or GetVehicleMod(veh, 48)
        options[#options + 1] = { label = 'Livery', icon = 'fa-solid fa-paint-roller', values = names, defaultIndex = math.max(1, (current or 0) + 1), close = false, args = { livery = true } }
    end
    for id = 0, 20 do
        if DoesExtraExist(veh, id) then
            options[#options + 1] = { label = ('Extra %d'):format(id), icon = 'fa-solid fa-puzzle-piece', checked = IsVehicleExtraTurnedOn(veh, id), close = false, args = { extra = id } }
        end
    end
    if #options == 0 then return end
    options[#options + 1] = { label = 'Done', icon = 'fa-solid fa-check', args = { done = true } }
    lib.registerMenu({
        id = 'vr-garages:setup',
        title = title or 'Vehicle setup',
        position = 'top-right',
        options = options,
        onSideScroll = function(_, scroll, args)
            if type(args) == 'table' and args.livery and DoesEntityExist(veh) then setLivery(veh, kind, (tonumber(scroll) or 1) - 1) end
        end,
        onCheck = function(_, checked, args)
            if type(args) == 'table' and args.extra and DoesEntityExist(veh) then SetVehicleExtra(veh, args.extra, not checked) end
        end,
    }, function() end)
    lib.showMenu('vr-garages:setup')
end
