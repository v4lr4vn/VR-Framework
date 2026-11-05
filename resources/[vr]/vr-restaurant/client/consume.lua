local active
local cancelRequested = false

local function debugPrint(...)
    if Config.Debug then print('^5[vr-restaurant]^7', ...) end
end

local function setBusy(state)
    LocalPlayer.state:set('invBusy', state, false)
    TriggerEvent('inventory:client:busy:status', state)
    TriggerEvent('canUseInventoryAndHotbar:toggle', not state)
end

local function makeButtons(label)
    local sf = RequestScaleformMovie('instructional_buttons')
    local timeout = GetGameTimer() + 2000
    while not HasScaleformMovieLoaded(sf) do
        if GetGameTimer() > timeout then return nil end
        Wait(0)
    end
    BeginScaleformMovieMethod(sf, 'CLEAR_ALL') EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'SET_CLEAR_SPACE') ScaleformMovieMethodAddParamInt(200) EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, Config.CancelKeys[1], true))
    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(label)
    EndTextCommandScaleformString()
    EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'DRAW_INSTRUCTIONAL_BUTTONS') EndScaleformMovieMethod()
    return sf
end

local function attachProp(ped, model, bone, placement)
    if not model then return end
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then
        debugPrint(('prop %s not found, skipped'):format(tostring(model)))
        return
    end
    if not lib.requestModel(hash, 5000) then return end
    local coords = GetEntityCoords(ped)
    local prop = CreateObject(hash, coords.x, coords.y, coords.z + 0.2, true, true, false)
    SetModelAsNoLongerNeeded(hash)
    local p = placement or {}
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, bone or 18905),
        p[1] or 0.0, p[2] or 0.0, p[3] or 0.0, p[4] or 0.0, p[5] or 0.0, p[6] or 0.0,
        true, true, false, true, 1, true)
    return prop
end

local function deleteProps(props)
    for _, prop in ipairs(props) do
        if DoesEntityExist(prop) then
            DetachEntity(prop, true, false)
            DeleteEntity(prop)
        end
    end
end

local function animFlag(ped, opts)
    if IsPedInAnyVehicle(ped, false) or opts.EmoteMoving then return 51 end
    if opts.EmoteLoop then return 1 end
    return 0
end

local function consume(data)
    local ped = cache.ped
    local emote = Config.Emotes[data.emote] or Config.Emotes[Config.FallbackEmote[data.type] or 'burger']
    local opts = emote and emote.AnimationOptions or {}
    local dict, clip = emote and emote[1], emote and emote[2]
    local animal = GetPedType(ped) == 28

    setBusy(true)

    if dict and not animal and lib.requestAnimDict(dict, 5000) then
        TaskPlayAnim(ped, dict, clip, 3.0, 3.0, -1, animFlag(ped, opts), 0, false, false, false)
    else
        dict = nil
    end

    local props = {}
    if not animal then
        props[#props + 1] = attachProp(ped, opts.Prop, opts.PropBone, opts.PropPlacement)
        props[#props + 1] = attachProp(ped, opts.SecondProp, opts.SecondPropBone, opts.SecondPropPlacement)
    end

    local verb = Config.Verbs[data.type] or 'Using'
    local buttons = makeButtons(('%s %s - %s'):format(Config.CancelHint, verb:lower(), data.label or data.name))

    local ends = GetGameTimer() + data.time
    local nextAnimCheck = 0
    local cancelled = false
    cancelRequested = false

    while GetGameTimer() < ends do
        ped = cache.ped
        if buttons then DrawScaleformMovieFullscreen(buttons, 255, 255, 255, 255, 0) end

        for i = 1, #Config.CancelKeys do
            if IsControlJustPressed(0, Config.CancelKeys[i]) then cancelled = true end
        end
        if not data.canRun and IsControlPressed(0, Config.SprintControl) and IsPedSprinting(ped) then cancelled = true end
        if IsPedRagdoll(ped) or IsEntityDead(ped) or IsPedSwimmingUnderWater(ped) or cancelRequested then cancelled = true end
        if cancelled then break end

        local now = GetGameTimer()
        if dict and now > nextAnimCheck then
            nextAnimCheck = now + 500
            if not IsEntityPlayingAnim(ped, dict, clip, 3) then
                TaskPlayAnim(ped, dict, clip, 3.0, 3.0, -1, animFlag(ped, opts), 0, false, false, false)
            end
        end
        Wait(0)
    end

    if dict then
        StopAnimTask(ped, dict, clip, 1.0)
        RemoveAnimDict(dict)
    end
    deleteProps(props)
    if buttons then SetScaleformMovieAsNoLongerNeeded(buttons) end
    setBusy(false)

    if cancelled then
        if not cancelRequested then TriggerServerEvent('vr-restaurant:server:cancel', data.token) end
        TriggerEvent('VRCore:Notify', ('Stopped %s'):format(verb:lower()), 'error')
    else
        TriggerServerEvent('vr-restaurant:server:finish', data.token)
    end
    cancelRequested = false
end

RegisterNetEvent('vr-restaurant:client:start', function(data)
    if GetInvokingResource() or type(data) ~= 'table' then return end
    if active then
        return TriggerServerEvent('vr-restaurant:server:cancel', data.token)
    end
    active = data
    CreateThread(function()
        local ok, err = pcall(consume, data)
        if not ok then
            print(('^1[vr-restaurant] %s^0'):format(err))
            setBusy(false)
            TriggerServerEvent('vr-restaurant:server:cancel', data.token)
        end
        active = nil
    end)
end)

RegisterNetEvent('vr-restaurant:client:cancel', function()
    if GetInvokingResource() then return end
    if active then cancelRequested = true end
end)

RegisterNetEvent('vr-restaurant:client:finished', function(result)
    if GetInvokingResource() or type(result) ~= 'table' then return end
    Effects.Apply(result)
end)

RegisterNetEvent('VRCore:Client:OnPlayerUnload', function()
    if active then cancelRequested = true end
    Effects.Reset()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if active then setBusy(false) end
    Effects.StopAll()
end)

exports('IsConsuming', function() return active ~= nil end)
