local U = Bridge.util
local core

local function getCore()
    if core then return core end
    U.waitFor('qb-core', 30000)
    core = exports['qb-core']:GetCoreObject()
    return core
end

AddEventHandler('QBCore:Server:UpdateObject', function() core = nil end)

return Bridge.include('server/framework/qbstyle.lua')({
    name = 'qb',
    table = 'players',
    events = 'QBCore',
    core = getCore,
    getPlayer = function(src) return src and getCore().Functions.GetPlayer(src) or nil end,
    getPlayerByCid = function(cid) return getCore().Functions.GetPlayerByCitizenId(cid) end,
    sources = function()
        local out = {}
        for _, s in ipairs(getCore().Functions.GetPlayers()) do out[#out + 1] = tonumber(s) end
        return out
    end,
    jobs = function() return getCore().Shared.Jobs end,
    gangs = function() return getCore().Shared.Gangs end,
    vehicleList = function() return getCore().Shared.Vehicles end,
    notify = function(src, msg, kind, ms) getCore().Functions.Notify(src, msg, kind or 'primary', ms) end,
    isAdmin = function(src)
        local fn = getCore().Functions.HasPermission
        return (U.callable(fn) and (fn(src, 'admin') == true or fn(src, 'god') == true)) or IsPlayerAceAllowed(src, 'command')
    end,
})
