local ALIASES = { 'vr-dispatch', 'ps-dispatch' }

local function exportAs(name, fn)
    exports(name, fn)
    for _, res in ipairs(ALIASES) do
        AddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
    end
end

local function here()
    local c = GetEntityCoords(Bridge.cache.ped)
    return { x = c.x, y = c.y, z = c.z }, Mdt.streetAt(c.x, c.y, c.z)
end

local function vehicleOf(ped)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetVehiclePedIsTryingToEnter(ped) end
    if veh == 0 then return nil end
    return veh
end

local function presetAlert(codeName, extra)
    return function(data)
        local coords, street = here()
        local info = {}
        if type(data) == 'table' and type(data.info) == 'table' then info = data.info end
        if extra then
            for _, e in ipairs(extra()) do info[#info + 1] = e end
        end
        TriggerServerEvent('vr-mdt:server:alert', codeName, { coords = coords, street = street, info = info })
    end
end

local function gender()
    return { { label = 'Gender', value = IsPedMale(Bridge.cache.ped) and 'Male' or 'Female' } }
end

local function withVehicle()
    local out = gender()
    local veh = vehicleOf(Bridge.cache.ped)
    if veh then
        local plate = GetVehicleNumberPlateText(veh)
        local model = GetDisplayNameFromVehicleModel(GetEntityModel(veh))
        out[#out + 1] = { label = 'Vehicle', value = GetLabelText(model) ~= 'NULL' and GetLabelText(model) or model }
        if plate then out[#out + 1] = { label = 'Plate', value = (plate:gsub('^%s+', ''):gsub('%s+$', '')) } end
    end
    return out
end

local presets = {
    VehicleTheft = { 'vehicletheft', withVehicle },
    CarJacking = { 'autotheft', withVehicle },
    Shooting = { 'shooting', gender },
    ShotsFired = { 'shooting', gender },
    VehicleShooting = { 'shootingvehicle', withVehicle },
    SpeedingVehicle = { 'speeding', withVehicle },
    Fight = { 'melee', gender },
    StoreRobbery = { 'storerobbery', gender },
    FleecaBankRobbery = { 'bankrobbery', gender },
    PaletoBankRobbery = { 'bankrobbery', gender },
    PacificBankRobbery = { 'bankrobbery', gender },
    VangelicoRobbery = { 'jewelryrobbery', gender },
    HouseRobbery = { 'houserobbery', gender },
    SuspiciousActivity = { 'suspicious', gender },
    DrugSale = { 'drugsale', gender },
    ExplosionAlert = { 'explosion' },
    InjuriedPerson = { 'injured' },
    DeceasedPerson = { 'deceased' },
    OfficerDown = { 'officerdown' },
    OfficerBackup = { 'officerbackup' },
    OfficerInDistress = { 'panic' },
    EmsDown = { 'emsdown' },
    SignRobbery = { 'signrobbery', gender },
}

for name, p in pairs(presets) do
    exportAs(name, presetAlert(p[1], p[2]))
end

exportAs('CustomAlert', function(data)
    if type(data) ~= 'table' then return end
    local coords, street = here()
    if type(data.coords) == 'vector3' or type(data.coords) == 'table' then
        coords = { x = data.coords.x, y = data.coords.y, z = data.coords.z }
        street = Mdt.streetAt(coords.x, coords.y, coords.z)
    end
    local info = {}
    for _, f in ipairs({ { 'gender', 'Gender' }, { 'vehicle', 'Vehicle' }, { 'plate', 'Plate' }, { 'color', 'Colour' }, { 'weapon', 'Weapon' } }) do
        if data[f[1]] then info[#info + 1] = { label = f[2], value = tostring(data[f[1]]) } end
    end
    TriggerServerEvent('vr-mdt:server:alert', 'custom', {
        coords = coords,
        street = street,
        title = data.message or data.title,
        description = data.information or data.description,
        code = data.code or data.dispatchCode,
        jobs = data.jobs,
        info = info,
    })
end)

exportAs('OpenDispatchMenu', function()
    Mdt.openTablet('dispatch')
end)
