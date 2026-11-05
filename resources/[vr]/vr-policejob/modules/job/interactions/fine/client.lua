if not Config.Interactions.enable or not Config.Interactions.fines then return end

local GetPlayerServerId            = GetPlayerServerId
local NetworkGetPlayerIndexFromPed = NetworkGetPlayerIndexFromPed
local TriggerServerEvent           = TriggerServerEvent

function player.finePlayer(target)
    local targetServerId = GetPlayerServerId(NetworkGetPlayerIndexFromPed(target))

    local input = lib.inputDialog(locale('fine_dialog_title'), {
        {
            type = 'number',
            label = locale('fine_amount_title'),
            icon = 'hashtag',
            required = true,
            min = 1,
            max = Config.Fines.max,
            precision = 0,
        },
        {
            type = 'input',
            label = locale('fine_reason_title'),
            icon = 'pencil',
            min = 4,
            max = Config.Fines.reasonMax,
            required = true,
        }
    })

    if not input then return end

    local amount = input[1]
    local reason = input[2]

    TriggerServerEvent('vr-policejob:server:finePlayer', targetServerId, amount, reason)
end

-- /fine [id] works too. Without an id it picks the closest person.
RegisterCommand('fine', function(_, args)
    if not (hasJob(Config.Interactions.jobs) and player.inDuty()) then return end
    local target
    local id = tonumber(args[1])
    if id then
        local idx = GetPlayerFromServerId(id)
        if idx ~= -1 and idx ~= PlayerId() then target = GetPlayerPed(idx) end
    else
        local here = GetEntityCoords(PlayerPedId())
        local best = Config.Fines.distance
        for _, idx in ipairs(GetActivePlayers()) do
            if idx ~= PlayerId() then
                local ped = GetPlayerPed(idx)
                local d = #(GetEntityCoords(ped) - here)
                if d <= best then best, target = d, ped end
            end
        end
    end
    if not target then
        return lib.notify({ description = locale('fine_invalid_target'), type = 'error' })
    end
    player.finePlayer(target)
end, false)
