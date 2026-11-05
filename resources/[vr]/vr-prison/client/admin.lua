local COLOUR = { station = { 245, 165, 36 }, canteen = { 61, 214, 140 }, cell = { 120, 170, 255 } }
local KIND_LABEL = { station = 'Station', canteen = 'Canteen', cell = 'Cell' }
local KIND_ICON = { station = 'fa-solid fa-briefcase', canteen = 'fa-solid fa-basket-shopping', cell = 'fa-solid fa-lock' }
local open = false
local menu

local ADMIN_ERRORS = {
    not_admin = 'Admins only',
    not_found = 'That point is gone',
    limit = 'Too many points',
    bad_value = 'That value is not allowed',
    bad_kind = 'Unknown kind',
    bad_type = 'Unknown station type',
    too_far = 'Aim closer to where you are standing',
    not_ready = 'Not ready yet, try again',
}

local function problem(code)
    Pr.notify(ADMIN_ERRORS[code] or 'Something went wrong, try again', 'error')
end

local function admin(action, data)
    local res = lib.callback.await('vr-prison:admin', false, action, data)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error
end

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

local RAY = { running = false, stamp = 0, flags = 511, distance = 20.0, hit = false, coords = nil }

local function rayCamera(flags, distance)
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
        local hit, _, coords = rayCamera(1 | 2 | 16, 60.0)
        if hit and coords then
            DrawMarker(1, coords.x, coords.y, coords.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.12, colour[1], colour[2], colour[3], 120, false, false, 2, false, nil, nil, false)
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 1.8, colour[1], colour[2], colour[3], 220)
            if IsDisabledControlJustPressed(0, 24) then
                out = { x = coords.x, y = coords.y, z = coords.z, w = (GetEntityHeading(Pr.ped()) + 180.0) % 360.0 }
                break
            end
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 200) then break end
        Wait(0)
    end
    lib.hideTextUI()
    return out
end

local function preview()
    CreateThread(function()
        while open do
            local here = GetEntityCoords(Pr.ped())
            for _, pt in ipairs(Pr.points) do
                local d = #(here - vec3(pt.x, pt.y, pt.z))
                if d < 120.0 then
                    local c = COLOUR[pt.kind] or { 255, 255, 255 }
                    DrawMarker(1, pt.x, pt.y, pt.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.15, c[1], c[2], c[3], 110, false, false, 2, false, nil, nil, false)
                    text3d(pt.x, pt.y, pt.z + 1.6, ('#%d %s'):format(pt.id, pt.label))
                end
            end
            Wait(0)
        end
    end)
end

local function refresh()
    local list = lib.callback.await('vr-prison:points', false)
    if type(list) == 'table' then Pr.points = list end
end

local function manage(pt)
    local id = 'vr-prison:point'
    local options = {
        {
            title = 'Rename', description = pt.label, icon = 'fa-solid fa-pen',
            onSelect = function()
                local input = lib.inputDialog('Name', { { type = 'input', label = 'Name', default = pt.label, required = true, max = 48 } })
                if input and input[1] then
                    local ok, err = admin('set', { id = pt.id, patch = { label = tostring(input[1]) } })
                    if not ok then problem(err) end
                    refresh()
                end
                menu()
            end,
        },
        {
            title = 'Move to where I aim', icon = 'fa-solid fa-arrows-up-down-left-right',
            onSelect = function()
                local at = aim(pt.kind)
                if at then
                    local ok, err = admin('move', { id = pt.id, at = at })
                    if not ok then problem(err) end
                    refresh()
                end
                menu()
            end,
        },
        {
            title = 'Go there', icon = 'fa-solid fa-person-walking-arrow-right',
            onSelect = function()
                SetEntityCoords(Pr.ped(), pt.x, pt.y, pt.z + 0.5, false, false, false, false)
                menu()
            end,
        },
    }
    if pt.kind == 'station' then
        local types = {}
        for key, cfg in pairs(Config.Stations) do types[#types + 1] = { value = key, label = cfg.label } end
        table.sort(types, function(a, b) return a.label < b.label end)
        options[#options + 1] = {
            title = 'Change type', description = (Config.Stations[pt.type] and Config.Stations[pt.type].label) or pt.type, icon = 'fa-solid fa-shuffle',
            onSelect = function()
                local input = lib.inputDialog('Station type', { { type = 'select', label = 'Type', options = types, default = pt.type, required = true } })
                if input and input[1] then
                    local ok, err = admin('set', { id = pt.id, patch = { type = tostring(input[1]) } })
                    if not ok then problem(err) end
                    refresh()
                end
                menu()
            end,
        }
    end
    options[#options + 1] = {
        title = 'Remove', icon = 'fa-solid fa-trash', iconColor = '#ef4444',
        onSelect = function()
            local sure = lib.alertDialog({ header = 'Remove this point?', content = ('#%d %s'):format(pt.id, pt.label), centered = true, cancel = true })
            if sure == 'confirm' then
                local ok, err = admin('remove', { id = pt.id })
                if not ok then problem(err) end
                refresh()
            end
            menu()
        end,
    }
    lib.registerContext({ id = id, title = ('#%d %s'):format(pt.id, pt.label), menu = 'vr-prison:admin', options = options, onExit = function() open = false end })
    lib.showContext(id)
end

local function add(kind, typ)
    local at = aim(kind)
    if not at then return menu() end
    local ok, data = admin('add', { kind = kind, type = typ, at = at })
    if not ok then problem(data) else Pr.notify(('%s placed. Open it in the list to rename it.'):format(KIND_LABEL[kind]), 'success') end
    refresh()
    menu()
end

local function addStation()
    local types = {}
    for key, cfg in pairs(Config.Stations) do types[#types + 1] = { value = key, label = cfg.label } end
    table.sort(types, function(a, b) return a.label < b.label end)
    local input = lib.inputDialog('Station type', { { type = 'select', label = 'What kind of station', options = types, required = true } })
    if not input or not input[1] then return menu() end
    add('station', tostring(input[1]))
end

local function saveOutfit()
    local gender = Pr.gender()
    if not gender then
        Pr.notify('Only the multiplayer male and female characters can be saved', 'error')
        return menu()
    end
    local sure = lib.alertDialog({ header = 'Save this outfit?', content = ('What you are wearing now becomes the prison outfit for %s characters.'):format(gender), centered = true, cancel = true })
    if sure == 'confirm' then
        local snap = Pr.snapshot()
        local ok, err = admin('outfit', { gender = gender, components = snap.components, props = snap.props })
        if ok then Pr.notify(('Saved as the %s prison outfit'):format(gender), 'success') else problem(err) end
    end
    menu()
end

local function resetOutfit()
    local input = lib.inputDialog('Reset outfit', { { type = 'select', label = 'Which outfit', options = { { value = 'male', label = 'Male' }, { value = 'female', label = 'Female' } }, required = true } })
    if input and input[1] then
        local ok, err = admin('outfitReset', { gender = tostring(input[1]) })
        if ok then Pr.notify('Back to the default outfit', 'success') else problem(err) end
    end
    menu()
end

menu = function()
    refresh()
    local here = GetEntityCoords(Pr.ped())
    local rows = {}
    for _, pt in ipairs(Pr.points) do rows[#rows + 1] = { pt = pt, d = #(here - vec3(pt.x, pt.y, pt.z)) } end
    table.sort(rows, function(a, b) return a.d < b.d end)
    local options = {
        { title = 'Add a work or workout station', description = 'Aim where the prisoner stands', icon = 'fa-solid fa-briefcase', onSelect = addStation },
        { title = 'Add the canteen', description = 'Aim at the counter', icon = 'fa-solid fa-basket-shopping', onSelect = function() add('canteen') end },
        { title = 'Add a cell', description = 'Aim where the prisoner wakes up', icon = 'fa-solid fa-lock', onSelect = function() add('cell') end },
        { title = 'Save what I am wearing as the prison outfit', description = 'Uses your character: male or female', icon = 'fa-solid fa-shirt', onSelect = saveOutfit },
        { title = 'Reset an outfit to the default', icon = 'fa-solid fa-rotate-left', onSelect = resetOutfit },
    }
    for i = 1, math.min(#rows, 25) do
        local pt = rows[i].pt
        options[#options + 1] = {
            title = ('#%d %s'):format(pt.id, pt.label),
            description = ('%s · %dm away'):format(KIND_LABEL[pt.kind] or pt.kind, math.floor(rows[i].d)),
            icon = KIND_ICON[pt.kind] or 'fa-solid fa-location-dot',
            onSelect = function() manage(pt) end,
        }
    end
    lib.registerContext({ id = 'vr-prison:admin', title = 'Prison', options = options, onExit = function() open = false end })
    lib.showContext('vr-prison:admin')
end

RegisterCommand(Config.Admin.command, function()
    if not lib.callback.await('vr-prison:isAdmin', false) then return end
    if open then return end
    open = true
    preview()
    menu()
end, false)
