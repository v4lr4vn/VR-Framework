function DebugPrint(...)
    if Config.DebugDisplay then print('[vr-emotes]', ...) end
end

function firstToUpper(str)
    return (str:gsub('^%l', string.upper))
end

function Notify(text, kind)
    if not text or text == '' then return end
    lib.notify({ description = tostring(text), type = kind or 'inform' })
end

SimpleNotify = Notify
ShowNotification = Notify

function EmoteChatMessage(msg)
    Notify(msg, 'error')
end

function IsPlayerAiming(player)
    return IsPlayerFreeAiming(player) or IsAimCamActive() or IsAimCamThirdPersonActive()
end

function CanPlayerCrouchCrawl(ped)
    return IsPedOnFoot(ped) and not IsPedJumping(ped) and not IsPedFalling(ped) and not IsPedInjured(ped)
        and not IsPedInMeleeCombat(ped) and not IsPedRagdoll(ped)
end

function LoadAnim(dict)
    if type(dict) ~= 'string' or not DoesAnimDictExist(dict) then return false end
    local deadline = GetGameTimer() + 2000
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then
            DebugPrint('anim dict timed out', dict)
            return false
        end
        RequestAnimDict(dict)
        Wait(5)
    end
    return true
end

function LoadPropDict(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if HasModelLoaded(hash) then return true end
    if not IsModelValid(hash) then return false end
    local deadline = GetGameTimer() + 2000
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then return false end
        Wait(5)
    end
    return true
end

function RequestWalking(set)
    local deadline = GetGameTimer() + 5000
    while not HasAnimSetLoaded(set) and GetGameTimer() < deadline do
        RequestAnimSet(set)
        Wait(5)
    end
    return HasAnimSetLoaded(set)
end

function PlayAnimOnce(ped, dict, anim, blendIn, blendOut, duration, startTime)
    LoadAnim(dict)
    TaskPlayAnim(ped, dict, anim, blendIn or 2.0, blendOut or 2.0, duration or -1, 0, startTime or 0.0, false, false, false)
    RemoveAnimDict(dict)
end

function ChangeHeadingSmooth(ped, amount, time)
    local times = math.abs(amount)
    if times == 0 then return end
    local step = amount / times
    local wait = time / times
    for _ = 1, times do
        Wait(wait)
        SetEntityHeading(ped, GetEntityHeading(ped) + step)
    end
end

function pairsByKeys(t, f)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, f)
    local i = 0
    return function()
        i = i + 1
        local k = keys[i]
        if k ~= nil then return k, t[k] end
    end
end

function tableHasKey(t, key)
    return t[key] ~= nil
end

function GetClosestPlayer(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local best, bestDist = -1, -1
    for _, id in ipairs(GetActivePlayers()) do
        local other = GetPlayerPed(id)
        if other ~= ped and DoesEntityExist(other) then
            local d = #(GetEntityCoords(other) - coords)
            if (bestDist == -1 or d < bestDist) and (not maxDistance or d <= maxDistance) then
                best, bestDist = id, d
            end
        end
    end
    return best, bestDist
end

function StripLabel(text)
    if type(text) ~= 'string' then return nil end
    local out = text:gsub('<[^>]*>', ''):gsub('~%a~', ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    return out ~= '' and out or nil
end
