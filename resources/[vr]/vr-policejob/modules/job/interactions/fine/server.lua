local function logFine(src, target, amount, reason)
    if GetResourceState('vr-mdt') ~= 'started' then return false end
    local ok, res = pcall(function()
        return exports['vr-mdt']:LogFine({ officer = src, target = target, amount = amount, reason = reason })
    end)
    if not ok then
        print(('^3[vr-policejob] vr-mdt LogFine failed: %s^7'):format(tostring(res)))
        return false
    end
    if res ~= true then
        print(('^3[vr-policejob] vr-mdt did not record a $%d fine (check Config.Fines.max <= vr-mdt Config.Fines.MaxAmount)^7'):format(amount))
        return false
    end
    return true
end

RegisterNetEvent('vr-policejob:server:finePlayer', function(target, amount, reason)
    local src = source
    if not Config.Interactions.enable or not Config.Interactions.fines then return end
    if not hasJob(src, Config.Interactions.jobs) then return end

    local cfg = Config.Fines
    target = Security.target(src, target, cfg.distance)
    if not target then return notify(src, locale('fine_invalid_target'), 'error') end

    amount = Security.int(amount, 1, cfg.max)
    if not amount then return notify(src, locale('fine_invalid_amount'):format(cfg.max), 'error') end

    reason = Security.text(reason, cfg.reasonMax)
    if not reason then return notify(src, locale('fine_invalid_reason'):format(cfg.reasonMax), 'error') end

    if Security.onCooldown('fine', src) then return notify(src, locale('fine_cooldown'), 'error') end

    local paidFrom = 'bank'
    if not removeAccountMoney(target, 'bank', amount, ('police fine: %s'):format(reason)) then
        paidFrom = 'cash'
        if not removeAccountMoney(target, 'cash', amount, ('police fine: %s'):format(reason)) then
            return notify(src, locale('fine_no_money'), 'error')
        end
    end
    Security.startCooldown('fine', src, cfg.cooldown)

    addSocietyMoney(cfg.society, amount, 'fine')
    logFine(src, target, amount, reason)

    notify(target, locale('have_been_fined'):format(amount, reason))
    notify(src, locale(paidFrom == 'cash' and 'fine_issued_cash' or 'fine_issued'):format(amount), 'success')
end)
