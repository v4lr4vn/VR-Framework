-- Booking: the officer's side. Third eye on a person at the station (or /book [id]) opens a charge picker,
-- then the plea and sentence, and the server does the rest.
local areas = {}
local busy = false
local busyAt = 0

local ERRORS = {
    disabled = 'Booking is turned off',
    not_loaded = 'You are not logged in',
    off_duty = 'Go on duty first',
    no_access = 'Only police can book people',
    not_allowed = 'You are not allowed to sentence people',
    bad_request = 'Pick someone else',
    not_found = 'That person is not around',
    too_far = 'The suspect is too far from you',
    not_at_station = 'You can only book people at a police station',
    not_restrained = 'The suspect must be handcuffed first',
    already_jailed = 'That person is already in prison',
    no_charges = 'Pick at least one charge',
    above_max = 'That is above what the charges allow',
    below_min = 'That is below what the charges allow',
    save_failed = 'Could not save the booking. Nothing was applied',
    already_sentenced = 'That person was already sentenced for this',
    prison_unavailable = 'The prison system is not running',
    jail_failed = 'The fine was taken but jail time could not start. Check the MDT',
    server_error = 'Something went wrong',
}

local function say(text, kind)
    Bridge.notify(text, kind or 'inform')
end

local function errorText(code)
    return ERRORS[code] or 'Something went wrong'
end

local function ui() return exports['vr-ui'] end

local function money(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '$' .. out
end

---------------------------------------------------------------------------
-- Where booking is allowed
---------------------------------------------------------------------------

RegisterNetEvent('vr-mdt:client:bookingAreas', function(list)
    areas = type(list) == 'table' and list or {}
end)

local function refresh()
    local list = Bridge.callback.await('vr-mdt:booking:areas')
    if type(list) == 'table' then areas = list end
end

Bridge.on('playerLoaded', function() SetTimeout(2500, refresh) end)
CreateThread(function()
    Wait(2500)
    if Bridge.loggedIn() then refresh() end
end)

local function inArea(c)
    for _, a in ipairs(areas) do
        local dx, dy, dz = c.x - a.x, c.y - a.y, c.z - a.z
        if math.sqrt(dx * dx + dy * dy + dz * dz) <= a.radius then return true end
    end
    return false
end

local function onDutyPolice()
    local job = Bridge.job()
    return type(job) == 'table' and job.type == 'leo' and job.onduty == true
end

---------------------------------------------------------------------------
-- The menu
---------------------------------------------------------------------------

local start

local function totals(state)
    local fine, months, n = 0, 0, 0
    for id, count in pairs(state.basket) do
        local c = state.byId[id]
        if c and count > 0 then
            fine = fine + c.fine * count
            months = months + c.months * count
            n = n + count
        end
    end
    return fine, months, n
end

local function chargeList(state)
    local out = {}
    for id, count in pairs(state.basket) do
        if count > 0 then out[#out + 1] = { id = id, count = count } end
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local showRoot

local function showCategory(state, cat)
    local options = {}
    for _, c in ipairs(cat.charges) do
        local count = state.basket[c.id] or 0
        options[#options + 1] = {
            title = count > 0 and ('%dx  %s'):format(count, c.title) or c.title,
            description = ('%s  ·  %s  ·  %s'):format(c.class, money(c.fine), c.months > 0 and ('%d months'):format(c.months) or 'no jail'),
            icon = count > 0 and 'fa-solid fa-circle-check' or 'fa-regular fa-circle',
            onSelect = function()
                local nextCount = count + 1
                if nextCount > state.maxCount then nextCount = 0 end
                state.basket[c.id] = nextCount
                showCategory(state, cat)
            end,
        }
    end
    options[#options + 1] = { title = 'Back', icon = 'fa-solid fa-arrow-left', onSelect = function() showRoot(state) end }
    ui():registerContext({ id = 'vr-mdt:book:cat', title = cat.name, options = options, onExit = function() busy = false end })
    ui():showContext('vr-mdt:book:cat')
end

local function finish(state)
    local list = chargeList(state)
    local first = ui():inputDialog(('Booking: %s'):format(state.name), {
        { type = 'checkbox', label = ('Pleaded guilty (sentence reduced by %d%%)'):format(math.floor(state.pleaReduction * 100 + 0.5)), checked = false },
        { type = 'textarea', label = 'Notes for the report (optional)', min = 1, max = 4, autosize = true },
    })
    if not first then return showRoot(state) end
    local plea = first[1] == true
    local notes = type(first[2]) == 'string' and first[2] or ''

    local q = Bridge.callback.await('vr-mdt:booking:quote', { target = state.target, charges = list, plea = plea })
    if type(q) ~= 'table' or not q.ok then
        say(errorText(q and q.error), 'error')
        return showRoot(state)
    end

    local rows = {}
    if q.max.months > 0 then
        rows[#rows + 1] = { type = 'number', label = ('Months in prison (%d to %d)'):format(q.min.months, q.max.months), default = q.max.months, min = q.min.months, max = q.max.months, required = true }
    end
    rows[#rows + 1] = { type = 'number', label = ('Fine (%s to %s)'):format(money(q.min.fine), money(q.max.fine)), default = q.max.fine, min = q.min.fine, max = q.max.fine, required = true }
    local second = ui():inputDialog(('Sentence for %s'):format(q.name), rows)
    if not second then return showRoot(state) end
    local months = q.max.months > 0 and math.floor(tonumber(second[1]) or q.max.months) or 0
    local fine = math.floor(tonumber(second[q.max.months > 0 and 2 or 1]) or q.max.fine)

    local confirm = ui():alertDialog({
        header = 'Confirm sentence',
        content = ('**%s**\n\n%s\n\nFine: **%s**\nPrison: **%s**%s\n\nThis is recorded in the MDT.'):format(
            q.name, plea and 'Pleaded guilty' or 'Not guilty plea', money(fine),
            months > 0 and ('%d months'):format(months) or 'none',
            months > 0 and '\n\nThe suspect is taken to prison straight away.' or ''),
        centered = true, cancel = true, labels = { confirm = 'Sentence', cancel = 'Go back' },
    })
    if confirm ~= 'confirm' then return showRoot(state) end

    local res = Bridge.callback.await('vr-mdt:booking:apply', { target = state.target, charges = list, plea = plea, fine = fine, months = months, notes = notes }, 20000)
    if type(res) ~= 'table' or not res.ok then
        say(errorText(res and res.error), 'error')
        return showRoot(state)
    end
    busy = false
    if res.jailed then
        say(('%s was booked: %d months, fine %s. They are on the way to prison.'):format(res.name, months, money(res.paid)), 'success')
    else
        say(('%s was booked: fine %s.'):format(res.name, money(res.paid)), 'success')
    end
    if res.warnings and #res.warnings > 0 then say(errorText(res.warnings[1]), 'error') end
end

function showRoot(state)
    local fine, months, n = totals(state)
    local options = {
        {
            title = n > 0 and ('%d charge%s  ·  %s  ·  %d months'):format(n, n == 1 and '' or 's', money(fine), months) or 'No charges picked yet',
            description = 'Pick charges below. Pick one again to add more of the same, up to ' .. state.maxCount,
            icon = 'fa-solid fa-scale-balanced', readOnly = true,
        },
    }
    for _, cat in ipairs(state.categories) do
        local picked = 0
        for _, c in ipairs(cat.charges) do picked = picked + (state.basket[c.id] or 0) end
        options[#options + 1] = {
            title = cat.name,
            description = picked > 0 and ('%d picked'):format(picked) or nil,
            icon = 'fa-solid fa-folder-open', arrow = true,
            onSelect = function() showCategory(state, cat) end,
        }
    end
    if n > 0 then
        options[#options + 1] = { title = 'Continue to sentence', icon = 'fa-solid fa-gavel', onSelect = function() CreateThread(function() finish(state) end) end }
        options[#options + 1] = { title = 'Clear charges', icon = 'fa-solid fa-eraser', onSelect = function() state.basket = {} showRoot(state) end }
    end
    ui():registerContext({
        id = 'vr-mdt:book:root', title = ('Book %s'):format(state.name), options = options,
        onExit = function() busy = false end,
    })
    ui():showContext('vr-mdt:book:root')
end

function start(target)
    target = tonumber(target)
    if not target then return end
    if busy and GetGameTimer() - busyAt < 180000 then return end
    busy = true
    busyAt = GetGameTimer()
    local res = Bridge.callback.await('vr-mdt:booking:charges', { target = target })
    if type(res) ~= 'table' or not res.ok then
        busy = false
        return say(errorText(res and res.error), 'error')
    end
    local state = {
        target = target, name = res.target.name, categories = res.categories, maxCount = res.maxCount,
        pleaReduction = res.pleaReduction, basket = {}, byId = {},
    }
    for _, cat in ipairs(res.categories) do
        for _, c in ipairs(cat.charges) do state.byId[c.id] = c end
    end
    if #state.categories == 0 then
        busy = false
        return say('The penal code has no charges. Add some in the MDT first', 'error')
    end
    showRoot(state)
end

exports('BookSuspect', function(serverId) CreateThread(function() start(serverId) end) end)

---------------------------------------------------------------------------
-- Third eye and /book
---------------------------------------------------------------------------

local function serverIdOf(entity)
    if not entity or entity == 0 or not IsPedAPlayer(entity) then return nil end
    local idx = NetworkGetPlayerIndexFromPed(entity)
    if not idx or idx == -1 then return nil end
    return GetPlayerServerId(idx)
end

CreateThread(function()
    Wait(1500)
    if not Config.Booking or not Config.Booking.enabled then return end
    Bridge.target.addGlobalPlayer({
        {
            name = 'vr_mdt_book',
            icon = 'fa-solid fa-handcuffs',
            label = 'Book suspect',
            distance = Config.Booking.interactDistance or 3.0,
            canInteract = function(entity)
                if (busy and GetGameTimer() - busyAt < 180000) or not onDutyPolice() then return false end
                if not inArea(GetEntityCoords(cache and cache.ped or PlayerPedId())) then return false end
                return serverIdOf(entity) ~= nil
            end,
            onSelect = function(data)
                local id = serverIdOf(data and data.entity)
                if id then CreateThread(function() start(id) end) end
            end,
        },
    })
end)

RegisterCommand(Config.Booking and Config.Booking.command or 'book', function(_, args)
    if not Config.Booking or not Config.Booking.enabled then return end
    local id = tonumber(args[1])
    if not id then
        local me = PlayerPedId()
        local mine = GetEntityCoords(me)
        local best, bestD
        for _, p in ipairs(GetActivePlayers()) do
            local ped = GetPlayerPed(p)
            if ped ~= me then
                local d = #(GetEntityCoords(ped) - mine)
                if d <= (Config.Booking.range or 6.0) and (not bestD or d < bestD) then best, bestD = GetPlayerServerId(p), d end
            end
        end
        id = best
    end
    if not id then return say('Nobody is close enough. Use /book <id> or stand next to the suspect', 'error') end
    CreateThread(function() start(id) end)
end, false)
