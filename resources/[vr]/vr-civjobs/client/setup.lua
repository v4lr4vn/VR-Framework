local applied = {}
local panel = { open = false, job = nil, field = nil, mouse = true, typing = false }

local ACTIONS = {
    open = true, job = true, set = true, add = true, update = true, move = true, remove = true, reset = true, resetJob = true,
}

local function receive(overrides)
    if type(overrides) ~= 'table' then overrides = {} end
    for job, fields in pairs(applied) do
        for id in pairs(fields) do
            if not (overrides[job] and overrides[job][id] ~= nil) then Setup.reset(job, id) end
        end
    end
    Setup.applyAll(overrides)
    applied = {}
    for job, fields in pairs(overrides) do
        applied[job] = {}
        for id in pairs(fields) do applied[job][id] = true end
    end
    Cj.setupReady = true
    if Cj.buildDepots then Cj.buildDepots() end
end

RegisterNetEvent('vr-civjobs:client:setup', function(overrides)
    receive(overrides)
end)

CreateThread(function()
    Wait(1500)
    for _ = 1, 20 do
        local ok, res = pcall(lib.callback.await, 'vr-civjobs:setupGet', false)
        if ok and type(res) == 'table' then
            if not Cj.setupReady then receive(res) end
            return
        end
        Wait(1500)
    end
    Cj.setupReady = true
end)

local COLOURS = {
    { 245, 166, 35 }, { 90, 169, 255 }, { 61, 214, 140 }, { 255, 111, 145 }, { 183, 156, 255 }, { 255, 90, 82 }, { 90, 220, 220 },
}

local function text3d(x, y, z, text, alpha)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, 0.3)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, alpha or 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function points(f)
    local v = Setup.read(f.job, f.path)
    local out = {}
    if v == nil then return out end
    if f.custom == 'anchor' then
        local c = Config.Jobs.builder.sites[1].tasks[1].from
        out[1] = { c = c }
        return out
    end
    if f.kind == 'vec3' or f.kind == 'vec4' then
        out[1] = { c = v, heading = f.kind == 'vec4' and v.w or nil }
    elseif f.kind == 'list' then
        for i, item in ipairs(v) do
            local c, r, h
            if f.item.ckey then
                c = item[f.item.ckey]
                r = f.item.rkey and item[f.item.rkey] or nil
                h = f.item.headingKey and item[f.item.headingKey] or nil
                if f.item.pos == 'vec4' then h = c.w end
            else
                c = item
                if f.item.pos == 'vec4' then h = item.w end
            end
            local label = item.label
            out[#out + 1] = { c = c, r = r, heading = h, i = i, label = label }
        end
    end
    return out
end

local function drawPreview()
    local job = panel.job
    local list = Setup.jobs[job]
    if not list then return end
    local here = GetEntityCoords(Cj.ped())
    for fi, f in ipairs(list) do
        if f.kind ~= 'number' then
            local col = COLOURS[(fi - 1) % #COLOURS + 1]
            local focus = panel.field == nil or panel.field == f.id
            local a = focus and 190 or 70
            for _, p in ipairs(points(f)) do
                local c = p.c
                local d = #(here - vec3(c.x, c.y, c.z))
                if d < 600.0 then
                    if p.r then
                        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, p.r * 2.0, p.r * 2.0, 6.0, col[1], col[2], col[3], focus and 55 or 25, false, false, 2, false, nil, nil, false)
                    end
                    DrawMarker(2, c.x, c.y, c.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.45, 0.45, 0.45, col[1], col[2], col[3], a, true, true, 2, false, nil, nil, false)
                    if p.heading then
                        local rad = math.rad(p.heading)
                        DrawLine(c.x, c.y, c.z + 1.0, c.x - math.sin(rad) * 1.8, c.y + math.cos(rad) * 1.8, c.z + 1.0, col[1], col[2], col[3], 255)
                    end
                    if d < 150.0 and focus then
                        local tag = f.label
                        if p.i then tag = ('%s %d'):format(f.label, p.i) end
                        if p.label then tag = tag .. ' - ' .. tostring(p.label) end
                        text3d(c.x, c.y, c.z + 1.9, tag)
                    end
                end
            end
        end
    end
end

local function focus(locked)
    panel.mouse = locked
    SetNuiFocus(true, locked)
    SetNuiFocusKeepInput(not locked)
    Cj.message({ action = 'setupMode', mouse = locked })
end

local function close()
    if not panel.open then return end
    panel.open = false
    panel.job, panel.field = nil, nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    Cj.message({ action = 'setupClose' })
end

local function loop()
    CreateThread(function()
        while panel.open do
            drawPreview()
            for _, c in ipairs({ 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }) do DisableControlAction(0, c, true) end
            if not panel.mouse and IsControlJustPressed(0, 19) then
                focus(true)
            end
            Wait(0)
        end
    end)
end

local function open()
    if panel.open or Board.open then return end
    local ok = lib.callback.await('vr-civjobs:isAdmin', false)
    if not ok then return end
    local res = lib.callback.await('vr-civjobs:setup', false, 'open', {})
    if type(res) ~= 'table' or not res.ok then
        Cj.notify(res and res.error == 'not_ready' and 'Setup is still loading, try again' or 'Setup is not available', 'error')
        return
    end
    panel.open = true
    Cj.message({ action = 'setupOpen', data = res.data })
    focus(true)
    loop()
end

RegisterCommand('jobsetup', function() open() end, false)

RegisterNUICallback('setup', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' or not ACTIONS[d.action] or not panel.open then
        return cb({ ok = false, error = 'bad_request' })
    end
    local res = lib.callback.await('vr-civjobs:setup', false, d.action, type(d.data) == 'table' and d.data or {})
    cb(type(res) == 'table' and res or { ok = false, error = 'failed' })
end)

RegisterNUICallback('setupSelect', function(d, cb)
    cb(true)
    if type(d) ~= 'table' then return end
    panel.job = type(d.job) == 'string' and Setup.jobs[d.job] and d.job or nil
    panel.field = type(d.field) == 'string' and d.field or nil
end)

RegisterNUICallback('setupTyping', function(_, cb)
    cb(true)
end)

RegisterNUICallback('setupWalk', function(_, cb)
    cb(true)
    if panel.open and panel.mouse then focus(false) end
end)

RegisterNUICallback('setupClose', function(_, cb)
    cb(true)
    close()
end)

RegisterNUICallback('setupGo', function(d, cb)
    cb(true)
    if not panel.open or type(d) ~= 'table' then return end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then return end
    if not lib.callback.await('vr-civjobs:isAdmin', false) then return end
    local ped = Cj.ped()
    RequestCollisionAtCoord(x, y, z)
    SetPedCoordsKeepVehicle(ped, x, y, z + 1.0)
    SetNewWaypoint(x, y)
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and panel.open then close() end
end)
