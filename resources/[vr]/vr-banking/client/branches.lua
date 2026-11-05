local zones, blips = {}, {}

CreateThread(function()
    local B = Config.Branch
    for _, branch in ipairs(Config.Branches) do
        zones[#zones + 1] = Bridge.target.addSphereZone({
            coords = branch.coords,
            radius = B.targetRadius,
            options = {
                {
                    name = 'vr-banking:open',
                    label = 'Open bank',
                    icon = 'fa-solid fa-building-columns',
                    distance = 2.5,
                    onSelect = function() Bank.show('bank', { branch = branch.label }) end,
                },
                {
                    name = 'vr-banking:dutyOn',
                    label = 'Clock in for debt recovery',
                    icon = 'fa-solid fa-user-clock',
                    distance = 2.5,
                    canInteract = function() local j = Bank.pd.job return type(j) == 'table' and j.name == Config.CollectorJob and not j.onduty end,
                    onSelect = function() TriggerServerEvent('vr-banking:server:duty', true) end,
                },
                {
                    name = 'vr-banking:dutyOff',
                    label = 'Clock out',
                    icon = 'fa-solid fa-user-clock',
                    distance = 2.5,
                    canInteract = function() return Bank.isCollector() end,
                    onSelect = function() TriggerServerEvent('vr-banking:server:duty', false) end,
                },
                {
                    name = 'vr-banking:collections',
                    label = 'Collections board',
                    icon = 'fa-solid fa-file-invoice-dollar',
                    distance = 2.5,
                    canInteract = function() return Bank.isCollector() end,
                    onSelect = function() Bank.show('collections', {}) end,
                },
            },
        })
        if branch.blip then
            local blip = AddBlipForCoord(branch.coords.x, branch.coords.y, branch.coords.z)
            SetBlipSprite(blip, B.blip.sprite)
            SetBlipColour(blip, B.blip.colour)
            SetBlipScale(blip, B.blip.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(B.blip.label)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, id in ipairs(zones) do pcall(function() Bridge.target.removeZone(id) end) end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
