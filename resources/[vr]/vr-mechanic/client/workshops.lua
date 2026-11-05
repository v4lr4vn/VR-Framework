local zones, blips = {}, {}

local function rebuild()
    for _, z in pairs(zones) do exports['vr-target']:removeZone(z) end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    zones, blips = {}, {}
    for id, w in pairs(GlobalState.vrWorkshops or {}) do
        local c = w.counter or w.center
        zones[id] = exports['vr-target']:addSphereZone({
            coords = vec3(c.x, c.y, c.z),
            radius = 1.5,
            options = {
                {
                    name = 'vr-mechanic:parts', label = 'Parts counter', icon = 'fa-solid fa-boxes-stacked', distance = Config.CounterDistance,
                    canInteract = function() return Mech.isMechanic() and Mech.pd.job.name == w.job end,
                    onSelect = function() Mech.openShop(id) end,
                },
                {
                    name = 'vr-mechanic:orders', label = 'Work orders', icon = 'fa-solid fa-clipboard-list', distance = Config.CounterDistance,
                    canInteract = function() return Mech.isMechanic() and Mech.pd.job.name == w.job end,
                    onSelect = function() Mech.openBoard() end,
                },
                {
                    name = 'vr-mechanic:dutyOn', label = 'Clock in', icon = 'fa-solid fa-user-clock', distance = Config.CounterDistance,
                    canInteract = function() local j = Mech.pd.job return type(j) == 'table' and j.name == w.job and not j.onduty end,
                    onSelect = function() TriggerServerEvent('vr-mechanic:server:duty', id, true) end,
                },
                {
                    name = 'vr-mechanic:dutyOff', label = 'Clock out', icon = 'fa-solid fa-user-clock', distance = Config.CounterDistance,
                    canInteract = function() local j = Mech.pd.job return type(j) == 'table' and j.name == w.job and j.onduty == true end,
                    onSelect = function() TriggerServerEvent('vr-mechanic:server:duty', id, false) end,
                },
            },
        })
        if Config.Blip then
            local b = AddBlipForCoord(w.center.x, w.center.y, w.center.z)
            SetBlipSprite(b, Config.Blip.sprite)
            SetBlipColour(b, Config.Blip.colour)
            SetBlipScale(b, Config.Blip.scale)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(w.label)
            EndTextCommandSetBlipName(b)
            blips[id] = b
        end
    end
end

AddStateBagChangeHandler('vrWorkshops', 'global', function() SetTimeout(0, rebuild) end)

CreateThread(function()
    while not GlobalState.vrWorkshops do Wait(500) end
    rebuild()
end)

CreateThread(function()
    exports['vr-target']:addGlobalVehicle({
        {
            name = 'vr-mechanic:inspect', label = 'Inspect vehicle', icon = 'fa-solid fa-stethoscope', distance = 3.0,
            canInteract = function(entity) return Mech.isMechanic() and not IsPedInAnyVehicle(cache.ped, false) and DoesEntityExist(entity) end,
            onSelect = function(data) Mech.inspect(type(data) == 'table' and data.entity or data) end,
        },
        {
            name = 'vr-mechanic:tune', label = 'Customise vehicle', icon = 'fa-solid fa-paint-roller', distance = 3.0,
            canInteract = function(entity)
                if not Mech.isMechanic() or IsPedInAnyVehicle(cache.ped, false) then return false end
                return Mech.workshopAt(GetEntityCoords(entity)) ~= nil
            end,
            onSelect = function(data) Tuning.open(type(data) == 'table' and data.entity or data) end,
        },
        {
            name = 'vr-mechanic:design', label = 'Design a new look', icon = 'fa-solid fa-swatchbook', distance = 3.0,
            canInteract = function(entity)
                if Mech.isMechanic() or IsPedInAnyVehicle(cache.ped, false) then return false end
                return Mech.anyWorkshopAt(GetEntityCoords(entity)) ~= nil
            end,
            onSelect = function(data) Design.open(type(data) == 'table' and data.entity or data) end,
        },
    })
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    pcall(function() exports['vr-target']:removeGlobalVehicle({ 'vr-mechanic:inspect', 'vr-mechanic:tune', 'vr-mechanic:design' }) end)
end)
