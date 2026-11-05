local DrawMarker            = DrawMarker
local IsControlJustReleased = IsControlJustReleased
local CreateThread          = CreateThread
local vrInventory          = exports['vr-inventory']
local hospitals             = lib.load("data.hospitals")
local emsJobs               = lib.load("config").emsJobs

local function createShops()
    for _, hospital in pairs(hospitals) do
        for name, pharmacy in pairs(hospital.pharmacy) do
            if pharmacy.blip.enable then
                utils.createBlip(pharmacy.blip)
            end

            lib.points.new({
                coords = pharmacy.pos,
                distance = 3,
                onEnter = function(self)
                    if pharmacy.job then
                        if Framework.hasJob(emsJobs) and Framework.getPlayerJobGrade() >= pharmacy.grade then
                            self.access = true
                            lib.showTextUI(locale('control_to_open_shop'))
                        else
                            self.access = false
                        end
                    else
                        self.access = true
                        lib.showTextUI(locale('control_to_open_shop'))
                    end
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                nearby = function(self)
                    if self.access then
                        DrawMarker(2, self.coords.x, self.coords.y, self.coords.z, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 1.0, 1.0, 1.0, 200, 20, 20, 50, false, true, 2, false, nil, nil, false)

                        if self.currentDistance < 1 and IsControlJustReleased(0, 38) then
                            vrInventory:openInventory("shop", { type = name, id = 1 })
                        end
                    end
                end
            })
        end
    end
end
CreateThread(createShops)
