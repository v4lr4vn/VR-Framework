local shops = {}

local function removePed(p)
    if p.ped and DoesEntityExist(p.ped) then
        pcall(function() Bridge.target.removeLocalEntity(p.ped) end)
        DeleteEntity(p.ped)
    end
    p.ped = nil
end

local function change()
    local res = Keys.api('list')
    if not res.ok then return Keys.notify(Keys.errorText(res.error), 'error') end
    local options = {}
    for _, v in ipairs(res.data.vehicles) do
        if v.kind == 'owner' then
            options[#options + 1] = { label = ('%s  ·  %s'):format(v.label, v.plate), description = ('New locks for $%d. Every other key stops working'):format(Config.Locksmith.fee), icon = 'fa-solid fa-lock', args = { plate = v.plate } }
        end
    end
    if #options == 0 then return Keys.notify('You do not own any vehicles', 'inform') end
    lib.registerMenu({ id = 'vr-vehiclekeys:locksmith', title = 'Change the locks', position = 'top-right', options = options }, function(_, _, args)
        if type(args) ~= 'table' or not args.plate then return end
        local r = Keys.api('locksmith.change', { plate = args.plate })
        if r.ok then
            Keys.notify(('New locks fitted to %s'):format(args.plate), 'success')
        else
            Keys.notify(Keys.errorText(r.error), 'error')
        end
    end)
    lib.showMenu('vr-vehiclekeys:locksmith')
end

local function addShop(loc)
    local c = loc.coords
    local blip = Config.Locksmith.blip
    local b
    if blip then
        b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, blip.sprite)
        SetBlipColour(b, blip.colour)
        SetBlipScale(b, blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(loc.label or blip.label)
        EndTextCommandSetBlipName(b)
    end
    local p
    p = lib.points.new({
        coords = vec3(c.x, c.y, c.z),
        distance = 60.0,
        onEnter = function(self)
            self.inside = true
            if self.ped then return end
            local model = lib.requestModel(loc.ped)
            if not model or not self.inside or self.ped then return end
            local ped = CreatePed(0, model, c.x, c.y, c.z - 1.0, c.w, false, false)
            SetModelAsNoLongerNeeded(model)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            self.ped = ped
            Bridge.target.addLocalEntity(ped, {
                {
                    name = 'vr-vehiclekeys:locksmith',
                    label = 'Change the locks',
                    icon = 'fa-solid fa-lock',
                    distance = 2.5,
                    onSelect = change,
                },
            })
        end,
        onExit = function(self)
            self.inside = false
            removePed(self)
        end,
    })
    shops[#shops + 1] = { point = p, blip = b }
end

CreateThread(function()
    for _, loc in ipairs(Config.Locksmith.locations) do addShop(loc) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, s in ipairs(shops) do
        removePed(s.point)
        if s.blip then RemoveBlip(s.blip) end
    end
end)
