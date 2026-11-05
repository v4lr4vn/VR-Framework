lib.callback.register('vr-cityhall:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

Bridge.on('playerLoaded', function(src)
    src = tonumber(src)
    if not src then return end
    Db.onReady(function()
        Wait(8000)
        if Config.Business.enabled then Biz.remind(src) end
    end)
end)

local function reply(src, text)
    if src <= 0 then return print(('[vr-cityhall] %s'):format(text)) end
    Core.notify(src, text, 'inform')
end

local function allowed(src)
    if src <= 0 then return true end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.' .. Config.Admin.command)
end

local sub = {}

sub.check = function(src, args)
    local number = args[1]
    local row = number and Biz.byNumber(number)
    if not row then return reply(src, 'No licence with that number') end
    local p = Biz.present(row, os.time())
    reply(src, ('%s: %s, %s, held by %s, %s, expires %s%s'):format(p.number, p.name, p.typeLabel, row.holder, p.status, os.date('%Y-%m-%d', p.expires), p.note and (' (' .. p.note .. ')') or ''))
end

sub.who = function(src, args)
    local target = tonumber(args[1])
    local info = target and Core.info(target)
    if not info then return reply(src, 'Use /' .. Config.Admin.command .. ' who <id>') end
    local list = Biz.list(info.cid)
    if #list == 0 then return reply(src, ('%s holds no business licences'):format(info.name)) end
    local lines = {}
    for _, p in ipairs(list) do lines[#lines + 1] = ('%s %s (%s)'):format(p.number, p.name, p.status) end
    reply(src, table.concat(lines, ', '))
end

sub.revoke = function(src, args)
    local number = table.remove(args, 1)
    local done, err = Biz.revoke(number, table.concat(args, ' '))
    if done then return reply(src, ('Revoked %s'):format(number:upper())) end
    reply(src, err == 'already' and 'That licence is already revoked' or 'No licence with that number')
end

sub.reinstate = function(src, args)
    local done, err = Biz.reinstate(args[1])
    if done then return reply(src, ('Reinstated %s'):format(args[1]:upper())) end
    reply(src, err == 'name_taken' and 'Another licence now uses that business name' or err == 'already' and 'That licence is already active' or 'No licence with that number')
end

sub.grant = function(src, args)
    local target, typeId = tonumber(args[1]), args[2]
    local info = target and Core.info(target)
    if not info or not typeId then return reply(src, 'Use /' .. Config.Admin.command .. ' grant <id> <type> <business name>') end
    table.remove(args, 1)
    table.remove(args, 1)
    local done, err, res = Biz.create(info, typeId, table.concat(args, ' '), { free = true, force = true })
    if done then return reply(src, ('Issued %s to %s'):format(res.number, info.name)) end
    reply(src, ('Could not issue it (%s)'):format(tostring(err)))
end

RegisterCommand(Config.Admin.command, function(src, args)
    if not allowed(src) then return end
    local fn = sub[(args[1] or ''):lower()]
    if not fn then return reply(src, 'Use check, who, revoke, reinstate or grant') end
    table.remove(args, 1)
    if not Db.ready then return reply(src, 'The database is not ready yet') end
    fn(src, args)
end, true)
