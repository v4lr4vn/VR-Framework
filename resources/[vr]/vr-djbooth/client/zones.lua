local drawing = false
local showing = {}

local function drawZone(points, minZ, maxZ, r, g, b)
    for i = 1, #points do
        local a, c = points[i], points[i % #points + 1]
        DrawLine(a.x, a.y, minZ, c.x, c.y, minZ, r, g, b, 255)
        DrawLine(a.x, a.y, maxZ, c.x, c.y, maxZ, r, g, b, 255)
        DrawLine(a.x, a.y, minZ, a.x, a.y, maxZ, r, g, b, 160)
    end
end

CreateThread(function()
    while true do
        if next(showing) then
            Wait(0)
            for _, z in ipairs(Zones) do
                if showing[z.key] then drawZone(z.points, z.minZ, z.maxZ, 140, 110, 255) end
            end
        else
            Wait(500)
        end
    end
end)

local function drawNewZone()
    local points, zs = {}, {}
    drawing = true
    lib.showTextUI('[E] Add corner  [Backspace] Undo  [Enter] Finish  [X] Cancel')
    local finished = false
    while drawing do
        Wait(0)
        DisableControlAction(0, 38, true)
        DisableControlAction(0, 177, true)
        DisableControlAction(0, 191, true)
        DisableControlAction(0, 73, true)
        local here = GetEntityCoords(cache.ped)
        local z = here.z - 1.0
        if #points > 0 then
            local temp = { table.unpack(points) }
            temp[#temp + 1] = { x = here.x, y = here.y }
            local lo, hi = math.huge, -math.huge
            for _, v in ipairs(zs) do lo, hi = math.min(lo, v), math.max(hi, v) end
            lo, hi = math.min(lo, z), math.max(hi, z)
            drawZone(temp, lo, hi + 4.0, 80, 220, 140)
        end
        DrawMarker(1, here.x, here.y, z, 0, 0, 0, 0, 0, 0, 0.4, 0.4, 0.6, 80, 220, 140, 160, false, false, 2, false, nil, nil, false)
        if IsDisabledControlJustPressed(0, 38) then
            points[#points + 1] = { x = here.x, y = here.y }
            zs[#zs + 1] = z
        elseif IsDisabledControlJustPressed(0, 177) and #points > 0 then
            points[#points] = nil
            zs[#zs] = nil
        elseif IsDisabledControlJustPressed(0, 191) then
            if #points >= 3 then
                finished = true
                drawing = false
            else
                Notify('Add at least 3 corners.', 'error')
            end
        elseif IsDisabledControlJustPressed(0, 73) then
            drawing = false
        end
    end
    lib.hideTextUI()
    if not finished then return nil end
    local lo, hi = math.huge, -math.huge
    for _, v in ipairs(zs) do lo, hi = math.min(lo, v), math.max(hi, v) end
    return points, lo, hi
end

local function createZone()
    local input = lib.inputDialog('New business area', {
        { type = 'input', label = 'Name', placeholder = "Benny's", required = true, max = 48 },
        { type = 'input', label = 'Job', description = 'The job name in vr-core, e.g. bennys', required = true },
        { type = 'number', label = 'Max speakers', default = Config.Limits.perBusiness, min = 1, max = Config.Limits.maxPerZone },
    })
    if not input then return end
    local points, lo, hi = drawNewZone()
    if not points then return end
    local heights = lib.inputDialog('Height of the area', {
        { type = 'number', label = 'Bottom (lowest floor)', default = math.floor(lo - 2.0), precision = 1 },
        { type = 'number', label = 'Top (highest ceiling)', default = math.floor(hi + 8.0), precision = 1 },
    })
    if not heights then return end
    local ok, reason = lib.callback.await('vr-djbooth:zones:create', false, {
        label = input[1], job = input[2], max = input[3] or Config.Limits.perBusiness,
        minZ = heights[1], maxZ = heights[2], points = points,
    })
    if not ok then return Notify(ReasonText(reason), 'error') end
    Notify(('Business area "%s" saved.'):format(input[1]), 'success')
end

local function plural(n, one, many) return ('%d %s'):format(n, n == 1 and one or many) end

local function countText(c)
    local parts = {}
    if c.speakers > 0 then parts[#parts + 1] = plural(c.speakers, 'speaker', 'speakers') end
    if c.boosters > 0 then parts[#parts + 1] = plural(c.boosters, 'Range Booster', 'Range Boosters') end
    if c.boomboxes > 0 then parts[#parts + 1] = plural(c.boomboxes, 'boombox', 'boomboxes') end
    if #parts == 0 then return 'nothing' end
    if #parts == 1 then return parts[1] end
    return table.concat(parts, ', ', 1, #parts - 1) .. ' and ' .. parts[#parts]
end

local function clearSpeakers(scope, where)
    local ok, counts = lib.callback.await('vr-djbooth:admin:clearCount', false, scope)
    if not ok then return Notify(ReasonText(counts), 'error') end
    if counts.speakers + counts.boosters + counts.boomboxes == 0 then
        return Notify(('There are no speakers to remove %s.'):format(where), 'primary')
    end
    local yes = Confirm({
        title = scope == 'all' and 'Remove every speaker?' or 'Remove the speakers here?',
        text = ("This removes %s %s. Nobody gets the items back, and it can't be undone."):format(countText(counts), where),
        yes = 'Remove them', no = 'Cancel', danger = true,
    })
    if not yes then return end
    local done, res, partial = lib.callback.await('vr-djbooth:admin:clear', false, scope)
    if not done then
        local msg = ReasonText(res)
        if type(partial) == 'table' then msg = msg .. (' Removed so far: %s.'):format(countText(partial)) end
        return Notify(msg, 'error')
    end
    Notify(('Removed %s.'):format(countText(res)), 'success')
end

RegisterNetEvent('vr-djbooth:client:clearAll', function()
    if drawing then return end
    clearSpeakers('all', 'everywhere on the server')
end)

local function placedIn(key)
    local n, place = 0, 'biz:' .. key
    for _, sp in pairs(Speakers) do
        if sp.place == place and not sp.booster then n = n + 1 end
    end
    return n
end

local function editZone(z)
    local input = lib.inputDialog('Edit ' .. z.label, {
        { type = 'input', label = 'Name', default = z.label, required = true, max = 48 },
        { type = 'number', label = 'Max speakers', description = ('1 to %d'):format(Config.Limits.maxPerZone),
          default = z.max or Config.Limits.perBusiness, min = 1, max = Config.Limits.maxPerZone, required = true },
    })
    if not input then return end
    local ok, res = lib.callback.await('vr-djbooth:zones:edit', false, z.key, { label = input[1], max = input[2] })
    if not ok then return Notify(ReasonText(res), 'error') end
    local max = math.floor(tonumber(input[2]) or 0)
    if type(res) == 'number' and res > max then
        Notify(('Saved. %d speakers are already here, so no more can go in until some are picked up.'):format(res), 'primary')
    else
        Notify(('Saved. Up to %d speakers can go here.'):format(max), 'success')
    end
end

local function zoneMenu(z)
    lib.registerContext({
        id = 'vr_djbooth_zone',
        title = z.label,
        menu = 'vr_djbooth_zones',
        options = {
            { title = ('Job: %s · %d / %d speakers'):format(z.job, placedIn(z.key), z.max or Config.Limits.perBusiness), disabled = true },
            {
                title = 'Edit area', icon = 'pen', disabled = not z.editable,
                description = z.editable and 'Name and max speakers' or 'Set in config.lua',
                onSelect = function() editZone(z) end,
            },
            {
                title = showing[z.key] and 'Hide outline' or 'Show outline', icon = 'eye',
                onSelect = function() showing[z.key] = not showing[z.key] or nil end,
            },
            {
                title = 'Teleport here', icon = 'location-arrow',
                onSelect = function()
                    local p = z.points[1]
                    SetEntityCoords(cache.ped, p.x, p.y, (z.minZ or 0) + 2.0, false, false, false, false)
                end,
            },
            {
                title = 'Remove all speakers here', icon = 'broom',
                description = 'Speakers and the Range Booster in this area. No items back.',
                onSelect = function() clearSpeakers(z.key, 'in ' .. z.label) end,
            },
            {
                title = 'Delete area', icon = 'trash', disabled = not z.editable,
                description = not z.editable and 'Set in config.lua' or nil,
                onSelect = function()
                    local confirm = lib.alertDialog({ header = 'Delete ' .. z.label .. '?', content = 'Speakers can no longer be placed here.', centered = true, cancel = true })
                    if confirm ~= 'confirm' then return end
                    local ok, reason, n = lib.callback.await('vr-djbooth:zones:delete', false, z.key)
                    if not ok then
                        return Notify(ReasonText(reason) .. (n and (' (%d)'):format(n) or ''), 'error')
                    end
                    showing[z.key] = nil
                    Notify('Area deleted.', 'success')
                end,
            },
        },
    })
    lib.showContext('vr_djbooth_zone')
end

RegisterNetEvent('vr-djbooth:client:zonesMenu', function()
    if drawing then return end
    local options = {
        { title = 'Create a business area', icon = 'plus', description = 'Walk the corners of the building', onSelect = createZone },
    }
    table.sort(Zones, function(a, b) return a.label < b.label end)
    for _, z in ipairs(Zones) do
        options[#options + 1] = {
            title = z.label, description = ('%s · %d / %d speakers'):format(z.job, placedIn(z.key), z.max or Config.Limits.perBusiness),
            icon = 'building', arrow = true, onSelect = function() zoneMenu(z) end,
        }
    end
    lib.registerContext({ id = 'vr_djbooth_zones', title = 'Speaker business areas', options = options })
    lib.showContext('vr_djbooth_zones')
end)
