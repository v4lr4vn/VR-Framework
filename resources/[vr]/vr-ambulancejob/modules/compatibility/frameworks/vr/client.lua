local VRCore         = exports['vr-core']:GetCoreObject()

Framework            = {}
local vrInventory   = exports['vr-inventory']

local config         = lib.load("config")
local clothingScript = config.clothingScript
local emsJobs        = config.emsJobs

local function playerData()
    return VRCore.Functions.GetPlayerData() or {}
end

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function()
    Wait(3000)
    onPlayerLoaded()
end)

RegisterNetEvent('VRCore:Client:OnPlayerUnload', function()
    player.isDead = false
    player.gettingRevived = false
    player.respawning = false
    SetEntityInvincible(cache.ped, false)
    SetEveryoneIgnorePlayer(cache.playerId, false)
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() or not LocalPlayer.state.isLoggedIn then return end
    CreateThread(onPlayerLoaded)
end)

function Framework.getJob()
    local job = playerData().job
    if type(job) ~= "table" then return nil end

    if not job.type then
        local shared = VRCore.Shared and VRCore.Shared.Jobs and VRCore.Shared.Jobs[job.name]
        job.type = shared and shared.type or "none"
    end

    return job
end

function Framework.getPlayerJobGrade()
    local job = Framework.getJob()
    local jobGrade = job and job.grade

    return type(jobGrade) == "table" and (tonumber(jobGrade.level) or 0) or (tonumber(jobGrade) or 0)
end

function Framework.playerJob()
    local job = Framework.getJob()
    return job and job.name
end

function Framework.hasJob(jobs, requireDuty)
    local job = Framework.getJob()
    if not job then return false end

    local matches = false
    if type(jobs) == "table" then
        for _, jobName in pairs(jobs) do
            if job.name == jobName or job.type == jobName then
                matches = true
                break
            end
        end
    else
        matches = job.name == jobs or job.type == jobs
    end

    if not matches then return false end
    if requireDuty ~= false and not job.onduty then return false end

    return true
end

local emsGroupCache
function Framework.emsGroups()
    if emsGroupCache then return emsGroupCache end

    local names, seen = {}, {}
    local jobs = VRCore.Shared and VRCore.Shared.Jobs or {}

    for _, key in pairs(emsJobs) do
        if not seen[key] then
            seen[key] = true
            names[#names + 1] = key
        end
    end

    for name, info in pairs(jobs) do
        if not seen[name] and type(info) == "table" then
            for _, key in pairs(emsJobs) do
                if info.type == key then
                    seen[name] = true
                    names[#names + 1] = name
                    break
                end
            end
        end
    end

    emsGroupCache = names
    return names
end

function Framework.isOnDuty()
    return Framework.hasJob(emsJobs)
end

function Framework.openBossMenu(job)
    local bossMenu = config.bossMenu
    if not bossMenu or not bossMenu.resource or GetResourceState(bossMenu.resource) ~= 'started' then
        return utils.showNotification(locale("bossmenu_unavailable"), "error")
    end

    TriggerEvent(bossMenu.event, job)
end

function Framework.healStatus()
end

function Framework.hasItem(item, _quantity)
    local quantity = _quantity or 1

    if item == "money" then
        local money = playerData().money or {}
        return (money.cash or 0) >= quantity
    end

    return (vrInventory:Search('count', item) or 0) >= quantity
end

function Framework.playerSpawned()
end

local function clothingReady()
    return clothingScript and GetResourceState(clothingScript) == 'started'
end

function Framework.toggleClothes(toggle, clothes)
    if not clothingReady() then return end

    if not toggle then
        utils.debug("Putting civil clothes")
        TriggerEvent('vr-clothing:client:reloadSkin')
        return
    end

    utils.debug("Putting on clothes")

    local playerPed = cache.ped
    local jobGrade = Framework.getPlayerJobGrade()
    local model = exports[clothingScript]:getPedModel(playerPed)
    local outfitsByGrade

    utils.debug("Job Grade " .. jobGrade)

    if model == 'mp_m_freemode_01' then
        outfitsByGrade = clothes.male[jobGrade] or clothes.male[1]
    elseif model == 'mp_f_freemode_01' then
        outfitsByGrade = clothes.female[jobGrade] or clothes.female[1]
    end

    if not outfitsByGrade then return end

    local data
    local outfits = {}

    for outfitName, outfit in pairs(outfitsByGrade) do
        outfits[#outfits + 1] = {
            title = outfitName,
            icon = 'fa-solid fa-shirt',
            onSelect = function()
                data = outfit
            end,
        }
    end

    lib.registerContext({
        id = 'vr-ambulancejob:ems_outfits',
        title = locale("police_outfits_title"),
        options = outfits,
        onExit = function()
            data = false
        end,
    })
    lib.showContext('vr-ambulancejob:ems_outfits')

    while data == nil do Wait(500) end
    if not data then return end

    utils.debug("Using " .. clothingScript)

    lib.progressBar({
        duration = 3000,
        label = locale("clothesmenu_job_use"),
        useWhileDead = false,
        allowCuffed = false,
        canCancel = false,
        disable = {
            car = true,
            move = true,
            combat = true,
        },
        anim = {
            dict = 'clothingshirt',
            clip = 'try_shirt_positive_d'
        },
    })

    exports[clothingScript]:setPedProps(playerPed, {
        {
            prop_id = 0,
            texture = data['helmet_2'],
            drawable = data['helmet_1']
        },
    })

    exports[clothingScript]:setPedComponents(playerPed, {
        { component_id = 1,  texture = data['mask_2'],    drawable = data['mask_1'] },
        { component_id = 3,  texture = 0,                 drawable = data['arms'] },
        { component_id = 8,  texture = data['tshirt_2'],  drawable = data['tshirt_1'] },
        { component_id = 11, texture = data['torso_2'],   drawable = data['torso_1'] },
        { component_id = 9,  texture = data['bproof_2'],  drawable = data['bproof_1'] },
        { component_id = 10, texture = data['decals_2'],  drawable = data['decals_1'] },
        { component_id = 7,  texture = data['chain_2'],   drawable = data['chain_1'] },
        { component_id = 4,  texture = data['pants_2'],   drawable = data['pants_1'] },
        { component_id = 6,  texture = data['shoes_2'],   drawable = data['shoes_1'] },
        { component_id = 5,  texture = data['bag_color'], drawable = data['bag'] },
    })
end
