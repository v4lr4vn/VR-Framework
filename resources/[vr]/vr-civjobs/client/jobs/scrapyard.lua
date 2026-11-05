local cfg = Config.Jobs.scrapyard
local H = {}

local wreck
local baleProp
local applied = {}
local binZones = {}
local crushed = false

local function partById(id)
    for _, p in ipairs(cfg.parts) do
        if p.id == id then return p end
    end
    return nil
end

local function applyBreak(part)
    if not wreck or not DoesEntityExist(wreck) then return end
    if part.door then SetVehicleDoorBroken(wreck, part.door, true) end
    if part.wheel then BreakOffVehicleWheel(wreck, part.wheel, true, false, true, false) end
end

local function removed(view)
    local set = {}
    for _, id in ipairs(view.data.removed or {}) do set[id] = true end
    return set
end

local function remove(part)
    if Cj.isCarrying() then return Cj.notify('Your hands are full', 'error') end
    local ok = Cj.timed({
        label = part.label,
        seconds = part.seconds,
        scenario = 'WORLD_HUMAN_VEHICLE_MECHANIC',
        face = GetEntityCoords(wreck),
    }, 'remove', { part = part.id })
    if ok then
        applyBreak(part)
        Cj.carry(cfg.partModel, 'part', 'part')
    end
end

local function sort(kind)
    local ok, err = Cj.act('sort', { kind = kind })
    if not ok then return Cj.fail(err) end
    Cj.drop()
end

local function crush()
    local ok = Cj.timed({
        label = 'Crushing the frame',
        seconds = cfg.crushSeconds,
        scenario = 'WORLD_HUMAN_WELDING',
        face = GetEntityCoords(wreck),
    }, 'crush')
    if ok and wreck and DoesEntityExist(wreck) then
        SetEntityAlpha(wreck, 0, false)
        SetEntityCollision(wreck, false, false)
        crushed = true
    end
end

local function bale(view)
    if Cj.isCarrying() then return Cj.notify('Your hands are full', 'error') end
    local ok, err = Cj.act('bale')
    if not ok then return Cj.fail(err) end
    if baleProp then Cj.removeProp(baleProp) baleProp = nil end
    Cj.carry(cfg.baleModel, 'box', 'bale')
end

local function deliver()
    local ok, err = Cj.act('deliver')
    if not ok then return Cj.fail(err) end
    Cj.drop()
end

local function wreckOptions()
    local list = {}
    for _, part in ipairs(cfg.parts) do
        list[#list + 1] = {
            name = 'vr-civjobs:part:' .. part.id, label = 'Remove ' .. part.label:lower(), icon = 'fa-solid fa-wrench', distance = 3.0, bones = { part.bone },
            canInteract = function()
                local s = Cj.session
                if not s or Cj.isCarrying() or s.data.phase ~= 'strip' then return false end
                for _, id in ipairs(s.data.removed or {}) do
                    if id == part.id then return false end
                end
                return true
            end,
            onSelect = function() remove(part) end,
        }
    end
    list[#list + 1] = {
        name = 'vr-civjobs:crush', label = 'Crush the frame', icon = 'fa-solid fa-compress', distance = 3.5,
        canInteract = function() return Cj.session and Cj.session.data.phase == 'crush' end,
        onSelect = crush,
    }
    return list
end

local function hud(view)
    local d = view.data
    local lines = {
        { label = 'Stage', value = d.phase == 'strip' and 'Strip the parts' or d.phase == 'crush' and 'Crush the frame' or d.phase == 'deliver' and 'Deliver the bale' or 'Done' },
        { label = 'Parts sorted', value = ('%d / %d'):format(#(d.sorted or {}), d.parts) },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    }
    Cj.hudSet('Scrapyard', lines, d.percent)
end

function H.start(view)
    crushed = false
    applied = {}
    CreateThread(function()
        local v = view.vehicles[1]
        wreck = v and Cj.entity(v.netId)
        if not wreck then return end
        SetVehicleEngineHealth(wreck, 0.0)
        SetVehicleBodyHealth(wreck, 200.0)
        SetVehicleDirtLevel(wreck, 14.0)
        FreezeEntityPosition(wreck, true)
        SetVehicleUndriveable(wreck, true)
        Cj.target(wreck, wreckOptions())
        H.sync(Cj.session or view)
    end)
    for _, b in ipairs(view.data.bins) do
        binZones[#binZones + 1] = Cj.zone('vr-civjobs:bin:' .. b.kind, b, cfg.binRange, {
            { name = 'vr-civjobs:bin:' .. b.kind, label = 'Put in ' .. b.label:lower(), icon = 'fa-solid fa-dumpster', distance = cfg.binRange, canInteract = function() return Cj.isCarrying('part') end, onSelect = function() sort(b.kind) end },
        })
    end
    Cj.zone('vr-civjobs:buyer', view.data.buyer, cfg.buyerRange, {
        { name = 'vr-civjobs:buyer', label = 'Deliver scrap', icon = 'fa-solid fa-truck-ramp-box', distance = cfg.buyerRange, canInteract = function() return Cj.isCarrying('bale') end, onSelect = deliver },
    })
    Cj.blip('yard', view.data.crusher, { sprite = 380, colour = 47, label = 'Scrap crusher' })
    Cj.blip('buyer', view.data.buyer, { sprite = 479, colour = 47, label = 'Scrap buyer' })
    hud(view)
end

function H.sync(view)
    local d = view.data
    hud(view)
    local set = removed(view)
    for id in pairs(set) do
        if not applied[id] then
            applied[id] = true
            local part = partById(id)
            if part then applyBreak(part) end
        end
    end
    if d.phase == 'deliver' and wreck and DoesEntityExist(wreck) then
        if not crushed then
            SetEntityAlpha(wreck, 0, false)
            SetEntityCollision(wreck, false, false)
            crushed = true
        end
        if not baleProp and not d.holder then
            local c = GetEntityCoords(wreck)
            baleProp = Cj.prop(cfg.baleModel, { x = c.x, y = c.y, z = c.z }, { ground = true, placeOnGround = true })
            if baleProp then
                Cj.target(baleProp, {
                    { name = 'vr-civjobs:bale', label = 'Lift the bale', icon = 'fa-solid fa-box', distance = 3.0, canInteract = function() return not Cj.isCarrying() end, onSelect = function() bale(view) end },
                })
            end
        elseif baleProp and d.holder then
            Cj.removeProp(baleProp)
            baleProp = nil
        end
    end
    if not d.carry and Cj.isCarrying() then Cj.drop() end
end

function H.stop()
    wreck, baleProp = nil, nil
    binZones = {}
end

Cj.register('scrapyard', H)
