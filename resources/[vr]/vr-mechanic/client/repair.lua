Repair = { busy = false }

local WORK = { engine = 'engine', radiator = 'engine', clutch = 'under', suspension = 'under', brakes = 'wheel', tyres = 'wheel' }
local KIND_WORK = { engine = 'engine', body = 'body', kit = 'engine' }

local LABEL = {
    engine = 'Rebuilding the engine',
    body = 'Fixing the bodywork',
    kit = 'Patching up the engine',
}

function Repair.run(kind, veh, part, reopen)
    if Repair.busy or not DoesEntityExist(veh) then return end
    if IsPedInAnyVehicle(cache.ped, false) then return Mech.notify(Mech.errorText('in_vehicle'), 'error') end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local res = Mech.api('work.begin', { kind = kind, part = part, netId = netId })
    if not res.ok then
        if res.error == 'no_item' and res.data and res.data.item then
            local item = res.data.item
            local label = item
            pcall(function()
                local it = exports['vr-inventory']:Items(item)
                if it and it.label then label = it.label end
            end)
            return Mech.notify(('You need %s'):format(label), 'error')
        end
        return Mech.notify(Mech.errorText(res.error), 'error')
    end
    Repair.busy = true
    local work = kind == 'part' and (WORK[part] or 'engine') or (KIND_WORK[kind] or 'engine')
    local done = Anim.perform(veh, work, res.data.seconds * 1000, kind == 'part' and ('Replacing %s'):format(res.data.label:lower()) or LABEL[kind] or res.data.label)
    if not done then
        Mech.api('work.cancel', { token = res.data.token })
        Repair.busy = false
        return Mech.notify('Stopped', 'error')
    end
    local fin = Mech.api('work.finish', { token = res.data.token })
    Repair.busy = false
    if not fin.ok then return Mech.notify(Mech.errorText(fin.error), 'error') end
    Mech.notify(kind == 'part' and ('%s replaced'):format(res.data.label) or 'Repair done', 'success')
    if reopen and Mech.isMechanic() and DoesEntityExist(veh) then Mech.inspect(veh) end
end

local function vehicleFromNet(netId)
    local deadline = GetGameTimer() + 3000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(50) end
    if not NetworkDoesNetworkIdExist(netId) then return 0 end
    return NetToVeh(netId)
end

RegisterNetEvent('vr-mechanic:client:fix', function(netId, what, value)
    local veh = vehicleFromNet(netId)
    if veh == 0 or not DoesEntityExist(veh) then return end
    if not NetworkHasControlOfEntity(veh) then
        local t = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do
            NetworkRequestControlOfEntity(veh)
            Wait(25)
        end
    end
    if what == 'engine' then
        SetVehicleEngineHealth(veh, math.max(GetVehicleEngineHealth(veh), (tonumber(value) or 1000.0) + 0.0))
        if (tonumber(value) or 0) >= 1000 then SetVehiclePetrolTankHealth(veh, 1000.0) end
    elseif what == 'body' then
        local engine, fuel = GetVehicleEngineHealth(veh), GetVehicleFuelLevel(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, engine)
        SetVehicleFuelLevel(veh, fuel)
        SetVehicleBodyHealth(veh, 1000.0)
    elseif what == 'tyres' then
        for i = 0, 7 do SetVehicleTyreFixed(veh, i) end
    elseif what == 'full' then
        local fuel = GetVehicleFuelLevel(veh)
        SetVehicleFixed(veh)
        SetVehicleDeformationFixed(veh)
        SetVehicleEngineHealth(veh, 1000.0)
        SetVehicleBodyHealth(veh, 1000.0)
        SetVehiclePetrolTankHealth(veh, 1000.0)
        SetVehicleFuelLevel(veh, fuel)
    end
    if Effects then Effects.reset(veh) end
end)

exports('repairKit', function()
    if Repair.busy then return end
    if IsPedInAnyVehicle(cache.ped, false) then return Mech.notify(Mech.errorText('in_vehicle'), 'error') end
    local veh = lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
    if not veh then return Mech.notify('No vehicle nearby', 'error') end
    Repair.run('kit', veh)
end)
