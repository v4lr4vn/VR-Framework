local canChange = true
local unableMessage = nil

CurrentWalk = nil
CurrentMood = nil

local function walkKey(name)
    if type(name) ~= 'string' then return nil end
    local key = firstToUpper(name:lower())
    if RP.Walks[key] then return key end
    for k in pairs(RP.Walks) do
        if k:lower() == name:lower() then return k end
    end
end

function WalkMenuStart(clipset, save)
    if not canChange then return EmoteChatMessage(unableMessage or Lang.walkunavailable) end
    if type(clipset) ~= 'string' or not RequestWalking(clipset) then return false end
    SetPedMovementClipset(PlayerPedId(), clipset, 0.2)
    RemoveAnimSet(clipset)
    CurrentWalk = clipset
    if save ~= false and SavePref then SavePref('walk', clipset) end
    return true
end

function ResetWalk(save)
    if not canChange then return EmoteChatMessage(unableMessage or Lang.walkunavailable) end
    ResetPedMovementClipset(PlayerPedId(), 0.2)
    CurrentWalk = nil
    if save ~= false and SavePref then SavePref('walk', false) end
end

function SetWalkByKey(key)
    local entry = RP.Walks[key]
    if not entry then return false end
    return WalkMenuStart(entry[1])
end

function SetPlayerPedExpression(expression, save)
    if type(expression) ~= 'string' then return end
    SetFacialIdleAnimOverride(PlayerPedId(), expression, 0)
    CurrentMood = expression
    if save ~= false and SavePref then SavePref('mood', expression) end
end

function ResetMood(save)
    ClearFacialIdleAnimOverride(PlayerPedId())
    CurrentMood = nil
    if save ~= false and SavePref then SavePref('mood', false) end
end

function SetMoodByKey(key)
    local entry = RP.Expressions[key]
    if not entry then return false end
    SetPlayerPedExpression(entry[1], true)
    return true
end

CreateThread(function()
    while true do
        Wait(15000)
        local ped = PlayerPedId()
        if CurrentWalk and not IsProne and canChange and GetPedMovementClipset(ped) ~= joaat(CurrentWalk) and IsPedOnFoot(ped) then
            WalkMenuStart(CurrentWalk, false)
        end
    end
end)

if Config.WalkingStylesEnabled then
    RegisterCommand('walk', function(_, args)
        local name = args[1]
        if not name then return OpenEmoteMenu('walks') end
        if name:lower() == 'reset' then return ResetWalk() end
        local key = walkKey(name)
        if key then SetWalkByKey(key) else EmoteChatMessage(("'%s' %s"):format(name, Lang.notvalidwalk)) end
    end, false)
    RegisterCommand('walks', function() OpenEmoteMenu('walks') end, false)
    TriggerEvent('chat:addSuggestion', '/walk', 'Set how you walk', { { name = 'style', help = 'A walking style, or reset' } })
    TriggerEvent('chat:addSuggestion', '/walks', 'Browse walking styles')
end

if Config.ExpressionsEnabled then
    RegisterCommand('mood', function(_, args)
        local name = args[1]
        if not name then return OpenEmoteMenu('moods') end
        if name:lower() == 'reset' then return ResetMood() end
        local key = firstToUpper(name:lower())
        if RP.Expressions[key] then SetMoodByKey(key) else EmoteChatMessage(("'%s' %s"):format(name, Lang.notvalidmood)) end
    end, false)
    RegisterCommand('moods', function() OpenEmoteMenu('moods') end, false)
    TriggerEvent('chat:addSuggestion', '/mood', 'Set your facial expression', { { name = 'mood', help = 'A mood, or reset' } })
    TriggerEvent('chat:addSuggestion', '/moods', 'Browse moods')
end

exports('toggleWalkstyle', function(state, message)
    canChange = state == true
    unableMessage = message
end)
exports('getWalkstyle', function() return CurrentWalk end)
exports('setWalkstyle', function(clipset) return WalkMenuStart(clipset) end)
exports('resetWalkstyle', function() ResetWalk() end)
