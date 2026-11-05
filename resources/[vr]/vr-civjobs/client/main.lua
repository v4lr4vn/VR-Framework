Board = { open = false, job = nil }

local SELL = {
    hunter = 'Sell game',
    fisherman = 'Sell catch',
    treasurehunter = 'Sell finds',
}

local ALLOWED = {
    open = true, start = true, stop = true, state = true, sell = true, shop = true,
    ['crew.invite'] = true, ['crew.accept'] = true, ['crew.decline'] = true, ['crew.kick'] = true, ['crew.nearby'] = true,
}

function Board.show(jobId)
    if Board.open then return end
    if not Bridge.loggedIn() then return end
    local res = Cj.api('open', { job = jobId })
    if not res.ok then return Cj.fail(res.error) end
    Board.open = true
    Board.job = jobId
    Cj.message({ action = 'open', data = res.data })
    SetNuiFocus(true, true)
end

function Board.hide()
    if not Board.open then return end
    Board.open = false
    Board.job = nil
    SetNuiFocus(false, false)
    Cj.message({ action = 'close' })
end

function Board.refresh()
    if not Board.open or not Board.job then return end
    local res = Cj.api('open', { job = Board.job })
    if res.ok then Cj.message({ action = 'update', data = res.data }) end
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' or not ALLOWED[d.action] then return cb({ ok = false, error = 'bad_request' }) end
    local data = type(d.data) == 'table' and d.data or {}
    cb(Cj.api(d.action, data))
    if d.action == 'start' or d.action == 'stop' or d.action:find('^crew') then
        SetTimeout(250, Board.refresh)
    end
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    Board.hide()
end)

RegisterNUICallback('skill', function(d, cb)
    cb(true)
    if Cj.skillPromise then
        local p = Cj.skillPromise
        Cj.skillPromise = nil
        p:resolve(type(d) == 'table' and d.success == true)
    end
end)

function Cj.sell(jobId, items)
    local res = Cj.api('sell', { job = jobId, items = items })
    if not res.ok then return Cj.fail(res.error) end
    Cj.notify(('Sold for $%d'):format(res.data.total), 'success')
    Board.refresh()
end

local depots = {}

local function depotOptions(id, def)
    local list = {
        { name = 'vr-civjobs:board:' .. id, label = 'Work board', icon = 'fa-solid ' .. def.icon, distance = 2.5, onSelect = function() Board.show(id) end },
    }
    if SELL[id] then
        list[#list + 1] = { name = 'vr-civjobs:sell:' .. id, label = SELL[id], icon = 'fa-solid fa-sack-dollar', distance = 2.5, onSelect = function() Cj.sell(id) end }
    end
    return list
end

local function removeDepotPed(d)
    if d.ped and DoesEntityExist(d.ped) then
        pcall(function() Bridge.target.removeLocalEntity(d.ped) end)
        DeleteEntity(d.ped)
    end
    d.ped = nil
end

local function addDepot(id, def)
    local c = def.depot.coords
    local d = { id = id }
    if Config.Blips and def.depot.blip then
        local b = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(b, def.depot.blip.sprite)
        SetBlipColour(b, def.depot.blip.colour)
        SetBlipScale(b, def.depot.blip.scale)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(def.depot.blip.label or def.label)
        EndTextCommandSetBlipName(b)
        d.blip = b
    end
    d.point = lib.points.new({
        coords = vec3(c.x, c.y, c.z),
        distance = 70.0,
        onEnter = function(self)
            self.inside = true
            if d.ped then return end
            local model = lib.requestModel(def.depot.ped)
            if not model or not self.inside or d.ped then return end
            local ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, false)
            SetModelAsNoLongerNeeded(model)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            d.ped = ped
            Bridge.target.addLocalEntity(ped, depotOptions(id, def))
        end,
        onExit = function(self)
            self.inside = false
            removeDepotPed(d)
        end,
    })
    depots[#depots + 1] = d
end

local function clearDepots()
    for _, d in ipairs(depots) do
        if d.point and d.point.remove then d.point:remove() end
        removeDepotPed(d)
        if d.blip then RemoveBlip(d.blip) end
    end
    depots = {}
end

function Cj.buildDepots()
    clearDepots()
    for id, def in pairs(Config.Jobs) do
        if not Config.Disabled[id] then addDepot(id, def) end
    end
end

CreateThread(function()
    local waited = 0
    while not Cj.setupReady and waited < 12000 do
        Wait(200)
        waited = waited + 200
    end
    if #depots == 0 then Cj.buildDepots() end
end)

local function prompt(data)
    Cj.message({ action = 'invite', from = data.name, label = data.label, seconds = data.seconds })
    local deadline = GetGameTimer() + (data.seconds or 30) * 1000
    Cj.pendingInvite = true
    while Cj.pendingInvite and GetGameTimer() < deadline do
        if IsControlJustPressed(0, 246) then
            Cj.pendingInvite = false
            Cj.message({ action = 'inviteEnd' })
            local res = Cj.api('crew.accept')
            if res.ok then Cj.notify('You joined the crew', 'success') else Cj.fail(res.error) end
            return
        elseif IsControlJustPressed(0, 306) then
            break
        end
        Wait(0)
    end
    if Cj.pendingInvite then
        Cj.pendingInvite = false
        Cj.message({ action = 'inviteEnd' })
        Cj.api('crew.decline')
    end
end

RegisterNetEvent('vr-civjobs:client:invite', function(data)
    if type(data) ~= 'table' or Cj.pendingInvite or Cj.session then return end
    CreateThread(function() prompt(data) end)
end)

RegisterNetEvent('vr-civjobs:client:sync', function(view)
    if type(view) ~= 'table' or type(view.job) ~= 'string' then return end
    local first = Cj.session == nil or Cj.session.job ~= view.job
    Cj.session = view
    local h = Cj.handlers[view.job]
    CreateThread(function()
        if h then
            local fn = first and h.start or h.sync
            if fn then
                local ok, err = pcall(fn, view)
                if not ok then print(('^1[vr-civjobs] %s: %s^0'):format(view.job, tostring(err))) end
            end
        end
        Board.refresh()
    end)
end)

RegisterNetEvent('vr-civjobs:client:ended', function(info)
    local h = type(info) == 'table' and Cj.handlers[info.job]
    if h and h.stop then
        local ok, err = pcall(h.stop, info)
        if not ok then print(('^1[vr-civjobs] stop: %s^0'):format(tostring(err))) end
    end
    Cj.session = nil
    Cj.cleanup()
    Board.refresh()
end)

RegisterNetEvent('vr-civjobs:client:vehicle', function(data)
    if type(data) ~= 'table' or not data.netId then return end
    CreateThread(function()
        local veh = Cj.entity(data.netId)
        if not veh then return end
        SetVehicleEngineOn(veh, true, true, false)
        SetVehicleOnGroundProperly(veh)
        if data.warp then
            TaskWarpPedIntoVehicle(Cj.ped(), veh, -1)
        end
    end)
end)

RegisterCommand(Config.Admin.command, function(_, args)
    if args[1] ~= 'here' then return end
    local ok = lib.callback.await('vr-civjobs:isAdmin', false)
    if not ok then return end
    local c = GetEntityCoords(Cj.ped())
    local h = GetEntityHeading(Cj.ped())
    local text = ('vec4(%.1f, %.1f, %.1f, %.1f)'):format(c.x, c.y, c.z, h)
    print('[vr-civjobs] ' .. text)
    Cj.notify(text, 'inform')
end, false)

Bridge.on('playerUnloaded', function()
    Board.hide()
    Cj.session = nil
    Cj.cleanup()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if Board.open then SetNuiFocus(false, false) end
    Cj.cleanup()
    for _, d in ipairs(depots) do
        removeDepotPed(d)
        if d.blip then RemoveBlip(d.blip) end
    end
end)

function Cj.register(id, handler)
    Cj.handlers[id] = handler
end
