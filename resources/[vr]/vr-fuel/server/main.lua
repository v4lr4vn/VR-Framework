-- Money and the petrol can item are handled here. The client only chooses how much it wants;
-- the server prices it, takes the money first and refunds what was not delivered.
local open = {}        -- [src] = { units, price, rate }  one pump fill at a time
local lastBuy = {}     -- [src] = game time of the last purchase

-- Petrol cans are weapon items whose level lives in the item metadata, so they need an ox-style inventory.
local function inventory()
    if Bridge.inventoryName ~= 'ox' then return nil end
    return GetResourceState(Bridge.inventoryResource) == 'started' and exports[Bridge.inventoryResource] or nil
end

local function atStation(src)
    if not Config.StationRadius then return true end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local pos = GetEntityCoords(ped)
    for i = 1, #Config.Stations do
        if #(pos - Config.Stations[i]) <= Config.StationRadius then return true end
    end
    return false
end

local function tooSoon(src)
    local t = GetGameTimer()
    if lastBuy[src] and t - lastBuy[src] < (Config.PurchaseCooldown or 2) * 1000 then return true end
    lastBuy[src] = t
    return false
end

local function wholeNumber(v, max)
    local n = tonumber(v)
    if not n or n ~= n or n % 1 ~= 0 or n < 1 or n > max then return nil end
    return math.floor(n)
end

local function charge(src, amount, reason)
    if amount <= 0 then return true end
    return Bridge.removeMoney(src, Config.MoneyType, amount, reason) and true or false
end

local function refund(src, amount, reason)
    if amount > 0 then Bridge.addMoney(src, Config.MoneyType, amount, reason) end
end

AddEventHandler('playerDropped', function()
    open[source], lastBuy[source] = nil, nil
end)

-- Pump: reserve and pay for up to `units` percent.
lib.callback.register('vr-fuel:begin', function(src, units)
    if not Bridge.cid(src) then return false, 'error' end
    units = wholeNumber(units, math.min(Config.MaxUnitsPerFill or 100, 100))
    if not units then return false, 'error' end
    if tooSoon(src) then return false, 'wait' end
    if not atStation(src) then return false, 'far' end

    open[src] = nil
    local each = math.max(0, Config.PricePerUnit)
    local cash = Bridge.money(src, Config.MoneyType)
    local granted = units
    if each > 0 then granted = math.min(units, math.floor(cash / each)) end
    if granted < 1 then return false, 'money' end

    local price = math.ceil(granted * each)
    if not charge(src, price, 'vr-fuel-pump') then return false, 'money' end
    open[src] = { units = granted, price = price, each = each }
    return true, granted, price
end)

-- Pump: the client reports what it really delivered; the rest is refunded.
lib.callback.register('vr-fuel:finish', function(src, delivered)
    local fill = open[src]
    open[src] = nil
    if not fill then return 0 end
    local d = tonumber(delivered)
    if not d or d ~= d then d = fill.units end
    d = math.max(0, math.min(fill.units, math.floor(d)))
    local cost = math.min(fill.price, math.ceil(d * fill.each))
    local back = fill.price - cost
    refund(src, back, 'vr-fuel-refund')
    return cost
end)

lib.callback.register('vr-fuel:buyCan', function(src)
    local inv = inventory()
    if not Bridge.cid(src) then return false, 'error' end
    if not inv then return false, 'unavailable' end
    if tooSoon(src) then return false, 'wait' end
    if not atStation(src) then return false, 'far' end
    if not inv:CanCarryItem(src, Config.CanItem, 1) then return false, 'full' end

    local price = math.max(0, math.floor(Config.CanPrice or 0))
    if not charge(src, price, 'vr-fuel-can') then return false, 'money' end
    if not inv:AddItem(src, Config.CanItem, 1) then
        refund(src, price, 'vr-fuel-can-refund')
        return false, 'full'
    end
    return true, price
end)

lib.callback.register('vr-fuel:refillCan', function(src)
    local inv = inventory()
    if not Bridge.cid(src) then return false, 'error' end
    if not inv then return false, 'unavailable' end
    if tooSoon(src) then return false, 'wait' end
    if not atStation(src) then return false, 'far' end

    local w = inv:GetCurrentWeapon(src)
    if not w or type(w.name) ~= 'string' or w.name:upper() ~= Config.CanItem:upper() then return false, 'nocan' end
    local meta = type(w.metadata) == 'table' and w.metadata or {}
    local level = math.max(0, math.min(100, tonumber(meta.durability) or tonumber(meta.ammo) or 0))
    local missing = math.floor(100 - level)
    if missing < 1 then return false, 'canfull' end

    local price = math.max(0, math.ceil(missing * Config.CanRefillPrice))
    if not charge(src, price, 'vr-fuel-can-refill') then return false, 'money' end
    meta.durability, meta.ammo = 100, 100
    inv:SetMetadata(src, w.slot, meta)
    return true, price
end)

-- Fuel level ---------------------------------------------------------------------------------------------
-- The level is the vehicle's state bag `vrFuel`. Clients can not write state bags (strict mode), so a client reports
-- the level it is working on and the server checks it and writes the bag.
local STATE = 'vrFuel'
local lastSet = {}   -- [vehicle] = game time of the last accepted report
local REACH = 12.0

local function vehicleOf(netId)
    netId = tonumber(netId)
    if not netId then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return nil end
    return entity
end

-- The most a level may go up between two reports, in percent per second. Pumps and cans are slower than this.
local function maxRise()
    local r = Config.Rate or {}
    return math.max(r.pump or 1.5, r.can or 1.0, r.siphon or 0.5) * 2.0 + 1.0
end

RegisterNetEvent('vr-fuel:set', function(netId, percent)
    local src = source
    local entity = vehicleOf(netId)
    percent = tonumber(percent)
    if not entity or not percent or percent ~= percent then return end
    percent = math.max(0.0, math.min(100.0, percent))

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local driving = GetPedInVehicleSeat(entity, -1) == ped
    if not driving and #(GetEntityCoords(ped) - GetEntityCoords(entity)) > REACH then return end

    local state = Entity(entity).state
    local current = state[STATE]
    local now = GetGameTimer()
    if type(current) == 'number' and percent > current then
        -- A rise is only for refuelling, on foot and at a believable speed.
        if driving then return end
        local seconds = math.max(1.0, (now - (lastSet[entity] or 0)) / 1000.0)
        if percent - current > maxRise() * seconds then return end
    end
    if type(current) == 'number' and math.abs(current - percent) < 0.05 then return end
    lastSet[entity] = now
    state:set(STATE, percent + 0.0, true)
end)

-- Other scripts set the level on the server through the bridge, which writes the bag `fuel`. Follow it.
AddStateBagChangeHandler('fuel', nil, function(bag, _, value)
    if type(value) ~= 'number' then return end
    local entity = GetEntityFromStateBagName(bag)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    local state = Entity(entity).state
    local level = math.max(0.0, math.min(100.0, value + 0.0))
    if state[STATE] ~= level then state:set(STATE, level, true) end
end)

exports('SetFuel', function(vehicle, percent)
    percent = tonumber(percent)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or not percent or percent ~= percent then return false end
    Entity(vehicle).state:set(STATE, math.max(0.0, math.min(100.0, percent + 0.0)), true)
    return true
end)

exports('GetFuel', function(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end
    return Entity(vehicle).state[STATE]
end)

AddEventHandler('entityRemoved', function(entity) lastSet[entity] = nil end)
