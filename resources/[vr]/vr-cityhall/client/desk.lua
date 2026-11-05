local desks = {}

local function removePed(p)
    if p.ped and DoesEntityExist(p.ped) then
        pcall(function() Bridge.target.removeLocalEntity(p.ped) end)
        DeleteEntity(p.ped)
    end
    p.ped = nil
end

local function options(desk)
    local list = {}
    if Config.Documents.enabled then
        list[#list + 1] = { name = 'vr-cityhall:docs', label = 'Replace ID or licence', icon = 'fa-solid fa-id-card', distance = 2.5, onSelect = function() Hall.show(desk) end }
    end
    if Config.JobCentre.enabled then
        list[#list + 1] = { name = 'vr-cityhall:jobs', label = 'Job Centre', icon = 'fa-solid fa-briefcase', distance = 2.5, onSelect = function() Hall.show(desk) end }
    end
    if Config.Business.enabled then
        list[#list + 1] = { name = 'vr-cityhall:biz', label = 'Business licences', icon = 'fa-solid fa-store', distance = 2.5, onSelect = function() Hall.show(desk) end }
    end
    -- vr-restaurant: restaurants for sale and food licences
    if GetResourceState('vr-restaurant') == 'started' then
        list[#list + 1] = { name = 'vr-cityhall:restaurants', label = 'Restaurants and food licences', icon = 'fa-solid fa-utensils', distance = 2.5, onSelect = function() exports['vr-restaurant']:OpenBusinesses() end }
    end
    return list
end

local function addDesk(desk)
    local c = desk.coords
    local b
    if desk.blip then
        b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, desk.blip.sprite)
        SetBlipColour(b, desk.blip.colour)
        SetBlipScale(b, desk.blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(desk.blip.label or desk.label)
        EndTextCommandSetBlipName(b)
    end
    local p
    p = lib.points.new({
        coords = vec3(c.x, c.y, c.z),
        distance = 60.0,
        onEnter = function(self)
            self.inside = true
            if self.ped then return end
            local model = lib.requestModel(desk.ped)
            if not model or not self.inside or self.ped then return end
            local ped = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
            SetModelAsNoLongerNeeded(model)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            self.ped = ped
            Bridge.target.addLocalEntity(ped, options(desk))
        end,
        onExit = function(self)
            self.inside = false
            removePed(self)
        end,
    })
    desks[#desks + 1] = { point = p, blip = b }
end

CreateThread(function()
    for _, desk in ipairs(Config.Desks) do addDesk(desk) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, d in ipairs(desks) do
        removePed(d.point)
        if d.blip then RemoveBlip(d.blip) end
    end
end)
