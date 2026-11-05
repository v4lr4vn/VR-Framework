return Bridge.include('client/framework/qbstyle.lua')({
    events = 'QBCore',
    playerData = function() return exports.qbx_core:GetPlayerData() end,
    notify = function(msg, kind, ms) exports.qbx_core:Notify(msg, kind or 'inform', ms) end,
})
