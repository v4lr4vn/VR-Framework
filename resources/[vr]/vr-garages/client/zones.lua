local defs, zones, blips, peds = {}, {}, {}, {}
local houses = {}
local insideId
local debugOn = false
local watching = false

local function member(kind, name)
    local g = kind == 'gang' and Garage.pd.gang or Garage.pd.job
    return type(g) == 'table' and g.name == name
end

local function relevant(def)
    if def.type == 'job' or def.type == 'gang' then return member(def.type, def.group) end
    return true
end

local function keyLabel()
    return Config.InteractLabel
end

local function driving()
    local veh = cache.vehicle
    return veh and veh ~= 0 and GetPedInVehicleSeat(veh, -1) == cache.ped and veh or nil
end

function Garage.prompt()
    local def = insideId and defs[insideId]
    if not def or Garage.open then return lib.hideTextUI() end
    local text
    local veh = driving()
    if veh then
        local job = Garage.jobTag(veh) ~= nil
        if def.type == 'impound' or (def.type == 'job' and not job) then return lib.hideTextUI() end
        text = ('[%s] %s'):format(keyLabel(), job and 'Return job vehicle' or 'Park vehicle')
    else
        text = ('[%s] %s'):format(keyLabel(), def.type == 'impound' and 'Impound lot' or def.label)
    end
    lib.showTextUI(text, { icon = def.type == 'impound' and 'fa-solid fa-truck-ramp-box' or 'fa-solid fa-warehouse' })
end

local function removePed(point)
    if point.ped and DoesEntityExist(point.ped) then DeleteEntity(point.ped) end
    point.ped = nil
end

local function clear()
    for _, z in pairs(zones) do z:remove() end
    for _, b in pairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for _, p in pairs(peds) do
        p.inside = false
        removePed(p)
        p:remove()
    end
    zones, blips, peds = {}, {}, {}
end

local function addPed(def)
    local p = def.ped
    if type(p) ~= 'table' or type(p.model) ~= 'string' or not tonumber(p.x) then return end
    peds[def.id] = lib.points.new({
        coords = vec3(p.x + 0.0, p.y + 0.0, p.z + 0.0),
        distance = 60.0,
        onEnter = function(self)
            self.inside = true
            if self.ped then return end
            local model = lib.requestModel(p.model)
            if not model or peds[def.id] ~= self or not self.inside or self.ped then return end
            local ped = CreatePed(0, model, p.x + 0.0, p.y + 0.0, p.z + 0.0, (p.w or 0.0) + 0.0, false, false)
            SetModelAsNoLongerNeeded(model)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            self.ped = ped
        end,
        onExit = function(self)
            self.inside = false
            removePed(self)
        end,
    })
end

local function blipFor(def)
    if not def.blip or def.type == 'house' then return end
    local style = def.type == 'impound' and Config.Blips.impound or def.type == 'job' and Config.Blips.job or def.type == 'gang' and Config.Blips.gang
        or def.category == 'air' and Config.Blips.air or def.category == 'boat' and Config.Blips.boat or Config.Blips.public
    local b = AddBlipForCoord(def.center.x, def.center.y, def.center.z)
    SetBlipSprite(b, style.sprite)
    SetBlipColour(b, style.colour)
    SetBlipScale(b, style.scale)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(def.type == 'public' and style.label or def.label)
    EndTextCommandSetBlipName(b)
    return b
end

local function addZone(def)
    local id = def.id
    defs[id] = def
    zones[id] = lib.zones.sphere({
        coords = vec3(def.center.x, def.center.y, def.center.z),
        radius = def.radius,
        debug = debugOn,
        onEnter = function()
            insideId = id
            Garage.prompt()
            Garage.watch()
        end,
        onExit = function()
            if insideId == id then
                insideId = nil
                Garage.prompt()
            end
        end,
    })
    blips[id] = blipFor(def)
    if def.ped then addPed(def) end
end

function Garage.rebuild()
    clear()
    defs = {}
    local was = insideId
    insideId = nil
    for id, def in pairs(GlobalState.vrGarages or {}) do
        def.id = id
        if relevant(def) then addZone(def) end
    end
    for _, def in pairs(houses) do addZone(def) end
    if was and defs[was] then
        local pos = GetEntityCoords(cache.ped)
        if #(pos - vec3(defs[was].center.x, defs[was].center.y, defs[was].center.z)) <= defs[was].radius then insideId = was end
    end
    Garage.prompt()
    if insideId then Garage.watch() end
end

function Garage.def(id)
    return defs[id]
end

function Garage.inside()
    return insideId and defs[insideId] or nil
end

local function interact()
    local def = insideId and defs[insideId]
    if not def or Garage.open or IsNuiFocused() then return end
    local veh = driving()
    if veh then
        if def.type == 'impound' then return Garage.notify('You cannot park at the impound lot', 'error') end
        if def.type == 'job' and not Garage.jobTag(veh) then return end
        return Garage.store(def, veh)
    end
    local res = Garage.api('open', { garage = def.id })
    if not res.ok then return Garage.notify(Garage.errorText(res.error), 'error') end
    lib.hideTextUI()
    Garage.show(def, res.data)
end

function Garage.watch()
    if watching then return end
    watching = true
    CreateThread(function()
        while insideId do
            if not Garage.open then
                if driving() then DisableControlAction(0, 86, true) end
                if IsControlJustReleased(0, Config.InteractKey) then interact() end
            end
            Wait(0)
        end
        watching = false
    end)
end

AddStateBagChangeHandler('vrGarages', 'global', function() SetTimeout(0, Garage.rebuild) end)
AddEventHandler('vr-garages:client:groupsChanged', function() Garage.rebuild() end)
AddEventHandler('vr-lib:cache:vehicle', function() SetTimeout(250, Garage.prompt) end)

RegisterNetEvent('vr-garages:client:debug', function()
    debugOn = not debugOn
    for _, z in pairs(zones) do z:setDebug(debugOn) end
    Garage.notify(debugOn and 'Garage debug on' or 'Garage debug off', 'inform')
    if not debugOn then return end
    CreateThread(function()
        while debugOn do
            for _, def in pairs(defs) do
                for i, s in ipairs(def.spawns or {}) do
                    DrawMarker(36, s.x, s.y, s.z + 0.6, 0.0, 0.0, 0.0, 0.0, 0.0, s.w + 0.0, 1.2, 1.2, 1.2, 245, 165, 36, 180, false, false, 2, false, nil, nil, false)
                end
            end
            Wait(0)
        end
    end)
end)

local function addHouse(propertyId, data)
    local t = type(data) == 'table' and data.takeVehicle
    if type(t) ~= 'table' or not t.x then return end
    local id = 'house:' .. tostring(propertyId)
    houses[id] = {
        id = id,
        label = data.label or 'House garage',
        type = 'house',
        category = 'car',
        center = { x = t.x + 0.0, y = t.y + 0.0, z = t.z + 0.0 },
        radius = Config.HouseGarageRadius,
        spawns = { { x = t.x + 0.0, y = t.y + 0.0, z = t.z + 0.0, w = (t.w or t.h or 0) + 0.0 } },
        blip = false,
    }
    Garage.rebuild()
end

RegisterNetEvent('qb-garages:client:addHouseGarage', addHouse)

local function removeHouse(propertyId)
    houses['house:' .. tostring(propertyId)] = nil
    Garage.rebuild()
end

RegisterNetEvent('qb-garages:client:removeHouseGarage', removeHouse)
RegisterNetEvent('qb-garages:client:setHouseGarage', function() end)

CreateThread(function()
    while not GlobalState.vrGarages do Wait(500) end
    Garage.rebuild()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clear()
    lib.hideTextUI()
end)
