local ChosenDict, ChosenAnimation, ChosenOptions = '', '', nil
local AnimationDuration = -1
local PlayerGender = 'male'
local PlayerProps = {}
local PlayerParticles = {}
local Ptfx = { prompt = false, shown = false, wait = 500, canHold = false, noProp = false, info = nil }
local threadOn = false
local CanCancel = true
local InExitEmote = false
local ExitAndPlay = false
local CancelPlaying = false
local LastProp = nil

IsInAnimation = false
CurrentAnimationName = nil
CurrentAnimationTable = nil
inHandsup = false
Pointing = false

local function scenario(dict)
    return dict == 'Scenario' or dict == 'MaleScenario' or dict == 'ScenarioObject'
end

local function stripInvalid()
    for _, tbl in ipairs({ 'Shared', 'Dances', 'AnimalEmotes', 'Emotes', 'PropEmotes', 'White2do', 'White3ro', 'White5to', 'Exits' }) do
        for key, entry in pairs(RP[tbl] or {}) do
            local dict = entry[1]
            if type(dict) == 'string' and not scenario(dict) and not DoesAnimDictExist(dict) then RP[tbl][key] = nil end
        end
    end
end

CreateThread(stripInvalid)

local function tableFor(name)
    if CurrentAnimationTable and RP[CurrentAnimationTable] and RP[CurrentAnimationTable][name] then return CurrentAnimationTable end
    local _, tbl = Catalog.find(name)
    if tbl then return tbl end
    if RP.Shared[name] then return 'Shared' end
end

function PtfxStart()
    TriggerServerEvent('vr-emotes:ptfx', true)
end

function PtfxStop()
    TriggerServerEvent('vr-emotes:ptfx', false)
end

local function ptfxAsset(asset)
    local deadline = GetGameTimer() + 3000
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer() < deadline do
        RequestNamedPtfxAsset(asset)
        Wait(10)
    end
    UseParticleFxAsset(asset)
end

AddStateBagChangeHandler('ptfx', nil, function(bagName, _, value)
    local serverId = tonumber((bagName:gsub('player:', '')), 10)
    if not serverId then return end
    if (PlayerParticles[serverId] and value) or (not PlayerParticles[serverId] and not value) then return end
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return end
    local bag = Player(serverId).state
    if value then
        local asset, name, offset, rot = bag.ptfxAsset, bag.ptfxName, bag.ptfxOffset, bag.ptfxRot
        if type(asset) ~= 'string' or type(name) ~= 'string' or not offset or not rot then return end
        local bone = bag.ptfxBone and GetPedBoneIndex(ped, bag.ptfxBone) or GetEntityBoneIndexByName(name, 'VFX')
        local target = ped
        if bag.ptfxPropNet then
            local obj = NetToObj(bag.ptfxPropNet)
            if DoesEntityExist(obj) then target = obj end
        end
        ptfxAsset(asset)
        local handle = StartNetworkedParticleFxLoopedOnEntityBone(name, target, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, bone, (bag.ptfxScale or 1) + 0.0, false, false, false, 1065353216, 1065353216, 1065353216, false)
        PlayerParticles[serverId] = handle
        local color = bag.ptfxColor
        if type(color) == 'table' then
            if type(color[1]) == 'table' then color = color[math.random(1, #color)] end
            if color.A then SetParticleFxLoopedAlpha(handle, color.A) end
            if color.R then SetParticleFxLoopedColour(handle, color.R / 255, color.G / 255, color.B / 255, false) end
        end
    else
        StopParticleFxLooped(PlayerParticles[serverId], false)
        if bag.ptfxAsset then RemoveNamedPtfxAsset(bag.ptfxAsset) end
        PlayerParticles[serverId] = nil
    end
end)

local function runThread()
    if threadOn then return end
    threadOn = true
    CreateThread(function()
        local playerId = PlayerId()
        while threadOn and (IsInAnimation or Ptfx.prompt) do
            local sleep = 500
            if IsInAnimation then
                sleep = 0
                if IsPlayerAiming(playerId) then EmoteCancel() end
            end
            if Ptfx.prompt then
                sleep = 0
                if not Ptfx.shown then
                    Notify(Ptfx.info)
                    Ptfx.shown = true
                end
                if IsControlPressed(0, 47) then
                    PtfxStart()
                    Wait(Ptfx.wait or 500)
                    if Ptfx.canHold then
                        while IsControlPressed(0, 47) and IsInAnimation and threadOn do Wait(5) end
                    end
                    PtfxStop()
                end
            end
            Wait(sleep)
        end
        threadOn = false
    end)
end

function PlayerPropList()
    return PlayerProps
end

function DestroyAllProps()
    for _, obj in pairs(PlayerProps) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
    end
    PlayerProps = {}
end

function AddPropToPed(ped, model, bone, placement, textureVariation, networked, store)
    if type(model) ~= 'string' or not LoadPropDict(model) then
        DebugPrint('bad prop', model)
        return nil
    end
    local pos = GetEntityCoords(ped)
    local obj = CreateObject(joaat(model), pos.x, pos.y, pos.z + 0.2, networked, networked, false)
    if textureVariation then SetObjectTextureVariation(obj, textureVariation) end
    local p = placement or {}
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, bone or 60309), (p[1] or 0.0) + 0.0, (p[2] or 0.0) + 0.0, (p[3] or 0.0) + 0.0,
        (p[4] or 0.0) + 0.0, (p[5] or 0.0) + 0.0, (p[6] or 0.0) + 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(joaat(model))
    if store then store[#store + 1] = obj end
    return obj
end

local function checkGender(ped)
    PlayerGender = GetEntityModel(ped) == joaat('mp_f_freemode_01') and 'female' or 'male'
end

function MovementFor(options, inVehicle)
    if inVehicle then return 51 end
    if options then
        if options.EmoteMoving then return 51 end
        if options.EmoteLoop then return 1 end
        if options.EmoteStuck then return 50 end
    end
    return 0
end

function CheckAnimalAndOnEmotePlay(entry, name)
    local list = name:sub(1, 4) == 'bdog' and BigDogs or name:sub(1, 4) == 'sdog' and SmallDogs or nil
    if not list then return OnEmotePlay(entry, name, nil, 'AnimalEmotes') end
    local model = GetEntityModel(PlayerPedId())
    for _, m in ipairs(list) do
        if model == joaat(m) then return OnEmotePlay(entry, name, nil, 'AnimalEmotes') end
    end
    EmoteChatMessage(Lang.notvalidpet)
end

function EmoteCancel(force)
    CancelPlaying = true
    if InExitEmote then return end
    local ped = PlayerPedId()
    if not CanCancel and force ~= true then return end
    if (ChosenDict == 'MaleScenario' or ChosenDict == 'Scenario' or ChosenDict == 'ScenarioObject') and IsInAnimation then
        ClearPedTasksImmediately(ped)
        IsInAnimation = false
    end
    Ptfx.shown = false
    Ptfx.prompt = false
    Pointing = false

    if IsInAnimation then
        if LocalPlayer.state.ptfx then PtfxStop() end
        DetachEntity(ped, true, false)
        CancelSharedEmote()
        if ChosenOptions and ChosenOptions.ExitEmote then
            local exitTable = ChosenOptions.ExitEmoteType or 'Emotes'
            local exitEntry = RP[exitTable] and RP[exitTable][ChosenOptions.ExitEmote]
            if not exitEntry then
                ClearPedTasks(ped)
                IsInAnimation = false
                DestroyAllProps()
                threadOn = false
                CancelPlaying = false
                return
            end
            OnEmotePlay(exitEntry, ChosenOptions.ExitEmote, nil, exitTable)
            local opts = exitEntry.AnimationOptions
            if opts and opts.EmoteDuration and opts.EmoteDuration > 0 then
                InExitEmote = true
                SetTimeout(opts.EmoteDuration, function()
                    InExitEmote = false
                    DestroyAllProps()
                    ClearPedTasks(ped)
                    IsInAnimation = false
                    CancelPlaying = false
                end)
                return
            end
        else
            ClearPedTasks(ped)
            IsInAnimation = false
        end
        DestroyAllProps()
    end
    CurrentAnimationName = nil
    CurrentAnimationTable = nil
    CancelPlaying = false
    threadOn = false
end

local function playExitThenEnter(entry, name, textureVariation, tbl)
    local ped = PlayerPedId()
    if scenario(ChosenDict) and IsInAnimation then
        ClearPedTasksImmediately(ped)
        IsInAnimation = false
    end
    Ptfx.shown = false
    Ptfx.prompt = false
    Pointing = false
    if LocalPlayer.state.ptfx then PtfxStop() end
    DetachEntity(ped, true, false)
    CancelSharedEmote()
    local exit = ChosenOptions and ChosenOptions.ExitEmote
    local exitTable = ChosenOptions and ChosenOptions.ExitEmoteType or 'Emotes'
    local exitEntry = exit and RP[exitTable] and RP[exitTable][exit]
    if exitEntry then
        OnEmotePlay(exitEntry, exit, nil, exitTable)
        local opts = exitEntry.AnimationOptions
        if opts and opts.EmoteDuration and opts.EmoteDuration > 0 then
            InExitEmote = true
            SetTimeout(opts.EmoteDuration, function()
                InExitEmote = false
                DestroyAllProps()
                ClearPedTasks(ped)
                OnEmotePlay(entry, name, textureVariation, tbl)
                ExitAndPlay = false
            end)
            return
        end
    end
    ClearPedTasks(ped)
    IsInAnimation = false
    DestroyAllProps()
    OnEmotePlay(entry, name, textureVariation, tbl)
    ExitAndPlay = false
end

function OnEmotePlay(entry, name, textureVariation, tbl)
    local ped = PlayerPedId()
    if type(entry) ~= 'table' or not DoesEntityExist(ped) then return false end
    local inVehicle = IsPedInAnyVehicle(ped, true)
    Pointing = false
    tbl = tbl or tableFor(name)

    if not Config.AllowedInCars and inVehicle then return false end
    if Config.AdultEmotesDisabled and Catalog.isAdult(entry, name) then return EmoteChatMessage(Lang.adultemotedisabled) end
    if InExitEmote then return false end
    if IsEntityDead(ped) then return EmoteChatMessage(Lang.dead) end
    if not Config.AllowInWater and (IsPedSwimming(ped) or IsPedSwimmingUnderWater(ped)) then return EmoteChatMessage(Lang.swimming) end

    if Config.CancelPreviousEmote and IsInAnimation and not ExitAndPlay and not CancelPlaying then
        ExitAndPlay = true
        return playExitThenEnter(entry, name, textureVariation, tbl)
    end

    local options = entry.AnimationOptions
    if inVehicle then
        if options and options.NotInVehicle then return EmoteChatMessage(Lang.not_in_a_vehicle) end
    elseif options and options.onlyInVehicle then
        return EmoteChatMessage(Lang.in_a_vehicle)
    end

    if ChosenOptions and ChosenOptions.ExitEmote and IsInAnimation then
        local exitEntry = RP.Exits[ChosenOptions.ExitEmote]
        if not (options and ChosenOptions.ExitEmote == options.ExitEmote) and exitEntry and exitEntry[2] ~= entry[2] then return false end
    end

    if IsProne then
        EmoteChatMessage(Lang.no_anim_crawling)
        return false
    end

    ChosenDict, ChosenAnimation = entry[1], entry[2]
    local label = entry[3] or name
    CurrentAnimationName = name
    CurrentAnimationTable = tbl
    ChosenOptions = options
    AnimationDuration = -1

    if Config.DisarmPlayer and IsPedArmed(ped, 7) then
        SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    end

    if options and options.Prop then DestroyAllProps() end

    if scenario(ChosenDict) then
        if inVehicle then return false end
        checkGender(ped)
        if ChosenDict == 'MaleScenario' and PlayerGender ~= 'male' then
            DestroyAllProps()
            EmoteCancel()
            EmoteChatMessage(Lang.maleonly)
            return false
        end
        ClearPedTasks(ped)
        DestroyAllProps()
        if ChosenDict == 'ScenarioObject' then
            local behind = GetOffsetFromEntityInWorldCoords(ped, 0.0, -0.5, -0.5)
            TaskStartScenarioAtPosition(ped, ChosenAnimation, behind.x, behind.y, behind.z, GetEntityHeading(ped), 0, true, false)
        else
            TaskStartScenarioInPlace(ped, ChosenAnimation, 0, true)
        end
        IsInAnimation = true
        runThread()
        return true
    end

    if options and options.StartDelay then Wait(options.StartDelay) end

    if not LoadAnim(ChosenDict) then
        EmoteChatMessage(("'%s' %s"):format(StripLabel(label) or name, Lang.notvalidemote))
        return false
    end

    local movement = MovementFor(options, inVehicle)
    local attachWait = 0
    if options and options.EmoteDuration and options.EmoteDuration > 0 then
        AnimationDuration = options.EmoteDuration
        attachWait = options.EmoteDuration
    end

    if options and options.PtfxAsset then
        Ptfx.noProp = options.PtfxNoProp == true
        Ptfx.info = options.PtfxInfo
        Ptfx.wait = options.PtfxWait
        Ptfx.canHold = options.PtfxCanHold
        Ptfx.shown = false
        Ptfx.prompt = true
        if tbl then TriggerServerEvent('vr-emotes:ptfx:sync', tbl .. ':' .. name) end
    else
        Ptfx.prompt = false
    end

    if IsPedUsingAnyScenario(ped) or IsPedActiveInScenario(ped) then ClearPedTasksImmediately(ped) end

    TaskPlayAnim(ped, ChosenDict, ChosenAnimation, 5.0, 5.0, AnimationDuration, movement, 0, false, false, false)
    RemoveAnimDict(ChosenDict)
    IsInAnimation = true
    runThread()

    if options and options.Prop then
        if attachWait > 0 then Wait(attachWait) end
        LastProp = AddPropToPed(ped, options.Prop, options.PropBone, options.PropPlacement, textureVariation, true, PlayerProps)
        if not LastProp then return true end
        if options.SecondProp then
            if not AddPropToPed(ped, options.SecondProp, options.SecondPropBone, options.SecondPropPlacement, textureVariation, true, PlayerProps) then
                DestroyAllProps()
                return true
            end
        end
        if options.PtfxAsset and not Ptfx.noProp then
            TriggerServerEvent('vr-emotes:ptfx:prop', ObjToNet(LastProp))
        end
    end
    return true
end

function PlayEmoteById(id, textureVariation)
    local entry, tbl, key = Catalog.get(id)
    if not entry then return false end
    local ok, why = Catalog.allowed(entry, tbl, key)
    if not ok then
        EmoteChatMessage(why == 'adult' and Lang.adultemotedisabled or Lang.animaldisabled)
        return false
    end
    if tbl == 'Shared' then return RequestSharedEmote(key) end
    if tbl == 'AnimalEmotes' then return CheckAnimalAndOnEmotePlay(entry, key) end
    return OnEmotePlay(entry, key, textureVariation, tbl)
end

function EmoteCommandStart(_, args)
    if #args == 0 then return OpenEmoteMenu() end
    local name = tostring(args[1]):lower()
    if name == 'c' then
        if IsInAnimation then EmoteCancel() else Notify(Lang.nocancel) end
        return
    end
    if name == 'help' then return OpenEmoteMenu() end
    local entry, tbl = Catalog.find(name)
    if not entry then
        if RP.Shared[name] then return RequestSharedEmote(name) end
        return EmoteChatMessage(("'%s' %s"):format(name, Lang.notvalidemote))
    end
    local ok, why = Catalog.allowed(entry, tbl, name)
    if not ok then return EmoteChatMessage(why == 'adult' and Lang.adultemotedisabled or Lang.animaldisabled) end
    if tbl == 'AnimalEmotes' then return CheckAnimalAndOnEmotePlay(entry, name) end
    local variation
    local variations = entry.AnimationOptions and entry.AnimationOptions.PropTextureVariations
    if variations and args[2] then
        local n = tonumber(args[2])
        if n and variations[n] then variation = n - 1 end
    end
    OnEmotePlay(entry, name, variation, tbl)
end

local function replay()
    local tbl, name = CurrentAnimationTable, CurrentAnimationName
    if not tbl or not name or not RP[tbl] or not RP[tbl][name] then return end
    if tbl ~= 'Emotes' and tbl ~= 'PropEmotes' then return end
    ClearPedTasks(PlayerPedId())
    DestroyAllProps()
    OnEmotePlay(RP[tbl][name], name, nil, tbl)
end

function Handsup()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) and not Config.HandsupInCar and not inHandsup then return end
    inHandsup = not inHandsup
    if inHandsup then
        DestroyAllProps()
        if LoadAnim('random@mugging3') then
            TaskPlayAnim(ped, 'random@mugging3', 'handsup_standing_base', 2.0, 2.0, -1, 49, 0, false, false, false)
        end
    else
        ClearPedSecondaryTask(ped)
        if Config.PersistentEmoteAfterHandsup and IsInAnimation then
            Wait(400)
            replay()
        end
    end
end

local openingDoor = false
AddEventHandler('CEventOpenDoor', function()
    if not IsInAnimation or openingDoor then return end
    openingDoor = true
    while IsPedOpeningADoor(PlayerPedId()) do Wait(100) end
    openingDoor = false
    Wait(200)
    if IsInAnimation then replay() end
end)

AddEventHandler('CEventPlayerCollisionWithPed', function()
    if not IsInAnimation then return end
    Wait(500)
    if IsInAnimation then replay() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    DestroyAllProps()
    if IsInAnimation then ClearPedTasksImmediately(ped) end
    DetachEntity(ped, true, false)
    threadOn = false
end)

RegisterCommand('e', EmoteCommandStart, false)
RegisterCommand('emote', EmoteCommandStart, false)
RegisterCommand('emotecancel', function() EmoteCancel() end, false)
if Config.HandsupEnabled then RegisterCommand('handsup', function() Handsup() end, false) end

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/e', 'Play an emote', { { name = 'emote', help = 'dance, sit, wave… or leave empty to open the menu' }, { name = 'variation', help = 'Optional prop colour number' } })
    TriggerEvent('chat:addSuggestion', '/emote', 'Play an emote', { { name = 'emote', help = 'dance, sit, wave… or leave empty to open the menu' } })
    TriggerEvent('chat:addSuggestion', '/emotecancel', 'Stop your current emote')
    if Config.HandsupEnabled then TriggerEvent('chat:addSuggestion', '/handsup', 'Put your hands up') end
end)

exports('EmoteCommandStart', function(name, variation) EmoteCommandStart(nil, { name, variation }) end)
exports('EmoteCancel', EmoteCancel)
exports('CanCancelEmote', function(state) CanCancel = state == true end)
exports('IsPlayerInAnim', function() return IsInAnimation end)
exports('PlayEmote', function(id, variation) return PlayEmoteById(id, variation) end)
exports('IsPlayerInHandsUp', function() return inHandsup end)
