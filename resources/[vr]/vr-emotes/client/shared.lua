local partner = nil
local pending = nil

local function sharedEntry(name)
    return RP.Shared[name] and RP.Shared[name] or RP.Dances[name], RP.Shared[name] and 'Shared' or 'Dances'
end

local function attachTo(ped, other, options)
    AttachEntityToEntity(ped, other, GetPedBoneIndex(other, options.bone or -1),
        (options.xPos or 0.0) + 0.0, (options.yPos or 0.0) + 0.0, (options.zPos or 0.0) + 0.0,
        (options.xRot or 0.0) + 0.0, (options.yRot or 0.0) + 0.0, (options.zRot or 0.0) + 0.0,
        false, false, false, true, 1, true)
end

local function otherPed(serverId)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return nil end
    local ped = GetPlayerPed(player)
    return DoesEntityExist(ped) and ped or nil
end

function RequestSharedEmote(name)
    if not Config.SharedEmotesEnabled then return false end
    local entry = RP.Shared[name] or RP.Dances[name]
    if not entry then
        EmoteChatMessage(("'%s' %s"):format(name, Lang.notvalidsharedemote))
        return false
    end
    if Config.AdultEmotesDisabled and Catalog.isAdult(entry, name) then
        EmoteChatMessage(Lang.adultemotedisabled)
        return false
    end
    local target, distance = GetClosestPlayer(Config.SharedDistance)
    if target == -1 or distance > Config.SharedDistance then
        Notify(Lang.nobodyclose, 'error')
        return false
    end
    TriggerServerEvent('vr-emotes:shared:request', GetPlayerServerId(target), name)
    Notify(Lang.sentrequest:format(GetPlayerName(target), StripLabel(entry[3]) or name))
    return true
end

function CancelSharedEmote()
    if partner then
        TriggerServerEvent('vr-emotes:shared:cancel')
        partner = nil
    end
end

RegisterNetEvent('vr-emotes:shared:incoming', function(from, name, fromName)
    if GetInvokingResource() then return end
    local entry = sharedEntry(name)
    if not entry then return end
    local token = {}
    pending = token
    PlaySoundFrontend(-1, 'NAV', 'HUD_AMMO_SHOP_SOUNDSET', true)
    Notify(Lang.incoming:format(fromName or 'Someone', StripLabel(entry[3]) or name) .. '\nPress Y to accept or L to decline.')
    SendEmoteUi('request', { from = from, label = StripLabel(entry[3]) or name, who = fromName, seconds = Config.SharedRequestSeconds })
    local deadline = GetGameTimer() + Config.SharedRequestSeconds * 1000
    CreateThread(function()
        while pending == token do
            if GetGameTimer() > deadline then
                pending = nil
                SendEmoteUi('request', false)
                Notify(Lang.expired)
                return
            end
            if IsControlJustPressed(1, 246) then
                pending = nil
                SendEmoteUi('request', false)
                TriggerServerEvent('vr-emotes:shared:accept', from)
                return
            end
            if IsControlJustPressed(1, 182) then
                pending = nil
                SendEmoteUi('request', false)
                TriggerServerEvent('vr-emotes:shared:decline', from)
                Notify(Lang.refused)
                return
            end
            Wait(0)
        end
    end)
end)

RegisterNetEvent('vr-emotes:shared:declined', function()
    if GetInvokingResource() then return end
    Notify(Lang.refused, 'error')
end)

RegisterNetEvent('vr-emotes:shared:play', function(name, other, leading)
    if GetInvokingResource() then return end
    local entry, tbl = sharedEntry(name)
    if not entry then return end
    local ped = PlayerPedId()
    local otherP = otherPed(other)
    if not otherP then return end
    local options = entry.AnimationOptions or {}

    if leading then
        local front = (options.SyncOffsetFront or 1.0) + 0.0
        local side = (options.SyncOffsetSide or 0.0) + 0.0
        local height = (options.SyncOffsetHeight or 0.0) + 0.0
        local heading = (options.SyncOffsetHeading or 180.1) + 0.0
        partner = nil
        EmoteCancel()
        local pos = GetOffsetFromEntityInWorldCoords(otherP, side, front, height)
        SetEntityHeading(ped, GetEntityHeading(otherP) - heading)
        SetEntityCoordsNoOffset(ped, pos.x, pos.y, pos.z, false, false, false)
        if options.Attachto then attachTo(ped, otherP, options) end
        Wait(300)
    else
        partner = nil
        EmoteCancel()
        Wait(300)
        if options.Attachto then
            local targetName = entry[4]
            local targetEntry = targetName and RP[tbl][targetName]
            if not (targetEntry and targetEntry.AnimationOptions and targetEntry.AnimationOptions.Attachto) then
                attachTo(ped, otherP, options)
            end
        end
    end
    partner = other
    OnEmotePlay(entry, name, nil, tbl)
end)

RegisterNetEvent('vr-emotes:shared:stop', function(other)
    if GetInvokingResource() then return end
    if partner and partner == other then
        partner = nil
        EmoteCancel()
    end
end)

if Config.SharedEmotesEnabled then
    RegisterCommand('nearby', function(_, args)
        if not args[1] then return OpenEmoteMenu('shared') end
        RequestSharedEmote(tostring(args[1]):lower())
    end, false)
    TriggerEvent('chat:addSuggestion', '/nearby', 'Do a shared emote with the closest player', { { name = 'emote', help = 'hug, handshake… or leave empty to open the menu' } })
end
