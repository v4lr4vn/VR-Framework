lib.callback.register('vr-dealership:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

RegisterNetEvent('vr-dealership:server:duty', function(on)
    local src = source
    local info = Core.info(src)
    if not info or info.job.name ~= Config.Job then return end
    local near = false
    for _, d in pairs(Dealers.list) do
        if Dealers.near(d, src) then near = true break end
    end
    if not near then return end
    if not Core.setDuty(src, on == true) then return end
    Core.notify(src, on and 'You are on the sales floor' or 'You are off duty', 'inform', 'Sales')
end)

Db.onReady(function()
    Dealers.load()
    local n, over = 0, 0
    for _ in pairs(Dealers.list) do n = n + 1 end
    for _ in pairs(Dealers.custom()) do over = over + 1 end
    print(('^2[vr-dealership] ready: %d dealerships (%d with locations saved in the database). Run /dealercheck to test the setup.^0'):format(n, over))
    while true do
        Wait(1000)
        local ok, err = pcall(TestDrive.tick)
        if not ok then print(('^1[vr-dealership] test drive: %s^0'):format(tostring(err))) end
    end
end)

local function reply(src, text, kind)
    if src > 0 then Core.notify(src, text, kind) else print(('[vr-dealership] %s'):format(text)) end
end

local function here(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local p = GetEntityCoords(ent)
    return vec4(p.x, p.y, p.z, GetEntityHeading(ent))
end

local POINTS = { kiosk = true, delivery = true, testdrive = 'testDrive', ['return'] = 'returnPoint', preview = true, center = true }

local function allowed(src)
    return src == 0 or Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.dealer')
end

local function fmt(n) return ('%.2f'):format(n) end

local function exportBlock(d)
    local lines = { ('    %s = {'):format(d.id), ('        label = %q,'):format(d.label or d.id), ('        shop = %q,'):format(d.shop or d.id) }
    lines[#lines + 1] = ('        center = vec3(%s, %s, %s),'):format(fmt(d.center.x), fmt(d.center.y), fmt(d.center.z))
    lines[#lines + 1] = ('        radius = %s,'):format(fmt(d.radius))
    for _, k in ipairs({ 'kiosk', 'returnPoint' }) do
        local c = d[k]
        if c then lines[#lines + 1] = ('        %s = vec3(%s, %s, %s),'):format(k, fmt(c.x), fmt(c.y), fmt(c.z)) end
    end
    for _, k in ipairs({ 'delivery', 'testDrive', 'preview' }) do
        local c = d[k]
        if c then lines[#lines + 1] = ('        %s = vec4(%s, %s, %s, %s),'):format(k, fmt(c.x), fmt(c.y), fmt(c.z), fmt(c.w)) end
    end
    lines[#lines + 1] = ('        garage = %q,'):format(d.garage or Config.DefaultGarage)
    if d.blip then lines[#lines + 1] = ('        blip = { sprite = %d, colour = %d },'):format(d.blip.sprite or 326, d.blip.colour or 3) end
    lines[#lines + 1] = '        display = {'
    for _, s in ipairs(d.display) do
        lines[#lines + 1] = ('            { coords = vec4(%s, %s, %s, %s), model = %q },'):format(fmt(s.coords.x), fmt(s.coords.y), fmt(s.coords.z), fmt(s.coords.w), s.model)
    end
    lines[#lines + 1] = '        },'
    lines[#lines + 1] = '    },'
    return table.concat(lines, '\n')
end

RegisterCommand('dealer', function(src, args)
    if not allowed(src) then return reply(src, 'You are not allowed to use /dealer', 'error') end
    local sub, id = (args[1] or ''):lower(), args[2]
    local d = id and Dealers.get(id)
    if sub == 'list' then
        local ids = {}
        for k, v in pairs(Dealers.list) do ids[#ids + 1] = ('%s (%s, %d display spots)'):format(k, v.shop, #v.display) end
        table.sort(ids)
        return reply(src, table.concat(ids, ', '), 'inform')
    end
    if not d then return reply(src, 'Usage: /dealer [kiosk|delivery|testdrive|return|preview|center|radius|display|cleardisplay|export|list] [dealer id]', 'inform') end
    if sub == 'export' then
        local block = exportBlock(d)
        local file = ('exports/%s.lua'):format(d.id)
        local saved = SaveResourceFile(GetCurrentResourceName(), file, block .. '\n', -1)
        print(('^3[vr-dealership] config block for %s, paste it into Config.Dealers in config.lua:^0\n%s'):format(d.id, block))
        return reply(src, saved and ('Wrote %s in the vr-dealership folder and printed it in the server console. Paste it into config.lua to keep it in your repo.'):format(file) or 'Printed the config block in the server console', 'success')
    end
    local pos = here(src)
    if not pos then return end
    local copy = {}
    for k, v in pairs(d) do copy[k] = v end
    if POINTS[sub] then
        local key = POINTS[sub] == true and sub or POINTS[sub]
        copy[key] = (key == 'kiosk' or key == 'returnPoint' or key == 'center') and vec3(pos.x, pos.y, pos.z) or pos
    elseif sub == 'radius' then
        copy.radius = math.max(5, math.min(80, tonumber(args[3]) or copy.radius)) + 0.0
    elseif sub == 'display' then
        local slots = {}
        for i, s in ipairs(d.display) do slots[i] = s end
        slots[#slots + 1] = { coords = vec4(pos.x, pos.y, pos.z - 1.0, pos.w), model = args[3] or 'adder' }
        copy.display = slots
    elseif sub == 'cleardisplay' then
        copy.display = {}
    else
        return reply(src, 'Unknown option', 'error')
    end
    Dealers.save(d.id, copy)
    reply(src, ('Updated %s %s. Saved in the database of this server only, use /dealer export %s to put it in config.lua.'):format(d.id, sub, d.id), 'success')
end, false)

local function line(out, ok, text)
    out[#out + 1] = { ok = ok, text = text }
end

RegisterCommand('dealercheck', function(src)
    if not allowed(src) then return reply(src, 'You are not allowed to use /dealercheck', 'error') end
    local out = {}
    line(out, Db.ready, Db.ready and 'Database connected' or 'Database NOT ready: the dealerships never loaded. Check vr-mysql/oxmysql and the connection string')
    if Db.ready then
        local names = { 'vr_dealership_locations', 'vr_dealership_display', 'vr_dealership_sales', 'player_vehicles' }
        for _, t in ipairs(names) do
            local ok, rows = pcall(MySQL.query.await, 'SELECT COUNT(*) AS n FROM information_schema.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?', { t })
            local has = ok and rows and rows[1] and tonumber(rows[1].n) == 1
            line(out, has, ('Table %s %s'):format(t, has and 'exists' or 'is MISSING'))
        end
        local ok, rows = pcall(MySQL.query.await, 'SELECT COUNT(*) AS n FROM vr_dealership_locations')
        line(out, ok, ok and ('%d dealership overrides saved in the database (the rest come from config.lua)'):format(rows and rows[1] and rows[1].n or 0) or 'Could not read vr_dealership_locations')
    end
    local nd = 0
    for _ in pairs(Dealers.list) do nd = nd + 1 end
    line(out, nd > 0, ('%d dealerships loaded'):format(nd))
    line(out, GetResourceState('vr-garages') == 'started', 'vr-garages is ' .. GetResourceState('vr-garages'))
    line(out, true, 'vr-banking is ' .. GetResourceState('vr-banking') .. ' (only needed for finance)')
    local okPlate, plate = pcall(function() return exports['vr-garages']:GeneratePlate() end)
    line(out, okPlate and plate ~= nil, okPlate and plate and 'vr-garages can make plates' or 'vr-garages GeneratePlate failed')
    local total = 0
    for _ in pairs(Core.vehicles() or {}) do total = total + 1 end
    line(out, total > 0, ('%d vehicles known to the framework'):format(total))
    line(out, Core.isJob(Config.Job), ('Job %q %s'):format(Config.Job, Core.isJob(Config.Job) and 'exists' or 'does NOT exist (commissions and society income are skipped)'))
    line(out, true, ('Self service is %s (%d salespeople on duty)'):format(Sales.selfServiceOpen() and 'OPEN' or 'closed', Core.staffOnDuty()))
    local pos = src > 0 and Core.coords(src) or nil
    if src > 0 and not pos then
        line(out, false, 'The server can not read your position. OneSync must be enabled (set onesync on), buying needs it')
    end
    local ids = {}
    for id in pairs(Dealers.list) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local d = Dealers.list[id]
        local items = #Dealers.catalogue(d)
        local where = ''
        if pos then
            local dist = #(pos - d.center)
            where = (', you are %.0fm away (%s)'):format(dist, dist <= d.radius + 4.0 and 'inside' or 'outside, buying needs inside')
        end
        line(out, items > 0, ('%s: %d vehicles for sale, centre %.1f %.1f %.1f radius %.0fm%s'):format(id, items, d.center.x, d.center.y, d.center.z, d.radius, where))
    end
    for _, r in ipairs(out) do print(('%s[vr-dealership] %s%s'):format(r.ok and '^2' or '^1', r.text, '^0')) end
    if src > 0 then
        local bad = 0
        for _, r in ipairs(out) do if not r.ok then bad = bad + 1 end end
        reply(src, bad == 0 and 'Dealership setup looks fine. Details are in the server console.' or ('%d problem(s) found: %s'):format(bad, (function() for _, r in ipairs(out) do if not r.ok then return r.text end end end)()), bad == 0 and 'success' or 'error')
    end
end, false)
