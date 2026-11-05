-- Messages from the phone screen (the web page) to the game.

RegisterNUICallback('close', function(_, cb)
    Phone.close()
    cb(1)
end)

RegisterNUICallback('fold', function(data, cb)
    local state = type(data) == 'table' and data.state or nil
    if Phone.FoldStates[state] then Phone.setFold(state) end
    cb(1)
end)

-- A text box got or lost focus. While typing, keys must not reach the game.
RegisterNUICallback('inputFocus', function(data, cb)
    Phone.State.typing = type(data) == 'table' and data.active == true
    Phone.applyFocus()
    cb(1)
end)

-- The screen opened an app (or went back to the home screen). The server uses it to work out battery use.
RegisterNUICallback('app', function(data, cb)
    local id = type(data) == 'table' and data.id or nil
    TriggerServerEvent('vr-phone:server:app', type(id) == 'string' and id or nil)
    cb(1)
end)

-- Screen -> server calls. The server answers with { ok = true, ... } or { ok = false, reason = '...' }.
local function proxy(name, event)
    RegisterNUICallback(name, function(data, cb)
        cb(lib.callback.await(event, false, data) or { ok = false, reason = 'timeout' })
    end)
end

proxy('unlock', 'vr-phone:unlock')
proxy('setPin', 'vr-phone:setPin')
proxy('removePin', 'vr-phone:removePin')
proxy('saveSettings', 'vr-phone:saveSettings')
proxy('saveLayout', 'vr-phone:saveLayout')
proxy('batteryUsage', 'vr-phone:batteryUsage')

RegisterNUICallback('lock', function(_, cb)
    cb(lib.callback.await('vr-phone:lock', false) == true)
end)

-- Some calls only need one value. The screen sends { id = 5 } or { number = '555-0142' } and the server gets the bare value.
local function field(name, event, key)
    RegisterNUICallback(name, function(data, cb)
        local value = type(data) == 'table' and data[key] or nil
        cb(lib.callback.await(event, false, value) or { ok = false, reason = 'timeout' })
    end)
end

proxy('badges', 'vr-phone:badges')

-- Contacts
proxy('contactsList', 'vr-phone:contacts:list')
proxy('contactsSave', 'vr-phone:contacts:save')
field('contactsRemove', 'vr-phone:contacts:remove', 'id')

-- Messages
proxy('threads', 'vr-phone:messages:threads')
proxy('history', 'vr-phone:messages:history')
proxy('sendMessage', 'vr-phone:messages:send')
field('markRead', 'vr-phone:messages:read', 'number')
field('deleteThread', 'vr-phone:messages:delete', 'number')

-- Calls and voicemail
proxy('recentCalls', 'vr-phone:calls:recent')
proxy('callsSeen', 'vr-phone:calls:seen')
proxy('callsClear', 'vr-phone:calls:clear')
proxy('startCall', 'vr-phone:call:start')
field('answerCall', 'vr-phone:call:answer', 'id')
field('endCall', 'vr-phone:call:end', 'id')
proxy('leaveVoicemail', 'vr-phone:call:voicemail')
proxy('voicemailList', 'vr-phone:voicemail:list')
field('voicemailHeard', 'vr-phone:voicemail:heard', 'id')
field('voicemailRemove', 'vr-phone:voicemail:remove', 'id')

-- Camera, photos and albums
RegisterNUICallback('cameraStart', function(_, cb)
    cb(Phone.Camera.start())
end)

RegisterNUICallback('cameraShoot', function(_, cb)
    Phone.Camera.shoot()
    cb(1)
end)

RegisterNUICallback('cameraFlip', function(_, cb)
    cb({ front = Phone.Camera.flip() })
end)

RegisterNUICallback('cameraTimer', function(_, cb)
    cb({ seconds = Phone.Camera.cycleTimer() })
end)

RegisterNUICallback('cameraStop', function(_, cb)
    Phone.Camera.stop()
    cb(1)
end)

-- A photo taken by the camera, already shrunk by the screen. The game sends it to the server in pieces.
RegisterNUICallback('mediaUpload', function(data, cb)
    if type(data) ~= 'table' or type(data.data) ~= 'string' or type(data.thumb) ~= 'string' then
        cb({ ok = false, reason = 'invalid_image' })
        return
    end
    cb(Phone.Camera.upload(data))
end)

proxy('mediaList', 'vr-phone:media:list')
field('mediaGet', 'vr-phone:media:get', 'id')
proxy('mediaStats', 'vr-phone:media:stats')
proxy('mediaAlbum', 'vr-phone:media:album')
proxy('mediaEdit', 'vr-phone:media:edit')

-- Nearby share
proxy('shareNearby', 'vr-phone:share:nearby')
proxy('shareSend', 'vr-phone:share:send')
proxy('shareRespond', 'vr-phone:share:respond')
field('shareCancel', 'vr-phone:share:cancel', 'id')

-- Notes, Reminders and Calendar
proxy('noteList', 'vr-phone:notes:list')
field('noteGet', 'vr-phone:notes:get', 'id')
proxy('noteSave', 'vr-phone:notes:save')
proxy('notePin', 'vr-phone:notes:pin')
field('noteRemove', 'vr-phone:notes:remove', 'id')

-- A reminder or an event changed, so the alert list in the game is out of date. The screen calls these after saving.
local function planner(name, event)
    RegisterNUICallback(name, function(data, cb)
        local r = lib.callback.await(event, false, data) or { ok = false, reason = 'timeout' }
        if type(r) == 'table' and r.ok then Phone.Due.refresh() end
        cb(r)
    end)
end

proxy('remList', 'vr-phone:rem:list')
planner('remSave', 'vr-phone:rem:save')
planner('remDone', 'vr-phone:rem:done')
planner('remRemove', 'vr-phone:rem:remove')
proxy('calList', 'vr-phone:cal:list')
planner('calSave', 'vr-phone:cal:save')
RegisterNUICallback('calRemove', function(data, cb)
    local r = lib.callback.await('vr-phone:cal:remove', false, type(data) == 'table' and data.id or nil) or { ok = false, reason = 'timeout' }
    if type(r) == 'table' and r.ok then Phone.Due.refresh() end
    cb(r)
end)

-- Wallet
proxy('walletOverview', 'vr-phone:wallet:overview')
proxy('walletSend', 'vr-phone:wallet:send')
proxy('walletRequest', 'vr-phone:wallet:request')
proxy('walletRespond', 'vr-phone:wallet:respond')
field('walletCancel', 'vr-phone:wallet:cancel', 'id')

-- Maps
proxy('mapsState', 'vr-phone:maps:state')
proxy('mapsSave', 'vr-phone:maps:save')
field('mapsRemove', 'vr-phone:maps:remove', 'id')

RegisterNUICallback('mapsPos', function(_, cb)
    cb(Phone.World.position())
end)

-- Sets the game's waypoint (the route shows on the game map). Answers with the position so the screen can show the route at once.
RegisterNUICallback('mapsGo', function(data, cb)
    local ok = type(data) == 'table' and Phone.World.go(data.x, data.y)
    cb({ ok = ok == true, waypoint = ok and Phone.World.waypoint() or nil })
end)

RegisterNUICallback('mapsStop', function(_, cb)
    Phone.World.stop()
    cb({ ok = true })
end)

-- Health
proxy('healthOverview', 'vr-phone:health:overview')

RegisterNUICallback('healthVitals', function(_, cb)
    cb(Phone.World.vitals())
end)

-- Music
proxy('storeList', 'vr-phone:store:list')
field('storeInstall', 'vr-phone:store:install', 'id')
field('storeUninstall', 'vr-phone:store:uninstall', 'id')

-- Veil and Hearth
proxy('veilState', 'vr-phone:veil:state')
proxy('veilAlias', 'vr-phone:veil:alias')
proxy('veilJoin', 'vr-phone:veil:join')
proxy('veilLeave', 'vr-phone:veil:leave')
proxy('veilCreate', 'vr-phone:veil:create')
proxy('veilHistory', 'vr-phone:veil:history')
proxy('veilSay', 'vr-phone:veil:say')
proxy('veilRead', 'vr-phone:veil:read')
proxy('veilThread', 'vr-phone:veil:thread')
proxy('veilDm', 'vr-phone:veil:dm')
proxy('veilBlock', 'vr-phone:veil:block')
proxy('veilUnblock', 'vr-phone:veil:unblock')

proxy('hearthState', 'vr-phone:hearth:state')
proxy('hearthCreate', 'vr-phone:hearth:create')
proxy('hearthUpdate', 'vr-phone:hearth:update')
proxy('hearthRemove', 'vr-phone:hearth:remove')
proxy('hearthDeck', 'vr-phone:hearth:deck')
proxy('hearthSwipe', 'vr-phone:hearth:swipe')
proxy('hearthPhoto', 'vr-phone:hearth:photo')
proxy('hearthMatches', 'vr-phone:hearth:matches')
proxy('hearthThread', 'vr-phone:hearth:thread')
proxy('hearthSay', 'vr-phone:hearth:say')
proxy('hearthRead', 'vr-phone:hearth:read')
proxy('hearthUnmatch', 'vr-phone:hearth:unmatch')

proxy('musicState', 'vr-phone:music:state')
proxy('musicAdd', 'vr-phone:music:add')
field('musicRemove', 'vr-phone:music:remove', 'id')
proxy('musicPlay', 'vr-phone:music:play')
proxy('musicQueue', 'vr-phone:music:queue')
proxy('musicControl', 'vr-phone:music:control')
proxy('musicReport', 'vr-phone:music:report')

RegisterNUICallback('musicSetup', function(data, cb)
    if type(data) == 'table' and type(data.hear) == 'boolean' then Phone.Music.setHear(data.hear) end
    cb(lib.callback.await('vr-phone:music:setup', false, data) or { ok = false, reason = 'timeout' })
end)

-- Mail
proxy('mailState', 'vr-phone:mail:state')
proxy('mailCreate', 'vr-phone:mail:create')
proxy('mailLogin', 'vr-phone:mail:login')
proxy('mailReset', 'vr-phone:mail:reset')
proxy('mailLogout', 'vr-phone:mail:logout')
proxy('mailPassword', 'vr-phone:mail:password')
proxy('mailList', 'vr-phone:mail:list')
field('mailGet', 'vr-phone:mail:get', 'id')
proxy('mailSend', 'vr-phone:mail:send')
proxy('mailEdit', 'vr-phone:mail:edit')
