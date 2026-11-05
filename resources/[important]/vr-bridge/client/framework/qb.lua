local core
local function getCore()
    if not core then core = exports['qb-core']:GetCoreObject() end
    return core
end
AddEventHandler('QBCore:Client:UpdateObject', function() core = nil end)
return Bridge.include('client/framework/qbstyle.lua')({
    events = 'QBCore',
    playerData = function() return getCore().Functions.GetPlayerData() end,
    notify = function(msg, kind, ms) getCore().Functions.Notify(msg, kind or 'primary', ms) end,
    textUI = {
        show = function(text) exports['qb-core']:DrawText(text, 'left') end,
        hide = function() exports['qb-core']:HideText() end,
    },
})
