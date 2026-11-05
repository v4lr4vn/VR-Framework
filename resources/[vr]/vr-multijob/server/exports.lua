exports('GetJobs', function(cid)
    if type(cid) ~= 'string' or cid == '' then return {} end
    return Store.get(cid)
end)

exports('AddJob', function(cid, job, grade)
    return Jobs.add(cid, job, grade)
end)

exports('UpdateJobRank', function(cid, job, grade)
    return Jobs.setRank(cid, job, grade)
end)

exports('RemoveJob', function(cid, job)
    return Jobs.remove(cid, job)
end)

exports('HasJob', function(cid, job)
    if type(cid) ~= 'string' or type(job) ~= 'string' then return false end
    return Store.get(cid)[job] ~= nil
end)

exports('GetMaxJobs', function()
    return Config.MaxJobs
end)

AddEventHandler('vr-multijob:server:removeJob', function(cid, job)
    if type(cid) ~= 'string' or cid == '' then return end
    if type(job) == 'string' then
        Jobs.remove(cid, job)
        return
    end
    Store.wipe(cid)
end)
