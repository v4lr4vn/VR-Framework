-- /restaurantcreator: place restaurants, choose owners and the wage limit, set the price and
-- licence length, and place the crafting areas for each business.

local ROOT = 'vr-restaurant:admin'
local open = false

local function admin(action, data)
    local ok, res, extra = Rn.call('admin', action, data)
    if not ok then
        Rn.fail(res, extra)
        return false
    end
    return true, res
end

local function here()
    local ped = cache.ped or PlayerPedId()
    local c = GetEntityCoords(ped)
    return { x = c.x, y = c.y, z = c.z, w = GetEntityHeading(ped) }
end

local COLOUR = {
    prep = { 255, 200, 92 }, grill = { 255, 120, 60 }, fryer = { 255, 170, 60 }, oven = { 255, 90, 90 }, hob = { 255, 140, 90 },
    bar = { 200, 120, 255 }, brew = { 170, 130, 60 }, fridge = { 90, 200, 255 }, till = { 120, 220, 120 }, counter = { 120, 220, 200 },
    clean = { 90, 170, 255 },
}

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

local function kindLabel(id)
    for _, k in ipairs(Config.Stations) do
        if k.id == id then return k.label end
    end
    return id
end

-- The aim ray is cast by a small poller thread so the markers draw every frame without flashing.
local RAY = { running = false, stamp = 0, hit = false, coords = nil }

local function ray(distance)
    RAY.stamp = GetGameTimer()
    if not RAY.running then
        RAY.running, RAY.hit, RAY.coords = true, false, nil
        CreateThread(function()
            while GetGameTimer() - RAY.stamp < 500 do
                local hit, _, coords = lib.raycast.fromCamera(1 | 2 | 16, 4, distance)
                RAY.hit, RAY.coords = hit and true or false, coords
                Wait(0)
            end
            RAY.running, RAY.hit, RAY.coords = false, false, nil
        end)
    end
    return RAY.hit, RAY.coords
end

local MIN_RADIUS, MAX_RADIUS = 0.3, 6.0

-- Point the camera where the area should go and click, like the heist creator.
-- Scroll wheel changes the size (hold Shift for bigger steps). Returns the spot and the radius.
local function aim(kind, radius)
    local c = COLOUR[kind] or { 255, 255, 255 }
    radius = math.max(MIN_RADIUS, math.min(MAX_RADIUS, (tonumber(radius) or 1.5) + 0.0))
    pcall(lib.hideContext, false)
    local function help()
        lib.showTextUI(('[Left click] Place   [Right click] Cancel   [Scroll] Size: %.1f m   [Shift + scroll] Big steps'):format(radius), { icon = 'crosshairs' })
    end
    help()
    local deadline = GetGameTimer() + 600
    while IsDisabledControlPressed(0, 24) and GetGameTimer() < deadline do Wait(0) end
    Wait(150)
    local out
    while true do
        DisablePlayerFiring(PlayerId(), true)
        for _, ctl in ipairs({ 14, 15, 16, 17, 24, 25, 37, 44, 140, 141, 142, 241, 242, 257, 263, 264 }) do DisableControlAction(0, ctl, true) end
        local step = IsDisabledControlPressed(0, 21) and 0.5 or 0.1
        local before = radius
        if IsDisabledControlJustPressed(0, 241) or IsDisabledControlJustPressed(0, 15) then radius = radius + step end
        if IsDisabledControlJustPressed(0, 242) or IsDisabledControlJustPressed(0, 14) then radius = radius - step end
        radius = math.floor(math.max(MIN_RADIUS, math.min(MAX_RADIUS, radius)) * 10 + 0.5) / 10
        if radius ~= before then help() end
        local hit, coords = ray(60.0)
        if hit and coords then
            local d = radius * 2.0
            DrawMarker(1, coords.x, coords.y, coords.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, 0.12, c[1], c[2], c[3], 110, false, false, 2, false, nil, nil, false)
            DrawLine(coords.x, coords.y, coords.z, coords.x, coords.y, coords.z + 1.8, c[1], c[2], c[3], 220)
            text3d(coords.x, coords.y, coords.z + 2.0, ('%s · %.1f m'):format(kindLabel(kind), radius))
            if IsDisabledControlJustPressed(0, 24) then
                out = { x = coords.x, y = coords.y, z = coords.z, w = (GetEntityHeading(cache.ped or PlayerPedId()) + 180.0) % 360.0 }
                break
            end
        end
        if IsDisabledControlJustPressed(0, 25) or IsControlJustPressed(0, 200) then break end
        Wait(0)
    end
    lib.hideTextUI()
    return out, radius
end

local previewing = false
local function preview()
    if previewing then return end
    previewing = true
    CreateThread(function()
        while open do
            local here = GetEntityCoords(cache.ped or PlayerPedId())
            for _, s in ipairs(Rn.stations or {}) do
                if #(here - vec3(s.x, s.y, s.z)) < 80.0 then
                    local c = COLOUR[s.kind] or { 255, 255, 255 }
                    local d = s.radius * 2.0
                    DrawMarker(1, s.x, s.y, s.z - 0.02, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, d, d, 0.12, c[1], c[2], c[3], 90, false, false, 2, false, nil, nil, false)
                    DrawLine(s.x, s.y, s.z, s.x, s.y, s.z + 1.5, c[1], c[2], c[3], 220)
                    text3d(s.x, s.y, s.z + 1.7, ('#%d %s%s'):format(s.id, kindLabel(s.kind), s.label ~= '' and (' · ' .. s.label) or ''))
                end
            end
            Wait(0)
        end
        previewing = false
    end)
end

local function stations(action, data)
    local ok, res, extra = Rn.call('adminStations', action, data)
    if not ok then
        Rn.fail(res, extra)
        return false
    end
    return true, res
end

local menu
local stationMenu

local function compact(list)
    local out = {}
    for _, v in ipairs(list) do
        if v then out[#out + 1] = v end
    end
    return out
end

local function stationOptions()
    local out = {}
    for _, k in ipairs(Config.Stations) do
        out[#out + 1] = { label = k.label, value = k.id }
    end
    return out
end

local function stationDetail(b, s)
    local id = ('%s:%d:station:%d'):format(ROOT, b.id, s.id)
    lib.registerContext({
        id = id,
        title = ('#%d %s'):format(s.id, s.kindLabel),
        menu = ('%s:%d:stations'):format(ROOT, b.id),
        onExit = function() open = false end,
        options = {
            {
                title = s.kindLabel .. (s.label ~= '' and (' · ' .. s.label) or ''),
                description = ('Radius %.1f · %d%% dirty'):format(s.radius, math.floor(tonumber(s.dirt) or 0)),
                icon = 'fa-solid fa-kitchen-set', readOnly = true,
            },
            {
                title = 'Go there', icon = 'fa-solid fa-location-arrow',
                onSelect = function() SetPedCoordsKeepVehicle(cache.ped or PlayerPedId(), s.x, s.y, s.z + 1.0) stationMenu(b) end,
            },
            {
                title = 'Move it', description = 'Aim and click to place it somewhere else', icon = 'fa-solid fa-up-down-left-right',
                onSelect = function()
                    local at, size = aim(s.kind, s.radius)
                    if at then
                        if stations('move', { id = s.id, at = at, radius = size }) then Rn.notify('Moved', 'success') end
                    end
                    stationMenu(b)
                end,
            },
            {
                title = 'Name and size', icon = 'fa-solid fa-pen',
                onSelect = function()
                    local input = lib.inputDialog('Crafting area', {
                        { type = 'select', label = 'Kind', options = stationOptions(), default = s.kind, required = true },
                        { type = 'input', label = 'Label (optional)', default = s.label, max = 32 },
                        { type = 'number', label = 'Radius in metres (0.3 to 6)', default = s.radius, min = 0.3, max = 6.0, precision = 1, required = true },
                    })
                    if input then stations('set', { id = s.id, patch = { kind = input[1], label = input[2] or '', radius = input[3] } }) end
                    stationMenu(b)
                end,
            },
            {
                title = 'Remove it', icon = 'fa-solid fa-trash',
                onSelect = function()
                    if lib.alertDialog({ header = 'Remove crafting area', content = ('Remove %s #%d?'):format(s.kindLabel, s.id), centered = true, cancel = true }) == 'confirm' then
                        stations('remove', { id = s.id })
                    end
                    stationMenu(b)
                end,
            },
        },
    })
    lib.showContext(id)
end

function stationMenu(b)
    local ok, res = stations('list', { business = b.id })
    if not ok then open = false return end
    local me = GetEntityCoords(cache.ped or PlayerPedId())
    local id = ('%s:%d:stations'):format(ROOT, b.id)
    local options = {
        {
            title = 'Add a crafting area', description = ('%d of %d placed. Aim, scroll to size, click'):format(#res.list, Config.MaxStations), icon = 'fa-solid fa-plus',
            onSelect = function()
                local input = lib.inputDialog('New crafting area', {
                    { type = 'select', label = 'Kind', options = stationOptions(), required = true },
                    { type = 'input', label = 'Label (optional)', max = 32 },
                })
                if not input then return stationMenu(b) end
                local kind
                for _, k in ipairs(Config.Stations) do if k.id == input[1] then kind = k end end
                local at, size = aim(input[1], kind and kind.radius or 1.5)
                if at then
                    local added = stations('add', { business = b.id, kind = input[1], label = input[2] or '', at = at, radius = size })
                    if added then Rn.notify('Crafting area placed', 'success') end
                end
                stationMenu(b)
            end,
        },
    }
    local rows = {}
    for _, s in ipairs(res.list) do
        rows[#rows + 1] = { s = s, d = #(me - vec3(s.x, s.y, s.z)) }
    end
    table.sort(rows, function(a, c) return a.d < c.d end)
    for i = 1, math.min(#rows, 30) do
        local s = rows[i].s
        options[#options + 1] = {
            title = ('#%d %s%s'):format(s.id, s.kindLabel, s.label ~= '' and (' · ' .. s.label) or ''),
            description = ('%dm away · radius %.1f'):format(math.floor(rows[i].d), s.radius),
            icon = 'fa-solid fa-kitchen-set',
            onSelect = function() stationDetail(b, s) end,
        }
    end
    lib.registerContext({ id = id, title = ('Crafting areas · %s'):format(b.label), menu = ('%s:%d'):format(ROOT, b.id), options = options, onExit = function() open = false end })
    lib.showContext(id)
end

local function manage(b)
    local id = ('%s:%d'):format(ROOT, b.id)
    lib.registerContext({
        id = id,
        title = ('#%d %s'):format(b.id, b.label),
        menu = ROOT,
        onExit = function() open = false end,
        options = compact({
            {
                title = b.owner and ('Owner: %s'):format(b.owner) or 'No owner yet',
                description = ('%d staff · account %s · owner wage %s of %s'):format(b.staff, Rn.money(b.balance), Rn.money(b.ownerWage), Rn.money(b.maxWage)),
                icon = 'fa-solid fa-store', readOnly = true,
            },
            {
                title = ('Crafting areas (%d)'):format(b.stations or 0), description = 'Place the cooking, bar, till and cleaning spots for this business', icon = 'fa-solid fa-kitchen-set',
                onSelect = function() stationMenu(b) end,
            },
            {
                title = 'Price and licence', icon = 'fa-solid fa-tags',
                description = ('%s · licence lasts %d days (%d to %d allowed). A price of 0 means it is not for sale'):format(Rn.money(b.price or 0), b.licenceDays or Config.Licence.defaultDays, Config.Licence.minDays, Config.Licence.maxDays),
                onSelect = function()
                    local input = lib.inputDialog('Price and licence', {
                        { type = 'number', label = 'Price at City Hall (0 = not for sale)', default = b.price or 0, min = 0, required = true },
                        { type = 'number', label = ('Real days a licence lasts (%d to %d)'):format(Config.Licence.minDays, Config.Licence.maxDays), default = b.licenceDays or Config.Licence.defaultDays, min = Config.Licence.minDays, max = Config.Licence.maxDays, required = true },
                    })
                    if input then
                        local ok = admin('set', { id = b.id, patch = { price = input[1], licenceDays = input[2] } })
                        if ok then Rn.notify('Saved', 'success') end
                    end
                    menu()
                end,
            },
            {
                title = 'Go there', icon = 'fa-solid fa-location-arrow',
                onSelect = function() SetPedCoordsKeepVehicle(cache.ped or PlayerPedId(), b.x, b.y, b.z + 1.0) end,
            },
            {
                title = 'Set the owner', description = 'Type the server id of the player', icon = 'fa-solid fa-crown',
                onSelect = function()
                    local input = lib.inputDialog('Owner', { { type = 'number', label = 'Server id of the new owner', min = 1, required = true } })
                    if input then
                        local ok = admin('set', { id = b.id, patch = { owner = input[1] } })
                        if ok then Rn.notify('Owner set', 'success') end
                    end
                    menu()
                end,
            },
            b.owner and {
                title = 'Remove the owner', icon = 'fa-solid fa-user-slash',
                onSelect = function()
                    if lib.alertDialog({ header = 'Remove the owner', content = 'The restaurant keeps its staff and money.', centered = true, cancel = true }) == 'confirm' then
                        admin('set', { id = b.id, patch = { owner = false } })
                    end
                    menu()
                end,
            } or false,
            {
                title = 'Name and wage limit', description = ('The owner can earn up to %s each payday, and no rank can earn more than the owner'):format(Rn.money(b.maxWage)), icon = 'fa-solid fa-pen',
                onSelect = function()
                    local input = lib.inputDialog('Restaurant', {
                        { type = 'input', label = 'Name', default = b.label, required = true, max = 48 },
                        { type = 'number', label = 'Most the owner can earn each payday', default = b.maxWage, min = 0, required = true },
                    })
                    if input then admin('set', { id = b.id, patch = { label = input[1], maxWage = input[2] } }) end
                    menu()
                end,
            },
            {
                title = 'Move the office here', description = 'Stand where the staff office target should be', icon = 'fa-solid fa-crosshairs',
                onSelect = function()
                    if admin('move', { id = b.id, at = here() }) then Rn.notify('Moved', 'success') end
                    menu()
                end,
            },
            {
                title = 'Remove this restaurant', description = 'Deletes its ranks and staff list', icon = 'fa-solid fa-trash',
                onSelect = function()
                    if lib.alertDialog({ header = 'Remove ' .. b.label, content = ('This deletes the restaurant, its ranks and its staff list.\n\nThe account holds %s.'):format(Rn.money(b.balance)), centered = true, cancel = true }) == 'confirm' then
                        local ok, res = admin('remove', { id = b.id })
                        if ok then Rn.notify(('Removed. %s was left in the account'):format(Rn.money(res.balance)), 'success') end
                    end
                    menu()
                end,
            },
        }),
    })
    lib.showContext(id)
end

function menu()
    local ok, res = admin('list', {})
    if not ok then open = false return end
    local me = GetEntityCoords(cache.ped or PlayerPedId())
    local rows = {}
    for _, b in ipairs(res.list) do
        local dx, dy = b.x - me.x, b.y - me.y
        rows[#rows + 1] = { b = b, d = math.sqrt(dx * dx + dy * dy) }
    end
    table.sort(rows, function(a, c) return a.d < c.d end)
    local options = {
        {
            title = 'Add a restaurant here', description = 'Stand where the staff office target should be', icon = 'fa-solid fa-plus',
            onSelect = function()
                local input = lib.inputDialog('New restaurant', {
                    { type = 'input', label = 'Name', required = true, max = 48 },
                    { type = 'number', label = 'Most the owner can earn each payday', default = Config.Business.defaultMaxWage, min = 0, required = true },
                    { type = 'number', label = 'Price at City Hall (0 = not for sale yet)', default = 0, min = 0, required = true },
                    { type = 'number', label = ('Real days a licence lasts (%d to %d)'):format(Config.Licence.minDays, Config.Licence.maxDays), default = Config.Licence.defaultDays, min = Config.Licence.minDays, max = Config.Licence.maxDays, required = true },
                })
                if input then
                    local added = admin('add', { label = input[1], maxWage = input[2], price = input[3], licenceDays = input[4], at = here() })
                    if added then Rn.notify('Restaurant added. Open it from the list to set the crafting areas, price or an owner', 'success') end
                end
                menu()
            end,
        },
    }
    for i = 1, math.min(#rows, 25) do
        local b = rows[i].b
        options[#options + 1] = {
            title = ('#%d %s'):format(b.id, b.label),
            description = ('%dm away · %s · %s'):format(math.floor(rows[i].d), b.owner and ('owner %s'):format(b.owner) or ((b.price or 0) > 0 and ('for sale %s'):format(Rn.money(b.price)) or 'no owner, not for sale'), b.status == 'revoked' and 'shut down' or ('%d areas'):format(b.stations or 0)),
            icon = 'fa-solid fa-store',
            onSelect = function() manage(b) end,
        }
    end
    lib.registerContext({ id = ROOT, title = 'Restaurants', options = options, onExit = function() open = false end })
    lib.showContext(ROOT)
end

RegisterNetEvent('vr-restaurant:client:creator', function()
    if open then return end
    if not lib.callback.await('vr-restaurant:isAdmin', false) then return end
    open = true
    preview()
    menu()
end)
