Pr = { points = {}, zones = {}, jailed = false, state = { credits = 0, reduced = 0, cap = 0 }, outfits = nil, busy = false }

local ERRORS = {
    not_inmate = 'This is for prisoners only',
    too_far = 'You are too far away',
    slow_down = 'Slow down a little',
    cooldown = 'You did that a moment ago. Give it a while',
    capped = 'You have earned all the time off you can for this sentence',
    nearly_out = 'You are nearly out, there is nothing left to take off',
    too_fast = 'You did that too fast',
    failed = 'You did not do it well enough. Try again',
    no_credit = 'You do not have enough canteen credit',
    full = 'You cannot carry that',
    not_sold = 'They do not sell that any more',
    not_ready = 'Not ready yet, try again',
    bad_request = 'Something went wrong, try again',
}

function Pr.notify(text, kind)
    lib.notify({ title = 'Prison', description = text, type = kind or 'inform' })
end

function Pr.problem(code, extra)
    local text = ERRORS[code] or ERRORS.bad_request
    if code == 'cooldown' and tonumber(extra) then
        text = ('You did that a moment ago. Try again in %d s'):format(math.ceil(extra))
    end
    Pr.notify(text, 'error')
end

function Pr.call(name, ...)
    local res = lib.callback.await('vr-prison:' .. name, false, ...)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error, res.data
end

function Pr.ped()
    return PlayerPedId()
end

local function span(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 60 then return ('%d min'):format(seconds // 60) end
    return ('%d s'):format(seconds)
end

-- Outfit ---------------------------------------------------------------------------

local COMPONENT_IDS = { 1, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
local PROP_IDS = { 0, 1, 2, 6, 7 }
local enforce = false

function Pr.gender()
    local model = GetEntityModel(Pr.ped())
    if model == joaat('mp_m_freemode_01') then return 'male' end
    if model == joaat('mp_f_freemode_01') then return 'female' end
    return nil
end

function Pr.snapshot()
    local ped = Pr.ped()
    local out = { components = {}, props = {} }
    for _, id in ipairs(COMPONENT_IDS) do
        out.components[#out.components + 1] = { id = id, d = GetPedDrawableVariation(ped, id), t = GetPedTextureVariation(ped, id) }
    end
    for _, id in ipairs(PROP_IDS) do
        out.props[#out.props + 1] = { id = id, d = GetPedPropIndex(ped, id), t = math.max(0, GetPedPropTextureIndex(ped, id)) }
    end
    return out
end

local function apply(outfit)
    if type(outfit) ~= 'table' then return end
    local ped = Pr.ped()
    for _, c in ipairs(outfit.components or {}) do
        SetPedComponentVariation(ped, c.id, c.d, c.t, 0)
    end
    for _, c in ipairs(outfit.props or {}) do
        if c.d < 0 then ClearPedProp(ped, c.id) else SetPedPropIndex(ped, c.id, c.d, c.t, true) end
    end
end
Pr.apply = apply

local function wearing(outfit)
    local ped = Pr.ped()
    for _, c in ipairs(outfit.components or {}) do
        if GetPedDrawableVariation(ped, c.id) ~= c.d then return false end
    end
    return true
end

function Pr.prisonOutfit()
    local g = Pr.gender()
    return g and Pr.outfits and Pr.outfits[g] or nil
end

local function startEnforce()
    if enforce or not Config.Outfit.enforce then return end
    enforce = true
    CreateThread(function()
        while enforce and Pr.jailed do
            Wait(math.max(2, Config.Outfit.checkSeconds or 5) * 1000)
            if not (enforce and Pr.jailed) then break end
            local outfit = Pr.prisonOutfit()
            if outfit and not wearing(outfit) and not IsPedInAnyVehicle(Pr.ped(), false) then apply(outfit) end
        end
        enforce = false
    end)
end

-- Intake and release -------------------------------------------------------------------

local function inside(area)
    if not area then return true end
    local c = GetEntityCoords(Pr.ped())
    return #(c - vec3(area.x, area.y, area.z)) <= (area.r or 150.0)
end

local function sendOriginal()
    TriggerServerEvent('vr-prison:server:original', Pr.snapshot())
end

RegisterNetEvent('vr-prison:client:intake', function(d)
    if type(d) ~= 'table' then return end
    CreateThread(function()
        Pr.jailed = true
        Pr.state = d.state or Pr.state
        Pr.outfits = d.outfits or Pr.outfits
        enforce = false
        if d.capture and d.fresh then sendOriginal() end
        if d.move and d.cell then
            local deadline = GetGameTimer() + 9000
            while GetGameTimer() < deadline and not inside(d.area) do Wait(250) end
            Wait(700)
            local ped = Pr.ped()
            DoScreenFadeOut(300)
            Wait(350)
            SetEntityCoords(ped, d.cell.x, d.cell.y, d.cell.z, false, false, false, false)
            SetEntityHeading(ped, d.cell.w or 0.0)
            Wait(300)
            DoScreenFadeIn(500)
        end
        if d.capture and not d.fresh then
            Wait(Config.Outfit.captureDelayMs or 9000)
            if Pr.jailed then sendOriginal() end
        end
        local outfit = Pr.prisonOutfit()
        if outfit then apply(outfit) end
        startEnforce()
        if d.fresh then
            Pr.notify('You have been processed. Work shifts and the canteen are around the prison.', 'inform')
        end
    end)
end)

RegisterNetEvent('vr-prison:client:release', function(original)
    enforce = false
    Pr.jailed = false
    Pr.state = { credits = 0, reduced = 0, cap = 0 }
    if type(original) == 'string' and original ~= '' then
        local ok, data = pcall(json.decode, original)
        if ok and type(data) == 'table' then
            Wait(1200)
            apply(data)
        end
    end
end)

RegisterNetEvent('vr-prison:client:state', function(state)
    if type(state) == 'table' then
        Pr.jailed = state.jailed == true
        Pr.state = state
    end
end)

-- The MDT also tells us when the sentence ends, whatever the cause.
RegisterNetEvent('vr-mdt:client:prison', function(d)
    if type(d) == 'table' and d.active == false then
        enforce = false
        Pr.jailed = false
    end
end)

-- Stations and canteen -----------------------------------------------------------------

local function work(pt)
    if Pr.busy then return end
    local cfg = Config.Stations[pt.type]
    if not cfg then return end
    Pr.busy = true
    local ok, data, extra = Pr.call('start', pt.id)
    if not ok then
        Pr.busy = false
        return Pr.problem(data, extra)
    end
    local done = lib.progressBar({
        duration = data.duration,
        label = cfg.label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = cfg.anim,
    })
    ClearPedTasks(Pr.ped())
    if not done then
        lib.callback.await('vr-prison:cancel', false)
        Pr.busy = false
        return
    end
    local good = true
    if cfg.skill then good = lib.skillCheck(cfg.skill, { 'e' }) == true end
    local fine, res, extra2 = Pr.call('finish', data.token, good)
    Pr.busy = false
    if not fine then return Pr.problem(res, extra2) end
    local parts = {}
    if res.seconds > 0 then parts[#parts + 1] = ('%s off your sentence'):format(span(res.seconds)) end
    if res.credits > 0 then parts[#parts + 1] = ('%d %s'):format(res.credits, Config.CreditLabel) end
    Pr.notify(#parts > 0 and ('Done. %s.'):format(table.concat(parts, ' and ')) or 'Done.', 'success')
end

local function canteen(pt)
    if Pr.busy then return end
    local ok, data, extra = Pr.call('canteen', pt.id)
    if not ok then return Pr.problem(data, extra) end
    local options = {}
    for _, row in ipairs(data.items) do
        local afford = data.credits >= row.price
        options[#options + 1] = {
            title = row.label,
            description = ('%d %s'):format(row.price, Config.CreditLabel),
            icon = 'fa-solid fa-basket-shopping',
            disabled = not afford,
            onSelect = function()
                local bought, res, more = Pr.call('buy', pt.id, row.index)
                if not bought then return Pr.problem(res, more) end
                Pr.notify(('Bought %s. %d %s left.'):format(row.label, res.credits, Config.CreditLabel), 'success')
                canteen(pt)
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'Nothing for sale', disabled = true } end
    lib.registerContext({ id = 'vr-prison:canteen', title = ('%s - %d %s'):format(data.label or 'Canteen', data.credits, Config.CreditLabel), options = options })
    lib.showContext('vr-prison:canteen')
end

local function clearZones()
    for _, id in ipairs(Pr.zones) do pcall(Bridge.target.removeZone, id) end
    Pr.zones = {}
end

local function buildZones()
    clearZones()
    for _, pt in ipairs(Pr.points) do
        local options
        if pt.kind == 'station' and Config.Stations[pt.type] then
            local cfg = Config.Stations[pt.type]
            options = {{
                name = ('vr_prison_station_%d'):format(pt.id),
                icon = cfg.icon,
                label = pt.label ~= '' and pt.label or cfg.label,
                distance = Config.Interact.distance,
                canInteract = function() return Pr.jailed and not Pr.busy end,
                onSelect = function() work(pt) end,
            }}
        elseif pt.kind == 'canteen' then
            options = {{
                name = ('vr_prison_canteen_%d'):format(pt.id),
                icon = 'fa-solid fa-basket-shopping',
                label = pt.label,
                distance = Config.Interact.distance,
                canInteract = function() return Pr.jailed and not Pr.busy end,
                onSelect = function() canteen(pt) end,
            }}
        end
        if options then
            local ok, id = pcall(function()
                return Bridge.target.addSphereZone({ coords = vector3(pt.x, pt.y, pt.z), radius = Config.Interact.radius, options = options })
            end)
            if ok and id then Pr.zones[#Pr.zones + 1] = id end
        end
    end
end

RegisterNetEvent('vr-prison:client:points', function(list)
    Pr.points = type(list) == 'table' and list or {}
    buildZones()
end)

-- /jailtime already tells you the time. This adds what working has done so far.
RegisterCommand('prisonstats', function()
    if not Pr.jailed then return Pr.notify("You're not in prison.", 'inform') end
    local s = Pr.state
    Pr.notify(('Time taken off by working: %s of at most %s. You have %d %s.'):format(span(s.reduced or 0), span(s.cap or 0), s.credits or 0, Config.CreditLabel), 'inform')
end, false)

CreateThread(function()
    Wait(2500)
    Pr.points = lib.callback.await('vr-prison:points', false) or {}
    buildZones()
    local me = lib.callback.await('vr-prison:me', false)
    if type(me) == 'table' and me.jailed then
        Pr.jailed = true
        Pr.state = me
        Pr.outfits = me.outfits
        local outfit = Pr.prisonOutfit()
        if outfit then apply(outfit) end
        startEnforce()
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clearZones() end
end)
