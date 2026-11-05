Gc = { points = {}, zones = {}, modelRefs = {}, busy = false }
local RES = GetCurrentResourceName()
local function name(n) return RES .. ':' .. n end
Gc.name = name

local ERRORS = {
    too_far = 'You are too far away',
    slow_down = 'Slow down a little',
    busy = 'You are already doing something',
    no_player = 'Choose a character first',
    no_tool = 'You need the right tool for this',
    missing = 'You do not have what that needs',
    depleted = 'There is nothing left here for now',
    cooldown = 'You just did that. Give it a while',
    too_fast = 'You did that too fast',
    failed = 'It did not work out. Try again',
    full = 'You cannot carry any more of that',
    bad_request = 'Something went wrong, try again',
    not_ready = 'Not ready yet, try again',
}

function Gc.notify(text, kind)
    lib.notify({ title = Config.Title, description = text, type = kind or 'inform' })
end

function Gc.problem(code, extra)
    local text = ERRORS[code] or ERRORS.bad_request
    if (code == 'depleted' or code == 'cooldown') and tonumber(extra) then
        text = ('%s. Try again in about %d s'):format(text, math.ceil(extra))
    elseif code == 'missing' and type(extra) == 'string' then
        text = ('You need %s for that'):format(extra)
    elseif code == 'no_tool' and type(extra) == 'string' then
        text = ('You need a %s for this'):format(extra)
    end
    Gc.notify(text, 'error')
end

function Gc.call(cbName, ...)
    local res = lib.callback.await(name(cbName), false, ...)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error, res.data
end

function Gc.ped() return PlayerPedId() end

local function listItems(items)
    local parts = {}
    for _, g in ipairs(items or {}) do parts[#parts + 1] = ('%dx %s'):format(g.count, g.label) end
    return table.concat(parts, ', ')
end

-- ref is a placed point id, or a kind name plus coords for props
local function run(cfg, ref, at, index)
    if Gc.busy then return end
    Gc.busy = true
    local ok, data, extra = Gc.call('start', ref, at, index)
    if not ok then
        Gc.busy = false
        return Gc.problem(data, extra)
    end
    local label = cfg.label
    if cfg.mode == 'craft' and index and cfg.recipes and cfg.recipes[index] then label = cfg.recipes[index].label end
    local done = lib.progressBar({
        duration = data.duration, label = label, useWhileDead = false, canCancel = true,
        disable = { move = true, car = true, combat = true }, anim = cfg.anim,
    })
    ClearPedTasks(Gc.ped())
    if not done then
        lib.callback.await(name('cancel'), false)
        Gc.busy = false
        return
    end
    local good = true
    if cfg.skill then good = lib.skillCheck(cfg.skill, { 'e' }) == true end
    local fine, res, extra2 = Gc.call('finish', data.token, good)
    Gc.busy = false
    if not fine then return Gc.problem(res, extra2) end
    if #res.items == 0 then
        Gc.notify('You found nothing this time', 'inform')
    else
        Gc.notify(('You got %s'):format(listItems(res.items)), 'success')
    end
    if res.broke then Gc.notify(('Your %s broke'):format(res.broke), 'error') end
end

local function craftMenu(cfg, ref, at)
    if Gc.busy then return end
    local ok, data, extra = Gc.call('recipes', ref, at)
    if not ok then return Gc.problem(data, extra) end
    local options = {}
    for _, rec in ipairs(data.recipes) do
        local needs = {}
        for _, t in ipairs(rec.takes) do needs[#needs + 1] = ('%dx %s (%d)'):format(t.count, t.label, t.have) end
        local gives = {}
        for _, g in ipairs(rec.gives) do gives[#gives + 1] = ('%dx %s'):format(g.count, g.label) end
        options[#options + 1] = {
            title = rec.label,
            description = ('%s  ->  %s'):format(table.concat(needs, ', '), table.concat(gives, ', ')),
            icon = 'fa-solid fa-hammer',
            disabled = not rec.can,
            onSelect = function() run(cfg, ref, at, rec.index) end,
        }
    end
    if #options == 0 then options[1] = { title = 'Nothing to make here', disabled = true } end
    lib.registerContext({ id = name('craft'), title = data.label or cfg.label, options = options })
    lib.showContext(name('craft'))
end

local function sellMenu(cfg, ref, at)
    if Gc.busy then return end
    local ok, data, extra = Gc.call('sellList', ref, at)
    if not ok then return Gc.problem(data, extra) end
    local options = {}
    for _, row in ipairs(data.items) do
        options[#options + 1] = {
            title = ('%s  x%d'):format(row.label, row.count),
            description = ('$%d each'):format(row.price),
            icon = 'fa-solid fa-sack-dollar',
            onSelect = function()
                local input = lib.inputDialog(row.label, {
                    { type = 'number', label = 'How many', description = ('$%d each'):format(row.price), default = row.count, min = 1, max = row.count, required = true },
                })
                if not input or not input[1] then return sellMenu(cfg, ref, at) end
                local sold, res, more = Gc.call('sell', ref, at, row.item, math.floor(tonumber(input[1]) or 0))
                if not sold then Gc.problem(res, more) else Gc.notify(('Sold %dx %s for $%d'):format(res.count, res.label, res.total), 'success') end
                sellMenu(cfg, ref, at)
            end,
        }
    end
    if #options == 0 then options[1] = { title = 'You have nothing they want', disabled = true } end
    lib.registerContext({ id = name('sell'), title = data.label or cfg.label, options = options })
    lib.showContext(name('sell'))
end

local function act(cfg, ref, at)
    if cfg.mode == 'gather' then run(cfg, ref, at)
    elseif cfg.mode == 'craft' then craftMenu(cfg, ref, at)
    elseif cfg.mode == 'sell' then sellMenu(cfg, ref, at) end
end

local function option(cfg, id, label, ref, getAt)
    return {
        name = id,
        icon = cfg.icon,
        label = label,
        distance = Config.Distance or 2.0,
        canInteract = function() return not Gc.busy end,
        onSelect = function(data) act(cfg, ref, getAt and getAt(data) or nil) end,
    }
end

local function clearZones()
    for _, id in ipairs(Gc.zones) do pcall(Bridge.target.removeZone, id) end
    Gc.zones = {}
end

local function buildZones()
    clearZones()
    for _, pt in ipairs(Gc.points) do
        local cfg = Config.Kinds[pt.kind]
        if cfg and not cfg.models then
            local ok, id = pcall(function()
                return Bridge.target.addSphereZone({
                    coords = vector3(pt.x, pt.y, pt.z), radius = Config.Radius or 1.5,
                    options = { option(cfg, ('%s_%d'):format(RES, pt.id), pt.label, pt.id) },
                })
            end)
            if ok and id then Gc.zones[#Gc.zones + 1] = id end
        end
    end
end

local function addModels()
    for kind, cfg in pairs(Config.Kinds) do
        if cfg.models then
            local at = function(data)
                local c = data and data.entity and GetEntityCoords(data.entity) or GetEntityCoords(Gc.ped())
                return { x = c.x, y = c.y, z = c.z }
            end
            pcall(Bridge.target.addModel, cfg.models, { option(cfg, ('%s_model_%s'):format(RES, kind), cfg.label, kind, at) })
        end
    end
end

RegisterNetEvent(name('client:points'), function(list)
    Gc.points = type(list) == 'table' and list or {}
    buildZones()
end)

CreateThread(function()
    Wait(2500)
    Gc.points = lib.callback.await(name('points'), false) or {}
    buildZones()
    addModels()
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then clearZones() end
end)
