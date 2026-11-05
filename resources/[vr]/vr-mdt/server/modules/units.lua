Units = {}

local state = {}
local validStatus = {}

for _, s in ipairs(Config.UnitStatuses) do validStatus[s.id] = true end

local function responderDept(dept)
    return dept == 'police' or dept == 'ems'
end

function Units.seesDispatch(ctx)
    return ctx ~= nil and (responderDept(ctx.dept) or ctx.dept == 'dispatch')
end

function Units.isUnit(ctx)
    return ctx ~= nil and responderDept(ctx.dept)
end

function Units.get(cid)
    return state[cid]
end

local function radioOf(src, override)
    if override ~= nil then return tonumber(override) or 0 end
    local st = Player(src).state
    return tonumber(st and st.radioChannel) or 0
end

local function entryFor(ctx, radio)
    local s = state[ctx.cid]
    if not s then
        s = { status = 'available', since = U.now() }
        state[ctx.cid] = s
    end
    return {
        cid = ctx.cid,
        name = ctx.name,
        callsign = ctx.callsign,
        dept = ctx.dept,
        job = ctx.job,
        gradeName = ctx.gradeName,
        status = s.status,
        since = s.since,
        callId = s.callId,
        radio = radioOf(ctx.src, radio),
    }
end

function Units.list()
    local out = {}
    for _, ctx in ipairs(Core.onlineContexts()) do
        if responderDept(ctx.dept) then out[#out + 1] = entryFor(ctx) end
    end
    table.sort(out, function(a, b)
        if a.dept ~= b.dept then return a.dept > b.dept end
        return (a.callsign or a.name) < (b.callsign or b.name)
    end)
    return out
end

function Units.entry(ctx)
    if not Units.isUnit(ctx) then return nil end
    return entryFor(ctx)
end

local function broadcast(ctx, radio)
    local entry = entryFor(ctx, radio)
    Push.where(Units.seesDispatch, 'units:update', entry)
end

AddStateBagChangeHandler('radioChannel', nil, function(bagName, _, value)
    local src = GetPlayerFromStateBagName(bagName)
    if not src or src == 0 then return end
    local ctx = Core.context(src)
    if ctx and Units.isUnit(ctx) then broadcast(ctx, value) end
end)

function Units.set(ctx, status, callId)
    if not validStatus[status] then return false end
    local s = state[ctx.cid] or {}
    s.status = status
    s.since = U.now()
    s.callId = callId
    state[ctx.cid] = s
    broadcast(ctx)
    TriggerEvent('vr-mdt:server:unitStatus', ctx.src, ctx.cid, status, callId)
    return true
end

function Units.setCall(cid, callId)
    local s = state[cid]
    if not s then return end
    s.callId = callId
end

function Units.forget(src, cid)
    if not cid or not state[cid] then return end
    state[cid] = nil
    Push.where(Units.seesDispatch, 'units:remove', { cid = cid })
end

Api.register('units.list', nil, function(src, ctx)
    if not Units.seesDispatch(ctx) then return false, 'not_allowed' end
    return true, Units.list()
end, { rate = 500 })

Api.register('units.status', nil, function(src, ctx, data)
    if not Units.isUnit(ctx) then return false, 'not_allowed' end
    local status = V.enum(data.status, validStatus)
    if not status then return false, 'bad_request' end
    local s = state[ctx.cid]
    Units.set(ctx, status, s and s.callId or nil)
    return true, entryFor(ctx)
end, { rate = 400 })

Api.register('units.setStatus', 'dispatch.manage', function(src, ctx, data)
    local cid = V.cid(data.cid)
    local status = V.enum(data.status, validStatus)
    if not cid or not status then return false, 'bad_request' end
    local p = Core.playerByCid(cid)
    local target = p and Core.context(p.source)
    if not target or not responderDept(target.dept) then return false, 'not_found' end
    local s = state[cid]
    Units.set(target, status, s and s.callId or nil)
    Audit.log(ctx, 'units.setStatus', cid, { status = status })
    return true, entryFor(target)
end, { rate = 300 })

Bridge.on('playerUnloaded', function(src)
    local p = Core.player(src)
    Units.forget(src, p and p.cid)
end)

Bridge.on('dutyChanged', function(src, onduty)
    local ctx = Core.context(src)
    if ctx and onduty then
        broadcast(ctx)
    else
        local p = Core.player(src)
        Units.forget(src, p and p.cid)
    end
end)

Bridge.on('jobChanged', function(src)
    local ctx = Core.context(src)
    if ctx and responderDept(ctx.dept) then
        broadcast(ctx)
    else
        local p = Core.player(src)
        Units.forget(src, p and p.cid)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local p = Core.player(src)
    Units.forget(src, p and p.cid)
end)

CreateThread(function()
    while true do
        Wait(Config.Dispatch.unitRefresh)
        local viewers = {}
        for src in pairs(Core.tabletOpen) do viewers[#viewers + 1] = src end
        if #viewers > 0 then
            local positions = {}
            for _, ctx in ipairs(Core.onlineContexts()) do
                if responderDept(ctx.dept) then
                    local ped = GetPlayerPed(ctx.src)
                    if ped and ped ~= 0 then
                        local c = GetEntityCoords(ped)
                        positions[#positions + 1] = { cid = ctx.cid, x = U.round(c.x, 1), y = U.round(c.y, 1), h = U.round(GetEntityHeading(ped), 0) }
                    end
                end
            end
            for _, src in ipairs(viewers) do
                local ctx = Core.context(src)
                if ctx and Units.seesDispatch(ctx) then
                    Push.to(src, 'units:positions', positions)
                else
                    Core.tabletOpen[src] = nil
                end
            end
        end
    end
end)
