local U = Bridge.util

local function qbx()
    U.waitFor('qbx_core', 30000)
    return exports.qbx_core
end

local function items()
    if U.started('ox_inventory') then return exports.ox_inventory:Items() or {} end
    return {}
end

return Bridge.include('server/framework/qbstyle.lua')({
    name = 'qbx',
    table = 'players',
    events = 'QBCore',
    core = function() return { Shared = { Items = items() } } end,
    getPlayer = function(src) return src and qbx():GetPlayer(src) or nil end,
    getPlayerByCid = function(cid) return qbx():GetPlayerByCitizenId(cid) end,
    sources = function()
        local out = {}
        for src in pairs(qbx():GetQBPlayers() or {}) do out[#out + 1] = tonumber(src) end
        return out
    end,
    jobs = function() return qbx():GetJobs() end,
    gangs = function() return qbx():GetGangs() end,
    vehicleList = function() return qbx():GetVehiclesByName() end,
    items = items,
    useItem = function(name, fn) qbx():CreateUseableItem(name, fn) return true end,
    canUseItem = function(name) return qbx():CanUseItem(name) end,
    notify = function(src, msg, kind, ms) qbx():Notify(src, msg, kind or 'inform', ms) end,
    isAdmin = function(src) return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'admin') end,
})
