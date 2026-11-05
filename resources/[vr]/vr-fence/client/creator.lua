local COLOUR = { launder = { 61, 214, 140 }, pawn = { 255, 200, 92 } }
local KIND_LABEL = { launder = 'Laundering contact', pawn = 'Pawn shop' }
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

function Fc.rayCamera(flags, distance)
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
        local hit, _, coords = Fc.rayCamera(1 | 2 | 16, 60.0)
        if hit and coords then
            DrawMarker(1, coords.x, coords.y, coords.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.8, 0.8, 0.12, colour[1], colour[2], colour[3], 120, false, false, 2, false, nil, nil, false)
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 1.8, colour[1], colour[2], colour[3], 220)
            if IsDisabledControlJustPressed(0, 24) then
                out = { x = coords.x, y = coords.y, z = coords.z, w = (GetEntityHeading(Fc.ped()) + 180.0) % 360.0 }
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
            local here = GetEntityCoords(Fc.ped())
            for _, spot in ipairs(Fc.spots) do
                local d = #(here - vec3(spot.x, spot.y, spot.z))
                if d < 80.0 then
                    local c = COLOUR[spot.kind] or { 255, 255, 255 }
                    DrawMarker(1, spot.x, spot.y, spot.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 0.15, c[1], c[2], c[3], 110, false, false, 2, false, nil, nil, false)
                    text3d(spot.x, spot.y, spot.z + 2.0, ('#%d %s'):format(spot.id, spot.label))
                end
            end
            Wait(0)
        end
    end)
end

local function admin(action, data)
    local res = lib.callback.await('vr-fence:admin', false, action, data)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error
end

local ADMIN_ERRORS = {
    not_admin = 'Admins only',
    not_found = 'That spot is gone',
    limit = 'Too many spots',
    bad_value = 'That value is not allowed',
    bad_kind = 'Unknown kind',
}

local function problem(code)
    Fc.notify(ADMIN_ERRORS[code] or Fc.text(code), 'error')
end

local menu

local function manage(spot)
    local id = ('vr-fence:spot:%d'):format(spot.id)
    lib.registerContext({
        id = id,
        title = ('#%d %s'):format(spot.id, spot.label),
        menu = 'vr-fence:admin',
        onExit = function() open = false end,
        options = {
            {
                title = 'Go there', icon = 'fa-solid fa-location-arrow',
                onSelect = function()
                    SetPedCoordsKeepVehicle(Fc.ped(), spot.x, spot.y, spot.z + 1.0)
                end,
            },
            {
                title = 'Aim and move', icon = 'fa-solid fa-crosshairs',
                onSelect = function()
                    local at = aim(spot.kind)
                    if at then
                        local ok, err = admin('move', { id = spot.id, at = at })
                        if not ok then problem(err) else Fc.notify('Moved', 'success') end
                    end
                    menu()
                end,
            },
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
            {
                title = 'Person model', description = spot.ped or 'none', icon = 'fa-solid fa-user',
                onSelect = function()
                    local input = lib.inputDialog('Person model', { { type = 'input', label = 'Ped model, empty for nobody', default = spot.ped or '', max = 48 } })
                    if input then
                        local ok, err = admin('set', { id = spot.id, patch = { ped = input[1] or '' } })
                        if not ok then problem(err) end
                    end
                    menu()
                end,
            },
            {
                title = spot.kind == 'launder' and 'Return rate' or 'Price multiplier',
                description = spot.rate and tostring(spot.rate) or 'default from the config',
                icon = 'fa-solid fa-percent',
                onSelect = function()
                    local input = lib.inputDialog('Rate', { { type = 'number', label = '0.05 to 1.5, 0 for the config default', default = spot.rate or 0, min = 0, max = 1.5, precision = 2 } })
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
                    local sure = lib.alertDialog({ header = 'Remove this spot?', content = spot.label, centered = true, cancel = true })
                    if sure == 'confirm' then
                        local ok, err = admin('remove', { id = spot.id })
                        if not ok then problem(err) else Fc.notify('Removed', 'success') end
                    end
                    menu()
                end,
            },
        },
    })
    lib.showContext(id)
end

local function add(kind)
    local at = aim(kind)
    if not at then return menu() end
    local ok, data = admin('add', { kind = kind, at = at })
    if not ok then problem(data) else Fc.notify(('%s placed. Open Manage to name it and set the person'):format(KIND_LABEL[kind]), 'success') end
    menu()
end

menu = function()
    local here = GetEntityCoords(Fc.ped())
    local rows = {}
    for _, spot in ipairs(Fc.spots) do rows[#rows + 1] = { spot = spot, d = #(here - vec3(spot.x, spot.y, spot.z)) } end
    table.sort(rows, function(a, b) return a.d < b.d end)
    local options = {
        { title = 'Add a laundering contact', description = 'Aim where they stand', icon = 'fa-solid fa-money-bill-transfer', onSelect = function() add('launder') end },
        { title = 'Add a pawn shop', description = 'Aim where the counter is', icon = 'fa-solid fa-gem', onSelect = function() add('pawn') end },
    }
    for i = 1, math.min(#rows, 25) do
        local spot = rows[i].spot
        options[#options + 1] = {
            title = ('#%d %s'):format(spot.id, spot.label),
            description = ('%s · %dm away'):format(KIND_LABEL[spot.kind], math.floor(rows[i].d)),
            icon = 'fa-solid fa-location-dot',
            onSelect = function() manage(spot) end,
        }
    end
    lib.registerContext({ id = 'vr-fence:admin', title = 'Fence spots', options = options, onExit = function() open = false end })
    lib.showContext('vr-fence:admin')
end

RegisterCommand(Config.Admin.command, function()
    if not lib.callback.await('vr-fence:isAdmin', false) then return end
    if open then return end
    open = true
    preview()
    menu()
end, false)
