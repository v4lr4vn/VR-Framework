-- Adds the app to the phone and the App Store.
local function add()
    exports['vr-phone']:AddApp({
        id = 'hello',                 -- a-z, 0-9 and _
        label = 'Hello',
        description = 'A tiny example app made by another script.',
        category = 'Other',
        url = 'ui/index.html',        -- a page of THIS resource (it must be listed in `files`)
        color = '#e0a82e',
        glyph = 'star',               -- an icon from the phone's set. Or use  image = 'ui/icon.png'
        preinstalled = false,         -- true: every new phone has it. false: it is in the App Store.
        price = 0,                    -- bank money. 0 is free.
        -- allow = function(source, phoneId) return true end,   -- keep it away from some players
    })
end

-- Add the app when the phone is ready (the phone may start after this script), and right away if it is already running.
AddEventHandler('vr-phone:server:ready', add)
if GetResourceState('vr-phone') == 'started' then add() end

-- Something the page can ask for. The page calls it with VRPhone.post('hello:time') from the client (see client.lua).
lib.callback.register('hello-app:time', function(src)
    local number = exports['vr-phone']:GetNumber(src)
    return { time = os.date('%H:%M:%S'), number = number }
end)

-- Giving the app to a player (for example from a job or an item):
--   exports['vr-phone']:SetAppInstalled(source, 'hello', true)
-- Sending that app's notification (it shows on the phone, and tapping it opens the app):
--   exports['vr-phone']:PushNotification(source, { app = 'hello', title = 'Hello', message = 'Hi there' })
