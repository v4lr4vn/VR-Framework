-- Hand out keys without opening the full /keys menu:
--   /givekeys [id]   a permanent copy of the car you are in (or the one next to you)
--   /lendkeys [id]   the same, but it runs out by itself
--   radial menu      "Vehicle keys" with the same actions
-- No id: the closest person is used, and you pick from a list when several are close.

local function ownedPlate(veh)
    local plate = Keys.plateOf(veh)
    if plate and Keys.held[plate] == 'owner' then return plate end
    local bag = KU.plate(Keys.bag(veh, 'vr_plate'))
    if bag and Keys.held[bag] == 'owner' then return bag end
    return nil
end

-- the car the player means: the one they sit in, else the closest one they own within reach
local function currentVehicle()
    local ped = cache.ped or PlayerPedId()
    local inside = GetVehiclePedIsIn(ped, false)
    if inside ~= 0 then
        -- sitting in someone else's car: fall through to the list of cars you own
        return ownedPlate(inside)
    end
    local pos = GetEntityCoords(ped)
    local best, bestD
    for _, v in ipairs(lib.getNearbyVehicles(pos, Config.Quick.vehicleRange, true)) do
        local plate = ownedPlate(v.vehicle)
        local d = #(pos - v.coords)
        if plate and (not bestD or d < bestD) then best, bestD = plate, d end
    end
    return best
end

-- calls fn(plate) with the car to work on; asks when nothing is close
local function withVehicle(fn)
    local plate = currentVehicle()
    if plate then return fn(plate) end
    local res = Keys.api('list')
    if not res.ok then return Keys.notify(Keys.errorText(res.error), 'error') end
    local options = {}
    for _, v in ipairs(res.data.vehicles) do
        if v.kind == 'owner' then
            options[#options + 1] = { label = ('%s  ·  %s'):format(v.label, v.plate), description = 'Not close by. Pick the car', icon = 'fa-solid fa-car', args = { plate = v.plate } }
        end
    end
    if #options == 0 then return Keys.notify('You do not own any vehicles', 'inform') end
    if #options == 1 then return fn(options[1].args.plate) end
    Keys.showMenu('Which vehicle?', options, function(a) fn(a.plate) end)
end

local function share(plate, target, name, lend)
    local r = Keys.api('share', { plate = plate, target = target, lend = lend })
    if not r.ok then return Keys.notify(Keys.errorText(r.error), 'error') end
    name = r.data and r.data.name or name or 'them'
    if lend then
        Keys.notify(('Lent the key to %s for %d minutes'):format(name, Config.Keys.lendMinutes), 'success')
    else
        Keys.notify(('Gave %s a copy of the key'):format(name), 'success')
    end
end

function Keys.quickGive(lend, targetId)
    lend = lend == true
    targetId = tonumber(targetId)
    withVehicle(function(plate)
        if targetId then return share(plate, targetId, nil, lend) end
        local res = Keys.api('nearby')
        local players = res.ok and res.data.players or {}
        if #players == 0 then return Keys.notify('Nobody is close enough', 'error') end
        if #players == 1 then return share(plate, players[1].src, players[1].name, lend) end
        Keys.pickPlayer({ plate = plate }, lend)
    end)
end

function Keys.quickHolders()
    withVehicle(function(plate) Keys.showHolders({ plate = plate }) end)
end

RegisterCommand('givekeys', function(_, args) Keys.quickGive(false, args[1]) end, false)
RegisterCommand('lendkeys', function(_, args) Keys.quickGive(true, args[1]) end, false)

-- radial menu --------------------------------------------------------------
local SUB = 'vr_vehiclekeys_menu'
local ROOT = 'vr_vehiclekeys'

local function addRadial()
    if not Config.Quick.radial or GetResourceState('vr-ui') ~= 'started' then return end
    exports['vr-ui']:registerRadial({
        id = SUB,
        label = Config.Quick.label,
        items = {
            { label = 'Give a key', icon = 'hand-holding', onSelect = function() Keys.quickGive(false) end },
            { label = ('Lend (%d min)'):format(Config.Keys.lendMinutes), icon = 'clock', onSelect = function() Keys.quickGive(true) end },
            { label = 'Who has keys', icon = 'users', onSelect = function() Keys.quickHolders() end },
            { label = 'My keys', icon = 'car', onSelect = function() Keys.openMenu() end },
        },
    })
    exports['vr-ui']:addRadialItem({ id = ROOT, label = Config.Quick.label, icon = Config.Quick.icon, menu = SUB })
end

CreateThread(function()
    Wait(1500)
    addRadial()
end)

-- vr-ui forgets its radial items when it restarts
AddEventHandler('onClientResourceStart', function(resource)
    if resource == 'vr-ui' then
        Wait(1000)
        addRadial()
    end
end)
