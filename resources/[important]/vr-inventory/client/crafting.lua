CraftingBenches = {}

local prompt = { options = { icon = 'fa-wrench' }, message = Utils.prompt(locale('open_crafting_bench')) }

local function createBench(id, data)
    local recipes = data.items
    if type(recipes) ~= 'table' then return end
    data.slots = #recipes

    for i = 1, data.slots do
        local recipe = recipes[i]
        local item = ItemList[recipe.name]
        if item then
            recipe.weight = item.weight
            recipe.slot = i
        end
    end

    local blip = data.blip
    if blip then
        blip.name = blip.name or ('vrinv_crafting_%s'):format(id)
        AddTextEntry(blip.name, data.label or locale('crafting_bench'))
    end

    if shared.target then
        data.points = nil
        if data.zones then
            CreateThread(function()
                while GetResourceState('vr-target') ~= 'started' do Wait(500) end
                for i = 1, #data.zones do
                    local zone = data.zones[i]
                    zone.name = ('craftingbench_%s:%s'):format(id, i)
                    zone.options = {
                        {
                            label = zone.label or locale('open_crafting_bench'),
                            canInteract = (zone.groups or data.groups) and function() return client.hasGroup(zone.groups or data.groups) ~= nil end or nil,
                            onSelect = function() client.openInventory('crafting', { id = id, index = i }) end,
                            distance = zone.distance or 2.0,
                            icon = zone.icon or 'fas fa-wrench',
                        },
                    }
                    Bridge.target.addBoxZone(zone)
                    if blip then Utils.CreateBlip(blip, zone.coords) end
                end
            end)
        end
    elseif data.points then
        data.zones = nil
        for i = 1, #data.points do
            local coords = data.points[i]
            lib.points.new({
                coords = coords,
                distance = 16,
                benchid = id,
                index = i,
                inv = 'crafting',
                prompt = prompt,
                marker = client.craftingmarker,
                nearby = Utils.nearbyMarker,
            })
            if blip then Utils.CreateBlip(blip, coords) end
        end
    end

    CraftingBenches[id] = data
end

for id, data in pairs(InvData('crafting')) do createBench(data.name or id, data) end

RegisterNetEvent('vr-inventory:registerCraftingBench', function(id, data)
    if type(id) ~= 'string' or type(data) ~= 'table' then return end
    createBench(id, data)
end)
