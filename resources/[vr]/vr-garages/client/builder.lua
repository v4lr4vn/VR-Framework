local B = { open = false, placing = false, preview = nil }
local ACTIONS = { ['builder.open'] = true, ['builder.save'] = true, ['builder.delete'] = true, ['builder.reset'] = true }
local CANCEL = { 177, 194, 202 }

local function here()
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local c = GetEntityCoords(ent)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = GetEntityHeading(ent) + 0.0 }, veh ~= 0
end

local function text3d(x, y, z, label)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, 0.32)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextOutline()
    SetTextColour(255, 200, 92, 230)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function drawArea(c, radius, alpha)
    if not c or not tonumber(c.x) then return end
    local d = (tonumber(radius) or 0) * 2.0
    DrawMarker(1, c.x + 0.0, c.y + 0.0, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, 1.4, 245, 165, 36, alpha or 45, false, false, 2, false, nil, nil, false)
    DrawMarker(2, c.x + 0.0, c.y + 0.0, c.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.5, 0.5, 0.5, 245, 165, 36, 200, true, true, 2, false, nil, nil, false)
end

local function drawSpot(s, label, r, g, b)
    if not s or not tonumber(s.x) then return end
    DrawMarker(36, s.x + 0.0, s.y + 0.0, s.z + 0.4, 0.0, 0.0, 0.0, 0.0, 0.0, (tonumber(s.w) or 0) + 0.0, 1.6, 1.6, 1.6, r or 245, g or 165, b or 36, 190, false, false, 2, false, nil, nil, false)
    DrawMarker(27, s.x + 0.0, s.y + 0.0, s.z - 0.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 1.0, r or 245, g or 165, b or 36, 110, false, false, 2, false, nil, nil, false)
    if label then text3d(s.x + 0.0, s.y + 0.0, s.z + 1.6, label) end
end

local function drawPed(p, r, g, b)
    if not p or not tonumber(p.x) then return end
    DrawMarker(0, p.x + 0.0, p.y + 0.0, p.z + 2.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.4, 0.4, 0.4, r or 90, g or 169, b or 255, 200, true, true, 2, false, nil, nil, false)
    DrawMarker(27, p.x + 0.0, p.y + 0.0, p.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, r or 90, g or 169, b or 255, 150, false, false, 2, false, nil, nil, false)
    text3d(p.x + 0.0, p.y + 0.0, p.z + 2.5, 'Worker')
end

local function drawLoop()
    CreateThread(function()
        while B.open do
            local d = B.preview
            if d then
                drawArea(d.center, d.radius)
                for i, s in ipairs(type(d.spawns) == 'table' and d.spawns or {}) do drawSpot(s, ('Spot %d'):format(i)) end
                if type(d.ped) == 'table' then drawPed(d.ped) end
            end
            Wait(0)
        end
    end)
end

local function finish()
    B.open = false
    B.placing = false
    B.preview = nil
    lib.hideTextUI()
    SetNuiFocus(false, false)
end

RegisterNetEvent('vr-garages:client:builder', function()
    if B.open then return end
    if Garage.open then Garage.hide() end
    local res = Garage.api('builder.open', {})
    if not res.ok then return Garage.notify(Garage.errorText(res.error), 'error') end
    res.data.me = here()
    B.open = true
    SendNUIMessage({ action = 'builder', data = res.data })
    SetNuiFocus(true, true)
    drawLoop()
end)

RegisterNUICallback('builder:api', function(d, cb)
    if not B.open or type(d) ~= 'table' or not ACTIONS[d.action] then return cb({ ok = false, error = 'bad_request' }) end
    cb(Garage.api(d.action, type(d.data) == 'table' and d.data or {}))
end)

RegisterNUICallback('builder:close', function(_, cb)
    cb(true)
    finish()
end)

RegisterNUICallback('builder:preview', function(d, cb)
    cb(true)
    B.preview = type(d) == 'table' and d or nil
end)

RegisterNUICallback('builder:tp', function(d, cb)
    cb(true)
    if type(d) ~= 'table' or not tonumber(d.x) or not tonumber(d.y) or not tonumber(d.z) then return end
    local ped = cache.ped or PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped and veh or ped
    SetEntityCoords(ent, d.x + 0.0, d.y + 0.0, d.z + 0.0, false, false, false, false)
    if tonumber(d.w) then SetEntityHeading(ent, d.w + 0.0) end
end)

RegisterNUICallback('builder:model', function(d, cb)
    local model = type(d) == 'table' and type(d.model) == 'string' and d.model or ''
    local hash = joaat(model)
    if model == '' or not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then return cb({ ok = false }) end
    local name = GetLabelText(GetDisplayNameFromVehicleModel(hash))
    if not name or name == 'NULL' then name = GetDisplayNameFromVehicleModel(hash) end
    local make = GetLabelText(GetMakeNameFromVehicleModel(hash))
    if make and make ~= 'NULL' and make ~= '' then name = make .. ' ' .. name end
    cb({ ok = true, name = name })
end)

local PROMPT = {
    center = 'Place the garage centre',
    spawn = 'Place this spawn spot',
    ped = 'Place the worker here',
}

RegisterNUICallback('builder:place', function(d, cb)
    cb(true)
    if not B.open or B.placing or type(d) ~= 'table' or not PROMPT[d.kind] then return end
    B.placing = true
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'builderHide' })
    lib.showTextUI(('[E] %s  ·  [Backspace] Cancel'):format(PROMPT[d.kind]), { icon = 'fa-solid fa-crosshairs' })
    CreateThread(function()
        local done, cancelled = nil, false
        while B.open and B.placing do
            local pos, inVehicle = here()
            if d.kind == 'center' then
                drawArea(pos, tonumber(d.radius) or 0, 70)
            elseif d.kind == 'spawn' then
                drawSpot(pos, inVehicle and 'Spawn here' or 'Spawn here (get in a car for the exact spot)', 61, 214, 140)
            elseif d.kind == 'ped' then
                drawPed({ x = pos.x, y = pos.y, z = pos.z - 1.0 }, 61, 214, 140)
            end
            DisableControlAction(0, 38, true)
            for _, c in ipairs(CANCEL) do DisableControlAction(0, c, true) end
            if IsDisabledControlJustReleased(0, 38) then
                if d.kind == 'ped' then pos.z = pos.z - 1.0 end
                done = pos
                break
            end
            for _, c in ipairs(CANCEL) do
                if IsDisabledControlJustReleased(0, c) then cancelled = true end
            end
            if cancelled then break end
            Wait(0)
        end
        lib.hideTextUI()
        B.placing = false
        if not B.open then return end
        SendNUIMessage({ action = 'builderPlaced', data = { kind = d.kind, index = d.index, coords = done, cancelled = done == nil } })
        SetNuiFocus(true, true)
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() or not B.open then return end
    finish()
end)
