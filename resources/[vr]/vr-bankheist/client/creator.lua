local panel = { open = false, bank = nil, el = nil, locked = true, picking = false }
local TEMP_HASH = joaat('vr_bankheist_temp')

local ACTIONS = {
    open = true, bank = true, create = true, delete = true, bankset = true, bankhere = true,
    add = true, update = true, move = true, remove = true, reset = true, doorpick = true,
}

local RADIUS = {
    cash = { min = 1.0, max = 25.0, step = 0.5, default = 1.5, height = 2.5 },
    gold = { min = 1.0, max = 25.0, step = 0.5, default = 1.5, height = 2.5 },
    case = { min = 0.1, max = 3.0, step = 0.05, default = 0.4, height = 1.0 },
}

local AIM = { hack = true, drill = true, cash = true, gold = true, till = true, case = true, door = true }

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

local COLOURS = {
    hack = { 90, 169, 255 }, drill = { 245, 165, 36 }, cash = { 61, 214, 140 }, gold = { 255, 200, 92 }, till = { 120, 220, 120 }, case = { 120, 210, 255 }, door = { 183, 156, 255 },
}

local function drawPreview()
    local bank = BHC.bank(panel.bank)
    if not bank then return end
    local here = GetEntityCoords(BHC.ped())
    local c = bank.center
    if c then
        DrawMarker(1, c.x, c.y, c.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, bank.radius * 2.0, bank.radius * 2.0, 8.0, 255, 90, 82, 22, false, false, 2, false, nil, nil, false)
        DrawMarker(0, c.x, c.y, c.z + 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.8, 255, 90, 82, 190, true, true, 2, false, nil, nil, false)
        if #(here - vec3(c.x, c.y, c.z)) < 250.0 then text3d(c.x, c.y, c.z + 3.0, ('%s (alert point)'):format(bank.label)) end
    end
    local byId = {}
    for _, el in ipairs(bank.elements or {}) do byId[el.id] = el end
    for _, el in ipairs(bank.elements or {}) do
        local col = COLOURS[el.type] or { 255, 255, 255 }
        local focus = panel.el == nil or panel.el == el.id
        local a = focus and 200 or 70
        local d = #(here - vec3(el.x, el.y, el.z))
        if d < 400.0 then
            if el.type == 'cash' or el.type == 'gold' then
                DrawMarker(1, el.x, el.y, el.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, el.r * 2.0, el.r * 2.0, 2.5, col[1], col[2], col[3], focus and 60 or 25, false, false, 2, false, nil, nil, false)
            else
                DrawMarker(1, el.x, el.y, el.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, (el.r or 1.5) * 2.0, (el.r or 1.5) * 2.0, 1.2, col[1], col[2], col[3], focus and 45 or 20, false, false, 2, false, nil, nil, false)
            end
            DrawMarker(2, el.x, el.y, el.z + 1.2, 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.45, 0.45, 0.45, col[1], col[2], col[3], a, true, true, 2, false, nil, nil, false)
            if el.needs and byId[el.needs] then
                local o = byId[el.needs]
                DrawLine(o.x, o.y, o.z + 1.2, el.x, el.y, el.z + 1.2, col[1], col[2], col[3], focus and 220 or 90)
            end
            if (el.w or 0.0) ~= 0.0 and (el.type == 'hack' or el.type == 'drill') then
                local rad = math.rad(el.w)
                DrawLine(el.x, el.y, el.z + 1.0, el.x - math.sin(rad) * 1.6, el.y + math.cos(rad) * 1.6, el.z + 1.0, col[1], col[2], col[3], 255)
            end
            if d < 120.0 and focus then
                local tag = ('#%d %s'):format(el.id, el.label or el.type)
                if el.needs then tag = tag .. ('  (after #%d)'):format(el.needs) end
                text3d(el.x, el.y, el.z + 1.9, tag)
            end
        end
    end
end

local function focus(locked)
    panel.locked = locked
    SetNuiFocus(true, locked)
    SetNuiFocusKeepInput(not locked)
    BHC.message({ action = 'creatorMode', locked = locked })
end

local function close()
    if not panel.open then return end
    panel.open = false
    panel.bank, panel.el = nil, nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    BHC.message({ action = 'creatorClose' })
end

local function loop()
    CreateThread(function()
        while panel.open do
            drawPreview()
            for _, c in ipairs({ 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }) do DisableControlAction(0, c, true) end
            if not panel.locked and not panel.picking and IsControlJustPressed(0, 19) then focus(true) end
            Wait(0)
        end
    end)
end

local function outline(entity, state)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        SetEntityDrawOutlineColor(245, 165, 36, 255)
        SetEntityDrawOutline(entity, state)
    end
end

local function capture(entity)
    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)
    AddDoorToSystem(TEMP_HASH, model, coords.x, coords.y, coords.z, false, false, false)
    DoorSystemSetDoorState(TEMP_HASH, 4, false, false)
    coords = GetEntityCoords(entity)
    RemoveDoorFromSystem(TEMP_HASH)
    return {
        entity = entity,
        model = model,
        coords = { x = coords.x, y = coords.y, z = coords.z },
        heading = math.floor(GetEntityHeading(entity) + 0.5),
    }
end

local function hidePanel()
    panel.picking = true
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    BHC.message({ action = 'creatorHide' })
end

local function showPanel()
    panel.picking = false
    if not panel.open then return end
    BHC.message({ action = 'creatorShow' })
    focus(true)
end

local function released()
    local deadline = GetGameTimer() + 600
    while IsDisabledControlPressed(0, 24) and GetGameTimer() < deadline do Wait(0) end
    Wait(150)
end

-- The aim ray is cast by a small poller thread (the same lib.raycast call the
-- creator always used) and this just hands back the latest answer, so the draw
-- loop runs every frame and the markers do not flash.
local RAY = { running = false, stamp = 0, flags = 511, distance = 20.0, hit = false, entity = 0, coords = nil }

function BHC.rayCamera(flags, distance)
    RAY.flags, RAY.distance, RAY.stamp = flags, distance, GetGameTimer()
    if not RAY.running then
        RAY.running, RAY.hit, RAY.coords = true, false, nil
        CreateThread(function()
            while GetGameTimer() - RAY.stamp < 500 do
                local hit, entity, coords = lib.raycast.fromCamera(RAY.flags, 4, RAY.distance)
                RAY.hit, RAY.entity, RAY.coords = hit and true or false, entity or 0, coords
                Wait(0)
            end
            RAY.running, RAY.hit, RAY.coords = false, false, nil
        end)
    end
    return RAY.hit, RAY.entity, RAY.coords
end

local function aimSpot(kind, radius)
    local rc = RADIUS[kind]
    local r = radius or (rc and rc.default) or 1.5
    lib.showTextUI('[Left click] Place   [Right click] Cancel' .. (rc and '   [Scroll] Radius' or ''), { icon = 'crosshairs' })
    released()
    local out
    local colour = COLOURS[kind] or { 255, 255, 255 }
    while panel.open do
        DisablePlayerFiring(PlayerId(), true)
        for _, c in ipairs({ 24, 25, 14, 15, 16, 17, 37, 44, 140, 141, 142, 257, 263, 264 }) do DisableControlAction(0, c, true) end
        local hit, _, coords = BHC.rayCamera(1 | 2 | 16, 60.0)
        if hit and coords then
            if rc then
                if IsDisabledControlJustPressed(0, 14) then r = math.min(rc.max, r + rc.step) end
                if IsDisabledControlJustPressed(0, 15) then r = math.max(rc.min, r - rc.step) end
                r = math.floor(r / rc.step + 0.5) * rc.step
                DrawMarker(1, coords.x, coords.y, coords.z - rc.height / 2.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r * 2.0, r * 2.0, rc.height, colour[1], colour[2], colour[3], 80, false, false, 2, false, nil, nil, false)
            end
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.14, 0.14, 0.14, colour[1], colour[2], colour[3], 220, false, false, 0, true, false, false, false)
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 1.0, colour[1], colour[2], colour[3], 220)
            if IsDisabledControlJustPressed(0, 24) then
                out = { x = coords.x, y = coords.y, z = coords.z, w = GetEntityHeading(BHC.ped()) }
                break
            end
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 200) then break end
        Wait(0)
    end
    lib.hideTextUI()
    return out, r
end

local function aimDoors(count)
    lib.showTextUI(count == 2 and '[Left click] Pick both door halves   [Right click] Cancel' or '[Left click] Pick the door   [Right click] Cancel', { icon = 'door-closed' })
    released()
    local picked = {}
    local last = 0
    local existing
    while panel.open do
        DisablePlayerFiring(PlayerId(), true)
        DisableControlAction(0, 25, true)
        local hit, entity, coords = BHC.rayCamera(1 | 16, 15.0)
        entity = entity or 0
        if last ~= entity and (not picked[1] or picked[1].entity ~= last) then outline(last, false) end
        last = entity
        if hit and coords then
            DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.12, 0.12, 245, 165, 36, 160, false, false, 0, true, false, false, false)
        end
        local valid = hit and entity > 0 and GetEntityType(entity) == 3 and (not picked[1] or picked[1].entity ~= entity)
        if valid then
            outline(entity, true)
            if IsDisabledControlJustPressed(0, 24) then
                local ok, id = pcall(function() return exports['vr-doorlock']:getDoorIdFromEntity(entity) end)
                if ok and id then
                    existing = id
                    outline(entity, false)
                    break
                end
                picked[#picked + 1] = capture(entity)
            end
        end
        if IsDisabledControlJustPressed(0, 25) then
            outline(entity, false)
            if not picked[1] then
                lib.hideTextUI()
                return nil
            end
            outline(picked[1].entity, false)
            picked = {}
        end
        if #picked >= count then break end
        Wait(0)
    end
    lib.hideTextUI()
    for i = 1, #picked do
        outline(picked[i].entity, false)
        picked[i].entity = nil
    end
    if existing then return { existing = existing } end
    if #picked < count then return nil end
    return { parts = picked }
end

local function placed(res, mode)
    BHC.message({ action = 'creatorPlaced', mode = mode, ok = res.ok == true, error = res.error, data = res.data })
end

local function currentRadius(bankId, elId)
    local bank = BHC.bank(bankId)
    if not bank then return nil end
    for _, el in ipairs(bank.elements or {}) do
        if el.id == elId then return el.r end
    end
    return nil
end

local function open()
    if panel.open then return end
    local ok = lib.callback.await('vr-bankheist:isAdmin', false)
    if not ok then return end
    local res = lib.callback.await('vr-bankheist:creator', false, 'open', {})
    if type(res) ~= 'table' or not res.ok then
        BHC.notify(res and res.error == 'not_ready' and 'The creator is still loading, try again' or 'The creator is not available', 'error')
        return
    end
    panel.open = true
    BHC.message({ action = 'creatorOpen', data = res.data })
    focus(true)
    loop()
end

RegisterCommand(Config.Admin.command, function() open() end, false)

RegisterNUICallback('creator', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' or not ACTIONS[d.action] or not panel.open then
        return cb({ ok = false, error = 'bad_request' })
    end
    local res = lib.callback.await('vr-bankheist:creator', false, d.action, type(d.data) == 'table' and d.data or {})
    cb(type(res) == 'table' and res or { ok = false, error = 'failed' })
end)

RegisterNUICallback('creatorPlace', function(d, cb)
    cb(true)
    if not panel.open or panel.picking or type(d) ~= 'table' then return end
    local mode = d.mode
    local bankId, elId = tonumber(d.id), tonumber(d.el)
    if mode ~= 'add' and mode ~= 'move' and mode ~= 'center' then return end
    local kind = d.type
    if mode == 'move' then
        local bank = BHC.bank(bankId)
        for _, el in ipairs(bank and bank.elements or {}) do
            if el.id == elId then kind = el.type end
        end
    end
    if mode == 'center' then kind = 'door' end
    if mode ~= 'center' and not AIM[kind] then return end
    CreateThread(function()
        hidePanel()
        local radius = RADIUS[kind] and (currentRadius(bankId, elId) or RADIUS[kind].default) or nil
        local at, r = aimSpot(kind, radius)
        if at then
            local payload = { id = bankId, at = at }
            local action = 'bankhere'
            if mode == 'add' then
                action = 'add'
                payload.type = kind
                if radius then payload.patch = { r = r } end
            elseif mode == 'move' then
                action = 'move'
                payload.el = elId
            end
            local res = lib.callback.await('vr-bankheist:creator', false, action, payload)
            placed(type(res) == 'table' and res or { ok = false, error = 'failed' }, mode)
        end
        showPanel()
    end)
end)

RegisterNUICallback('creatorPickDoor', function(d, cb)
    cb(true)
    if not panel.open or panel.picking or type(d) ~= 'table' then return end
    local bankId, elId = tonumber(d.id), tonumber(d.el)
    if not bankId or not elId then return end
    CreateThread(function()
        hidePanel()
        local got = aimDoors(d.double and 2 or 1)
        if got then
            local payload = { id = bankId, el = elId }
            if got.existing then payload.existing = got.existing else payload.parts = got.parts end
            local res = lib.callback.await('vr-bankheist:creator', false, 'doorpick', payload)
            placed(type(res) == 'table' and res or { ok = false, error = 'failed' }, 'door')
        end
        showPanel()
    end)
end)

RegisterNUICallback('creatorSelect', function(d, cb)
    cb(true)
    if type(d) ~= 'table' then return end
    panel.bank = tonumber(d.bank)
    panel.el = tonumber(d.el)
end)

RegisterNUICallback('creatorWalk', function(_, cb)
    cb(true)
    if panel.open and panel.locked then focus(false) end
end)

RegisterNUICallback('creatorClose', function(_, cb)
    cb(true)
    close()
end)

RegisterNUICallback('creatorGo', function(d, cb)
    cb(true)
    if not panel.open or type(d) ~= 'table' then return end
    local x, y, z = tonumber(d.x), tonumber(d.y), tonumber(d.z)
    if not x or not y or not z then return end
    if not lib.callback.await('vr-bankheist:isAdmin', false) then return end
    RequestCollisionAtCoord(x, y, z)
    SetPedCoordsKeepVehicle(BHC.ped(), x, y, z + 1.0)
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and panel.open then close() end
end)
