local labels = {
    paycheck = 'Salary',
    ['paycheck-society'] = 'Salary',
}

local function describe(reason)
    if type(reason) ~= 'string' or reason == '' or reason == 'unknown' then return nil end
    return labels[reason] or reason
end

Bridge.on('moneyChanged', function(src, moneytype, amount, operation, reason)
    if moneytype ~= 'bank' or not Db.ready then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 and operation ~= 'set' then return end
    local cid = Core.cid(src)
    if not cid or Accounts.isMuted(cid) then return end
    local acc = Accounts.personal(cid)
    if not acc then return end
    local text = describe(reason)
    if operation == 'add' then
        Accounts.log(acc, text == 'Salary' and 'salary' or 'payment_in', amount, { reason = text or 'Incoming payment' })
    elseif operation == 'remove' then
        Accounts.log(acc, 'payment_out', -amount, { reason = text or 'Card payment' })
    elseif operation == 'set' then
        Accounts.log(acc, 'adjust', 0, { reason = text or 'Balance set by staff', balance = amount })
    end
end)

Bridge.on('societyChanged', function(name, amount, operation, reason, balance)
    if not Db.ready or Accounts.isMuted(name) then return end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return end
    local acc = Accounts.find('job', name) or Accounts.find('gang', name)
    if not acc then
        acc = Core.isJob(name) and Accounts.job(name) or (Core.isGang(name) and Accounts.gang(name)) or nil
    end
    if not acc then return end
    local text = describe(reason)
    if operation == 'add' then
        Accounts.log(acc, 'payment_in', amount, { reason = text or 'Incoming payment', balance = balance })
    else
        Accounts.log(acc, 'payment_out', -amount, { reason = text or 'Payment', balance = balance })
    end
end)

local function groupChanged(src, kind, group)
    local cid = Core.cid(src)
    if not cid then return end
    for _, card in ipairs(Cards.listFor(cid)) do
        local acc = Accounts.byId(card.accountId)
        if acc and acc.type == kind and (type(group) ~= 'table' or group.name ~= acc.owner) then
            Cards.cancelForHolder(acc.id, cid)
        end
    end
end

Bridge.on('jobChanged', function(src, job) groupChanged(src, 'job', job) end)
Bridge.on('gangChanged', function(src, gang) groupChanged(src, 'gang', gang or false) end)

Bridge.on('playerLoaded', function(src)
    local cid = src and Core.cid(src)
    if not cid or not Db.ready then return end
    Accounts.personal(cid)
    local c = Collections.openFor(cid)
    if c then
        SetTimeout(15000, function()
            Core.notify(src, ('You owe $%s to %s collections. Your vehicles can be repossessed until it is paid.'):format(Fmt.money(c.amount), Config.BankName), 'error')
        end)
    end
    local info = Core.info(src)
    if info and Collections.isCollector(info) then
        SetTimeout(5000, function() TriggerClientEvent('vr-banking:client:repoPlates', src, Collections.plates()) end)
    end
end)
