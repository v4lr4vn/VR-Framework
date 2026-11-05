local TaskStartScenarioInPlace         = TaskStartScenarioInPlace
local GetOffsetFromEntityInWorldCoords = GetOffsetFromEntityInWorldCoords
local TaskPlayAnim                     = TaskPlayAnim
local Wait                             = Wait
local CreateObjectNoOffset             = CreateObjectNoOffset
local PlaceObjectOnGroundProperly      = PlaceObjectOnGroundProperly
local DeleteEntity                     = DeleteEntity
local ClearPedTasks                    = ClearPedTasks
local RegisterNetEvent                 = RegisterNetEvent

local medicBagProp                     = lib.load("config").medicBagProp

local function openMedicalBag(netId)
    local playerPed = cache.ped or PlayerPedId()

    TaskStartScenarioInPlace(playerPed, "CODE_HUMAN_MEDIC_TEND_TO_DEAD")

    local stash = lib.callback.await('vr-ambulancejob:openMedicalBag', false, netId)
    if not stash then
        ClearPedTasks(playerPed)
        return
    end

    exports['vr-inventory']:openInventory("stash", stash)
end

local function placeMedicalBag()
    if not lib.callback.await('vr-ambulancejob:placeMedicalBag', false) then return end

    lib.requestAnimDict("pickup_object")
    lib.requestModel(medicBagProp)

    local playerPed = cache.ped or PlayerPedId()
    local coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 0.5, 0.0)

    TaskPlayAnim(playerPed, "pickup_object", "pickup_low", 8.0, 8.0, 1000, 50, 0, false, false, false)

    Wait(900)

    local medicBag = CreateObjectNoOffset(medicBagProp, coords.x, coords.y, coords.z, true, false)
    PlaceObjectOnGroundProperly(medicBag)

    local timeout = GetGameTimer() + 3000
    while not NetworkGetEntityIsNetworked(medicBag) and GetGameTimer() < timeout do Wait(50) end

    local netId = NetworkGetNetworkIdFromEntity(medicBag)
    TriggerServerEvent('vr-ambulancejob:registerMedicalBag', netId)

    Target.addLocalEntity(medicBag, {
        {
            label = locale('open_medical_bag'),
            icon = 'fa-solid fa-suitcase',
            groups = false,
            fn = function()
                openMedicalBag(netId)
            end
        },
        {
            label = locale('pickup_medical_bag'),
            icon = 'fa-solid fa-xmark',
            groups = false,
            fn = function(data)
                local ped = cache.ped or PlayerPedId()
                TaskPlayAnim(ped, "pickup_object", "pickup_low", 8.0, 8.0, 1000, 50, 0, false, false, false)

                Wait(900)
                ClearPedTasks(ped)

                local ok, reason = lib.callback.await('vr-ambulancejob:pickupMedicalBag', false, netId)
                if not ok then
                    if reason then utils.showNotification(locale(reason), "error") end
                    return
                end

                local entity = type(data) == "number" and data or data.entity
                if DoesEntityExist(entity) then DeleteEntity(entity) end
            end
        },
    })
end

local emsJobs = lib.load("config").emsJobs

RegisterNetEvent("vr-ambulancejob:placeMedicalBag", function()
    if not Framework.hasJob(emsJobs) then return end

    placeMedicalBag()
end)
