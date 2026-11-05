local core
local function getCore()
    if not core then core = exports['vr-core']:GetCoreObject() end
    return core
end
AddEventHandler('VRCore:Client:UpdateObject', function() core = nil end)
return Bridge.include('client/framework/qbstyle.lua')({
    events = 'VRCore',
    playerData = function() return getCore().Functions.GetPlayerData() end,
    notify = function(msg, kind, ms) getCore().Functions.Notify(msg, kind or 'primary', ms) end,
})
