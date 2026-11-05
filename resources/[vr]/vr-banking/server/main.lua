lib.callback.register('vr-banking:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

RegisterNetEvent('vr-banking:server:debtRespond', function(token, method)
    local src = source
    if type(token) ~= 'string' then return end
    local success, res = Collections.respond(src, token, method)
    if success and res and not res.refused then
        Core.notify(src, 'Debt paid. Your account is clear.', 'success')
        if res.released and #res.released > 0 then
            Core.notify(src, ('Released: %s'):format(table.concat(res.released, ', ')), 'success')
        end
    elseif not success and res ~= 'no_request' then
        Core.notify(src, res == 'no_cash' and 'You do not have enough cash' or res == 'no_funds' and 'You do not have enough in the bank' or 'Payment failed', 'error')
    end
end)

RegisterNetEvent('vr-banking:server:duty', function(on)
    local src = source
    local info = Core.info(src)
    if not info or info.job.name ~= Config.CollectorJob or not Api.nearBranch(src) then return end
    if not Core.setDuty(src, on == true) then return end
    Core.notify(src, on and 'You are on duty. Open cases show on the collections board.' or 'You are off duty.', 'inform', 'Collections')
    if on then SetTimeout(500, function() TriggerClientEvent('vr-banking:client:repoPlates', src, Collections.plates()) end) end
end)

Db.onReady(function()
    Accounts.load()
    Cards.load()
    Collections.load()
    Repo.load()
    Collections.refreshPlates()
    CreateThread(function()
        Wait(((Config.Collections.stage or {}).startDelaySeconds or 45) * 1000)
        while true do
            local ok, err = pcall(Repo.ensure)
            if not ok then print(('^1[vr-banking] repo cars: %s^0'):format(tostring(err))) end
            Wait(((Config.Collections.stage or {}).checkMinutes or 3) * 60000)
        end
    end)
    CreateThread(function()
        while true do
            Wait(((Config.Collections.tracker or {}).intervalSeconds or 8) * 1000)
            local ok, err = pcall(Repo.tick)
            if not ok then print(('^1[vr-banking] tracker: %s^0'):format(tostring(err))) end
        end
    end)
    local ticks = 0
    while true do
        local ok, err = pcall(Loans.process)
        if not ok then print(('^1[vr-banking] loans: %s^0'):format(tostring(err))) end
        if ticks % 10 == 0 then
            local ok2, err2 = pcall(Savings.run)
            if not ok2 then print(('^1[vr-banking] savings: %s^0'):format(tostring(err2))) end
        end
        if ticks % 5 == 4 then pcall(Collections.refreshPlates) end
        ticks = ticks + 1
        Wait(60000)
    end
end)

local function targetCid(arg)
    local id = tonumber(arg)
    if id then return Core.cid(id) end
    if type(arg) == 'string' and arg ~= '' then return arg:upper() end
end

local function reply(src, text, kind)
    if src > 0 then Core.notify(src, text, kind) else print(('[vr-banking] %s'):format(text)) end
end

RegisterCommand('setcredit', function(src, args)
    local cid = targetCid(args[1])
    local score = tonumber(args[2])
    if not cid or not score then return reply(src, 'Usage: /setcredit [id or citizen id] [score]', 'error') end
    local after = Credit.set(cid, score, 'Set by staff')
    reply(src, ('Credit score for %s is now %d'):format(cid, after), 'success')
end, true)

RegisterCommand('releasevehicle', function(src, args)
    if not args[1] then return reply(src, 'Usage: /releasevehicle [plate]', 'error') end
    local plate = table.concat(args, ' ')
    reply(src, Collections.releaseVehicle(plate) and ('Released %s'):format(plate) or 'That vehicle is not held', 'inform')
end, true)

RegisterCommand('closecase', function(src, args)
    local id = tonumber(args[1])
    if not id then return reply(src, 'Usage: /closecase [case id]', 'error') end
    reply(src, Collections.close(id, 'Closed by staff') and ('Case #%d closed'):format(id) or 'No open case with that id', 'inform')
end, true)
