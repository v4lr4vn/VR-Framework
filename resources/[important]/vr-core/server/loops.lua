local VRCore    = VRCore
local Config    = VRCore.Config
local Shared    = VRCore.Shared
local Functions = VRCore.Functions
local Players   = VRCore.Players
local Resources = Config.Resources

local function payPlayer(player)
    local job = player.PlayerData.job
    local info = job and Shared.Jobs[job.name]
    if not info then return end
    local grade = info.grades[tostring(job.grade and job.grade.level or 0)]
    local payment = tonumber(grade and grade.payment or job.grade and job.grade.payment or job.payment) or 0
    if payment <= 0 or not (info.offDutyPay or job.onduty) then return end

    if Config.Money.PayCheckSociety and ResourceUp(Resources.banking) then
        local banking = exports[Resources.banking]
        local balance = banking:GetAccountBalance(job.name)
        if balance ~= 0 then
            if balance < payment then return player:Notify(Lang:t('error.company_too_poor'), 'error') end
            banking:RemoveMoney(job.name, payment, 'Employee Paycheck')
        end
    elseif Config.Money.PayCheckSociety and VRCore.Functions.GetSocietyMoney then
        local balance = VRCore.Functions.GetSocietyMoney(job.name)
        if balance ~= 0 then
            if balance < payment then return player:Notify(Lang:t('error.company_too_poor'), 'error') end
            VRCore.Functions.RemoveSocietyMoney(job.name, payment, 'Employee Paycheck')
        end
    end

    player:AddMoney('bank', payment, 'paycheck')
    player:Notify(Lang:t('info.received_paycheck', { value = payment }))
end

CreateThread(function()
    local interval = Config.Money.PayCheckTimeOut * 60000
    while true do
        Wait(interval)
        local sources = Functions.GetPlayers()
        for i = 1, #sources do
            local player = Players[sources[i]]
            if player then
                local ok, err = pcall(payPlayer, player)
                if not ok then VRCore.ShowError(GetCurrentResourceName(), 'paycheck failed: ' .. tostring(err)) end
                Wait(50)
            end
        end
    end
end)

CreateThread(function()
    local interval = Config.UpdateInterval * 60000
    local hungerRate, thirstRate = Config.Player.HungerRate, Config.Player.ThirstRate
    while true do
        Wait(interval)
        local sources = Functions.GetPlayers()
        for i = 1, #sources do
            local player = Players[sources[i]]
            if player then
                local md = player.PlayerData.metadata
                player:SetMetaData('hunger', (tonumber(md.hunger) or 100) - hungerRate)
                player:SetMetaData('thirst', (tonumber(md.thirst) or 100) - thirstRate)
                player:Save()
                Wait(25)
            end
        end
    end
end)
