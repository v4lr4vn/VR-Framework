Cj = { handlers = {}, session = nil, track = { props = {}, blips = {}, targets = {}, zones = {}, peds = {}, keep = {} }, hud = {} }

local ERRORS = {
    not_ready = 'Work is not ready yet, try again in a moment',
    no_character = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    bad_job = 'That job does not exist',
    slow_down = 'Slow down a little',
    failed = 'Something went wrong, try again',
    wrong_job = 'You need to take this job at the City Hall Job Centre first',
    busy = 'You are already on a shift',
    cooldown = 'Take a short break before your next shift',
    too_far = 'You are too far away',
    level = 'Your level is too low for that',
    daily_done = 'You already did that one today',
    no_vehicle = 'The work vehicle could not be made, try again',
    no_session = 'You are not on a shift',
    not_host = 'Only the crew leader can do that',
    solo_job = 'This job is a solo job',
    crew_full = 'The crew is full',
    bad_target = 'That player can not join',
    target_busy = 'They are already working',
    target_wrong_job = 'They do not have this job',
    target_far = 'They are too far away',
    invite_gone = 'That invite has run out',
    refused = 'You can not do that right now',
    taken = 'Someone already took that',
    gone = 'That is already done',
    too_fast = 'You did that too fast',
    full = 'Your bag is full',
    wrong_bin = 'That goes in a different bin',
    out_of_zone = 'You are not in a work area',
    felled = 'That tree is already down',
    no_water = 'You need to stand at the water',
    not_done = 'You are not finished yet',
    nothing = 'You have nothing to sell',
    no_money = 'You can not afford that',
    truck_far = 'Bring the truck closer',
    trailer_far = 'Bring the trailer closer',
    empty = 'You have nothing loaded',
    enough = 'That is plenty for now',
    refused_item = 'You can not carry that',
}

function Cj.errorText(code)
    return ERRORS[code] or ERRORS.failed
end

function Cj.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-civjobs:api', false, action, data or {})
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Cj.act(kind, data)
    local res = Cj.api('act', { kind = kind, data = data or {} })
    if res.ok then return true, res.data end
    return false, res.error
end

function Cj.notify(text, kind)
    lib.notify({ title = 'Civilian work', description = text, type = kind or 'inform' })
end

function Cj.fail(code)
    Cj.notify(Cj.errorText(code), 'error')
end

function Cj.ped()
    return cache.ped or PlayerPedId()
end

function Cj.here()
    return GetEntityCoords(Cj.ped())
end

function Cj.dist(c)
    return #(Cj.here() - vec3(c.x, c.y, c.z))
end

function Cj.v3(t)
    if not t then return nil end
    return vec3(t.x + 0.0, t.y + 0.0, t.z + 0.0)
end

function Cj.ground(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
    if ok and gz then return gz end
    return z
end

function Cj.message(data)
    SendNUIMessage(data)
end

function Cj.entity(netId, tries)
    for _ = 1, tries or 40 do
        if NetworkDoesNetworkIdExist(netId) then
            local e = NetworkGetEntityFromNetworkId(netId)
            if e and e ~= 0 and DoesEntityExist(e) then return e end
        end
        Wait(100)
    end
    return nil
end

function Cj.blip(key, c, o)
    o = o or {}
    Cj.unblip(key)
    local b = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(b, o.sprite or 1)
    SetBlipColour(b, o.colour or 5)
    SetBlipScale(b, o.scale or 0.9)
    SetBlipAsShortRange(b, o.short == true)
    if o.route then
        SetBlipRoute(b, true)
        SetBlipRouteColour(b, o.colour or 5)
    end
    if o.radius then
        local r = AddBlipForRadius(c.x, c.y, c.z, o.radius)
        SetBlipColour(r, o.colour or 5)
        SetBlipAlpha(r, 90)
        Cj.track.blips[key .. ':radius'] = r
    end
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(o.label or 'Work')
    EndTextCommandSetBlipName(b)
    Cj.track.blips[key] = b
    return b
end

function Cj.unblip(key)
    for _, k in ipairs({ key, key .. ':radius' }) do
        local b = Cj.track.blips[k]
        if b then
            RemoveBlip(b)
            Cj.track.blips[k] = nil
        end
    end
end

function Cj.prop(model, c, o)
    o = o or {}
    local hash = lib.requestModel(model)
    if not hash then return nil end
    local z = c.z
    if o.ground then z = Cj.ground(c.x, c.y, c.z) + (o.lift or 0.0) end
    local obj = CreateObjectNoOffset(hash, c.x, c.y, z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end
    if o.heading then SetEntityHeading(obj, o.heading) end
    if o.freeze ~= false then FreezeEntityPosition(obj, true) end
    if o.placeOnGround then PlaceObjectOnGroundProperly(obj) end
    Cj.track.props[#Cj.track.props + 1] = obj
    return obj
end

function Cj.removeProp(obj)
    if not obj then return end
    for i, p in ipairs(Cj.track.props) do
        if p == obj then table.remove(Cj.track.props, i) break end
    end
    if DoesEntityExist(obj) then
        pcall(function() Bridge.target.removeLocalEntity(obj) end)
        DeleteEntity(obj)
    end
end

function Cj.target(ent, options)
    if not ent then return end
    Bridge.target.addLocalEntity(ent, options)
    Cj.track.targets[#Cj.track.targets + 1] = ent
end

function Cj.untarget(ent)
    if not ent then return end
    pcall(function() Bridge.target.removeLocalEntity(ent) end)
    for i, e in ipairs(Cj.track.targets) do
        if e == ent then table.remove(Cj.track.targets, i) break end
    end
end

function Cj.zone(name, c, radius, options)
    local id = Bridge.target.addSphereZone({ name = name, coords = vec3(c.x, c.y, c.z), radius = radius, options = options })
    Cj.track.zones[#Cj.track.zones + 1] = id or name
    return id or name
end

function Cj.unzone(id)
    pcall(function() Bridge.target.removeZone(id) end)
    for i, z in ipairs(Cj.track.zones) do
        if z == id then table.remove(Cj.track.zones, i) break end
    end
end

function Cj.ped_(model, c, o)
    o = o or {}
    local hash = lib.requestModel(model)
    if not hash then return nil end
    local ped = CreatePed(4, hash, c.x, c.y, c.z - (o.lower or 1.0), c.w or 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    SetEntityInvincible(ped, o.invincible ~= false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    if o.freeze ~= false then FreezeEntityPosition(ped, true) end
    Cj.track.peds[#Cj.track.peds + 1] = ped
    return ped
end

function Cj.removePed(ped)
    if not ped then return end
    for i, p in ipairs(Cj.track.peds) do
        if p == ped then table.remove(Cj.track.peds, i) break end
    end
    if DoesEntityExist(ped) then
        pcall(function() Bridge.target.removeLocalEntity(ped) end)
        DeleteEntity(ped)
    end
end

Cj.carrying = nil

local CARRY = {
    bag = { dict = 'missfbi4prepp1', clip = '_bag_walk_garbage_man', bone = 57005, pos = vec3(0.12, 0.0, -0.05), rot = vec3(220.0, 120.0, 0.0), flag = 49 },
    box = { dict = 'anim@heists@box_carry@', clip = 'idle', bone = 60309, pos = vec3(0.025, 0.08, 0.255), rot = vec3(-145.0, 290.0, 0.0), flag = 49 },
    log = { dict = 'anim@heists@box_carry@', clip = 'idle', bone = 60309, pos = vec3(0.025, -0.1, 0.2), rot = vec3(-145.0, 290.0, 90.0), flag = 49 },
    part = { dict = 'anim@heists@box_carry@', clip = 'idle', bone = 60309, pos = vec3(0.025, 0.08, 0.255), rot = vec3(-145.0, 290.0, 0.0), flag = 49 },
}

function Cj.carry(model, kind, tag)
    Cj.drop()
    local style = CARRY[kind or 'box'] or CARRY.box
    local ped = Cj.ped()
    local hash = lib.requestModel(model)
    if not hash then return false end
    local c = GetEntityCoords(ped)
    local obj = CreateObject(hash, c.x, c.y, c.z + 0.2, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return false end
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, style.bone), style.pos.x, style.pos.y, style.pos.z, style.rot.x, style.rot.y, style.rot.z, true, true, false, true, 1, true)
    Cj.carrying = { obj = obj, style = style, tag = tag }
    CreateThread(function()
        while Cj.carrying and Cj.carrying.obj == obj do
            local p = Cj.ped()
            if not IsEntityPlayingAnim(p, style.dict, style.clip, 3) then
                local dict = lib.requestAnimDict(style.dict)
                if dict then TaskPlayAnim(p, style.dict, style.clip, 8.0, -8.0, -1, style.flag, 0, false, false, false) end
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            Wait(0)
        end
    end)
    return true
end

function Cj.drop()
    local c = Cj.carrying
    if not c then return end
    Cj.carrying = nil
    if c.obj and DoesEntityExist(c.obj) then
        DetachEntity(c.obj, true, true)
        DeleteEntity(c.obj)
    end
    ClearPedTasks(Cj.ped())
end

function Cj.isCarrying(tag)
    if not Cj.carrying then return false end
    if tag then return Cj.carrying.tag == tag end
    return true
end

function Cj.progress(o)
    local ped = Cj.ped()
    local ms = math.floor((o.seconds or 5) * 1000)
    Cj.message({ action = 'progress', label = o.label or 'Working', ms = ms })
    if o.face then
        TaskTurnPedToFaceCoord(ped, o.face.x, o.face.y, o.face.z, 600)
        Wait(600)
    end
    local prop
    if o.scenario then
        TaskStartScenarioInPlace(ped, o.scenario, 0, true)
    elseif o.anim then
        local dict = lib.requestAnimDict(o.anim.dict)
        if dict then TaskPlayAnim(ped, o.anim.dict, o.anim.clip, 8.0, -8.0, -1, o.anim.flag or 1, 0, false, false, false) end
    end
    if o.prop then
        local hash = lib.requestModel(o.prop.model)
        if hash then
            local c = GetEntityCoords(ped)
            prop = CreateObject(hash, c.x, c.y, c.z + 0.2, false, false, false)
            SetModelAsNoLongerNeeded(hash)
            local p, r = o.prop.pos or vec3(0, 0, 0), o.prop.rot or vec3(0, 0, 0)
            AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, o.prop.bone or 57005), p.x, p.y, p.z, r.x, r.y, r.z, true, true, false, true, 1, true)
        end
    end
    local started = GetGameTimer()
    local done = true
    while GetGameTimer() - started < ms do
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 23, true)
        if o.cancel ~= false and IsControlJustPressed(0, 73) then done = false break end
        if IsEntityDead(ped) then done = false break end
        if o.guard and not o.guard() then done = false break end
        Wait(0)
    end
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    if o.scenario or o.anim then ClearPedTasks(ped) end
    Cj.message({ action = 'progressEnd' })
    return done
end

function Cj.timed(o, kind, data)
    local ok, err = Cj.act('begin', data)
    if not ok and err ~= 'bad_request' then
        Cj.fail(err)
        return false
    end
    if not Cj.progress(o) then
        Cj.notify('You stopped', 'inform')
        return false
    end
    local done, res = Cj.act(kind, data)
    if not done then
        Cj.fail(res)
        return false
    end
    return true, res
end

function Cj.hudSet(title, lines, pct)
    Cj.message({ action = 'hud', title = title, lines = lines or {}, pct = pct })
end

function Cj.hudClear()
    Cj.message({ action = 'hudClear' })
end

function Cj.skill(o)
    local p = promise.new()
    Cj.skillPromise = p
    Cj.message({ action = 'skill', label = o.label or 'Reel it in', zone = o.zone or 0.22, speed = o.speed or 1.0, rounds = o.rounds or 1 })
    SetNuiFocus(true, false)
    SetNuiFocusKeepInput(true)
    local result = Citizen.Await(p)
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    return result == true
end

function Cj.sleepFor(distance, near, far)
    if distance <= (near or 30.0) then return 0 end
    if distance <= (far or 120.0) then return 250 end
    return 800
end

function Cj.cleanup()
    Cj.drop()
    for _, p in ipairs(Cj.track.props) do
        if DoesEntityExist(p) then DeleteEntity(p) end
    end
    Cj.track.props = {}
    for _, e in ipairs(Cj.track.targets) do
        pcall(function() Bridge.target.removeLocalEntity(e) end)
    end
    Cj.track.targets = {}
    for _, z in ipairs(Cj.track.zones) do
        pcall(function() Bridge.target.removeZone(z) end)
    end
    Cj.track.zones = {}
    for _, p in ipairs(Cj.track.peds) do
        if DoesEntityExist(p) then DeleteEntity(p) end
    end
    Cj.track.peds = {}
    for k, b in pairs(Cj.track.blips) do
        RemoveBlip(b)
        Cj.track.blips[k] = nil
    end
    Cj.hudClear()
    Cj.message({ action = 'progressEnd' })
end

function Cj.finishZone(key, c, label, radius)
    if Cj.track.keep[key] then return end
    Cj.track.keep[key] = Cj.zone('vr-civjobs:' .. key, c, radius or 10.0, {
        { name = 'vr-civjobs:' .. key, label = label or 'Clock off', icon = 'fa-solid fa-flag-checkered', distance = radius or 10.0, onSelect = function()
            local ok, err = Cj.act('finish')
            if not ok then Cj.fail(err) end
        end },
    })
end

function Cj.dropFinish(key)
    local id = Cj.track.keep[key]
    if id then
        Cj.unzone(id)
        Cj.track.keep[key] = nil
    end
end

Cj.spotSets = {}

function Cj.setSpots(key, fn)
    Cj.spotSets[key] = fn
end

function Cj.clearSpots(key)
    Cj.spotSets[key] = nil
    if Cj.spotHint == key then
        Bridge.textUI.hide()
        Cj.spotHint = nil
    end
end

CreateThread(function()
    while true do
        local sleep = 800
        local shown
        if next(Cj.spotSets) and Cj.session then
            local here = GetEntityCoords(Cj.ped())
            for key, fn in pairs(Cj.spotSets) do
                local ok, list = pcall(fn)
                if ok and type(list) == 'table' then
                    for i = 1, #list do
                        local s = list[i]
                        local d = #(here - s.coords)
                        if d < 40.0 then
                            sleep = 0
                            local col = s.color or { 245, 166, 35 }
                            DrawMarker(s.marker or 2, s.coords.x, s.coords.y, s.coords.z + (s.lift or 0.3), 0.0, 0.0, 0.0, 180.0, 0.0, 0.0, 0.3, 0.3, 0.3, col[1], col[2], col[3], 150, false, true, 2, false, nil, nil, false)
                            if d <= (s.range or 2.0) and not shown then
                                shown = s
                            end
                        elseif d < 120.0 and sleep > 250 then
                            sleep = 250
                        end
                    end
                end
            end
        end
        if shown then
            if Cj.spotHint ~= shown.text then
                Cj.spotHint = shown.text
                Bridge.textUI.show(shown.text)
            end
            if IsControlJustPressed(0, 38) and not Cj.busy then
                Cj.busy = true
                CreateThread(function()
                    pcall(shown.onUse)
                    Cj.busy = false
                end)
            end
        elseif Cj.spotHint then
            Cj.spotHint = nil
            Bridge.textUI.hide()
        end
        Wait(sleep)
    end
end)
