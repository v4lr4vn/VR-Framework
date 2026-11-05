Core = {}

function Core.player(src)
    src = tonumber(src)
    if not src then return nil end
    return Bridge.player(src)
end

function Core.info(src)
    local p = Core.player(src)
    if not p then return nil end
    local job, gang = p.job or {}, p.gang or {}
    return {
        src = tonumber(src),
        cid = p.cid,
        license = Bridge.license(src),
        name = p.name,
        firstName = p.firstname or p.name,
        job = { name = job.name, label = job.label, grade = tonumber(job.grade) or 0, isboss = job.isboss == true, onduty = job.onduty == true },
        gang = { name = gang.name, label = gang.label, grade = tonumber(gang.grade) or 0, isboss = gang.isboss == true },
    }
end

function Core.money(src, kind)
    return Bridge.money(src, kind)
end

function Core.take(src, amount, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.removeMoney(src, kind, amount, reason)
end

function Core.give(src, amount, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.addMoney(src, kind, amount, reason)
end

function Core.setDuty(src, on)
    return Bridge.setDuty(src, on == true)
end

function Core.addSociety(name, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.society.add(name, amount, reason)
end

function Core.removeSociety(name, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.society.remove(name, amount, reason)
end

function Core.societyBalance(name)
    return Bridge.society.balance(name)
end

function Core.vehicles()
    return Bridge.vehicleList()
end

function Core.vehicle(model)
    return Bridge.vehicleData(model)
end

function Core.vehicleLabel(model)
    if Core.vehicle(model) then return Bridge.vehicleLabel(model) end
    return tostring(model)
end

function Core.isJob(name) return Bridge.isJob(name) end

function Core.notify(src, text, kind, title)
    if not src then return end
    Bridge.notify(src, text, kind or 'inform', nil, title or 'Dealership')
end

function Core.coords(src)
    return Bridge.coords(src)
end

function Core.staffOnDuty()
    local n = 0
    for _, src in ipairs(Bridge.sources()) do
        local info = Core.info(src)
        if info and info.job.name == Config.Job and info.job.onduty then n = n + 1 end
    end
    return n
end

function Core.started(name)
    return GetResourceState(name) == 'started'
end
