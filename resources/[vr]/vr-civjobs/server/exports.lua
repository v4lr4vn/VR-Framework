local function cidOf(v)
    if type(v) == 'number' then return Bridge.cid(v) end
    if type(v) == 'string' and v ~= '' then return v end
    return nil
end

exports('GetLevel', function(who, job)
    local cid = cidOf(who)
    if not cid or not Config.Jobs[job] then return nil end
    return Progress.level(cid, job)
end)

exports('GetXp', function(who, job)
    local cid = cidOf(who)
    if not cid or not Config.Jobs[job] then return nil end
    return Progress.get(cid, job).xp
end)

exports('AddXp', function(who, job, xp)
    local cid = cidOf(who)
    if not cid or not Config.Jobs[job] then return false end
    Progress.addXp(cid, job, xp)
    return true
end)

exports('GetStats', function(who, job)
    local cid = cidOf(who)
    if not cid or not Config.Jobs[job] then return nil end
    local row = Progress.get(cid, job)
    local level, into, need = Civ.levelOf(row.xp)
    return { level = level, xp = into, xpNext = need, done = row.done, earned = row.earned }
end)

exports('IsWorking', function(src)
    local sess = Session.of(tonumber(src))
    return sess ~= nil, sess and sess.job or nil
end)

exports('EndShift', function(src)
    local sess = Session.of(tonumber(src))
    if not sess then return false end
    Session.close(sess, 'quit')
    return true
end)

exports('GetJobs', function()
    local out = {}
    for id, def in pairs(Config.Jobs) do
        if not Config.Disabled[id] then
            out[#out + 1] = { id = id, label = def.label, job = def.job, crew = def.crew or 0 }
        end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end)
