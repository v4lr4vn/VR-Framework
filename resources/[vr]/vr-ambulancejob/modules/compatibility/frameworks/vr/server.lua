local VRCore       = exports['vr-core']:GetCoreObject()

Framework          = {}
local vrInventory = exports['vr-inventory']

local config       = lib.load("config")
local emsJobs      = config.emsJobs

function Framework.getPlayer(target)
    target = tonumber(target)
    if not target then return end
    return VRCore.Functions.GetPlayer(target)
end

function Framework.getJob(target)
    local xPlayer = Framework.getPlayer(target)
    if not xPlayer then return end

    local job = xPlayer.PlayerData.job
    if type(job) ~= "table" then return end

    if not job.type then
        local shared = VRCore.Shared and VRCore.Shared.Jobs and VRCore.Shared.Jobs[job.name]
        job.type = shared and shared.type or "none"
    end

    return job
end

local function jobMatches(job, jobs)
    if type(jobs) == "table" then
        for _, jobName in pairs(jobs) do
            if job.name == jobName or job.type == jobName then return true end
        end
        return false
    end

    return job.name == jobs or job.type == jobs
end

function Framework.hasJob(target, jobs, requireDuty)
    local job = Framework.getJob(target)
    if not job then return false end

    if not jobMatches(job, jobs) then return false end
    if requireDuty ~= false and not job.onduty then return false end

    return true
end

function Framework.isOnDutyType(target, jobType)
    local job = Framework.getJob(target)
    return job ~= nil and job.type == jobType and job.onduty == true
end

function Framework.playerJob(target)
    local job = Framework.getJob(target)
    return job and job.name
end

function Framework.emsJobNames()
    local names, seen = {}, {}
    local jobs = VRCore.Shared and VRCore.Shared.Jobs or {}

    for _, key in pairs(emsJobs) do
        if jobs[key] and not seen[key] then
            seen[key] = true
            names[#names + 1] = key
        end
    end

    for name, info in pairs(jobs) do
        if not seen[name] and type(info) == "table" and info.type then
            for _, key in pairs(emsJobs) do
                if info.type == key then
                    seen[name] = true
                    names[#names + 1] = name
                    break
                end
            end
        end
    end

    table.sort(names)
    return names
end

function Framework.updateStatus(data)
    local xPlayer = Framework.getPlayer(data.target)
    if not xPlayer then return end

    local isDead = data.status == true
    if xPlayer.PlayerData.metadata.isdead ~= isDead then
        xPlayer.Functions.SetMetaData("isdead", isDead)
    end
    if xPlayer.PlayerData.metadata.inlaststand ~= false then
        xPlayer.Functions.SetMetaData("inlaststand", false)
    end
end

function Framework.resetNeeds(target)
    local xPlayer = Framework.getPlayer(target)
    if not xPlayer then return end

    xPlayer.Functions.SetMetaData("hunger", 100)
    xPlayer.Functions.SetMetaData("thirst", 100)
end

function Framework.getPlayerName(target)
    local xPlayer = Framework.getPlayer(target)
    if not xPlayer then return end

    local charinfo = xPlayer.PlayerData.charinfo or {}
    return ("%s %s"):format(charinfo.firstname or "", charinfo.lastname or "")
end

function Framework.getCitizenId(target)
    local xPlayer = Framework.getPlayer(target)
    return xPlayer and xPlayer.PlayerData.citizenid
end

function Framework.getDeathStatus(target)
    local xPlayer = Framework.getPlayer(target)
    if not xPlayer then return end

    local metadata = xPlayer.PlayerData.metadata or {}

    return {
        isDead = metadata.isdead == true or metadata.inlaststand == true
    }
end

function Framework.removeAccountMoney(target, account, amount, reason)
    local xPlayer = Framework.getPlayer(target)
    if not xPlayer then return false end

    return xPlayer.Functions.RemoveMoney(account, amount, reason) == true
end

function Framework.addAccountMoney(target, account, amount, reason)
    local xPlayer = Framework.getPlayer(target)
    if not xPlayer then return false end

    return xPlayer.Functions.AddMoney(account, amount, reason) == true
end

function Framework.addSocietyMoney(society, amount, reason)
    if GetResourceState('vr-core') ~= 'started' then return false end

    local ok, result = pcall(function()
        return exports['vr-core']:AddSocietyMoney(society, amount, reason)
    end)

    return ok and result == true
end

function Framework.hasPermission(source, permission)
    return VRCore.Functions.HasPermission(source, permission) == true
end

function Framework.addItem(source, item, amount, metadata)
    return vrInventory:AddItem(source, item, amount, metadata)
end

function Framework.removeItem(source, item, amount, metadata, slot)
    return vrInventory:RemoveItem(source, item, amount, metadata, slot)
end

function Framework.wipeInventory(target, keep)
    return vrInventory:ClearInventory(target, keep)
end

function Framework.onPlayerLoaded(fn)
    AddEventHandler('VRCore:Server:PlayerLoaded', function(xPlayer)
        local source = xPlayer and xPlayer.PlayerData and xPlayer.PlayerData.source
        if source then fn(source, xPlayer) end
    end)
end

function Framework.onPlayerUnload(fn)
    AddEventHandler('VRCore:Server:OnPlayerUnload', function(source) fn(source) end)
end

function Framework.getPlayers()
    return VRCore.Functions.GetPlayers()
end

local medicBagItem = config.medicBagItem
local tabletItem = config.tabletItem

VRCore.Functions.CreateUseableItem(medicBagItem, function(source, item)
    if not Framework.hasJob(source, emsJobs) then return end

    TriggerClientEvent("vr-ambulancejob:placeMedicalBag", source)
end)

VRCore.Functions.CreateUseableItem(tabletItem, function(source, item)
    if not Framework.hasJob(source, emsJobs) then return end

    TriggerClientEvent("vr-ambulancejob:openDistressCalls", source)
end)
