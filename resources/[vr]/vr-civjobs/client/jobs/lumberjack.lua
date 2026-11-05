local cfg = Config.Jobs.lumberjack
local H = {}

local hidden = {}
local logProps = {}
local loadedProps = {}
local treeTarget = false
local treeHashes = {}

for _, name in ipairs(cfg.treeModels) do treeHashes[#treeHashes + 1] = joaat(name) end

local function hide(t)
    if hidden[t.key] then return end
    hidden[t.key] = t
    CreateModelHide(t.x, t.y, t.z, 2.0, t.model, true)
    SetTimeout(math.max(1, math.floor((t.seconds or cfg.treeRespawnSeconds))) * 1000, function()
        local h = hidden[t.key]
        if h then
            RemoveModelHide(h.x, h.y, h.z, 2.0, h.model, false)
            hidden[t.key] = nil
        end
    end)
end

RegisterNetEvent('vr-civjobs:client:felled', function(t)
    if type(t) == 'table' and t.key then hide(t) end
end)

RegisterNetEvent('vr-civjobs:client:felledSync', function(list)
    if type(list) ~= 'table' then return end
    for _, t in ipairs(list) do
        if type(t) == 'table' and t.key then hide(t) end
    end
end)

CreateThread(function()
    Wait(6000)
    TriggerServerEvent('vr-civjobs:server:requestFelled')
end)

local function inForest(c)
    local s = Cj.session
    local list = s and s.data and s.data.forests or {}
    if #list == 0 then return true end
    for _, f in ipairs(list) do
        if #(vec2(c.x, c.y) - vec2(f.x, f.y)) <= f.r then return true end
    end
    return false
end

local function chop(data)
    if Cj.isCarrying() then return Cj.notify('Your hands are full', 'error') end
    local ent = data.entity
    if not ent or ent == 0 then return end
    local c = GetEntityCoords(ent)
    local model = GetEntityModel(ent)
    local ok, res = Cj.timed({
        label = 'Chopping',
        seconds = cfg.chopSeconds,
        anim = { dict = 'melee@hatchet@streamed_core', clip = 'plyr_front_takedown', flag = 1 },
        prop = { model = 'w_me_hatchet', bone = 57005, pos = vec3(0.1, 0.0, 0.0), rot = vec3(90.0, 0.0, 0.0) },
        face = c,
    }, 'chop', { x = c.x, y = c.y, z = c.z, model = model })
    if ok then Cj.notify(('Timber! %d logs'):format(res.logs), 'success') end
end

local function pickLog(key, obj)
    if Cj.isCarrying() then return Cj.notify('Your hands are full', 'error') end
    local ok, err = Cj.act('pickup', { key = key })
    if not ok then return Cj.fail(err) end
    if obj then Cj.removeProp(obj) end
    Cj.carry(cfg.logModel, 'log', 'log')
end

local function loadLog()
    local ok, err = Cj.act('load')
    if not ok then return Cj.fail(err) end
    Cj.drop()
end

local function syncLogs(view)
    local want = {}
    for _, g in ipairs(view.data.ground or {}) do want[g.key] = g end
    for key, list in pairs(logProps) do
        local g = want[key]
        local keep = g and g.left or 0
        while #list > keep do
            Cj.removeProp(table.remove(list))
        end
        if keep == 0 then logProps[key] = nil end
    end
    for key, g in pairs(want) do
        logProps[key] = logProps[key] or {}
        local list = logProps[key]
        while #list < g.left do
            local n = #list + 1
            local ang = n * 1.9
            local obj = Cj.prop(cfg.logModel, { x = g.x + math.cos(ang) * 2.0, y = g.y + math.sin(ang) * 2.0, z = g.z }, { ground = true, placeOnGround = true })
            if not obj then break end
            list[n] = obj
            Cj.target(obj, {
                { name = 'vr-civjobs:log:' .. key .. ':' .. n, label = 'Pick up log', icon = 'fa-solid fa-tree', distance = 2.5, canInteract = function() return not Cj.isCarrying() end, onSelect = function() pickLog(key, obj) end },
            })
        end
    end
end

local function syncTruck(view)
    local v = view.vehicles[1]
    if not v then return end
    local want = math.min(view.data.loaded or 0, 6)
    if #loadedProps == want then return end
    local veh = Cj.entity(v.netId, 5)
    if not veh then return end
    for _, o in ipairs(loadedProps) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    loadedProps = {}
    for i = 1, want do
        local hash = lib.requestModel(cfg.logModel)
        if hash then
            local o = CreateObject(hash, 0.0, 0.0, 0.0, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            local row, col = (i - 1) // 3, (i - 1) % 3
            AttachEntityToEntity(o, veh, 0, -0.6 + col * 0.6, -1.9 - row * 0.6, 0.55 + row * 0.2, 0.0, 0.0, 90.0, false, false, true, false, 2, true)
            loadedProps[#loadedProps + 1] = o
        end
    end
end

local function hud(view)
    local d = view.data
    Cj.hudSet('Lumber run', {
        { label = 'Trees felled', value = tostring(d.trees) },
        { label = 'On the truck', value = ('%d / %d'):format(d.loaded, d.capacity) },
        { label = 'Delivered', value = tostring(d.delivered) },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    })
end

function H.start(view)
    local d = view.data
    for i, f in ipairs(d.forests) do
        Cj.blip('forest' .. i, f, { sprite = 153, colour = 25, scale = 0.7, label = 'Forest', radius = f.r })
    end
    Cj.blip('sawmill', d.sawmill, { sprite = 516, colour = 25, label = 'Sawmill' })
    if not treeTarget then
        treeTarget = true
        Bridge.target.addModel(treeHashes, {
            { name = 'vr-civjobs:chop', label = 'Chop tree', icon = 'fa-solid fa-tree', distance = 2.5, canInteract = function(ent)
                if not Cj.session or Cj.session.job ~= 'lumberjack' or Cj.isCarrying() then return false end
                return inForest(GetEntityCoords(ent))
            end, onSelect = chop },
        })
    end
    CreateThread(function()
        local v = view.vehicles[1]
        local veh = v and Cj.entity(v.netId)
        if veh then
            Cj.target(veh, {
                { name = 'vr-civjobs:load', label = 'Load log', icon = 'fa-solid fa-truck-ramp-box', distance = 5.0, canInteract = function() return Cj.isCarrying('log') end, onSelect = loadLog },
            })
        end
    end)
    Cj.zone('vr-civjobs:sell', d.sawmill, cfg.sawmillRadius, {
        { name = 'vr-civjobs:sell', label = 'Sell the logs', icon = 'fa-solid fa-sack-dollar', distance = cfg.sawmillRadius, canInteract = function()
            return Cj.session and (Cj.session.data.loaded or 0) > 0
        end, onSelect = function()
            local ok, res = Cj.act('unload')
            if not ok then return Cj.fail(res) end
            Cj.notify(('Delivered %d logs'):format(res.delivered), 'success')
        end },
    })
    H.sync(view)
end

function H.sync(view)
    syncLogs(view)
    syncTruck(view)
    hud(view)
    if not view.data.carry and Cj.isCarrying('log') then Cj.drop() end
    if view.data.delivered > 0 then
        Cj.finishZone('finish', Config.Jobs.lumberjack.depot.coords, 'Finish shift', 14.0)
    end
end

function H.stop()
    if treeTarget then
        treeTarget = false
        pcall(function() Bridge.target.removeModel(treeHashes, 'vr-civjobs:chop') end)
    end
    for _, o in ipairs(loadedProps) do
        if DoesEntityExist(o) then DeleteEntity(o) end
    end
    loadedProps = {}
    logProps = {}
end

Cj.register('lumberjack', H)
