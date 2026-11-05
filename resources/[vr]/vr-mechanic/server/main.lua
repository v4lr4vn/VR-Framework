lib.callback.register('vr-mechanic:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

RegisterNetEvent('vr-mechanic:server:wear', function(netId, status, distance)
    Wear.report(source, netId, status, distance)
end)

RegisterNetEvent('vr-mechanic:server:duty', function(id, on)
    local src = source
    local info = Core.info(src)
    if not info or not Config.Jobs[info.job.name] then return end
    local w = Workshops.atCounter(src, id)
    if not w or w.job ~= info.job.name then return end
    local p = Core.player(src)
    if not p then return end
    p.Functions.SetJobDuty(on == true)
    Core.notify(src, on and ('Clocked in at %s'):format(w.label) or 'You are off duty', 'inform')
end)

AddEventHandler('entityRemoved', function(ent)
    if GetEntityType(ent) == 2 then Wear.forget(ent) end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Cars.flush() end
end)

Db.onReady(function()
    Workshops.load()
    pcall(Orders.expire)
    local nextFlush = os.time() + Config.Wear.persistSeconds
    local nextExpire = os.time() + 3600
    while true do
        Wait(1000)
        local s, err = pcall(Bills.tick)
        if not s then print(('^1[vr-mechanic] bills: %s^0'):format(tostring(err))) end
        if os.time() >= nextExpire then
            nextExpire = os.time() + 3600
            pcall(Orders.expire)
        end
        if os.time() >= nextFlush then
            nextFlush = os.time() + Config.Wear.persistSeconds
            s, err = pcall(Cars.flush)
            if not s then print(('^1[vr-mechanic] wear: %s^0'):format(tostring(err))) end
        end
    end
end)

local function reply(src, text, kind)
    if src > 0 then Core.notify(src, text, kind) else print(('[vr-mechanic] %s'):format(text)) end
end

local USAGE = 'Usage: /workshop [create|center|counter|radius|label|job|delete|list] [id] [value]'

RegisterCommand('workshop', function(src, args)
    local sub, id = (args[1] or ''):lower(), args[2] and args[2]:lower() or nil
    if sub == 'list' then
        local ids = {}
        for k, w in pairs(Workshops.list) do ids[#ids + 1] = ('%s (%s, %dm)'):format(k, w.label, math.floor(w.radius)) end
        table.sort(ids)
        return reply(src, #ids > 0 and table.concat(ids, ', ') or 'No workshops', 'inform')
    end
    if not id or not id:match('^[%w_]+$') then return reply(src, USAGE, 'inform') end
    local pos = src > 0 and Core.coords(src) or nil
    local w = Workshops.get(id)
    if sub == 'create' then
        if w then return reply(src, 'That workshop already exists', 'error') end
        if not pos then return end
        local label = table.concat(args, ' ', 3)
        Workshops.save(id, { id = id, label = label ~= '' and label or id, job = 'mechanic', center = pos, counter = pos, radius = 15.0 })
        return reply(src, ('Workshop %s created here. Set the counter with /workshop counter %s'):format(id, id), 'success')
    end
    if not w then return reply(src, 'No workshop with that id', 'error') end
    local copy = {}
    for k, v in pairs(w) do copy[k] = v end
    if sub == 'center' or sub == 'counter' then
        if not pos then return end
        copy[sub] = pos
    elseif sub == 'radius' then
        copy.radius = math.max(5, math.min(60, tonumber(args[3]) or copy.radius)) + 0.0
    elseif sub == 'label' then
        local label = table.concat(args, ' ', 3)
        if label == '' then return reply(src, USAGE, 'inform') end
        copy.label = label
    elseif sub == 'job' then
        if not args[3] then return reply(src, USAGE, 'inform') end
        copy.job = args[3]:lower()
    elseif sub == 'delete' then
        Workshops.save(id, nil)
        return reply(src, ('Workshop %s removed'):format(id), 'success')
    else
        return reply(src, USAGE, 'inform')
    end
    Workshops.save(id, copy)
    reply(src, ('Workshop %s updated'):format(id), 'success')
end, true)
