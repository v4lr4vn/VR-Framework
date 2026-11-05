local COLOUR = { field = { 120, 220, 90 }, store = { 255, 200, 92 }, well = { 90, 170, 255 } }
local KIND_LABEL = { field = 'Farm field', store = 'Farm store', well = 'Water well' }
local open = false

local function text3d(x, y, z, text)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, 0.3)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function released()
    local deadline = GetGameTimer() + 600
    while IsDisabledControlPressed(0, 24) and GetGameTimer() < deadline do Wait(0) end
    Wait(150)
end

-- The aim ray is cast by a small poller thread and this hands back the latest
-- answer, so the draw loop runs every frame and the markers do not flash.
local RAY = { running = false, stamp = 0, flags = 511, distance = 20.0, hit = false, coords = nil }

function Fm.rayCamera(flags, distance)
    RAY.flags, RAY.distance, RAY.stamp = flags, distance, GetGameTimer()
    if not RAY.running then
        RAY.running, RAY.hit, RAY.coords = true, false, nil
        CreateThread(function()
            while GetGameTimer() - RAY.stamp < 500 do
                local hit, _, coords = lib.raycast.fromCamera(RAY.flags, 4, RAY.distance)
                RAY.hit, RAY.coords = hit and true or false, coords
                Wait(0)
            end
            RAY.running, RAY.hit, RAY.coords = false, false, nil
        end)
    end
    return RAY.hit, 0, RAY.coords
end

local function aim(kind)
    local colour = COLOUR[kind] or { 255, 255, 255 }
    lib.showTextUI('[Left click] Place   [Right click] Cancel', { icon = 'crosshairs' })
    released()
    local out
    while true do
        DisablePlayerFiring(PlayerId(), true)
        for _, c in ipairs({ 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }) do DisableControlAction(0, c, true) end
        local hit, _, coords = Fm.rayCamera(1 | 2 | 16, 60.0)
        if hit and coords then
            DrawMarker(1, coords.x, coords.y, coords.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.12, colour[1], colour[2], colour[3], 120, false, false, 2, false, nil, nil, false)
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 1.8, colour[1], colour[2], colour[3], 220)
            if IsDisabledControlJustPressed(0, 24) then
                out = { x = coords.x, y = coords.y, z = coords.z, w = (GetEntityHeading(Fm.ped()) + 180.0) % 360.0 }
                break
            end
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 200) then break end
        Wait(0)
    end
    lib.hideTextUI()
    return out
end

local function drawWall(a, b, minZ, maxZ, r, g, bl, al)
    DrawPoly(a.x, a.y, minZ, b.x, b.y, minZ, b.x, b.y, maxZ, r, g, bl, al)
    DrawPoly(a.x, a.y, minZ, b.x, b.y, maxZ, a.x, a.y, maxZ, r, g, bl, al)
    DrawPoly(b.x, b.y, maxZ, b.x, b.y, minZ, a.x, a.y, minZ, r, g, bl, al)
    DrawPoly(a.x, a.y, maxZ, b.x, b.y, maxZ, a.x, a.y, minZ, r, g, bl, al)
    DrawLine(a.x, a.y, minZ, b.x, b.y, minZ, r, g, bl, 255)
    DrawLine(a.x, a.y, maxZ, b.x, b.y, maxZ, r, g, bl, 255)
    DrawLine(a.x, a.y, minZ, a.x, a.y, maxZ, r, g, bl, 255)
end

local previewing = false

local function preview()
    if previewing then return end
    previewing = true
    CreateThread(function()
        while open do
            local here = GetEntityCoords(Fm.ped())
            for _, spot in ipairs(Fm.spots) do
                local d = #(here - vec3(spot.x, spot.y, spot.z))
                if d < (spot.points and (spot.radius or 20.0) + 150.0 or 150.0) then
                    local c = COLOUR[spot.kind] or { 255, 255, 255 }
                    if spot.kind == 'field' then
                        if spot.points and #spot.points >= 3 then
                            for i, p in ipairs(spot.points) do
                                drawWall(p, spot.points[i % #spot.points + 1], spot.minZ, spot.maxZ, c[1], c[2], c[3], 40)
                            end
                        else
                            local r = (spot.radius or 20.0) * 2.0
                            DrawMarker(1, spot.x, spot.y, spot.z - 0.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, r, r, 1.0, c[1], c[2], c[3], 45, false, false, 2, false, nil, nil, false)
                        end
                    end
                    DrawMarker(1, spot.x, spot.y, spot.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.15, c[1], c[2], c[3], 110, false, false, 2, false, nil, nil, false)
                    local line = ('#%d %s'):format(spot.id, spot.label)
                    if spot.kind == 'field' then
                        line = line .. ' · ' .. ((spot.crops and #spot.crops > 0) and Fm.cropNames(spot.crops) or 'all crops')
                        if spot.irrigated then line = line .. ' · irrigated' end
                    end
                    text3d(spot.x, spot.y, spot.z + 2.0, line)
                end
            end
            Wait(0)
        end
        previewing = false
    end)
end

-- Walk round the edge of a field and press E at every corner, like the dispatch zone tool.
local TOOL_ADD, TOOL_UNDO, TOOL_SAVE, TOOL_CANCEL = 38, 194, 191, 73

local function walkOutline()
    pcall(lib.hideContext, false)
    local pts = {}
    local function help()
        lib.showTextUI(('Field: %d corners  [E] add corner  [Backspace] undo  [Enter] save  [X] cancel'):format(#pts), { icon = 'draw-polygon' })
    end
    help()
    Fm.notify('Walk to each corner of the field and press E. Press Enter when you are done.', 'inform')
    local out
    while true do
        for _, c in ipairs({ TOOL_ADD, TOOL_UNDO, TOOL_SAVE, TOOL_CANCEL, 177 }) do DisableControlAction(0, c, true) end
        local pos = GetEntityCoords(Fm.ped())
        local feet = pos.z - 1.0
        local lowest, highest = feet, feet
        for _, p in ipairs(pts) do lowest, highest = math.min(lowest, p.z), math.max(highest, p.z) end
        local minZ, maxZ = lowest - 0.5, highest + 3.0
        for i, p in ipairs(pts) do
            DrawMarker(28, p.x, p.y, p.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, 255, 200, 92, 220, false, false, 2, false, nil, nil, false)
            if i > 1 then drawWall(pts[i - 1], p, minZ, maxZ, 120, 220, 90, 45) end
        end
        if #pts >= 1 then
            local here = { x = pos.x, y = pos.y }
            drawWall(pts[#pts], here, minZ, maxZ, 255, 200, 92, 35)
            if #pts >= 2 then drawWall(here, pts[1], minZ, maxZ, 255, 200, 92, 20) end
        end
        if IsDisabledControlJustPressed(0, TOOL_ADD) then
            if #pts >= 40 then
                Fm.notify('That is the most corners a field can have', 'error')
            else
                pts[#pts + 1] = { x = pos.x, y = pos.y, z = feet }
                help()
            end
        elseif IsDisabledControlJustPressed(0, TOOL_UNDO) and #pts > 0 then
            pts[#pts] = nil
            help()
        elseif IsDisabledControlJustPressed(0, TOOL_SAVE) then
            if #pts < 3 then
                Fm.notify('Add at least 3 corners first', 'error')
            else
                out = pts
                break
            end
        elseif IsDisabledControlJustPressed(0, TOOL_CANCEL) then
            break
        end
        Wait(0)
    end
    lib.hideTextUI()
    open = true
    preview()
    return out
end

local function admin(action, data)
    local res = lib.callback.await('vr-farming:admin', false, action, data)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error
end

local ADMIN_ERRORS = {
    few_corners = 'A field needs at least 3 corners',
    many_corners = 'Too many corners',
    bad_corner = 'One of the corners is not valid, try again',
    too_big = 'That field is too big. Keep it under 500 metres across',
    too_small = 'That field is too small',
    not_admin = 'Admins only',
    not_found = 'That spot is gone',
    limit = 'Too many spots',
    bad_value = 'That value is not allowed',
    bad_kind = 'Unknown kind',
}

local function problem(code)
    Fm.notify(ADMIN_ERRORS[code] or Fm.text(code), 'error')
end

local menu

local function compact(list)
    local out = {}
    for _, o in ipairs({ table.unpack(list, 1, 12) }) do
        if o then out[#out + 1] = o end
    end
    return out
end

local function chooseCrops(spot)
    local names, options = {}, {}
    for name in pairs(Config.Crops) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do options[#options + 1] = { label = Config.Crops[name].label, value = name } end
    local input = lib.inputDialog(('Crops for %s'):format(spot.label), {
        { type = 'multi-select', label = 'Crops that can grow here', description = 'Leave empty to allow every crop', options = options, default = spot.crops or {}, clearable = true },
        { type = 'checkbox', label = 'Irrigated field', description = 'Plants here water themselves, no watering can needed', checked = spot.irrigated == true },
    })
    if not input then return false end
    local ok, err = admin('set', { id = spot.id, patch = { crops = input[1] or false, irrigated = input[2] == true } })
    if not ok then
        problem(err)
        return false
    end
    Fm.notify((input[1] and ('Now grows: ' .. Fm.cropNames(input[1])) or 'Every crop can grow here') .. (input[2] == true and ' · irrigated' or ''), 'success')
    return true
end

local function manage(spot)
    local id = ('vr-farming:spot:%d'):format(spot.id)
    lib.registerContext({
        id = id,
        title = ('#%d %s'):format(spot.id, spot.label),
        menu = 'vr-farming:admin',
        onExit = function() open = false end,
        options = compact({
            {
                title = 'Go there', icon = 'fa-solid fa-location-arrow',
                onSelect = function()
                    SetPedCoordsKeepVehicle(Fm.ped(), spot.x, spot.y, spot.z + 1.0)
                end,
            },
            not (spot.kind == 'field' and spot.points) and {
                title = 'Aim and move', icon = 'fa-solid fa-crosshairs',
                onSelect = function()
                    local at = aim(spot.kind)
                    if at then
                        local ok, err = admin('move', { id = spot.id, at = at })
                        if not ok then problem(err) else Fm.notify('Moved', 'success') end
                    end
                    menu()
                end,
            } or false,
            spot.kind == 'field' and {
                title = 'Crops and irrigation', description = ((spot.crops and #spot.crops > 0) and Fm.cropNames(spot.crops) or 'Every crop') .. (spot.irrigated and ' · irrigated' or ' · needs watering'),
                icon = 'fa-solid fa-seedling',
                onSelect = function()
                    chooseCrops(spot)
                    menu()
                end,
            } or false,
            spot.kind == 'field' and {
                title = 'Redraw the outline', description = spot.points and (#spot.points .. ' corners') or 'Round field',
                icon = 'fa-solid fa-draw-polygon',
                onSelect = function()
                    local pts = walkOutline()
                    if pts then
                        local ok, data = admin('shape', { id = spot.id, points = pts })
                        if not ok then problem(data) else
                            Fm.notify(data.removed > 0 and ('Outline saved. %d plants outside it were removed'):format(data.removed) or 'Outline saved', 'success')
                        end
                    end
                    menu()
                end,
            } or false,
            {
                title = 'Name', description = spot.label, icon = 'fa-solid fa-pen',
                onSelect = function()
                    local input = lib.inputDialog('Name', { { type = 'input', label = 'Name', default = spot.label, required = true, max = 48 } })
                    if input and input[1] then
                        local ok, err = admin('set', { id = spot.id, patch = { label = input[1] } })
                        if not ok then problem(err) end
                    end
                    menu()
                end,
            },
            spot.kind == 'field' and not spot.points and {
                title = 'Radius', description = ('%.0f m'):format(spot.radius or 20.0), icon = 'fa-solid fa-circle-dot',
                onSelect = function()
                    local input = lib.inputDialog('Field radius', { { type = 'number', label = 'Metres, 3 to 120', default = spot.radius or 20.0, min = 3, max = 120, required = true } })
                    if input and input[1] then
                        local ok, err = admin('set', { id = spot.id, patch = { radius = input[1] } })
                        if not ok then problem(err) end
                    end
                    menu()
                end,
            } or false,
            spot.kind ~= 'field' and {
                title = 'Person model', description = spot.ped or 'none', icon = 'fa-solid fa-user',
                onSelect = function()
                    local input = lib.inputDialog('Person model', { { type = 'input', label = 'Ped model, empty for nobody', default = spot.ped or '', max = 48 } })
                    if input then
                        local ok, err = admin('set', { id = spot.id, patch = { ped = input[1] or '' } })
                        if not ok then problem(err) end
                    end
                    menu()
                end,
            } or false,
            spot.kind == 'store' and {
                title = 'Price multiplier',
                description = spot.rate and tostring(spot.rate) or 'default from the config',
                icon = 'fa-solid fa-percent',
                onSelect = function()
                    local input = lib.inputDialog('Buy price multiplier', { { type = 'number', label = 'Share of the crop price the store pays: 0.05 to 2, 0 for the config default', default = spot.rate or 0, min = 0, max = 2, precision = 2 } })
                    if input and input[1] ~= nil then
                        local ok, err = admin('set', { id = spot.id, patch = { rate = input[1] } })
                        if not ok then problem(err) end
                    end
                    menu()
                end,
            },
            {
                title = 'Remove', icon = 'fa-solid fa-trash',
                onSelect = function()
                    local sure = lib.alertDialog({ header = 'Remove this spot?', content = spot.kind == 'field' and (spot.label .. '. Every plant growing in it is removed too.') or spot.label, centered = true, cancel = true })
                    if sure == 'confirm' then
                        local ok, err = admin('remove', { id = spot.id })
                        if not ok then problem(err) else Fm.notify('Removed', 'success') end
                    end
                    menu()
                end,
            },
        }),
    })
    lib.showContext(id)
end

local function add(kind)
    if kind == 'field' then
        local pts = walkOutline()
        if not pts then return menu() end
        local ok, data = admin('add', { kind = 'field', points = pts })
        if not ok then
            problem(data)
            return menu()
        end
        Fm.notify('Field saved. Choose which crops can grow in it and whether it is irrigated', 'success')
        chooseCrops(data.spot)
        return menu()
    end
    local at = aim(kind)
    if not at then return menu() end
    local ok, data = admin('add', { kind = kind, at = at })
    if not ok then problem(data) else Fm.notify(('%s placed. Open it from the list to name it'):format(KIND_LABEL[kind]), 'success') end
    menu()
end

menu = function()
    local here = GetEntityCoords(Fm.ped())
    local rows = {}
    for _, spot in ipairs(Fm.spots) do rows[#rows + 1] = { spot = spot, d = #(here - vec3(spot.x, spot.y, spot.z)) } end
    table.sort(rows, function(a, b) return a.d < b.d end)
    local options = {
        { title = 'Add a field', description = 'Walk round the edge and press E at each corner', icon = 'fa-solid fa-wheat-awn', onSelect = function() add('field') end },
        { title = 'Add a farm store', description = 'Aim where the seller stands', icon = 'fa-solid fa-store', onSelect = function() add('store') end },
        { title = 'Add a well', description = 'Aim where the water is', icon = 'fa-solid fa-faucet-drip', onSelect = function() add('well') end },
    }
    for i = 1, math.min(#rows, 25) do
        local spot = rows[i].spot
        options[#options + 1] = {
            title = ('#%d %s'):format(spot.id, spot.label),
            description = ('%s · %dm away%s'):format(KIND_LABEL[spot.kind], math.floor(rows[i].d), spot.kind == 'field' and (' · ' .. ((spot.crops and #spot.crops > 0) and Fm.cropNames(spot.crops) or 'all crops') .. (spot.irrigated and ' · irrigated' or '')) or ''),
            icon = 'fa-solid fa-location-dot',
            onSelect = function() manage(spot) end,
        }
    end
    lib.registerContext({ id = 'vr-farming:admin', title = 'Farm spots', options = options, onExit = function() open = false end })
    lib.showContext('vr-farming:admin')
end

RegisterCommand(Config.Admin.command, function()
    if not lib.callback.await('vr-farming:isAdmin', false) then return end
    if open then return end
    open = true
    preview()
    menu()
end, false)
