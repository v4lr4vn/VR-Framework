local function reply(src, text, kind)
    if src <= 0 then return print(('[vr-civjobs] %s'):format(text)) end
    Core.notify(src, text, kind)
end

local function allowed(src)
    if src <= 0 then return true end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

lib.callback.register('vr-civjobs:isAdmin', function(src)
    return allowed(src)
end)

RegisterCommand(Config.Admin.command, function(src, args)
    if not allowed(src) then return end
    local sub = args[1]
    if sub == 'here' then return end
    local target = tonumber(args[2])
    local info = target and Core.info(target)
    if sub == 'stats' then
        if not info then return reply(src, 'Use /civjobs stats <id>', 'error') end
        local lines = {}
        for id in pairs(Config.Jobs) do
            local row = Progress.get(info.cid, id)
            if row.xp > 0 or row.done > 0 then
                lines[#lines + 1] = ('%s: level %d, %d runs, $%d earned'):format(id, (Civ.levelOf(row.xp)), row.done, row.earned)
            end
        end
        return reply(src, #lines > 0 and table.concat(lines, ' | ') or 'No progress yet', 'inform')
    elseif sub == 'setlevel' then
        local job, level = args[3], tonumber(args[4])
        if not info or not Config.Jobs[job] or not level or level < 1 or level > Config.Levels.max then
            return reply(src, 'Use /civjobs setlevel <id> <job> <level>', 'error')
        end
        local xp = 0
        for l = 1, level - 1 do xp = xp + Civ.xpFor(l) end
        Progress.setXp(info.cid, job, xp)
        return reply(src, ('%s is now level %d as %s'):format(info.name, level, job), 'success')
    elseif sub == 'reset' then
        local job = args[3]
        if not info or not Config.Jobs[job] then return reply(src, 'Use /civjobs reset <id> <job>', 'error') end
        Progress.reset(info.cid, job)
        return reply(src, ('Reset %s for %s'):format(job, info.name), 'success')
    elseif sub == 'end' then
        if not target then return reply(src, 'Use /civjobs end <id>', 'error') end
        local sess = Session.of(target)
        if not sess then return reply(src, 'They are not working', 'error') end
        Session.close(sess, 'quit')
        return reply(src, 'Ended their shift', 'success')
    end
    reply(src, 'Use /civjobs here, stats, setlevel, reset or end', 'inform')
end, true)

Bridge.on('playerLoaded', function(src)
    local cid = Bridge.cid(src)
    if cid then Progress.bind(src, cid) end
end)
