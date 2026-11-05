VRCore = exports['vr-core']:GetCoreObject()

local PlayerData = {}

local function sharedJobType(name)
    local jobs = VRCore.Shared and VRCore.Shared.Jobs
    local job = jobs and name and jobs[name]
    return job and job.type or nil
end

local function setPlayerData(pd)
    PlayerData = type(pd) == 'table' and pd or {}
    local job = PlayerData.job
    if type(job) == 'table' and job.type == nil then job.type = sharedJobType(job.name) end
end

local function refresh()
    setPlayerData(VRCore.Functions.GetPlayerData())
end

if LocalPlayer.state.isLoggedIn then refresh() end

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', refresh)

RegisterNetEvent('VRCore:Client:OnPlayerUnload', function()
    PlayerData = {}
end)

AddEventHandler('VRCore:Player:SetPlayerData', setPlayerData)

AddEventHandler('VRCore:Client:OnJobUpdate', function(job)
    if type(job) ~= 'table' then return end
    if job.type == nil then job.type = sharedJobType(job.name) end
    PlayerData.job = job
end)

RegisterNetEvent('VRCore:Client:SetDuty', function(onduty)
    if type(PlayerData.job) == 'table' then PlayerData.job.onduty = onduty == true end
end)

local function jobIn(job, list)
    if type(job) ~= 'table' then return false end
    if type(list) == 'string' then list = { list } end
    if type(list) ~= 'table' then return false end
    for _, key in pairs(list) do
        if key == job.name or (job.type ~= nil and key == job.type) then return true end
    end
    return false
end

function hasJob(jobs)
    local job = PlayerData.job
    return jobIn(job, jobs) or jobIn(job, Config.JobTypes)
end

function isOnDuty()
    return type(PlayerData.job) == 'table' and PlayerData.job.onduty == true
end

function getPlayerJobGrade()
    local grade = type(PlayerData.job) == 'table' and PlayerData.job.grade
    return tonumber(type(grade) == 'table' and grade.level or grade) or 0
end

function getPlayerData()
    return PlayerData
end

local function clothing()
    local res = Config.ClothingScript
    return res and GetResourceState(res) == 'started' and res or nil
end

function toggleClothes(toggle, clothes)
    local res = clothing()
    if not res then return utils.showNotification(locale('clothing_unavailable'), 'error') end

    if not toggle then
        utils.debug('Putting civil clothes')
        TriggerEvent('vr-clothing:client:reloadSkin')
        return
    end

    utils.debug('Putting on clothes')

    local playerPed = cache.ped
    local jobGrade = getPlayerJobGrade()
    local model = exports[res]:getPedModel(playerPed)
    local data

    if model == 'mp_m_freemode_01' then
        data = clothes.male[jobGrade] or clothes.male[1]
    elseif model == 'mp_f_freemode_01' then
        data = clothes.female[jobGrade] or clothes.female[1]
    end

    if not data then return end

    exports[res]:setPedProps(playerPed, {
        { prop_id = 0, texture = data['helmet_2'], drawable = data['helmet_1'] },
    })

    exports[res]:setPedComponents(playerPed, {
        { component_id = 1,  texture = data['mask_2'],    drawable = data['mask_1'] },
        { component_id = 3,  texture = 0,                 drawable = data['arms'] },
        { component_id = 8,  texture = data['tshirt_2'],  drawable = data['tshirt_1'] },
        { component_id = 11, texture = data['torso_2'],   drawable = data['torso_1'] },
        { component_id = 9,  texture = data['bproof_2'],  drawable = data['bproof_1'] },
        { component_id = 10, texture = data['decals_2'],  drawable = data['decals_1'] },
        { component_id = 7,  texture = data['chain_2'],   drawable = data['chain_1'] },
        { component_id = 4,  texture = data['pants_2'],   drawable = data['pants_1'] },
        { component_id = 6,  texture = data['shoes_2'],   drawable = data['shoes_1'] },
        { component_id = 5,  texture = data['bag_color'] or 0, drawable = data['bag'] or 0 },
    })
end

function openBossMenu(job)
    local boss = Config.BossMenu
    if not boss or not boss.resource or GetResourceState(boss.resource) ~= 'started' then
        return utils.showNotification(locale('bossmenu_unavailable'), 'error')
    end
    TriggerEvent(boss.event, job)
end

function setVehicleFuel(vehicle, level)
    local res = Config.Fuel
    if res and GetResourceState(res) == 'started' then
        local ok = pcall(function() exports[res]:SetFuel(vehicle, level) end)
        if ok then return end
    end
    SetVehicleFuelLevel(vehicle, level + 0.0)
end

function giveVehicleKeys(vehicle)
    local res = Config.VehicleKeys
    if not res or GetResourceState(res) ~= 'started' then return end
    TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(vehicle))
end
