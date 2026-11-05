-- What other scripts can call.

-- exports['vr-phone']:PushNotification(target, { app = 'news', title = 'Breaking', message = '...' })
-- target is a server id (number) or a phone number (string).
-- Returns true, 'sent' or true, 'queued' (the phone is off or has no signal, so it waits), or false and a reason.
exports('PushNotification', function(target, data)
    return Phone.Notify.push(target, data)
end)

-- exports['vr-phone']:GetNumber(source) -> the number of the phone the player is holding, or nil.
exports('GetNumber', function(src)
    local s = Phone.Session.get(tonumber(src))
    return s and s.number or nil
end)

-- exports['vr-phone']:GetPhoneId(source)
exports('GetPhoneId', function(src)
    local s = Phone.Session.get(tonumber(src))
    return s and s.phoneId or nil
end)

-- exports['vr-phone']:GetApps() -> every app the phone knows about.
exports('GetApps', function()
    return Phone.Apps.list()
end)

-- exports['vr-phone']:OpenApp(source, 'settings') -> takes the phone out and opens the app.
exports('OpenApp', function(src, appId)
    src = tonumber(src)
    if not src or type(appId) ~= 'string' or not Phone.Apps.exists(appId) then return false end
    TriggerClientEvent('vr-phone:client:openApp', src, appId)
    return true
end)

-- exports['vr-phone']:GetBattery(source) -> { level = 0..100, charging = bool, powered = bool }, or nil.
exports('GetBattery', function(src)
    local s = Phone.Session.get(tonumber(src))
    if not s then return nil end
    Phone.Status.ensure(tonumber(src), s)
    local snap = Phone.Status.snapshot(s)
    return { level = snap.battery, charging = snap.charging, powered = snap.powered }
end)

-- exports['vr-phone']:SetCharging(source, 3.0, 'powerbank')  charges the phone 3% a minute. Pass nil as the rate to stop.
-- The name tells sources apart, so two scripts do not stop each other. The best rate counts.
exports('SetCharging', function(src, rate, name)
    src = tonumber(src)
    local s = src and Phone.Session.get(src)
    if not s or type(name) ~= 'string' or name == '' or #name > 32 then return false end
    Phone.Status.ensure(src, s)
    Phone.Status.refresh(src, s)
    Phone.Battery.setSource(s, name, rate)
    Phone.Status.refresh(src, s, true)
    return true
end)

-- exports['vr-phone']:AddBattery(source, 25)  adds charge at once (negative removes). Returns the new level.
exports('AddBattery', function(src, amount)
    src = tonumber(src)
    local s = src and Phone.Session.get(src)
    if not s then return nil end
    Phone.Status.ensure(src, s)
    Phone.Status.refresh(src, s)
    local level = Phone.Battery.add(s, amount)
    Phone.Status.refresh(src, s, true)
    return level
end)

-- exports['vr-phone']:GetSignal(source) -> { level = 'full'|'low'|'none', bars = 0..4, service = bool, airplane = bool }, or nil.
-- Calls and messages should check `service` before they go out.
exports('GetSignal', function(src)
    local s = Phone.Session.get(tonumber(src))
    if not s then return nil end
    Phone.Status.ensure(tonumber(src), s)
    return Phone.Status.snapshot(s).signal
end)

-- exports['vr-phone']:StartCall(source, '555-0142') -> true, or false and a reason. Rings the number as if the player dialled it.
-- The phone must be switched on and have service. Reasons: no_session, invalid_number, self, in_call, no_service, not_in_service, unavailable, line_busy.
exports('StartCall', function(src, number)
    src = tonumber(src)
    local s = src and Phone.Session.get(src)
    if not s then return false, 'no_session' end
    local call, reason = Phone.Calls.start(src, s, number)
    if not call then return false, reason end
    return true
end)

-- exports['vr-phone']:EndCall(source) -> true when the player was in a call (it is hung up, declined or cancelled).
exports('EndCall', function(src)
    src = tonumber(src)
    if not src then return false end
    return (Phone.Calls.hangup(src)) == true
end)

-- exports['vr-phone']:GetCall(source) -> { id, state = 'ringing'|'active'|'voicemail', number, outgoing }, or nil.
exports('GetCall', function(src)
    return Phone.Calls.info(tonumber(src))
end)

-- exports['vr-phone']:IsInCall(source) -> true while the player is in a call. Other scripts can use it to stop things during a call.
exports('IsInCall', function(src)
    return Phone.Calls.of(tonumber(src)) ~= nil
end)

-- exports['vr-phone']:SendMessage('555-0100', '555-0142', 'Hello') -> true, or false and a reason.
-- Sends a text from one number to another without a player behind it (a business, a script). The receiver gets it like any other text.
exports('SendMessage', function(from, to, body)
    local f = Phone.number(from)
    if not f then return false, 'invalid_number' end
    local m, reason = Phone.Messages.send(f, to, body)
    if not m then return false, reason end
    Phone.Messages.deliver(m)
    return true
end)

-- exports['vr-phone']:SendMail('name@ravenmail.io', { from = 'courier@ravenmail.io', fromName = 'Courier', subject = 'Parcel', body = '...' }) -> true, or false and a reason.
-- Puts a message in someone's inbox without a player writing it (a shop, the courier, a job). Reasons: 'invalid_address', 'no_such_account', 'empty'.
-- `from` is optional (noreply@ravenmail.io). The player's phone shows a notification.
exports('SendMail', function(to, rec)
    return Phone.Mail.system(to, rec)
end)

-- exports['vr-phone']:GetMailAddress(source) -> the address of the mail account the player's phone is signed in to, or nil.
exports('GetMailAddress', function(src)
    local s = Phone.Session.get(src)
    if not s then return nil end
    local acc = Phone.Mail.account(s.phoneId)
    return acc and acc.address or nil
end)

-- exports['vr-phone']:AddApp({ id = 'taxi', label = 'Taxi', url = 'ui/index.html', color = '#f5b301', glyph = 'car', description = 'Order a cab.' })
-- Adds an app to the phone and the App Store. The page is a web page of your own resource (put it in that resource's `files`).
-- Fields: id (a-z, 0-9, _), label, url (page, relative to your resource, or a full https address), description, category, color ('#rrggbb'),
-- glyph (an icon name) or image (a picture), preinstalled (on every new phone), removable (default true), price (bank money, default 0),
-- allow = function(source, phoneId) return true end  (hide the app from some players).
-- Returns true, or false and a reason. Add it again when 'vr-phone:server:ready' fires (so it survives a vr-phone restart).
-- Apps go away by themselves when your resource stops.
exports('AddApp', function(def)
    return Phone.Apps.register(def, GetInvokingResource() or 'unknown')
end)

-- exports['vr-phone']:UpdateApp('taxi', { label = 'Cab', price = 50 })  (only for apps your own resource added)
exports('UpdateApp', function(id, patch)
    return Phone.Apps.update(id, patch, GetInvokingResource() or 'unknown')
end)

-- exports['vr-phone']:RemoveApp('taxi')
exports('RemoveApp', function(id)
    return Phone.Apps.remove(id, GetInvokingResource() or 'unknown')
end)

-- exports['vr-phone']:IsAppInstalled(source, 'taxi') -> true or false (nil when the player has no phone out)
exports('IsAppInstalled', function(src, id)
    local s = Phone.Session.get(tonumber(src))
    if not s or type(id) ~= 'string' then return nil end
    return Phone.Apps.isInstalled(s.phoneId, id)
end)

-- exports['vr-phone']:SetAppInstalled(source, 'taxi', true)  puts the app on the player's phone (free), or takes it off with false.
-- For jobs, items and rewards. Takes off even apps the player is not allowed to remove.
exports('SetAppInstalled', function(src, id, installed)
    src = tonumber(src)
    local s = src and Phone.Session.get(src)
    if not s or type(id) ~= 'string' then return false end
    local r
    if installed == false then r = Phone.Apps.uninstall(src, s, id, true) else r = Phone.Apps.install(src, s, id, true) end
    if r.ok then TriggerClientEvent('vr-phone:client:appsChanged', src) end
    return r.ok == true
end)
