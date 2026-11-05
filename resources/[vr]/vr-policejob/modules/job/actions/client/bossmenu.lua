for index, station in pairs(Config.PoliceStations) do
    exports['vr-target']:addBoxZone({
        coords = station.bossmenu.pos,
        size = vector3(2.0, 2.0, 2.0),
        drawSprite = true,
        options = {
            {
                name = "open_boosmenu" .. index,
                icon = 'fa-solid fa-road',
                label = locale("bossmenu_label"),
                canInteract = function()
                    return hasJob(station.jobs)
                end,
                onSelect = function(data)
                    if getPlayerJobGrade() >= station.bossmenu.min_grade then
                        openBossMenu(getPlayerData().job and getPlayerData().job.name or station.jobs[1])
                    else
                        utils.showNotification(locale("no_access"), 'error')
                    end
                end
            }
        }
    })
end
