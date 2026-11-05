local I = Config.Impound

local function canImpound()
    local job = Garage.pd.job
    if type(job) ~= 'table' then return false end
    local min = I.jobs[job.name]
    if not min then return false end
    local grade = type(job.grade) == 'table' and tonumber(job.grade.level) or tonumber(job.grade) or 0
    if grade < min then return false end
    return not I.requireDuty or job.onduty == true
end

local busy = false

local function impound(entity)
    if busy or not entity or entity == 0 then return end
    local input = lib.inputDialog('Impound vehicle', {
        { type = 'input', label = 'Reason', required = true, min = 3, max = 120, placeholder = 'Parked illegally, used in a crime...' },
        { type = 'number', label = 'Release fee', default = I.defaultFee, min = 0, max = I.maxFee },
        { type = 'number', label = 'Hold time in hours', default = 0, min = 0, max = I.maxHoldHours },
    })
    if not input or not DoesEntityExist(entity) then return end
    busy = true
    local done = lib.progressBar({
        duration = 6000,
        label = 'Calling the tow truck',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
    })
    ClearPedTasks(cache.ped)
    if not done or not DoesEntityExist(entity) then busy = false return end
    local data = Garage.condition(entity)
    data.netId = NetworkGetNetworkIdFromEntity(entity)
    data.reason = input[1]
    data.fee = input[2]
    data.hours = input[3]
    local res = Garage.api('police.impound', data)
    busy = false
    if not res.ok then return Garage.notify(Garage.errorText(res.error), 'error') end
    Garage.notify(res.data.owned and ('%s sent to the impound lot'):format(res.data.plate) or 'Unregistered vehicle removed', 'success')
end

CreateThread(function()
    Bridge.target.addGlobalVehicle({
        {
            name = 'vr-garages:impound',
            label = 'Impound vehicle',
            icon = 'fa-solid fa-truck-ramp-box',
            distance = I.distance,
            canInteract = function(entity) return not busy and canImpound() and GetPedInVehicleSeat(entity, -1) == 0 end,
            onSelect = function(data) impound(type(data) == 'table' and data.entity or data) end,
        },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    pcall(function() Bridge.target.removeGlobalVehicle('vr-garages:impound') end)
end)
