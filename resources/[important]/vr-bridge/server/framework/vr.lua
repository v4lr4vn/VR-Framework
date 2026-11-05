local U = Bridge.util
local core

local function getCore()
    if core then return core end
    U.waitFor('vr-core', 30000)
    core = exports['vr-core']:GetCoreObject()
    return core
end

AddEventHandler('VRCore:Server:UpdateObject', function() core = nil end)

local F = Bridge.include('server/framework/qbstyle.lua')({
    name = 'vr',
    table = 'vr_players',
    events = 'VRCore',
    societyEvent = 'VRCore:Server:OnSocietyMoneyChange',
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
    isAdmin = function(src) return getCore().Functions.HasPermission(src, 'admin') == true end,
})

F.societyApi = {
    balance = function(name)
        local fn = getCore().Functions.GetSocietyMoney
        return U.callable(fn) and tonumber(fn(name)) or 0
    end,
    add = function(name, amount, reason)
        local fn = getCore().Functions.AddSocietyMoney
        return U.callable(fn) and fn(name, amount, reason) ~= false
    end,
    remove = function(name, amount, reason)
        local fn = getCore().Functions.RemoveSocietyMoney
        return U.callable(fn) and fn(name, amount, reason) == true
    end,
    events = true,
}

return F
