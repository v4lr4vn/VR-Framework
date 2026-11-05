-- Ways to charge that need the game's help: the player's game says when they are indoors, and the power bank item.
-- (Vehicles, properties and charging points are worked out in status.lua. Rates are in Config.Phone.Battery.charge.)
local Session = Phone.Session
local Battery = Phone.Battery
local Status = Phone.Status

local Charging = {}
Phone.Charging = Charging

local cfg = Config.Phone.Battery.charge or {}
local pack = cfg.powerbank or {}

local using = {} -- src -> true while a power bank is plugged in
local lastUse = {}

local function tell(src, key)
    TriggerClientEvent('vr-phone:client:charging', src, key)
end

-- The player's game reports whether they stand in an interior. It repeats while it is true.
RegisterNetEvent('vr-phone:server:indoors', function(inside)
    local src = source
    if Phone.tooFast and Phone.tooFast(src, 'indoors', 2000) then return end
    local s = Session.get(src)
    if not s then return end
    s.indoors = inside == true and GetGameTimer() or nil
end)

-- Using the power bank item. The item is only used up once the charge has been added.
function Charging.usePack(src)
    if using[src] then return false, 'busy' end
    local s = Session.get(src)
    if not s then return false, 'no_phone' end
    local held = Phone.Identity.resolve(src, false)
    if not held or held.phone_id ~= s.phoneId then return false, 'no_phone' end

    local now = GetGameTimer()
    if lastUse[src] and now - lastUse[src] < (pack.cooldownSeconds or 20) * 1000 then return false, 'busy' end

    local b = Battery.load(s)
    if b.level >= 99.5 then return false, 'full' end

    using[src] = true
    lastUse[src] = now
    local seconds = math.max(1, pack.seconds or 5)
    TriggerClientEvent('vr-phone:client:plug', src, seconds)
    CreateThread(function()
        Wait(seconds * 1000)
        using[src] = nil
        local still = Session.get(src)
        if not still or still.phoneId ~= s.phoneId then return end
        local ped = GetPlayerPed(src)
        if not ped or ped == 0 or GetEntityHealth(ped) <= 0 then return end
        if not Bridge.inventory.remove(src, pack.item, 1) then return tell(src, 'no_pack') end
        Status.ensure(src, still)
        Status.refresh(src, still)
        Battery.add(still, pack.amount or 40)
        Status.refresh(src, still, true)
        tell(src, 'charged')
    end)
    return true
end

CreateThread(function()
    if type(pack.item) ~= 'string' or pack.item == '' then return end
    -- The item may not be known to the inventory yet when this starts.
    Wait(2000)
    if not Bridge.useItem(pack.item, function(src)
        local ok, why = Charging.usePack(src)
        if not ok then tell(src, why) end
    end) then
        print(('^3[vr-phone] the power bank item "%s" could not be made usable (is it in your inventory items?)^0'):format(pack.item))
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    using[src] = nil
    lastUse[src] = nil
end)
