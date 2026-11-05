VRCore = exports['vr-core']:GetCoreObject()

function getPlayer(src)
    src = tonumber(src)
    if not src then return nil end
    return VRCore.Functions.GetPlayer(src)
end

function normalizeJob(job)
    if type(job) ~= 'table' then return nil end
    if job.type == nil and job.name then
        local shared = VRCore.Shared and VRCore.Shared.Jobs and VRCore.Shared.Jobs[job.name]
        job.type = shared and shared.type or nil
    end
    return job
end

function getJob(src)
    local p = getPlayer(src)
    return normalizeJob(p and p.PlayerData and p.PlayerData.job)
end

function jobIn(job, list)
    if type(job) ~= 'table' then return false end
    if type(list) == 'string' then list = { list } end
    if type(list) ~= 'table' then return false end
    for _, key in pairs(list) do
        if key == job.name or (job.type ~= nil and key == job.type) then return true end
    end
    return false
end

function isPoliceJob(job, jobs)
    return jobIn(job, jobs) or jobIn(job, Config.JobTypes)
end

function hasJob(src, jobs, allowOffDuty)
    if not src or tonumber(src) == nil or tonumber(src) < 1 then return false end
    local job = getJob(src)
    if not job or not isPoliceJob(job, jobs) then return false end
    return allowOffDuty == true or job.onduty == true
end

function playerJob(src)
    local job = getJob(src)
    return job and job.name or nil
end

function getPlayerJobGrade(src)
    local job = getJob(src)
    local grade = job and job.grade
    return tonumber(type(grade) == 'table' and grade.level or grade) or 0
end

function removeAccountMoney(src, account, amount, reason)
    local p = getPlayer(src)
    if not p then return false end
    return p.Functions.RemoveMoney(account, amount, reason) == true
end

function addSocietyMoney(name, amount, reason)
    if GetResourceState('vr-core') ~= 'started' then return false end
    local ok, res = pcall(function() return exports['vr-core']:AddSocietyMoney(name, amount, reason) end)
    if not ok or res ~= true then
        print(('^3[vr-policejob] could not add $%s to the %s society account^7'):format(tostring(amount), tostring(name)))
        return false
    end
    return true
end

function getOnDutyPlayers(jobs)
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local job = src and getJob(src)
        if job and job.onduty == true and jobIn(job, jobs) then out[#out + 1] = src end
    end
    return out
end

function policeJobList(extra)
    local list, seen = {}, {}
    local function add(t)
        for _, v in ipairs(t or {}) do
            if not seen[v] then
                seen[v] = true
                list[#list + 1] = v
            end
        end
    end
    add(Config.AccessToMenu)
    add(Config.JobTypes)
    add(extra)
    return list
end

function notify(src, msg, notifyType)
    TriggerClientEvent('vr-policejob:showNotification', src, msg, notifyType)
end
