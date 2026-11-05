if not Config.ClothingScript then return end

local function openClothingMenu(clothes)
    lib.registerContext({
        id = 'clothing_menu',
        title = 'Clothing Menu',
        options = {
            {
                title = '🧥 Civil Clothes',
                description = 'Example button description',
                onSelect = function()
                    if lib.progressBar({
                            duration = 3000,
                            label = 'Putting on civil clothes',
                            useWhileDead = false,
                            allowCuffed = false,
                            canCancel = false,
                            disable = {
                                car = true,
                                move = true,
                                combat = true,
                            },
                            anim = {
                                dict = 'clothingshirt',
                                clip = 'try_shirt_positive_d'
                            },
                        }) then
                        toggleClothes(false, clothes)
                    end
                end,
            },
            {
                title = '👮 Work Clothes',
                description = 'Example button description',
                onSelect = function()
                    if lib.progressBar({
                            duration = 3000,
                            label = 'Putting on works clothes',
                            useWhileDead = false,
                            allowCuffed = false,
                            canCancel = false,
                            disable = {
                                car = true,
                                move = true,
                                combat = true,
                            },
                            anim = {
                                dict = 'clothingshirt',
                                clip = 'try_shirt_positive_d'
                            },
                        }) then
                        toggleClothes(true, clothes)
                    end
                end,
            },
        }
    })

    lib.showContext('clothing_menu')
end

function initClothes(data, jobs)
    local ped = utils.createPed(data.model, data.pos)

    exports['vr-target']:addLocalEntity(ped, {
        {
            name = 'clothing' .. ped,
            label = locale('clothing_interact_label'),
            icon = 'fa-solid fa-road',
            canInteract = function(entity, distance, coords, name, bone)
                return hasJob(jobs) and player.inDuty()
            end,
            onSelect = function(entity)
                openClothingMenu(data)
            end
        }
    })
end
