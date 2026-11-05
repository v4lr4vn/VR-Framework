-- Food Standards officers: look at a restaurant's licence and hygiene, then warn, fine, close
-- or (senior officers) shut it down.

local ROOT = 'vr-restaurant:inspect'

local OUTCOME = {
    pass = 'Passed', warning = 'Warning', closed = 'Closed', shut_down = 'Shut down', fine = 'Fine',
    visit = 'Visit', reopened = 'Allowed to open',
}
local REASON = {
    licence = 'No valid licence', hygiene = 'Failed hygiene', officer = 'Closed by an officer', revoked = 'Shut down for good',
}

local function act(id, action, a, b)
    local ok, data, extra = Rn.call('inspectAct', id, action, a, b)
    if not ok then
        Rn.fail(data, extra)
        return false
    end
    return true, data
end

local function confirm(header, content)
    return lib.alertDialog({ header = header, content = content, centered = true, cancel = true }) == 'confirm'
end

local open

local function build(r)
    local reopen = function() CreateThread(function() open(r.id) end) end
    local l = r.licence
    local licText
    if l.status == 'none' then licText = 'No licence'
    elseif l.valid then licText = ('%s · %s left'):format(l.number, Rn.span(l.left))
    else licText = ('%s · EXPIRED %s ago'):format(l.number, Rn.span(-l.left)) end

    local options = {
        { title = r.label, description = r.owner and ('Owner: %s · %d staff on duty'):format(r.owner, r.onDuty) or 'No owner', icon = 'fa-solid fa-store', readOnly = true },
        { title = licText, description = l.valid and 'Licence is valid' or 'This business is running illegally', icon = 'fa-solid fa-certificate', readOnly = true },
        {
            title = ('Hygiene: %d%% %s'):format(math.floor(tonumber(r.hygiene) or 0), Rn.stars(r.stars)), description = r.rating,
            icon = 'fa-solid fa-soap', readOnly = true,
        },
    }
    if r.noPoints then
        options[#options + 1] = { title = 'No cleaning points set up', description = 'Hygiene is capped until the area has them', icon = 'fa-solid fa-broom', readOnly = true }
    else
        for _, a in ipairs(r.areas) do
            options[#options + 1] = { title = a.label, description = ('%d%% dirty'):format(math.floor(tonumber(a.dirt) or 0)), icon = 'fa-solid fa-broom', readOnly = true }
        end
    end
    options[#options + 1] = { title = ('Strikes: %d of %d'):format(r.strikes, r.maxStrikes), icon = 'fa-solid fa-triangle-exclamation', readOnly = true }
    if r.closed then
        options[#options + 1] = {
            title = 'Closed', icon = 'fa-solid fa-ban', readOnly = true,
            description = ('%s%s'):format(REASON[r.reason] or 'Closed', r.closedLeft > 0 and (' · %s left'):format(Rn.span(r.closedLeft)) or ''),
        }
    end

    local hist = {}
    if #r.history == 0 then hist[1] = { title = 'No inspections yet', icon = 'fa-solid fa-clipboard', readOnly = true } end
    for _, h in ipairs(r.history) do
        hist[#hist + 1] = {
            title = ('%s · %s ago'):format(OUTCOME[h.outcome] or h.outcome, Rn.span(h.ago)),
            description = ('%s · hygiene %d%%%s%s'):format(h.by ~= '' and h.by or 'Officer', math.floor(tonumber(h.hygiene) or 0), h.fine > 0 and (' · fined %s'):format(Rn.money(h.fine)) or '', h.note ~= '' and (' · ' .. h.note) or ''),
            icon = 'fa-solid fa-clipboard', readOnly = true,
        }
    end
    lib.registerContext({ id = ROOT .. ':history', title = 'Inspection history', menu = ROOT, options = hist })
    options[#options + 1] = { title = 'Inspection history', icon = 'fa-solid fa-clock-rotate-left', menu = ROOT .. ':history', arrow = true }

    options[#options + 1] = {
        title = 'Record a visit', description = 'Log that you checked the place', icon = 'fa-solid fa-clipboard-check',
        onSelect = function() act(r.id, 'record') reopen() end,
    }
    options[#options + 1] = {
        title = 'Give a warning', icon = 'fa-solid fa-circle-exclamation',
        onSelect = function()
            local input = lib.inputDialog('Warning', { { type = 'input', label = 'What needs fixing', required = true, max = 200 } })
            if input then act(r.id, 'warn', input[1]) end
            reopen()
        end,
    }
    options[#options + 1] = {
        title = 'Fine the business', description = ('Up to %s, taken from the business account'):format(Rn.money(r.limits.fine)), icon = 'fa-solid fa-money-bill',
        onSelect = function()
            local input = lib.inputDialog('Fine', {
                { type = 'number', label = 'Amount', min = 1, max = r.limits.fine, required = true },
                { type = 'input', label = 'Reason', required = true, max = 200 },
            })
            if input then
                local ok, res = act(r.id, 'fine', input[1], input[2])
                if ok then
                    if res.paid < res.asked then
                        Rn.notify(('Only %s was in the account, so that is what was taken'):format(Rn.money(res.paid)), 'inform')
                    else
                        Rn.notify('Fine issued', 'success')
                    end
                end
            end
            reopen()
        end,
    }
    if r.closed and r.status ~= 'revoked' then
        options[#options + 1] = {
            title = 'Allow it to open again', icon = 'fa-solid fa-door-open',
            onSelect = function()
                if confirm('Open again', 'Lift the closure on ' .. r.label .. '?') and act(r.id, 'reopen') then Rn.notify('Reopened', 'success') end
                reopen()
            end,
        }
    elseif not r.closed and r.owner then
        options[#options + 1] = {
            title = 'Close temporarily', description = ('Up to %d hours'):format(r.limits.hours), icon = 'fa-solid fa-ban',
            onSelect = function()
                local input = lib.inputDialog('Close', {
                    { type = 'number', label = 'Hours', min = 1, max = r.limits.hours, default = 6, required = true },
                    { type = 'input', label = 'Reason', required = true, max = 200 },
                })
                if input and act(r.id, 'close', input[1], input[2]) then Rn.notify('Closed', 'success') end
                reopen()
            end,
        }
    end
    if r.limits.canRevoke and r.owner and r.status ~= 'revoked' then
        options[#options + 1] = {
            title = 'Shut down for good', description = 'The owner loses the business and cannot buy another for a while', icon = 'fa-solid fa-gavel',
            onSelect = function()
                local input = lib.inputDialog('Shut down', { { type = 'input', label = 'Reason', required = true, max = 200 } })
                if input and confirm('Shut down ' .. r.label, 'This takes the business away from its owner. It is put up for sale again after a while.') then
                    if act(r.id, 'revoke', input[1]) then return Rn.notify('Shut down', 'success') end
                end
                reopen()
            end,
        }
    end
    lib.registerContext({ id = ROOT, title = ('Inspection: %s'):format(r.label), options = options })
end

function open(id)
    local ok, r, extra = Rn.call('inspect', id)
    if not ok then return Rn.fail(r, extra) end
    build(r)
    lib.showContext(ROOT)
end
Rn.openInspection = open

-- The inspect option shows on every restaurant for officers on duty.
local function officerOnDuty()
    local ok, res = pcall(function() return Bridge.hasGroup({ [Config.Inspect.job] = 0 }, true) end)
    return ok and res and true or false
end

local zones = {}

local function build_zones()
    for _, id in ipairs(zones) do pcall(function() Bridge.target.removeZone(id) end) end
    zones = {}
    for _, spot in ipairs(Rn.spots) do
        zones[#zones + 1] = Bridge.target.addSphereZone({
            name = ('vr-restaurant:inspect:%d'):format(spot.id),
            coords = vec3(spot.x, spot.y, spot.z),
            radius = 3.0,
            options = {
                {
                    name = ('vr-restaurant:inspect:%d:open'):format(spot.id),
                    label = 'Food standards inspection',
                    icon = 'fa-solid fa-clipboard-check',
                    distance = 4.0,
                    canInteract = officerOnDuty,
                    onSelect = function() CreateThread(function() open(spot.id) end) end,
                },
            },
        })
    end
    -- Also at each crafting area, so an officer standing in the kitchen can start from there.
end

RegisterNetEvent('vr-restaurant:client:spots', function() SetTimeout(200, build_zones) end)
CreateThread(function() Wait(2500) build_zones() end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, id in ipairs(zones) do pcall(function() Bridge.target.removeZone(id) end) end
end)
