local active
local localProps = {}
local remoteProps = {}

local function loadModel(model, timeout)
    model = type(model) == 'string' and joaat(model) or model
    if type(model) ~= 'number' or not IsModelInCdimage(model) then return nil end
    RequestModel(model)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return nil end
        Wait(0)
    end
    return model
end

local function vec(v, fallback)
    if type(v) == 'vector3' or type(v) == 'vector4' then return v.x, v.y, v.z end
    if type(v) == 'table' then return tonumber(v.x or v[1]) or 0.0, tonumber(v.y or v[2]) or 0.0, tonumber(v.z or v[3]) or 0.0 end
    return fallback or 0.0, fallback or 0.0, fallback or 0.0
end

local function attach(ped, prop)
    local model = loadModel(prop.model)
    if not model then return nil end
    local coords = GetEntityCoords(ped)
    local obj = CreateObject(model, coords.x, coords.y, coords.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return nil end
    local px, py, pz = vec(prop.pos)
    local rx, ry, rz = vec(prop.rot)
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, tonumber(prop.bone) or 60309), px, py, pz, rx, ry, rz, true, true, false, true, tonumber(prop.rotOrder) or 0, true)
    SetEntityCollision(obj, false, false)
    return obj
end

local function clean(list)
    for i = #list, 1, -1 do
        local obj = list[i]
        if DoesEntityExist(obj) then
            DetachEntity(obj, true, true)
            DeleteEntity(obj)
        end
        list[i] = nil
    end
end

local function propList(data)
    local list = {}
    local function add(p)
        if type(p) == 'table' and p.model then list[#list + 1] = p end
    end
    if type(data.prop) == 'table' then
        if data.prop.model then add(data.prop) else for _, p in ipairs(data.prop) do add(p) end end
    end
    add(data.propTwo)
    local limit = UIConfig.progress.propLimit or 2
    while #list > limit do table.remove(list) end
    return list
end

local function wire(list)
    local out = {}
    for i = 1, #list do
        local p = list[i]
        local px, py, pz = vec(p.pos)
        local rx, ry, rz = vec(p.rot)
        out[i] = { model = p.model, bone = tonumber(p.bone) or 60309, pos = { px, py, pz }, rot = { rx, ry, rz }, rotOrder = tonumber(p.rotOrder) or 0 }
    end
    return out
end

local function interrupted(data, ped)
    if not data.useWhileDead and IsEntityDead(ped) then return true end
    if not data.allowRagdoll and IsPedRagdoll(ped) then return true end
    if not data.allowCuffed and IsPedCuffed(ped) then return true end
    if not data.allowFalling and IsPedFalling(ped) then return true end
    if not data.allowSwimming and IsPedSwimming(ped) then return true end
    return false
end

local function playAnim(ped, anim)
    if anim.dict then
        RequestAnimDict(anim.dict)
        local deadline = GetGameTimer() + 5000
        while not HasAnimDictLoaded(anim.dict) do
            if GetGameTimer() > deadline then return false end
            Wait(0)
        end
        TaskPlayAnim(ped, anim.dict, anim.clip, anim.blendIn or 3.0, anim.blendOut or 1.0, anim.duration or -1, anim.flag or 49, anim.playbackRate or 0, anim.lockX or false, anim.lockY or false, anim.lockZ or false)
        RemoveAnimDict(anim.dict)
        return true
    elseif anim.scenario then
        TaskStartScenarioInPlace(ped, anim.scenario, 0, anim.playEnter == nil or anim.playEnter)
        return true
    end
    return false
end

local function disable(d, playerId)
    if d.mouse then
        DisableControlAction(0, 1, true)
        DisableControlAction(0, 2, true)
        DisableControlAction(0, 106, true)
    end
    if d.move then
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 30, true)
        DisableControlAction(0, 31, true)
        DisableControlAction(0, 36, true)
    end
    if d.sprint and not d.move then DisableControlAction(0, 21, true) end
    if d.car then
        DisableControlAction(0, 63, true)
        DisableControlAction(0, 64, true)
        DisableControlAction(0, 71, true)
        DisableControlAction(0, 72, true)
        DisableControlAction(0, 75, true)
    end
    if d.combat then
        DisableControlAction(0, 25, true)
        DisablePlayerFiring(playerId, true)
    end
end

local function run(data, kind)
    if active or type(data) ~= 'table' then return false end
    local ped = PlayerPedId()
    if interrupted(data, ped) then return false end
    local duration = math.max(0, math.floor(tonumber(data.duration) or 0))
    active = { data = data, owner = UI.owner(), cancelled = false }
    LocalPlayer.state:set('invBusy', true, false)

    local anim = type(data.anim) == 'table' and data.anim or nil
    local playing = anim and playAnim(ped, anim)

    local props = propList(data)
    if #props > 0 then
        for i = 1, #props do
            local obj = attach(ped, props[i])
            if obj then localProps[#localProps + 1] = obj end
        end
        TriggerServerEvent('vr-ui:server:props', wire(props))
    end

    UI.send('progress:start', {
        kind = kind,
        label = UI.text(data.label, 120),
        duration = duration,
        position = UI.text(data.position, 12),
    })

    local started = GetGameTimer()
    local playerId = PlayerId()
    local disables = type(data.disable) == 'table' and data.disable or {}
    local result = true

    while true do
        if active.cancelled then result = false break end
        if GetGameTimer() - started >= duration then break end
        ped = PlayerPedId()
        if interrupted(data, ped) then result = false break end
        if anim and anim.dict and playing and not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then
            TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, 1.0, anim.duration or -1, anim.flag or 49, anim.playbackRate or 0, false, false, false)
        end
        disable(disables, playerId)
        Wait(0)
    end

    ped = PlayerPedId()
    if anim then
        if anim.dict then
            StopAnimTask(ped, anim.dict, anim.clip, 1.0)
        elseif anim.scenario then
            ClearPedTasks(ped)
        end
    end
    clean(localProps)
    if #props > 0 then TriggerServerEvent('vr-ui:server:props', nil) end
    LocalPlayer.state:set('invBusy', false, false)
    UI.send('progress:stop', { cancelled = not result })
    active = nil
    return result
end

local function cancel()
    if active then active.cancelled = true end
end

exports('progressBar', function(data) return run(data, 'bar') end)
exports('progressCircle', function(data) return run(data, 'circle') end)
exports('progressActive', function() return active ~= nil end)
exports('cancelProgress', cancel)

RegisterCommand('vrui_cancelprogress', function()
    if active and active.data.canCancel then cancel() end
end, false)
Keybinds.add({
    name = 'cancelprogress',
    label = 'Cancel current action',
    description = 'Stops an action that shows a progress bar, when it can be stopped',
    suggested = UIConfig.progress.cancelKey or 'x',
    order = 30,
    onPressed = function()
        if active and active.data.canCancel then cancel() end
    end,
})

UI.onOwnerStop(function(resource)
    if active and active.owner == resource then cancel() end
end)

CreateThread(function()
    local me = PlayerId()
    while true do
        local seen = {}
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= me then
                local sid = GetPlayerServerId(player)
                local list = Player(sid).state['vrui:props']
                if type(list) == 'table' and #list > 0 then
                    seen[sid] = true
                    local ped = GetPlayerPed(player)
                    local sig = json.encode(list)
                    local entry = remoteProps[sid]
                    if not entry or entry.sig ~= sig or entry.ped ~= ped then
                        if entry then clean(entry.objs) end
                        local objs = {}
                        for i = 1, math.min(#list, UIConfig.progress.propLimit or 2) do
                            local obj = attach(ped, list[i])
                            if obj then objs[#objs + 1] = obj end
                        end
                        remoteProps[sid] = { sig = sig, ped = ped, objs = objs }
                    end
                end
            end
        end
        for sid, entry in pairs(remoteProps) do
            if not seen[sid] then
                clean(entry.objs)
                remoteProps[sid] = nil
            end
        end
        Wait(next(remoteProps) and 250 or 500)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clean(localProps)
    for _, entry in pairs(remoteProps) do clean(entry.objs) end
end)
