-- The screen's way into the App Store. Same rules as comms.lua: Phone.guard (the phone is in the player's hands and unlocked)
-- and Phone.tooFast on everything that changes something.
local Apps = Phone.Apps
local guard, tooFast = Phone.guard, Phone.tooFast

local function fail(reason) return { ok = false, reason = reason } end

lib.callback.register('vr-phone:store:list', function(src)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if tooFast(src, 'slist', 300) then return fail('busy') end
    local list, featured = Apps.catalogue(src, s.phoneId)
    return { ok = true, apps = list, featured = featured }
end)

lib.callback.register('vr-phone:store:install', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(id) ~= 'string' then return fail('invalid') end
    if tooFast(src, 'sinst', 600) then return fail('busy') end
    return Apps.install(src, s, id, false)
end)

lib.callback.register('vr-phone:store:uninstall', function(src, id)
    local s, reason = guard(src, true)
    if not s then return fail(reason) end
    if type(id) ~= 'string' then return fail('invalid') end
    if tooFast(src, 'suninst', 600) then return fail('busy') end
    return Apps.uninstall(src, s, id, false)
end)

-- An app was added or taken away by another script while the phone is out: the screen asks for the new list.
lib.callback.register('vr-phone:apps:sync', function(src)
    local s = guard(src, false)
    if not s then return fail() end
    if tooFast(src, 'async', 500) then return fail('busy') end
    return { ok = true, apps = Apps.list(), installed = Apps.installedIds(s.phoneId), layout = Phone.Settings.getLayout(s.phoneId) }
end)
