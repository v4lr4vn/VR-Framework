local zone, blip, ped

local function clearPed()
    if ped and DoesEntityExist(ped) then DeleteEntity(ped) end
    ped = nil
end

local function spawnPed(c)
    clearPed()
    local model = joaat(Config.Shop.ped)
    if not IsModelInCdimage(model) or not lib.requestModel(model, 5000) then return end
    ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, false)
    SetModelAsNoLongerNeeded(model)
    if not ped or ped == 0 then ped = nil return end
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
end

local function rebuild()
    local c = GlobalState.vrCardShop
    if zone then Bridge.target.removeZone(zone) zone = nil end
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    clearPed()
    if type(c) ~= 'table' then return end
    zone = Bridge.target.addSphereZone({
        coords = vec3(c.x, c.y, c.z),
        radius = 1.6,
        options = {
            { name = 'vr-cards:shop', label = 'Card shop', icon = 'fa-solid fa-layer-group', distance = Config.Shop.radius, onSelect = function() TCG.openShop() end },
        },
    })
    local b = Config.Shop.blip
    if b then
        blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(blip, b.sprite)
        SetBlipColour(blip, b.colour)
        SetBlipScale(blip, b.scale)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(c.label or Config.Shop.label)
        EndTextCommandSetBlipName(blip)
    end
end

AddStateBagChangeHandler('vrCardShop', 'global', function() SetTimeout(0, rebuild) end)

CreateThread(function()
    while not GlobalState.vrCardShop do Wait(500) end
    rebuild()
    while true do
        local c = GlobalState.vrCardShop
        if Config.Shop.ped and type(c) == 'table' then
            local near = #(GetEntityCoords(cache.ped) - vec3(c.x, c.y, c.z)) < 60.0
            if near and not ped then spawnPed(c) elseif not near and ped then clearPed() end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearPed()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
end)
