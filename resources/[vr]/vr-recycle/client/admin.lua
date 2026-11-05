local RES = GetCurrentResourceName()
local open = false
local menu

local ADMIN_ERRORS = {
    not_admin = 'Admins only', not_found = 'That point is gone', limit = 'Too many points', bad_value = 'That value is not allowed',
    bad_kind = 'Unknown kind', too_far = 'Aim closer to where you are standing', not_ready = 'Not ready yet, try again',
}

local function problem(code) Gc.notify(ADMIN_ERRORS[code] or 'Something went wrong, try again', 'error') end

local function admin(action, data)
    local res = lib.callback.await(Gc.name('admin'), false, action, data)
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

local function aim()
    lib.showTextUI('[Left click] Place   [Right click] Cancel', { icon = 'crosshairs' })
    released()
    local out
    while true do
        DisablePlayerFiring(PlayerId(), true)
        for _, c in ipairs({ 24, 25, 37, 44, 140, 141, 142, 257, 263, 264 }) do DisableControlAction(0, c, true) end
        local hit, _, coords = rayCamera(1 | 2 | 16, 60.0)
        if hit and coords then
            DrawMarker(1, coords.x, coords.y, coords.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.12, 245, 165, 36, 120, false, false, 2, false, nil, nil, false)
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 1.8, 245, 165, 36, 220)
            if IsDisabledControlJustPressed(0, 24) then
                out = { x = coords.x, y = coords.y, z = coords.z, w = (GetEntityHeading(Gc.ped()) + 180.0) % 360.0 }
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
            local here = GetEntityCoords(Gc.ped())
            for _, pt in ipairs(Gc.points) do
                if #(here - vec3(pt.x, pt.y, pt.z)) < 120.0 then
                    DrawMarker(1, pt.x, pt.y, pt.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 0.15, 245, 165, 36, 110, false, false, 2, false, nil, nil, false)
                    text3d(pt.x, pt.y, pt.z + 1.6, ('#%d %s'):format(pt.id, pt.label))
                end
            end
            Wait(0)
        end
    end)
end

local function refresh()
    local list = lib.callback.await(Gc.name('points'), false)
    if type(list) == 'table' then Gc.points = list end
end

local function kindOptions()
    local out = {}
    for key, cfg in pairs(Config.Kinds) do
        if not cfg.models then out[#out + 1] = { value = key, label = cfg.label } end
    end
    table.sort(out, function(a, b) return a.label < b.label end)
    return out
end

local function manage(pt)
    local cfg = Config.Kinds[pt.kind]
    local options = {
        { title = 'Rename', description = pt.label, icon = 'fa-solid fa-pen', onSelect = function()
            local input = lib.inputDialog('Name', { { type = 'input', label = 'Name', default = pt.label, required = true, max = 48 } })
            if input and input[1] then
                local ok, err = admin('set', { id = pt.id, patch = { label = tostring(input[1]) } })
                if not ok then problem(err) end
                refresh()
            end
            menu()
        end },
        { title = 'Change kind', description = cfg and cfg.label or pt.kind, icon = 'fa-solid fa-shuffle', onSelect = function()
            local input = lib.inputDialog('Kind', { { type = 'select', label = 'Kind', options = kindOptions(), default = pt.kind, required = true } })
            if input and input[1] then
                local ok, err = admin('set', { id = pt.id, patch = { kind = tostring(input[1]) } })
                if not ok then problem(err) end
                refresh()
            end
            menu()
        end },
        { title = 'Move to where I aim', icon = 'fa-solid fa-arrows-up-down-left-right', onSelect = function()
            local at = aim()
            if at then
                local ok, err = admin('move', { id = pt.id, at = at })
                if not ok then problem(err) end
                refresh()
            end
            menu()
        end },
        { title = 'Go there', icon = 'fa-solid fa-person-walking-arrow-right', onSelect = function()
            SetEntityCoords(Gc.ped(), pt.x, pt.y, pt.z + 0.5, false, false, false, false)
            menu()
        end },
        { title = 'Remove', icon = 'fa-solid fa-trash', iconColor = '#ef4444', onSelect = function()
            local sure = lib.alertDialog({ header = 'Remove this point?', content = ('#%d %s'):format(pt.id, pt.label), centered = true, cancel = true })
            if sure == 'confirm' then
                local ok, err = admin('remove', { id = pt.id })
                if not ok then problem(err) end
                refresh()
            end
            menu()
        end },
    }
    lib.registerContext({ id = RES .. ':point', title = ('#%d %s'):format(pt.id, pt.label), menu = RES .. ':admin', options = options, onExit = function() open = false end })
    lib.showContext(RES .. ':point')
end

local function add()
    local input = lib.inputDialog('Add a point', { { type = 'select', label = 'What kind', options = kindOptions(), required = true } })
    if not input or not input[1] then return menu() end
    local at = aim()
    if not at then return menu() end
    local ok, err = admin('add', { kind = tostring(input[1]), at = at })
    if not ok then problem(err) else Gc.notify('Placed. Open it in the list to rename it.', 'success') end
    refresh()
    menu()
end

menu = function()
    refresh()
    local here = GetEntityCoords(Gc.ped())
    local rows = {}
    for _, pt in ipairs(Gc.points) do rows[#rows + 1] = { pt = pt, d = #(here - vec3(pt.x, pt.y, pt.z)) } end
    table.sort(rows, function(a, b) return a.d < b.d end)
    local options = { { title = 'Add a point', description = 'Pick the kind, then aim where it goes', icon = 'fa-solid fa-plus', onSelect = add } }
    for i = 1, math.min(#rows, 25) do
        local pt = rows[i].pt
        local cfg = Config.Kinds[pt.kind]
        options[#options + 1] = {
            title = ('#%d %s'):format(pt.id, pt.label),
            description = ('%s · %dm away'):format(cfg and cfg.label or pt.kind, math.floor(rows[i].d)),
            icon = cfg and cfg.icon or 'fa-solid fa-location-dot',
            onSelect = function() manage(pt) end,
        }
    end
    lib.registerContext({ id = RES .. ':admin', title = Config.Title, options = options, onExit = function() open = false end })
    lib.showContext(RES .. ':admin')
end

RegisterCommand(Config.AdminCommand, function()
    if not lib.callback.await(Gc.name('isAdmin'), false) then return end
    if open then return end
    open = true
    preview()
    menu()
end, false)
