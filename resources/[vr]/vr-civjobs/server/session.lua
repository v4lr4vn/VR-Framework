Civ.jobs = Civ.jobs or {}

function Civ.register(id, handler)
    Civ.jobs[id] = handler
end

Session = { byMember = {}, invites = {}, cool = {} }

local nextId = 0

local function copyCoords(c)
    return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0, w = c.w and (c.w + 0.0) or nil }
end

function Session.of(src)
    return Session.byMember[src]
end

function Session.count(sess)
    local n = 0
    for _ in pairs(sess.members) do n = n + 1 end
    return n
end

function Session.vehicleEntity(sess, index)
    local v = sess.vehicles[index or 1]
    if not v then return nil end
    local ent = v.entity
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
    return nil
end

function Session.spawn(sess, model, c, opts)
    opts = opts or {}
    local hash = joaat(model)
    local veh = CreateVehicleServerSetter(hash, opts.type or 'automobile', c.x, c.y, c.z, c.w or 0.0)
    local deadline = GetGameTimer() + 5000
    while (not veh or veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < deadline do Wait(25) end
    if not veh or veh == 0 or not DoesEntityExist(veh) then return nil end
    local plate = ('CIV%05d'):format(math.random(0, 99999))
    SetVehicleNumberPlateText(veh, plate)
    local state = Entity(veh).state
    state:set('vr_civjob', sess.job, true)
    Bridge.vehicle.setFuel(veh, 100.0)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local rec = { entity = veh, netId = netId, plate = plate, model = model, trailer = opts.trailer == true, wreck = opts.wreck == true, coords = copyCoords(c) }
    sess.vehicles[#sess.vehicles + 1] = rec
    if opts.wreck then SetVehicleDoorsLocked(veh, 2) end
    if not opts.trailer and not opts.wreck then
        for s in pairs(sess.members) do
            Bridge.vehicle.giveKeys(s, veh, plate)
        end
    end
    return rec
end

function Session.view(sess, src)
    local H = Civ.jobs[sess.job]
    local members = {}
    for s, m in pairs(sess.members) do
        members[#members + 1] = { src = s, name = m.name, tasks = m.tasks, host = s == sess.host }
    end
    table.sort(members, function(a, b) return a.src < b.src end)
    local vehicles = {}
    for i = 1, #sess.vehicles do
        local v = sess.vehicles[i]
        vehicles[#vehicles + 1] = { netId = v.netId, plate = v.plate, trailer = v.trailer, wreck = v.wreck }
    end
    local data = {}
    if H and H.view then
        local ok, res = pcall(H.view, Session.ctx(sess, src))
        if ok and type(res) == 'table' then data = res end
    end
    return {
        job = sess.job,
        label = sess.def.label,
        icon = sess.def.icon,
        host = sess.host,
        me = src,
        members = members,
        started = sess.started,
        pool = math.floor(sess.pool),
        vehicles = vehicles,
        data = data,
    }
end

function Session.sync(sess)
    for s in pairs(sess.members) do
        TriggerClientEvent('vr-civjobs:client:sync', s, Session.view(sess, s))
    end
end

function Session.ctx(sess, src)
    local m = sess.members[src]
    local info = Core.info(src)
    local prog = info and Progress.get(info.cid, sess.job) or nil
    local level = prog and (Civ.levelOf(prog.xp)) or 1
    local ctx = { src = src, sess = sess, info = info, def = sess.def, cfg = sess.def, state = sess.state, member = m, level = level, prog = prog }

    function ctx.pos() return Bridge.coords(src) end

    function ctx.near(coords, radius)
        return Core.near(src, coords, radius)
    end

    function ctx.limit(key, ms)
        return Core.throttle(src, sess.id .. ':' .. key, ms)
    end

    function ctx.notify(text, kind)
        Core.notify(src, text, kind, sess.def.label)
    end

    function ctx.xp(amount)
        if not info then return end
        local before, after = Progress.addXp(info.cid, sess.job, amount)
        if after > before then
            Core.notify(src, ('You reached level %d'):format(after), 'success', sess.def.label)
            TriggerEvent('vr-civjobs:server:levelUp', src, sess.job, after)
        end
        ctx.level = after
    end

    function ctx.earn(amount, xp)
        amount = (tonumber(amount) or 0) * Civ.mult(ctx.level)
        sess.pool = sess.pool + amount
        if m then m.tasks = m.tasks + 1 end
        if xp and xp > 0 then ctx.xp(xp) end
        return amount
    end

    function ctx.pay(amount, xp, reason)
        amount = math.floor((tonumber(amount) or 0) * Civ.mult(ctx.level))
        if amount > 0 and not Core.pay(src, amount, reason or sess.def.label) then
            print(('^3[vr-civjobs] the bank did not confirm a payment of $%d to player %s (%s). Check the money bridge.^0'):format(amount, src, sess.job))
        end
        if info then Progress.record(info.cid, sess.job, amount, 0) end
        if m then m.tasks = m.tasks + 1 end
        if xp and xp > 0 then ctx.xp(xp) end
        return amount
    end

    function ctx.begin(key)
        if not m then return end
        m.timers = m.timers or {}
        m.timers[key] = GetGameTimer()
    end

    function ctx.since(key)
        if not m or not m.timers or not m.timers[key] then return nil end
        return GetGameTimer() - m.timers[key]
    end

    function ctx.clear(key)
        if m and m.timers then m.timers[key] = nil end
    end

    function ctx.each(fn)
        for s in pairs(sess.members) do fn(s) end
    end

    function ctx.vehicle(index)
        return Session.vehicleEntity(sess, index)
    end

    function ctx.spawn(model, c, opts)
        return Session.spawn(sess, model, c, opts)
    end

    function ctx.sync()
        Session.sync(sess)
    end

    return ctx
end

local function returned(sess)
    local spec = sess.def.vehicle
    local rec = sess.vehicles[1]
    if not spec or not rec or rec.wreck then return true end
    local ent = Session.vehicleEntity(sess, 1)
    if not ent then return false end
    local p = GetEntityCoords(ent)
    local radius = spec.returnRadius or 40.0
    return Civ.dist(p, spec.coords) <= radius
end

function Session.returned(sess)
    return returned(sess)
end

local function cleanup(sess)
    for i = 1, #sess.vehicles do
        local ent = sess.vehicles[i].entity
        if ent and ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    sess.vehicles = {}
end

function Session.settle(sess, opts)
    opts = opts or {}
    local fraction = opts.fraction or 1.0
    local raw = sess.pool * fraction + (opts.bonus or 0) - (opts.penalty or 0)
    local owed = raw < 0 and math.floor(-raw) or 0
    local total = math.max(0, raw)
    local count = Session.count(sess)
    if sess.def.crew and count > 1 then
        total = total * (1 + (count - 1) * Config.Crew.bonusPerExtraMember)
    end
    total = math.floor(total)
    local eligible = {}
    for s, m in pairs(sess.members) do
        if s == sess.host or m.tasks > 0 then eligible[#eligible + 1] = s end
    end
    if owed > 0 then
        local hostInfo = Core.info(sess.host)
        if hostInfo then Bridge.removeMoney(sess.host, Config.Account, owed, 'Vehicle not returned') end
    end
    if #eligible == 0 then return 0, {} end
    local share = math.floor(total / #eligible)
    local paid = {}
    for _, s in ipairs(eligible) do
        local info = Core.info(s)
        if info then
            if share > 0 then Core.pay(s, share, sess.def.label) end
            Progress.record(info.cid, sess.job, share, opts.complete and 1 or 0)
            paid[s] = share
        end
    end
    if (opts.xp or 0) > 0 then
        for s in pairs(sess.members) do
            local ctx = Session.ctx(sess, s)
            ctx.xp(opts.xp)
        end
    end
    return total, paid
end

function Session.close(sess, reason, by)
    if sess.closed then return end
    sess.closed = true
    local H = Civ.jobs[sess.job]
    local host = by and sess.members[by] and by or sess.host
    local ctx = Session.ctx(sess, host)
    ctx.returned = returned(sess)
    local opts = {}
    if H and H.finish then
        local ok, res = pcall(H.finish, ctx, reason)
        if ok and type(res) == 'table' then
            opts = res
        elseif not ok then
            print(('^1[vr-civjobs] %s finish: %s^0'):format(sess.job, tostring(res)))
        end
    end
    if reason ~= 'done' and opts.fraction == nil then opts.fraction = Config.Crew.earlyStopPercent / 100 end
    if not ctx.returned then
        opts.penalty = (opts.penalty or 0) + Config.Penalty.vehicleNotReturned
    end
    if opts.crash then opts.penalty = (opts.penalty or 0) + opts.crash end
    local total, paid = Session.settle(sess, opts)
    cleanup(sess)
    for s in pairs(sess.members) do
        Session.byMember[s] = nil
        Session.cool[s] = os.time() + Config.StartCooldownSeconds
        TriggerClientEvent('vr-civjobs:client:ended', s, {
            job = sess.job,
            label = sess.def.label,
            reason = reason,
            total = total,
            paid = paid[s] or 0,
            note = opts.note,
        })
        Core.notify(s, (paid[s] or 0) > 0 and ('Shift over. You were paid $%d'):format(paid[s]) or 'Shift over', (paid[s] or 0) > 0 and 'success' or 'inform', sess.def.label)
    end
    TriggerEvent('vr-civjobs:server:sessionEnded', sess.job, reason, total)
end

function Session.start(info, jobId, opts)
    local def = Config.Jobs[jobId]
    local H = Civ.jobs[jobId]
    if not def or not H or Config.Disabled[jobId] then return nil, 'bad_job' end
    if Session.byMember[info.src] then return nil, 'busy' end
    if not Core.qualifies(info, def) then return nil, 'wrong_job' end
    if Session.cool[info.src] and os.time() < Session.cool[info.src] then return nil, 'cooldown' end
    if not Core.near(info.src, def.depot.coords, 30.0) then return nil, 'too_far' end
    nextId = nextId + 1
    local sess = {
        id = nextId, job = jobId, def = def, host = info.src, started = os.time(),
        members = { [info.src] = { cid = info.cid, name = info.name, tasks = 0, carry = false } },
        state = {}, pool = 0.0, vehicles = {},
    }
    local ctx = Session.ctx(sess, info.src)
    local ok, res, code = pcall(H.start, ctx, type(opts) == 'table' and opts or {})
    if not ok then
        print(('^1[vr-civjobs] %s start: %s^0'):format(jobId, tostring(res)))
        cleanup(sess)
        return nil, 'failed'
    end
    if not res then
        cleanup(sess)
        return nil, code or 'failed'
    end
    Session.byMember[info.src] = sess
    Progress.bind(info.src, info.cid)
    for _, rec in ipairs(sess.vehicles) do
        if not rec.trailer then
            TriggerClientEvent('vr-civjobs:client:vehicle', info.src, { netId = rec.netId, warp = true })
        end
    end
    Session.sync(sess)
    TriggerEvent('vr-civjobs:server:sessionStarted', jobId, info.src)
    return sess
end

function Session.leave(src, reason)
    local sess = Session.byMember[src]
    if not sess then return false end
    if Session.count(sess) <= 1 then
        Session.close(sess, reason or 'quit', src)
        return true
    end
    if src == sess.host then
        local nextHost
        for s in pairs(sess.members) do
            if s ~= src and (not nextHost or s < nextHost) then nextHost = s end
        end
        sess.host = nextHost
    end
    local H = Civ.jobs[sess.job]
    if H and H.left then pcall(H.left, sess, src) end
    sess.members[src] = nil
    Session.byMember[src] = nil
    Session.cool[src] = os.time() + Config.StartCooldownSeconds
    TriggerClientEvent('vr-civjobs:client:ended', src, { job = sess.job, label = sess.def.label, reason = 'left', total = 0, paid = 0 })
    Session.sync(sess)
    return true
end

function Session.invite(host, targetSrc)
    local sess = Session.byMember[host]
    if not sess then return nil, 'no_session' end
    if sess.host ~= host then return nil, 'not_host' end
    if not sess.def.crew then return nil, 'solo_job' end
    if Session.count(sess) >= sess.def.crew then return nil, 'crew_full' end
    targetSrc = tonumber(targetSrc)
    if not targetSrc or targetSrc == host then return nil, 'bad_target' end
    local target = Core.info(targetSrc)
    if not target then return nil, 'bad_target' end
    if Session.byMember[targetSrc] then return nil, 'target_busy' end
    if not Core.qualifies(target, sess.def) then return nil, 'target_wrong_job' end
    local a, b = Bridge.coords(host), Bridge.coords(targetSrc)
    if not a or not b or Civ.dist(a, b) > Config.Crew.range then return nil, 'target_far' end
    Session.invites[targetSrc] = { sess = sess.id, host = host, expires = os.time() + Config.Crew.inviteSeconds }
    local me = Core.info(host)
    TriggerClientEvent('vr-civjobs:client:invite', targetSrc, { from = host, name = me and me.name or 'Someone', job = sess.job, label = sess.def.label, seconds = Config.Crew.inviteSeconds })
    return true
end

function Session.accept(src)
    local inv = Session.invites[src]
    Session.invites[src] = nil
    if not inv or os.time() > inv.expires then return nil, 'invite_gone' end
    if Session.byMember[src] then return nil, 'busy' end
    local sess = Session.byMember[inv.host]
    if not sess or sess.id ~= inv.sess or sess.closed then return nil, 'invite_gone' end
    if Session.count(sess) >= sess.def.crew then return nil, 'crew_full' end
    local info = Core.info(src)
    if not info or not Core.qualifies(info, sess.def) then return nil, 'wrong_job' end
    sess.members[src] = { cid = info.cid, name = info.name, tasks = 0, carry = false }
    Session.byMember[src] = sess
    Progress.bind(src, info.cid)
    for _, rec in ipairs(sess.vehicles) do
        if not rec.trailer and rec.entity then Bridge.vehicle.giveKeys(src, rec.entity, rec.plate) end
    end
    Core.notify(inv.host, ('%s joined your crew'):format(info.name), 'success', sess.def.label)
    Session.sync(sess)
    return sess
end

function Session.decline(src)
    local inv = Session.invites[src]
    Session.invites[src] = nil
    if inv then
        local info = Core.info(src)
        Core.notify(inv.host, ('%s declined your invite'):format(info and info.name or 'They'), 'inform')
    end
    return true
end

function Session.kick(host, target)
    local sess = Session.byMember[host]
    if not sess or sess.host ~= host then return nil, 'not_host' end
    target = tonumber(target)
    if not target or target == host or not sess.members[target] then return nil, 'bad_target' end
    Session.leave(target, 'kicked')
    return true
end

function Session.act(src, kind, data)
    local sess = Session.byMember[src]
    if not sess or sess.closed then return nil, 'no_session' end
    local H = Civ.jobs[sess.job]
    local fn = H and H.act and H.act[kind]
    if type(kind) ~= 'string' or not fn then return nil, 'bad_request' end
    local ctx = Session.ctx(sess, src)
    if not ctx.info then return nil, 'no_character' end
    local ok, res, err = pcall(fn, ctx, type(data) == 'table' and data or {})
    if not ok then
        print(('^1[vr-civjobs] %s.%s: %s^0'):format(sess.job, kind, tostring(res)))
        return nil, 'failed'
    end
    if res == nil or res == false then return nil, err or 'refused' end
    if type(res) == 'table' and res.finish then
        Session.close(sess, 'done', src)
        return res
    end
    if not (type(res) == 'table' and res.quiet) then Session.sync(sess) end
    return res
end

AddEventHandler('playerDropped', function()
    local src = source
    Session.invites[src] = nil
    Session.cool[src] = nil
    if Session.byMember[src] then Session.leave(src, 'dropped') end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    local seen = {}
    for _, sess in pairs(Session.byMember) do
        if not seen[sess] then
            seen[sess] = true
            cleanup(sess)
        end
    end
end)
