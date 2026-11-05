Api = {}

local handlers = {}

local function fail(code, extra) return { ok = false, error = code, data = extra } end
local function ok(data) return { ok = true, data = data } end

local function reg(name, fn) handlers[name] = fn end

Api.reg, Api.ok, Api.fail = reg, ok, fail

reg('list', function(info)
    return ok(Jobs.snapshot(info))
end)

reg('select', function(info, d)
    local done, err, extra = Jobs.select(info, d.job)
    if not done then return fail(err) end
    Core.notify(info.src, extra.job == Config.FallbackJob and 'You are not working a job now' or ('You are now working as %s'):format(extra.label), 'success')
    return ok(extra)
end)

reg('leave', function(info, d)
    local done, err, extra = Jobs.leave(info, d.job)
    if not done then return fail(err) end
    Core.notify(info.src, ('You left your job as %s'):format(extra.label), 'inform')
    return ok(extra)
end)

reg('duty', function(info)
    local done, err, extra = Jobs.duty(info)
    if not done then return fail(err) end
    Core.notify(info.src, extra.onduty and 'You are on duty' or 'You are off duty', extra.onduty and 'success' or 'inform')
    return ok(extra)
end)

function Api.handle(src, action, data)
    if not Db.ready then return fail('not_ready') end
    local info = Core.info(src)
    if not info then return fail('no_character') end
    local fn = type(action) == 'string' and handlers[action] or nil
    if not fn then return fail('bad_request') end
    if action ~= 'list' and Core.throttle(src, 'act', Config.ActionCooldown) then return fail('slow_down') end
    local done, res = pcall(fn, info, type(data) == 'table' and data or {})
    if not done then
        print(('^1[vr-multijob] %s: %s^0'):format(action, tostring(res)))
        return fail('failed')
    end
    return res
end
