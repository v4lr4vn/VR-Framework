function player.inDuty()
    return isOnDuty()
end

exports("onDuty", function()
    return player.inDuty()
end)

if not Config.DutyPoints then return end

for index, station in pairs(Config.PoliceStations) do
    if station.duty then
        exports['vr-target']:addBoxZone({
            coords = station.duty,
            size = vector3(1.0, 1.0, 1.0),
            drawSprite = true,
            options = {
                {
                    name = "clock_in" .. index,
                    icon = 'fa-solid fa-road',
                    label = locale("clock_in"),
                    canInteract = function()
                        return hasJob(station.jobs)
                    end,
                    onSelect = function(data)
                        if not player.inDuty() then
                            TriggerServerEvent('VRCore:ToggleDuty')
                        else
                            utils.showNotification(locale("already_in_duty"))
                        end
                    end
                },
                {
                    name = "clock_out" .. index,
                    icon = 'fa-solid fa-road',
                    label = locale("clock_out"),
                    canInteract = function()
                        return hasJob(station.jobs)
                    end,
                    onSelect = function(data)
                        if player.inDuty() then
                            TriggerServerEvent('VRCore:ToggleDuty')
                        else
                            utils.showNotification(locale("already_off_duty"))
                        end
                    end
                },
            }
        })
    end
end
