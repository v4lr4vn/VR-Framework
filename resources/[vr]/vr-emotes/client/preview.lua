Preview = {}

local state = { active = false, ped = nil, cam = nil, props = {}, token = 0, mode = 'body', home = nil }

local function deleteProps()
    for _, obj in ipairs(state.props) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    state.props = {}
end

local function offset(ped, x, y, z)
    return GetOffsetFromEntityInWorldCoords(ped, x, y, z)
end

local function clearLine(from, to, ignore)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 + 16, ignore, 7)
    local _, hit, at = GetShapeTestResult(ray)
    if hit == 1 then
        local dir = to - from
        local len = #dir
        if len > 0.01 then
            local back = math.max(0.35, #(at - from) - 0.25)
            return from + dir / len * back
        end
    end
    return to
end

local function frame()
    local ped = state.ped
    if not ped or not state.cam then return end
    local head = offset(ped, 0.0, 0.0, 0.65)
    local camPos, target, fov
    if state.mode == 'face' then
        camPos = offset(ped, -0.12, 0.95, 0.68)
        target = offset(ped, -0.26, 0.0, 0.62)
        fov = 32.0
    else
        camPos = offset(ped, -0.55, 2.75, 0.28)
        target = offset(ped, -0.85, 0.0, 0.02)
        fov = 45.0
    end
    camPos = clearLine(head, camPos, ped)
    SetCamCoord(state.cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(state.cam, target.x, target.y, target.z)
    SetCamFov(state.cam, fov)
end

function Preview.available()
    if not Config.Preview then return false, 'off' end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, true) then return false, 'vehicle' end
    if IsEntityDead(ped) or IsPedSwimming(ped) or IsPedFalling(ped) or IsPedRagdoll(ped) then return false, 'busy' end
    if IsProne then return false, 'busy' end
    return true
end

function Preview.isActive()
    return state.active
end

function Preview.start()
    if state.active then return true end
    local ok = Preview.available()
    if not ok then return false end
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local clone = ClonePed(ped, false, false, true)
    if not clone or clone == 0 or not DoesEntityExist(clone) then return false end
    SetEntityCoordsNoOffset(clone, pos.x, pos.y, pos.z, false, false, false)
    SetEntityHeading(clone, heading)
    FreezeEntityPosition(clone, true)
    SetEntityCollision(clone, false, false)
    SetEntityInvincible(clone, true)
    SetBlockingOfNonTemporaryEvents(clone, true)
    SetPedCanRagdoll(clone, false)
    SetEntityAsMissionEntity(clone, true, true)
    RemoveAllPedWeapons(clone, true)
    if CurrentMood then SetFacialIdleAnimOverride(clone, CurrentMood, 0) end
    state.ped = clone
    state.home = { pos = pos, heading = heading }
    state.mode = 'body'
    state.cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    state.active = true
    frame()
    RenderScriptCams(true, true, 450, true, true)
    CreateThread(function()
        local ticks = 0
        while state.active do
            local me = PlayerPedId()
            SetEntityLocallyInvisible(me)
            for _, obj in pairs(PlayerPropList()) do SetEntityLocallyInvisible(obj) end
            HideHudAndRadarThisFrame()
            ticks = ticks + 1
            if ticks % 30 == 0 then frame() end
            Wait(0)
        end
    end)
    return true
end

function Preview.stop()
    if not state.active then return end
    state.active = false
    state.token = state.token + 1
    deleteProps()
    if state.cam then
        RenderScriptCams(false, true, 350, true, true)
        DestroyCam(state.cam, false)
        state.cam = nil
    end
    if state.ped and DoesEntityExist(state.ped) then DeleteEntity(state.ped) end
    state.ped = nil
end

local function reset(clone)
    deleteProps()
    ClearPedTasksImmediately(clone)
    local home = state.home
    if home then
        SetEntityCoordsNoOffset(clone, home.pos.x, home.pos.y, home.pos.z, false, false, false)
        SetEntityHeading(clone, home.heading)
    end
end

function Preview.setMode(mode)
    if state.mode == mode then return end
    state.mode = mode
    frame()
end

function Preview.idle()
    if not state.active then return end
    state.token = state.token + 1
    reset(state.ped)
end

function Preview.emote(id)
    if not state.active then return false end
    local entry, tbl, key = Catalog.get(id)
    if not entry or not Catalog.allowed(entry, tbl, key) then return false end
    state.token = state.token + 1
    local token = state.token
    local clone = state.ped
    reset(clone)
    Preview.setMode('body')
    local dict, anim = entry[1], entry[2]
    CreateThread(function()
        if dict == 'Scenario' or dict == 'MaleScenario' or dict == 'ScenarioObject' then
            if token ~= state.token then return end
            TaskStartScenarioInPlace(clone, anim, 0, false)
            return
        end
        if not LoadAnim(dict) or token ~= state.token or not DoesEntityExist(clone) then return end
        TaskPlayAnim(clone, dict, anim, 8.0, -8.0, -1, 1, 0.0, false, false, false)
        local o = entry.AnimationOptions
        if o and o.Prop then
            AddPropToPed(clone, o.Prop, o.PropBone, o.PropPlacement, nil, false, state.props)
            if o.SecondProp then AddPropToPed(clone, o.SecondProp, o.SecondPropBone, o.SecondPropPlacement, nil, false, state.props) end
            if token ~= state.token then deleteProps() end
        end
    end)
    return true
end

function Preview.walk(key)
    if not state.active then return false end
    local entry = RP.Walks[key]
    if not entry then return false end
    state.token = state.token + 1
    local token = state.token
    local clone = state.ped
    reset(clone)
    Preview.setMode('body')
    local set = entry[1]
    CreateThread(function()
        if not LoadAnim(set) or token ~= state.token or not DoesEntityExist(clone) then return end
        TaskPlayAnim(clone, set, 'walk', 8.0, -8.0, -1, 1, 0.0, false, false, false)
    end)
    return true
end

function Preview.mood(key)
    if not state.active then return false end
    local entry = key and RP.Expressions[key]
    state.token = state.token + 1
    reset(state.ped)
    Preview.setMode('face')
    if entry then
        SetFacialIdleAnimOverride(state.ped, entry[1], 0)
    else
        ClearFacialIdleAnimOverride(state.ped)
    end
    return true
end

function Preview.syncMood()
    if not state.active then return end
    if CurrentMood then SetFacialIdleAnimOverride(state.ped, CurrentMood, 0) else ClearFacialIdleAnimOverride(state.ped) end
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then Preview.stop() end
end)
