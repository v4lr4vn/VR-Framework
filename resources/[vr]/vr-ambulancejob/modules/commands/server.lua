local VRCore     = exports['vr-core']:GetCoreObject()
local config     = lib.load("config")
local permission = config.adminPermission or "admin"

local function reply(source, key, ...)
    local text = locale(key, ...)

    if source > 0 then
        TriggerClientEvent("vr-ambulancejob:showNotification", source, text)
    else
        print("^4vr-ambulancejob > ^0" .. text)
    end
end

local function targetFrom(source, arg)
    if arg == nil then return source > 0 and source or nil end
    return tonumber(arg)
end

local function radiusFrom(arg)
    local radius = tonumber(arg)
    if not radius or radius ~= radius or radius <= 0 then return nil end
    return math.min(radius, config.maxAreaRadius or 500.0)
end

local function playersInRadius(source, radius)
    local origin = GetEntityCoords(GetPlayerPed(source))
    local bucket = GetPlayerRoutingBucket(source)
    local found = {}
    local players = Framework.getPlayers()

    for i = 1, #players do
        local id = players[i]
        local ped = GetPlayerPed(id)

        if ped ~= 0 and GetPlayerRoutingBucket(id) == bucket and #(GetEntityCoords(ped) - origin) <= radius then
            found[#found + 1] = id
        end
    end

    return found
end

VRCore.Commands.Add(config.reviveCommand, locale("revive_player"), {
    { name = "id", help = "Target player's server id (optional)" },
}, false, function(source, args)
    local target = targetFrom(source, args[1])
    if not target or not RevivePlayer(target) then return reply(source, "player_not_found") end

    reply(source, "revived_player", target)
end, permission)

VRCore.Commands.Add(config.reviveAreaCommand, locale("revive_area"), {
    { name = "radius", help = "to revive players in radius" },
}, true, function(source, args)
    if source <= 0 then return print("^4vr-ambulancejob > ^0You cant run this command from console") end

    local radius = radiusFrom(args[1])
    if not radius then return reply(source, "invalid_radius") end

    local players = playersInRadius(source, radius)
    for i = 1, #players do RevivePlayer(players[i]) end

    reply(source, "revived_area", radius)
end, permission)

VRCore.Commands.Add(config.healCommand, locale("heal_player"), {
    { name = "id", help = "Target player's server id (optional)" },
}, false, function(source, args)
    local target = targetFrom(source, args[1])
    if not target or not HealPlayer(target) then return reply(source, "player_not_found") end

    reply(source, "healed_player", target)
end, permission)

VRCore.Commands.Add(config.healAreaCommand, locale("heal_area"), {
    { name = "radius", help = "to heal players in radius" },
}, true, function(source, args)
    if source <= 0 then return print("^4vr-ambulancejob > ^0You cant run this command from console") end

    local radius = radiusFrom(args[1])
    if not radius then return reply(source, "invalid_radius") end

    local players = playersInRadius(source, radius)
    for i = 1, #players do HealPlayer(players[i]) end

    reply(source, "healed_area", radius)
end, permission)

VRCore.Commands.Add(config.reviveAllCommand, locale("revive_all"), {}, false, function(source)
    local players = Framework.getPlayers()
    for i = 1, #players do RevivePlayer(players[i]) end

    reply(source, "revived_all")
end, permission)
