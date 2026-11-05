local zones, blips, shown = {}, {}, {}

local function spawnDisplay(id, def, models)
    shown[id] = shown[id] or {}
    for i, slot in ipairs(def.display or {}) do
        local model = models and models[tostring(i)] or slot.model
        local cur = shown[id][i]
        if cur and (cur.model ~= model or not DoesEntityExist(cur.entity)) then
            if DoesEntityExist(cur.entity) then DeleteEntity(cur.entity) end
            shown[id][i] = nil
            cur = nil
        end
        if not cur and model and IsModelInCdimage(joaat(model)) then
            local hash = joaat(model)
            if lib.requestModel(hash, 5000) then
                local c = slot.coords
                local veh = CreateVehicle(hash, c.x, c.y, c.z, c.w, false, false)
                SetModelAsNoLongerNeeded(hash)
                if veh and veh ~= 0 then
                    SetVehicleOnGroundProperly(veh)
                    FreezeEntityPosition(veh, true)
                    SetEntityInvincible(veh, true)
                    SetVehicleDoorsLocked(veh, 2)
                    SetVehicleDirtLevel(veh, 0.0)
                    SetVehicleNumberPlateText(veh, 'VALRAVN')
                    SetEntityAsMissionEntity(veh, true, true)
                    shown[id][i] = { entity = veh, model = model }
                end
            end
        end
    end
end

local function clearDisplay(id)
    for _, s in pairs(shown[id] or {}) do
        if DoesEntityExist(s.entity) then DeleteEntity(s.entity) end
    end
    shown[id] = nil
end

function Dealer.hideDisplay(id, hidden)
    for _, s in pairs(shown[id] or {}) do
        if DoesEntityExist(s.entity) then SetEntityVisible(s.entity, not hidden, false) SetEntityCollision(s.entity, not hidden, true) end
    end
end

local function rebuild()
    for _, z in pairs(zones) do Bridge.target.removeZone(z) end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    zones, blips = {}, {}
    for id, def in pairs(GlobalState.vrDealers or {}) do
        local k = def.kiosk
        zones[id] = Bridge.target.addSphereZone({
            coords = vec3(k.x, k.y, k.z),
            radius = 1.5,
            options = {
                { name = 'vr-dealership:browse', label = 'Browse vehicles', icon = 'fa-solid fa-car-side', distance = 2.5, onSelect = function() Dealer.browse(id) end },
                {
                    name = 'vr-dealership:dutyOn', label = 'Clock in for sales', icon = 'fa-solid fa-user-clock', distance = 2.5,
                    canInteract = function() local j = Dealer.pd.job return type(j) == 'table' and j.name == Config.Job and not j.onduty end,
                    onSelect = function() TriggerServerEvent('vr-dealership:server:duty', true) end,
                },
                {
                    name = 'vr-dealership:dutyOff', label = 'Clock out', icon = 'fa-solid fa-user-clock', distance = 2.5,
                    canInteract = function() return Dealer.isStaff() end,
                    onSelect = function() TriggerServerEvent('vr-dealership:server:duty', false) end,
                },
            },
        })
        if def.blip then
            local b = AddBlipForCoord(k.x, k.y, k.z)
            SetBlipSprite(b, def.blip.sprite or 326)
            SetBlipColour(b, def.blip.colour or 3)
            SetBlipScale(b, 0.75)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(def.label)
            EndTextCommandSetBlipName(b)
            blips[id] = b
        end
    end
end

AddStateBagChangeHandler('vrDealers', 'global', function() SetTimeout(0, rebuild) end)
AddStateBagChangeHandler('vrDealerDisplay', 'global', function()
    SetTimeout(0, function()
        for id in pairs(shown) do
            local def = (GlobalState.vrDealers or {})[id]
            if def then spawnDisplay(id, def, (GlobalState.vrDealerDisplay or {})[id]) end
        end
    end)
end)

CreateThread(function()
    while not GlobalState.vrDealers do Wait(500) end
    rebuild()
    while true do
        local pos = GetEntityCoords(cache.ped)
        for id, def in pairs(GlobalState.vrDealers or {}) do
            local c = def.center or def.kiosk
            local near = #(pos - vec3(c.x, c.y, c.z)) < 120.0
            if near and not shown[id] and #(def.display or {}) > 0 then
                spawnDisplay(id, def, (GlobalState.vrDealerDisplay or {})[id])
            elseif not near and shown[id] then
                clearDisplay(id)
            end
        end
        Wait(2500)
    end
end)

RegisterCommand('salestablet', function()
    if not Dealer.isStaff() then return Dealer.notify('Clock in at the sales desk first', 'error') end
    local pos = GetEntityCoords(cache.ped)
    for id, def in pairs(GlobalState.vrDealers or {}) do
        local c = def.center or def.kiosk
        if #(pos - vec3(c.x, c.y, c.z)) <= (def.radius or 20.0) then return Dealer.browse(id) end
    end
    Dealer.notify('You need to be on the sales floor', 'error')
end, false)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for id in pairs(shown) do clearDisplay(id) end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
end)
