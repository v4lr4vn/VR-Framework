Shops = {}

local shopTypes = {}
local active = {}

for shopType, data in pairs(InvData('shops')) do
    local shop = {
        name = data.name,
        groups = data.groups or data.jobs,
        blip = data.blip,
        label = data.label,
        icon = data.icon,
    }

    if shared.target then
        shop.model = data.model
        shop.targets = data.targets
        if not shop.targets and not shop.model then shop.locations = data.locations end
    else
        shop.locations = data.locations
    end

    if shop.blip then
        shop.blip.name = ('vrinv_shop_%s'):format(shopType)
        AddTextEntry(shop.blip.name, shop.name or shopType)
    end

    shopTypes[shopType] = shop
end

local function onEnterShop(point)
    if point.entity then return end
    local model = lib.requestModel(point.ped)
    if not model then return end

    local entity = CreatePed(0, model, point.coords.x, point.coords.y, point.coords.z, point.heading or 0.0, false, true)
    if point.scenario then TaskStartScenarioInPlace(entity, point.scenario, 0, true) end
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(entity, true)
    SetEntityInvincible(entity, true)
    SetBlockingOfNonTemporaryEvents(entity, true)

    Bridge.target.addLocalEntity(entity, {
        {
            icon = point.icon or 'fas fa-shopping-basket',
            label = point.label,
            groups = point.groups,
            onSelect = function() client.openInventory('shop', { id = point.invId, type = point.type }) end,
            iconColor = point.iconColor,
            distance = point.shopDistance or 2.0,
        },
    })

    point.entity = entity
end

local function onExitShop(point)
    local entity = point.entity
    if not entity then return end
    Bridge.target.removeLocalEntity(entity)
    Utils.DeleteEntity(entity)
    point.entity = nil
end

local function hasAccess(shop)
    return not shop.groups or client.hasGroup(shop.groups)
end

function Shops.wipe()
    for i = 1, #active do
        local shop = active[i]
        if shop.zoneId then
            Bridge.target.removeZone(shop.zoneId)
            shop.zoneId = nil
        end
        if shop.remove then
            if shop.entity then onExitShop(shop) end
            Utils.clearPrompt(shop)
            shop:remove()
        end
        if shop.blip then RemoveBlip(shop.blip) end
        if shop.model then Bridge.target.removeModel(shop.model, shop.optionName) end
    end
    active = {}
end

function Shops.refresh()
    Shops.wipe()

    for shopType, shop in pairs(shopTypes) do
        local blip = shop.blip
        local label = shop.label or locale('open_label', shop.name or shopType)

        if shared.target and shop.model then
            if hasAccess(shop) then
                local optionName = ('vrinv_shop_%s'):format(shopType)
                Bridge.target.addModel(shop.model, {
                    {
                        name = optionName,
                        icon = shop.icon or 'fas fa-shopping-basket',
                        label = label,
                        onSelect = function() client.openInventory('shop', { type = shopType }) end,
                        distance = 2,
                    },
                })
                active[#active + 1] = { model = shop.model, optionName = optionName }
            end
        elseif shared.target and shop.targets then
            for i = 1, #shop.targets do
                local target = shop.targets[i]

                if target.ped then
                    active[#active + 1] = lib.points.new({
                        coords = target.loc,
                        heading = target.heading,
                        distance = 60,
                        inv = 'shop',
                        invId = i,
                        type = shopType,
                        blip = blip and hasAccess(shop) and Utils.CreateBlip(blip, target.loc) or nil,
                        ped = target.ped,
                        scenario = target.scenario,
                        label = label,
                        groups = shop.groups,
                        icon = shop.icon or 'fas fa-shopping-basket',
                        iconColor = target.iconColor,
                        onEnter = onEnterShop,
                        onExit = onExitShop,
                        shopDistance = target.distance,
                    })
                elseif hasAccess(shop) then
                    local zone = InvUtil.deepclone(target)
                    active[#active + 1] = {
                        zoneId = Utils.CreateBoxZone(zone, {
                            {
                                name = ('%s-%s'):format(shopType, i),
                                icon = shop.icon or 'fas fa-shopping-basket',
                                label = label,
                                groups = shop.groups,
                                onSelect = function() client.openInventory('shop', { id = i, type = shopType }) end,
                                iconColor = target.iconColor,
                                distance = target.distance,
                            },
                        }),
                        blip = blip and Utils.CreateBlip(blip, target.loc or target.coords) or nil,
                    }
                end
            end
        elseif shop.locations and hasAccess(shop) then
            local prompt = { options = { icon = shop.icon or 'fa-basket-shopping' }, message = Utils.prompt(label) }
            for i = 1, #shop.locations do
                local coords = shop.locations[i]
                active[#active + 1] = lib.points.new({
                    coords = coords,
                    distance = 16,
                    inv = 'shop',
                    invId = i,
                    type = shopType,
                    marker = client.shopmarker,
                    prompt = prompt,
                    nearby = Utils.nearbyMarker,
                    blip = blip and Utils.CreateBlip(blip, coords) or nil,
                })
            end
        end
    end
end
