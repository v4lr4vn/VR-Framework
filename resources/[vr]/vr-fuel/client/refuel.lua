local busy = false
local ANIM = { dict = 'timetable@gardener@filling_can', clip = 'gar_ig_5_filling_can', flag = 50 }

local WHY = {
    money = "You don't have enough money",
    far = 'You need to be at a fuel station',
    wait = 'Please wait a moment',
    full = "You can't carry a petrol can",
    nocan = 'You need a petrol can in your hands',
    canfull = 'Your can is full',
    unavailable = 'Petrol cans are not available right now',
    error = 'Something went wrong',
}

local function say(text, kind) lib.notify({ description = text, type = kind or 'inform' }) end

local function inventoryUp()
    return Bridge.inventoryName == 'ox' and GetResourceState(Bridge.inventoryResource) == 'started'
end

-- Petrol can (a weapon item in vr-inventory; its level is 0-100 in the weapon metadata) ------------
local CAN_HASH = `WEAPON_PETROLCAN`

local function canLevel()
    if not inventoryUp() or GetSelectedPedWeapon(PlayerPedId()) ~= CAN_HASH then return nil end
    local w = exports[Bridge.inventoryResource]:getCurrentWeapon()
    if not w or type(w.name) ~= 'string' or w.name:upper() ~= Config.CanItem:upper() then return nil end
    local meta = w.metadata or {}
    return math.max(0, math.min(100, tonumber(meta.durability) or tonumber(meta.ammo) or 0))
end

local function setCanLevel(percent)
    if not inventoryUp() then return end
    TriggerServerEvent(Bridge.inventoryResource .. ':updateWeapon', 'ammo', math.floor(math.max(0, math.min(100, percent))))
end

-- Exports used by the target options and other scripts --------------------------------------------
function IsSiphonFuelAllowed(vehicle)
    if busy or not Config.AllowSiphoning or not vehicle or vehicle == 0 then return false end
    if GetVehicleEngineHealth(vehicle) <= 0 then return false end
    local level = canLevel()
    return level ~= nil and level < 100
end

function IsPetrolCanRefuelAllowed(vehicle)
    if busy or not Config.AllowCanRefuel or not vehicle or vehicle == 0 then return false end
    if GetVehicleEngineHealth(vehicle) <= 0 then return false end
    local level = canLevel()
    return level ~= nil and level > 0
end

function CanPumpRefuelPetrolCan()
    if busy then return false end
    local level = canLevel()
    return level ~= nil and level < 100
end

exports('IsSiphonFuelAllowed', IsSiphonFuelAllowed)
exports('IsPetrolCanRefuelAllowed', IsPetrolCanRefuelAllowed)
exports('CanPumpRefuelPetrolCan', CanPumpRefuelPetrolCan)

-- The transfer ---------------------------------------------------------------------------------------
-- Runs a progress bar long enough for `units` percent at `rate` per second. While it runs `apply(done)` is
-- called with the amount moved so far. Stops if somebody gets in the driver's seat or you walk away.
-- Returns how much was moved (it may be less than `units` if cancelled).
local function transfer(vehicle, units, rate, label, apply)
    local duration = math.max(500, math.floor(units / rate * 1000))
    local started = GetGameTimer()
    local running = true

    CreateThread(function()
        while running do
            Wait(250)
            local moved = math.min(units, (GetGameTimer() - started) / duration * units)
            apply(moved)
            local ped = PlayerPedId()
            if DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 5.0 then
                lib.cancelProgress()
                break
            end
        end
    end)

    local finished = lib.progressBar({
        duration = duration,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = ANIM,
    })
    running = false
    local moved = finished and units or math.min(units, (GetGameTimer() - started) / duration * units)
    apply(moved)
    return moved
end

local function target(entity)
    if entity and entity ~= 0 and DoesEntityExist(entity) and IsEntityAVehicle(entity) then return entity end
    local v = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 5.0, true)
    if v and v ~= 0 then return v end
end

local function ready(vehicle)
    if not vehicle then say('You are too far away from the vehicle', 'error') return false end
    if #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle)) > 2.5 then
        say('You are too far away from the vehicle', 'error')
        return false
    end
    return true
end

local function maybeExplode(vehicle)
    local c = Config.Explosion
    if c and c.enabled and GetIsVehicleEngineRunning(vehicle) and math.random(1, 100) <= c.chance then
        AddExplosion(GetEntityCoords(vehicle), 5, 50.0, true, false, true)
        return true
    end
    return false
end

local function face(vehicle)
    TaskTurnPedToFaceEntity(PlayerPedId(), vehicle, 1000)
    Wait(1000)
end

-- Pump -----------------------------------------------------------------------------------------------
local function pumpFill(entity)
    if busy then return end
    local vehicle = target()
    if not ready(vehicle) then return end
    local start = GetFuel(vehicle)
    local want = math.floor(100.0 - start)
    if want < 1 then return say('The tank is full', 'error') end

    busy = true
    face(vehicle)
    if maybeExplode(vehicle) then busy = false return end

    local ok, units, price = lib.callback.await('vr-fuel:begin', false, want)
    if not ok then
        busy = false
        return say(WHY[units] or WHY.error, 'error')
    end

    local moved = transfer(vehicle, units, Config.Rate.pump, 'Refuelling...', function(done)
        SetFuel(vehicle, start + done)
    end)
    local paid = lib.callback.await('vr-fuel:finish', false, math.floor(moved + 0.001))
    busy = false
    say(('You paid $%s for fuel'):format(paid or price), 'success')
end

-- Petrol can: buy / refill at the pump -----------------------------------------------------------------
local function buyCan()
    local ok, r = lib.callback.await('vr-fuel:buyCan', false)
    if ok then say('You bought a petrol can', 'success') else say(WHY[r] or WHY.error, 'error') end
end

local function refillCan()
    local level = canLevel()
    if level == nil then return say("You don't have a petrol can to refill", 'error') end
    if level >= 100 then return say('Your can is full', 'error') end
    local ok, r = lib.callback.await('vr-fuel:refillCan', false)
    if ok then say(('You refilled your petrol can for $%s'):format(r), 'success') else say(WHY[r] or WHY.error, 'error') end
end

-- Can into a vehicle, and siphoning a vehicle into the can ------------------------------------------------
local function canToVehicle(entity)
    if busy then return end
    local vehicle = target(entity)
    if not ready(vehicle) then return end
    local level = canLevel()
    if level == nil then return say('You need a petrol can in your hands', 'error') end
    if level <= 0 then return say('Your petrol can is empty', 'error') end
    local start = GetFuel(vehicle)
    local units = math.min(level, 100.0 - start)
    if units < 1 then return say('The tank is full', 'error') end

    busy = true
    face(vehicle)
    if maybeExplode(vehicle) then busy = false return end
    local moved = transfer(vehicle, units, Config.Rate.can, 'Refuelling...', function(done)
        SetFuel(vehicle, start + done)
    end)
    setCanLevel(level - moved)
    busy = false
    say('You refuelled the vehicle', 'success')
end

local function vehicleToCan(entity)
    if busy then return end
    local vehicle = target(entity)
    if not ready(vehicle) then return end
    local level = canLevel()
    if level == nil then return say('You need a petrol can in your hands', 'error') end
    if level >= 100 then return say('Your petrol can is full', 'error') end
    local start = GetFuel(vehicle)
    local units = math.min(start, 100.0 - level)
    if units < 1 then return say('The tank is empty', 'error') end

    busy = true
    face(vehicle)
    local moved = transfer(vehicle, units, Config.Rate.siphon, 'Siphoning fuel...', function(done)
        SetFuel(vehicle, start - done)
    end)
    setCanLevel(level + moved)
    busy = false
    say('You siphoned fuel', 'success')
end

-- Targets and blips ---------------------------------------------------------------------------------------
CreateThread(function()
    if GetResourceState('vr-target') ~= 'started' then
        print('^3[vr-fuel] vr-target is not running, the fuel interactions are disabled^0')
    else
        exports['vr-target']:addGlobalVehicle({
            {
                name = 'vr-fuel:canToVehicle', icon = 'fas fa-gas-pump', label = 'Refuel Car',
                bones = Config.CanBones, distance = Config.CanDistance,
                canInteract = function(entity) return IsPetrolCanRefuelAllowed(entity) end,
                onSelect = function(data) canToVehicle(data.entity) end,
            },
            {
                name = 'vr-fuel:siphon', icon = 'fas fa-gas-pump', label = 'Siphon Fuel',
                bones = Config.CanBones, items = Config.SiphonItem, distance = 3.0,
                canInteract = function(entity) return IsSiphonFuelAllowed(entity) end,
                onSelect = function(data) vehicleToCan(data.entity) end,
            },
        })

        exports['vr-target']:addModel(Config.PumpModels, {
            {
                name = 'vr-fuel:pump', icon = 'fas fa-gas-pump', label = 'Get Fuel', distance = 3.0,
                canInteract = function() return not busy end,
                onSelect = function(data) pumpFill(data.entity) end,
            },
            {
                name = 'vr-fuel:buyCan', icon = 'fas fa-gas-pump', label = 'Buy Petrol Can', distance = 3.0,
                canInteract = function() return inventoryUp() end,
                onSelect = buyCan,
            },
            {
                name = 'vr-fuel:refillCan', icon = 'fas fa-gas-pump', label = 'Refuel Petrol Can', distance = 3.0,
                canInteract = function() return CanPumpRefuelPetrolCan() end,
                onSelect = refillCan,
            },
        })
    end

    local b = Config.Blips
    if b and b.enabled then
        for _, at in ipairs(Config.Stations) do
            local blip = AddBlipForCoord(at.x, at.y, at.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipDisplay(blip, 2)
            SetBlipScale(blip, b.scale)
            SetBlipColour(blip, b.colour)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(b.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)
