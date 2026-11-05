local lastSent = {}

local function jobType()
    local job = Mdt.playerData().job or {}
    return job.type, job.onduty
end

local function ignored()
    local t, onduty = jobType()
    if not onduty then return false end
    for _, j in ipairs(Config.AutoAlerts.ignoreJobs or {}) do
        if j == t then return true end
    end
    return false
end

local function ready(kind)
    local now = GetGameTimer()
    if lastSent[kind] and now - lastSent[kind] < (Config.AutoAlerts.cooldown or 20) * 1000 then return false end
    lastSent[kind] = now
    return true
end

local function colourName(veh)
    local primary = GetVehicleColours(veh)
    local names = {
        [0] = 'Black', [1] = 'Graphite', [2] = 'Black steel', [3] = 'Dark silver', [4] = 'Silver', [5] = 'Blue silver', [6] = 'Steel grey',
        [7] = 'Shadow silver', [8] = 'Stone silver', [9] = 'Midnight silver', [10] = 'Gunmetal', [11] = 'Anthracite', [12] = 'Matte black',
        [13] = 'Grey', [14] = 'Light grey', [27] = 'Red', [28] = 'Torino red', [29] = 'Formula red', [30] = 'Blaze red', [31] = 'Grace red',
        [32] = 'Garnet red', [33] = 'Sunset red', [34] = 'Cabernet red', [35] = 'Candy red', [36] = 'Sunrise orange', [38] = 'Orange',
        [49] = 'Dark green', [50] = 'Racing green', [51] = 'Sea green', [52] = 'Olive green', [53] = 'Bright green', [55] = 'Lime green',
        [61] = 'Midnight blue', [62] = 'Dark blue', [63] = 'Saxon blue', [64] = 'Blue', [65] = 'Mariner blue', [66] = 'Harbor blue',
        [67] = 'Diamond blue', [68] = 'Surf blue', [69] = 'Nautical blue', [70] = 'Ultra blue', [73] = 'Racing blue', [74] = 'Light blue',
        [88] = 'Yellow', [89] = 'Race yellow', [90] = 'Bronze', [91] = 'Dew yellow', [94] = 'Brown', [96] = 'Dark brown', [104] = 'Sandy brown',
        [111] = 'White', [112] = 'Frost white', [134] = 'Pure white', [135] = 'Hot pink', [137] = 'Pink', [141] = 'Purple', [142] = 'Midnight purple',
        [145] = 'Bright purple', [147] = 'Carbon black',
    }
    return names[primary] or 'Unknown'
end

local function vehicleInfo(veh)
    if not veh or veh == 0 or not DoesEntityExist(veh) then return {} end
    local model = GetEntityModel(veh)
    local label = GetLabelText(GetDisplayNameFromVehicleModel(model))
    if label == 'NULL' then label = GetDisplayNameFromVehicleModel(model) end
    local info = {
        { label = 'Vehicle', value = label },
        { label = 'Colour', value = colourName(veh) },
    }
    local plate = GetVehicleNumberPlateText(veh)
    if plate and plate ~= '' then info[#info + 1] = { label = 'Plate', value = plate:gsub('^%s+', ''):gsub('%s+$', '') } end
    local heading = GetEntityHeading(veh)
    local dirs = { 'north', 'north-west', 'west', 'south-west', 'south', 'south-east', 'east', 'north-east' }
    info[#info + 1] = { label = 'Heading', value = dirs[(math.floor((heading + 22.5) / 45) % 8) + 1] }
    return info
end

local function gender(ped)
    return IsPedMale(ped) and 'Male' or 'Female'
end

local function send(codeName, info)
    local c = GetEntityCoords(Bridge.cache.ped)
    TriggerServerEvent('vr-mdt:server:alert', codeName, {
        coords = { x = c.x, y = c.y, z = c.z },
        street = Mdt.streetAt(c.x, c.y, c.z),
        info = info,
    })
end

local function witnessed(radius)
    local here = GetEntityCoords(Bridge.cache.ped)
    local handle, ped = FindFirstPed()
    local ok = true
    local found = false
    while ok do
        if ped ~= Bridge.cache.ped and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true) and #(GetEntityCoords(ped) - here) < radius then
            found = true
            break
        end
        ok, ped = FindNextPed(handle)
    end
    EndFindPed(handle)
    return found
end

local silenced = {}
for _, h in ipairs((Config.AutoAlertWeapons or {}).silenced or {}) do silenced[h] = true end

CreateThread(function()
    while true do
        local sleep = 500
        if Config.AutoAlerts.shooting and IsPedShooting(Bridge.cache.ped) then
            sleep = 0
            local weapon = GetSelectedPedWeapon(Bridge.cache.ped)
            if not silenced[weapon] and not IsPedCurrentWeaponSilenced(Bridge.cache.ped) and not ignored() and ready('shooting') then
                local veh = Bridge.cache.vehicle
                local info = { { label = 'Gender', value = gender(Bridge.cache.ped) } }
                if veh then
                    for _, e in ipairs(vehicleInfo(veh)) do info[#info + 1] = e end
                    send('shootingvehicle', info)
                else
                    send('shooting', info)
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    while true do
        Wait(250)
        local ped = Bridge.cache.ped
        if Config.AutoAlerts.autotheft and (IsPedJacking(ped) or IsPedTryingToEnterALockedVehicle(ped)) and not ignored() then
            local veh = GetVehiclePedIsTryingToEnter(ped)
            if veh == 0 then veh = GetVehiclePedIsIn(ped, false) end
            if ready('autotheft') and witnessed(40.0) then
                local info = { { label = 'Gender', value = gender(ped) } }
                for _, e in ipairs(vehicleInfo(veh)) do info[#info + 1] = e end
                send('autotheft', info)
            end
        end
        if Config.AutoAlerts.melee and IsPedInMeleeCombat(ped) and not ignored() then
            local target = GetMeleeTargetForPed(ped)
            if target ~= 0 and IsPedAPlayer(target) == false and ready('melee') and witnessed(30.0) then
                send('melee', { { label = 'Gender', value = gender(ped) } })
            end
        end
        if Config.AutoAlerts.speeding and Bridge.cache.vehicle and GetPedInVehicleSeat(Bridge.cache.vehicle, -1) == ped and not ignored() then
            local speed = GetEntitySpeed(Bridge.cache.vehicle) * 2.236936
            if speed > 120 and ready('speeding') and witnessed(60.0) then
                local info = vehicleInfo(Bridge.cache.vehicle)
                info[#info + 1] = { label = 'Speed', value = ('%d mph'):format(math.floor(speed)) }
                send('speeding', info)
            end
        end
    end
end)

AddEventHandler('gameEventTriggered', function(name, args)
    if not Config.AutoAlerts.explosion or name ~= 'CEventNetworkEntityDamage' then return end
    local victim, attacker, _, _, _, weapon = args[1], args[2], args[3], args[4], args[5], args[7]
    if attacker ~= Bridge.cache.ped or ignored() then return end
    if weapon and (weapon == `WEAPON_EXPLOSION` or weapon == `WEAPON_GRENADE` or weapon == `WEAPON_STICKYBOMB` or weapon == `WEAPON_RPG`) and victim ~= 0 then
        if ready('explosion') then send('explosion', {}) end
    end
end)
