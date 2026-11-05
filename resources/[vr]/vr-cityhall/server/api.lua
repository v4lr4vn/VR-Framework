Api = {}

local handlers = {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end

local function reg(name, fn) handlers[name] = fn end

Api.reg, Api.ok, Api.fail = reg, ok, fail

local function payload(info, desk)
    local biz = Config.Business
    local types = {}
    for _, t in ipairs(biz.types) do
        types[#types + 1] = { id = t.id, label = t.label, icon = t.icon, fee = t.fee, days = t.days, description = t.description }
    end
    return {
        desk = { id = desk.id, label = desk.label },
        citizen = { name = info.name, cid = info.cid },
        money = Core.money(info.src),
        documents = { enabled = Config.Documents.enabled, items = Docs.list(info), cooldownMinutes = Config.Documents.cooldownMinutes },
        jobcentre = Jobs.list(info),
        business = {
            enabled = biz.enabled,
            max = biz.maxPerPlayer,
            types = types,
            licences = biz.enabled and Biz.list(info.cid) or {},
            active = biz.enabled and Biz.activeCount(info.cid) or 0,
            nameMin = biz.nameMin,
            nameMax = biz.nameMax,
            renewWindowDays = biz.renewWindowDays,
            reprintFee = biz.reprintFee,
            certificate = biz.item ~= nil and biz.item ~= '' and Core.itemExists(biz.item),
        },
        now = os.time(),
    }
end

reg('open', function(info, d, desk)
    return ok(payload(info, desk))
end)

reg('document.replace', function(info, d)
    local done, err, extra = Docs.replace(info, d.item)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('%s replaced for $%d'):format(extra.label, extra.fee), 'success')
    return ok(extra)
end)

reg('job.take', function(info, d)
    local done, err, extra = Jobs.take(info, d.job)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('You are now working as %s'):format(extra.label), 'success')
    return ok(extra)
end)

reg('job.quit', function(info, d)
    local done, err, extra = Jobs.quit(info, d.job)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('You left your job as %s'):format(extra.label), 'inform')
    return ok(extra)
end)

reg('business.apply', function(info, d)
    local done, err, extra = Biz.create(info, d.type, d.name)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('%s is now licensed (%s)'):format(extra.name, extra.number), 'success')
    return ok(extra)
end)

reg('business.renew', function(info, d)
    local done, err, extra = Biz.renew(info, d.id)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('Licence %s renewed'):format(extra.number), 'success')
    return ok(extra)
end)

reg('business.surrender', function(info, d)
    local done, err, extra = Biz.surrender(info, d.id)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('Licence %s surrendered'):format(extra.number), 'inform')
    return ok(extra)
end)

reg('business.reprint', function(info, d)
    local done, err, extra = Biz.reprint(info, d.id)
    if not done then return fail(err, extra) end
    Core.notify(info.src, ('Certificate for %s reissued'):format(extra.number), 'success')
    return ok(extra)
end)

function Api.handle(src, action, data)
    if not Db.ready then return fail('not_ready') end
    local info = Core.info(src)
    if not info then return fail('no_character') end
    local fn = type(action) == 'string' and handlers[action] or nil
    if not fn then return fail('bad_request') end
    local desk = Core.deskNear(src)
    if not desk then return fail('too_far') end
    if action ~= 'open' and Core.throttle(src, 'api', 0.4) then return fail('slow_down') end
    local done, res = pcall(fn, info, type(data) == 'table' and data or {}, desk)
    if not done then
        print(('^1[vr-cityhall] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end
