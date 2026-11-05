lib.callback.register('vr-vehiclekeys:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

local function reply(src, text)
    if src <= 0 then return print(('[vr-vehiclekeys] %s'):format(text)) end
    Core.notify(src, text, 'inform')
end

local function allowed(src)
    if src <= 0 then return true end
    return Bridge.isAdmin(src) == true or IsPlayerAceAllowed(src, 'command.vehkeys')
end

local sub = {}

sub.give = function(src, args)
    local target, plate = tonumber(args[1]), KU.plate(args[2])
    local info = target and Core.info(target)
    if not info or not plate then return reply(src, 'Use /vehkeys give <id> <plate>') end
    Keys.grantTemp(info.cid, plate, Config.Keys.tempMinutes)
    Keys.push(target)
    reply(src, ('%s now has temporary keys to %s'):format(info.name, plate))
end

sub.remove = function(src, args)
    local target, plate = tonumber(args[1]), KU.plate(args[2])
    local info = target and Core.info(target)
    if not info or not plate then return reply(src, 'Use /vehkeys remove <id> <plate>') end
    local done = Keys.revoke(info.cid, plate)
    Keys.push(target)
    reply(src, done and ('Took the keys to %s from %s'):format(plate, info.name) or ('%s has no loose keys to %s'):format(info.name, plate))
end

sub.clear = function(src, args)
    local plate = KU.plate(args[1])
    if not plate then return reply(src, 'Use /vehkeys clear <plate>') end
    local who = Keys.clearPlate(plate)
    Keys.pushAll(who)
    reply(src, ('Removed every loose key to %s (%d people)'):format(plate, #who))
end

sub.who = function(src, args)
    local plate = KU.plate(args[1])
    if not plate then return reply(src, 'Use /vehkeys who <plate>') end
    local owner = Keys.ownerOf(plate)
    local lines = { ('Owner: %s'):format(owner or 'nobody') }
    for _, h in ipairs(Keys.holders(plate)) do
        lines[#lines + 1] = ('%s (%s)%s'):format(h.name, h.cid, h.lent and ' lent' or '')
    end
    reply(src, table.concat(lines, ', '))
end

sub.lock = function(src, args)
    local plate = KU.plate(args[1])
    local veh = plate and Keys.entityFor(plate)
    if not veh then return reply(src, 'That vehicle is not in the world') end
    Keys.setLocked(veh, args[2] ~= 'off')
    reply(src, ('%s is now %s'):format(plate, args[2] == 'off' and 'unlocked' or 'locked'))
end

RegisterCommand('vehkeys', function(src, args)
    if not allowed(src) then return end
    local fn = sub[(args[1] or ''):lower()]
    if not fn then return reply(src, 'Use /vehkeys give, remove, clear, who or lock') end
    table.remove(args, 1)
    fn(src, args)
end, true)

Db.onReady(function()
    Keys.sweep()
    CreateThread(function()
        while true do
            Wait(60000)
            Keys.sweep()
        end
    end)
end)
