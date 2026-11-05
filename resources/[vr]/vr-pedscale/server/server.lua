local VRCore = exports['vr-core']:GetCoreObject({ 'Functions', 'Commands' })

local function heightOf(pd)
    local cm = pd and pd.charinfo and tonumber(pd.charinfo.height)
    return cm and Config.ClampHeight(cm) or nil
end

local function setState(src, cm)
    Player(src).state:set('vrHeight', cm, true)
end

AddEventHandler('VRCore:Server:PlayerLoaded', function(player)
    local pd = player and player.PlayerData
    if pd and pd.source then setState(pd.source, heightOf(pd)) end
end)

AddEventHandler('VRCore:Server:OnPlayerUnload', function(src)
    setState(src, nil)
end)

CreateThread(function()
    for _, id in ipairs(GetPlayers()) do
        local player = exports['vr-core']:GetPlayer(tonumber(id))
        if player then setState(player.PlayerData.source, heightOf(player.PlayerData)) end
    end
end)

local function setHeight(src, cm)
    local player = exports['vr-core']:GetPlayer(tonumber(src))
    if not player then return false end
    cm = Config.ClampHeight(cm)
    local charinfo = player.PlayerData.charinfo or {}
    charinfo.height = cm
    player.Functions.SetPlayerData('charinfo', charinfo)
    setState(player.PlayerData.source, cm)
    return cm
end

exports('SetHeight', setHeight)
exports('GetHeight', function(src)
    local player = exports['vr-core']:GetPlayer(tonumber(src))
    return player and heightOf(player.PlayerData) or nil
end)
exports('FormatHeight', Config.FormatHeight)
exports('GetLimits', function()
    return { min = Config.MinHeight, max = Config.MaxHeight, default = Config.DefaultHeight }
end)

local function parseHeight(text)
    text = tostring(text or '')
    local ft, inch = text:match("^(%d+)'%s*(%d*)")
    if ft then return (tonumber(ft) * 12 + (tonumber(inch) or 0)) * 2.54 end
    local n = tonumber(text)
    if not n then return nil end
    if n <= 8 then return n * 30.48 end
    return n
end

VRCore.Commands.Add('setheight', "Set a player's height (admin)", {
    { name = 'id', help = 'Player ID' },
    { name = 'height', help = "cm (e.g. 178) or feet (e.g. 5'10)" },
}, true, function(source, args)
    local target = tonumber(args[1])
    local cm = parseHeight(args[2])
    if not target or not cm then
        return TriggerClientEvent('VRCore:Notify', source, "Usage: /setheight [id] [cm or 5'10]", 'error')
    end
    local set = setHeight(target, cm)
    if not set then
        return TriggerClientEvent('VRCore:Notify', source, 'That player is not loaded in.', 'error')
    end
    TriggerClientEvent('VRCore:Notify', source, ('Height set to %s'):format(Config.FormatHeight(set)), 'success')
end, 'admin')
