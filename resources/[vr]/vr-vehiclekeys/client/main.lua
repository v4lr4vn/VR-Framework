Keys = { held = {}, hotLocal = {} }

local ERRORS = {
    no_keys = 'You do not have the keys to this vehicle',
    no_vehicle = 'No vehicle found',
    too_far = 'Get closer',
    not_owner = 'Only the owner can do that',
    no_player = 'That person is not around',
    bad_target = 'Pick someone else',
    limit = 'Too many people already hold keys to this vehicle',
    cooldown = 'Give it a moment before trying again',
    no_item = 'You need a lockpick',
    not_locked = 'It is not locked',
    in_vehicle = 'Get out of the vehicle first',
    have_keys = 'You already have the keys',
    not_driver = 'You need to be in the driver seat',
    already = 'That is already done',
    no_money = 'You cannot afford that',
    slow_down = 'Slow down',
    not_yours = 'That vehicle belongs to someone else',
    occupied = 'Someone is driving it',
    owner_key = 'That is your own key',
    no_key = 'There is no key to take',
    disabled = 'That is turned off',
}

function Keys.errorText(code)
    return ERRORS[code] or 'Something went wrong'
end

function Keys.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-vehiclekeys:api', false, action, data or {})
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Keys.notify(text, kind)
    lib.notify({ title = 'Vehicle keys', description = text, type = kind or 'inform' })
end

function Keys.bag(veh, key)
    local ok, v = pcall(function() return Entity(veh).state[key] end)
    if ok then return v end
    return nil
end

function Keys.plateOf(veh)
    return KU.plate(GetVehicleNumberPlateText(veh))
end

function Keys.group(veh)
    if not Config.Group.jobVehicles then return false end
    local tag = Keys.bag(veh, 'vr_jobveh')
    local group = type(tag) == 'table' and type(tag.group) == 'string' and tag.group or nil
    if not group then return false end
    local what, name = group:match('^(%a+):(.+)$')
    if what == 'job' then
        local job = Bridge.job()
        return type(job) == 'table' and job.name == name and (not Config.Group.requireDuty or job.onduty == true)
    end
    if what == 'gang' then
        local gang = Bridge.gang()
        return type(gang) == 'table' and gang.name == name
    end
    return false
end

function Keys.has(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    if Config.NoKeyClasses[GetVehicleClass(veh)] then return 'free' end
    local plate = Keys.plateOf(veh)
    local kind = plate and Keys.held[plate]
    if kind then return kind end
    local bag = KU.plate(Keys.bag(veh, 'vr_plate'))
    kind = bag and Keys.held[bag]
    if kind then return kind end
    if Keys.group(veh) then return 'group' end
    if Keys.bag(veh, 'vr_hotwired') == true or Keys.hotLocal[veh] then return 'hotwired' end
    return nil
end

RegisterNetEvent('vr-vehiclekeys:client:sync', function(held)
    Keys.held = type(held) == 'table' and held or {}
end)

local function sync()
    local res = Keys.api('sync')
    if res.ok and type(res.data) == 'table' and type(res.data.held) == 'table' then Keys.held = res.data.held end
end

Bridge.on('playerLoaded', function()
    CreateThread(function()
        Wait(1500)
        sync()
    end)
end)

Bridge.on('playerUnloaded', function()
    Keys.held = {}
end)

CreateThread(function()
    Wait(2000)
    if Bridge.loggedIn() then sync() end
end)

local function findByPlate(plate)
    local ped = cache.ped or PlayerPedId()
    local inside = GetVehiclePedIsIn(ped, false)
    if inside ~= 0 and Keys.plateOf(inside) == plate then return inside end
    local pos = GetEntityCoords(ped)
    for _, v in ipairs(lib.getNearbyVehicles(pos, Config.Claims.range - 1.0, true)) do
        if Keys.plateOf(v.vehicle) == plate then return v.vehicle end
    end
    return nil
end

RegisterNetEvent('vehiclekeys:client:SetOwner', function(plate)
    plate = KU.plate(plate)
    if not plate or Keys.held[plate] then return end
    CreateThread(function()
        local veh
        for _ = 1, 10 do
            veh = findByPlate(plate)
            if veh then break end
            Wait(200)
        end
        if not veh or not NetworkGetEntityIsNetworked(veh) then return end
        Keys.api('claim', { netId = NetworkGetNetworkIdFromEntity(veh), how = 'event' })
    end)
end)

exports('HasKeys', function(v)
    if type(v) == 'string' then
        local plate = KU.plate(v)
        return plate ~= nil and Keys.held[plate] ~= nil
    end
    return Keys.has(v) ~= nil
end)
