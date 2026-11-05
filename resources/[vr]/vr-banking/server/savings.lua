Savings = {}

local S = Config.Savings

function Savings.run()
    local period = S.periodHours * 3600
    local t = os.time()
    local paid = 0
    for _, acc in ipairs(Accounts.allSavings()) do
        local periods = 0
        local at = acc.interestAt
        while at + period <= t and periods < (S.catchUpPeriods or 1) do
            periods = periods + 1
            at = at + period
        end
        if periods > 0 then
            if at + period <= t then at = t end
            for _ = 1, periods do
                local base = math.min(acc.balance, S.maxInterestBalance or math.huge)
                if base >= (S.minBalance or 0) then
                    local interest = math.floor(base * S.ratePercent / 100)
                    if interest > 0 and Accounts.credit(acc, interest, 'interest') then
                        Accounts.log(acc, 'interest', interest, { reason = ('Interest at %s%%'):format(S.ratePercent), balance = acc.balance })
                        paid = paid + interest
                    end
                end
            end
            Accounts.setInterestAt(acc, at)
        end
    end
    return paid
end
