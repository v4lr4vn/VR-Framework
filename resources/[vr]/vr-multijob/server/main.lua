lib.callback.register('vr-multijob:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

local function reply(src, text, kind)
    if src <= 0 then return print(('[vr-multijob] %s'):format(text)) end
    Core.notify(src, text, kind)
end

local function allowed(src)
    if src <= 0 then return true end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.addjob')
end

RegisterCommand('addjob', function(src, args)
    if not allowed(src) then return end
    local target = tonumber(args[1])
    local info = target and Core.info(target)
    local job = type(args[2]) == 'string' and args[2]:lower() or nil
    if not info or not job then return reply(src, 'Use /addjob <id> <job> <grade>', 'error') end
    if not Core.def(job, args[3]) then return reply(src, 'That job or grade does not exist', 'error') end
    if Config.IgnoredJobs[job] then return reply(src, 'That job can not be added to the job menu', 'error') end
    if Jobs.add(info.cid, job, args[3]) then
        reply(src, ('Added %s (grade %s) to %s'):format(job, Core.toGrade(args[3]), info.name), 'success')
    end
end, true)

RegisterCommand('removejob', function(src, args)
    if not allowed(src) then return end
    local target = tonumber(args[1])
    local info = target and Core.info(target)
    local job = type(args[2]) == 'string' and args[2]:lower() or nil
    if not info or not job then return reply(src, 'Use /removejob <id> <job>', 'error') end
    if Jobs.remove(info.cid, job) then
        reply(src, ('Removed %s from %s'):format(job, info.name), 'success')
    else
        reply(src, "That player doesn't have that job", 'error')
    end
end, true)
