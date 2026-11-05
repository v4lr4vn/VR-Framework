local hospitals = lib.load("data.hospitals")
local emsJobs = lib.load("config").emsJobs
for index, hospital in pairs(hospitals) do
    Target.addBoxZone(hospital.bossmenu.pos, {
        {
            name = "open_bossmenu" .. index,
            icon = 'fa-solid fa-road',
            label = locale("bossmenu_label"),
            groups = Framework.emsGroups(),
            fn = function(data)
                if Framework.hasJob(emsJobs, false) and Framework.getPlayerJobGrade() >= hospital.bossmenu.min_grade then
                    Framework.openBossMenu(Framework.playerJob())
                else
                    utils.showNotification(locale("bossmenu_denied"), "error")
                end
            end
        }
    })
end
