BHC = { banks = {}, status = {}, zones = {}, zoneOf = {}, props = {}, blips = {}, busy = false, ready = false }

local ERRORS = {
    not_ready = 'The heist system is not ready yet',
    no_player = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    slow_down = 'Slow down a little',
    too_far = 'You are too far away',
    locked = 'Something else has to happen first',
    empty = 'There is nothing left here',
    over = 'This heist is over',
    disabled = 'This bank is not available',
    cooldown = 'This bank was hit recently. Come back later',
    police = 'Not enough police in the city',
    need_laptop = 'You need a laptop',
    need_kit = 'You need an exploit kit for a target this secure',
    need_drill = 'You need a drill',
    need_tool = 'You need a tool to force this open',
    need_weapon = 'Hold a weapon to smash the glass',
    busy = 'You are already connected',
    hack_cooldown = 'Your connection was burned. Wait a little',
    too_fast = 'You did that too fast',
    full = 'You cannot carry any more',
    missing = 'That item does not exist on this server',
    no_session = 'The connection was lost',
    failed = 'Something went wrong, try again',
    no_doorlock = 'vr-doorlock is not running',
    bad_door = 'That is not a usable door',
    door_added = 'That door is already on this step',
}

local blocks = 0

function BHC.block(on)
    if on then
        blocks = blocks + 1
        LocalPlayer.state:set('vrDoorBlock', true, false)
    else
        SetTimeout(900, function()
            blocks = math.max(0, blocks - 1)
            if blocks == 0 then LocalPlayer.state:set('vrDoorBlock', false, false) end
        end)
    end
end

local BADMODEL = {}

function BHC.loadModel(names)
    for _, name in ipairs(names) do
        if type(name) == 'string' and name ~= '' and not BADMODEL[name] then
            local hash = joaat(name)
            local usable = IsModelInCdimage(hash) and IsModelValid(hash)
            if usable then
                local ok, got = pcall(lib.requestModel, name)
                if ok and got then return got end
            end
            BADMODEL[name] = true
        end
    end
    return nil
end

function BHC.errorText(code)
    return ERRORS[code] or ERRORS.failed
end

function BHC.notify(text, kind)
    lib.notify({ title = 'Bank heist', description = text, type = kind or 'inform' })
end

function BHC.fail(code)
    BHC.notify(BHC.errorText(code), 'error')
end

function BHC.call(name, ...)
    local res = lib.callback.await('vr-bankheist:' .. name, false, ...)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error
end

function BHC.message(data)
    SendNUIMessage(data)
end

function BHC.ped()
    return cache.ped or PlayerPedId()
end

function BHC.bank(id)
    for _, b in ipairs(BHC.banks) do
        if b.id == id then return b end
    end
    return nil
end

local function slot(st, id)
    if not st or not st.el then return nil end
    return st.el[tostring(id)] or st.el[id]
end

function BHC.elState(bank, el)
    return slot(BHC.status[bank.id], el.id)
end

local IDLE = { state = 'idle', el = {} }

function BHC.usable(bank, el)
    local st = BHC.status[bank.id] or IDLE
    if not bank.enabled then return false end
    if st.state ~= 'idle' and st.state ~= 'active' then return false end
    if el.needs then
        local need = slot(st, el.needs)
        if not need or need.d ~= true then return false end
    end
    local mine = BHC.elState(bank, el)
    if el.type == 'cash' or el.type == 'gold' then
        if mine and mine.l ~= nil and mine.l <= 0 then return false end
    elseif el.type == 'hack' or el.type == 'drill' or el.type == 'till' or el.type == 'case' then
        if mine and mine.d == true then return false end
    end
    return true
end

local function clearZones()
    BHC.zoneOf = {}
    for _, id in ipairs(BHC.zones) do
        pcall(function() Bridge.target.removeZone(id) end)
    end
    BHC.zones = {}
end

local OPTIONS = {
    hack = { label = 'Connect laptop', icon = 'fa-solid fa-terminal', act = 'hack' },
    drill = { label = 'Drill lock box', icon = 'fa-solid fa-screwdriver-wrench', act = 'drill' },
    cash = { label = 'Grab cash', icon = 'fa-solid fa-money-bill-wave', act = 'grab' },
    gold = { label = 'Grab gold', icon = 'fa-solid fa-gem', act = 'grab' },
    till = { label = 'Force open the register', icon = 'fa-solid fa-cash-register', act = 'till' },
    case = { label = 'Smash the glass', icon = 'fa-solid fa-ring', act = 'case' },
}

local SIZE = {
    hack = { radius = 1.2, reach = 3.0, tolerance = 0.9 },
    drill = { radius = 1.0, reach = 3.0, tolerance = 0.8 },
    till = { radius = 0.7, reach = 2.5, tolerance = 0.5 },
}

local function sizeOf(el)
    if el.type == 'cash' or el.type == 'gold' then
        local radius = math.max(1.5, el.r or 2.5)
        return { radius = radius, reach = radius + 1.5, tolerance = radius }
    elseif el.type == 'case' then
        return { radius = math.min(0.8, math.max(0.45, (el.r or 0.4) + 0.2)), reach = 2.5, tolerance = 0.4 }
    end
    return SIZE[el.type] or { radius = math.max(2.0, (el.r or 1.5) + 0.6), reach = 3.0, tolerance = 0.8 }
end

function BHC.sees(center, tolerance)
    local ped = BHC.ped()
    local from = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, center.x, center.y, center.z, 1, ped, 4)
    local _, hit, point = GetShapeTestResult(handle)
    if hit ~= 1 or not point then return true end
    return #(vec3(point.x, point.y, point.z) - center) <= tolerance
end

local function buildZones()
    clearZones()
    for _, bank in ipairs(BHC.banks) do
        for _, el in ipairs(bank.elements or {}) do
            local o = OPTIONS[el.type]
            if o then
                local size = sizeOf(el)
                local radius, reach = size.radius, size.reach
                local center = vec3(el.x, el.y, el.z)
                local id = Bridge.target.addSphereZone({
                    name = ('vr-bankheist:%d:%d'):format(bank.id, el.id),
                    coords = center,
                    radius = radius,
                    options = {
                        {
                            name = ('vr-bankheist:%d:%d:opt'):format(bank.id, el.id),
                            label = o.label,
                            icon = o.icon,
                            distance = reach,
                            canInteract = function() return not BHC.busy and BHC.usable(bank, el) and BHC.sees(center, size.tolerance) end,
                            onSelect = function()
                                if BHC.busy then return end
                                BHC.busy = true
                                BHC.block(true)
                                CreateThread(function()
                                    local fn = BHC.actions[o.act]
                                    if fn then pcall(fn, bank, el) end
                                    BHC.busy = false
                                    BHC.block(false)
                                end)
                            end,
                        },
                    },
                })
                BHC.zones[#BHC.zones + 1] = id
                BHC.zoneOf[('%d:%d'):format(bank.id, el.id)] = { id = id, radius = radius, reach = reach }
            end
        end
    end
end

RegisterNetEvent('vr-bankheist:client:banks', function(list)
    if type(list) ~= 'table' then return end
    BHC.banks = list
    buildZones()
    if BHC.refreshProps then pcall(BHC.refreshProps, true) end
end)

RegisterNetEvent('vr-bankheist:client:status', function(id, status)
    if type(status) ~= 'table' then return end
    BHC.status[id] = status
    if BHC.syncCases then pcall(BHC.syncCases) end
end)

local SWING_DEGREES = 90.0
local turns = {}
local baseHeading = {}
local held = {}

local function doorParts(id)
    if GetResourceState('vr-doorlock') ~= 'started' then return {} end
    local ok, list = pcall(function() return exports['vr-doorlock']:getDoorParts(id) end)
    if ok and type(list) == 'table' then return list end
    return {}
end

local function wrap(angle)
    return (angle + 180.0) % 360.0 - 180.0
end

local function findEntity(part)
    local entity = part.entity
    if entity and entity ~= 0 and DoesEntityExist(entity) then return entity end
    local c = part.coords
    if part.model and type(c) == 'table' then
        local found = GetClosestObjectOfType(c.x + 0.0, c.y + 0.0, c.z + 0.0, 5.0, part.model, false, false, false)
        if found and found ~= 0 then return found end
    end
    return nil
end

local function turnObject(entity, key, part, ratio, stale)
    if not baseHeading[key] then baseHeading[key] = GetEntityHeading(entity) end
    local from = GetEntityHeading(entity)
    local to = baseHeading[key] - SWING_DEGREES * ratio
    local delta = wrap(to - from)
    if math.abs(delta) < 0.5 then
        held[key] = ratio ~= 0.0 and { part = part, heading = to } or nil
        return true
    end
    if NetworkGetEntityIsNetworked(entity) then NetworkRequestControlOfEntity(entity) end
    local started = GetGameTimer()
    local length = math.max(1200, math.floor(math.abs(delta) / SWING_DEGREES / math.max(Config.Vault.rate, 0.1) * 1000))
    while true do
        local t = (GetGameTimer() - started) / length
        if t >= 1.0 or stale() then break end
        SetEntityHeading(entity, from + delta * t)
        Wait(0)
    end
    if stale() then return true end
    SetEntityHeading(entity, to)
    held[key] = ratio ~= 0.0 and { part = part, heading = to } or nil
    return true
end

local function swingPart(part, key, ratio, stale)
    local entity = findEntity(part)
    local before = entity and GetEntityHeading(entity)
    if entity and not baseHeading[key] and ratio ~= 0.0 then baseHeading[key] = before end
    local hash = part.hash
    local registered = hash and IsDoorRegisteredWithSystem(hash) or false
    if registered then
        DoorSystemSetAutomaticRate(hash, Config.Vault.rate, true, true)
        DoorSystemSetOpenRatio(hash, ratio, true, true)
        Wait(1500)
        if stale() then return end
    end
    local moved = false
    if entity then
        moved = math.abs(wrap(GetEntityHeading(entity) - before)) > 2.0
    elseif registered then
        moved = true
    end
    local turned = false
    if entity and not moved then turned = turnObject(entity, key, part, ratio, stale) end
    print(('[vr-bankheist] door swing: registered=%s object=%s moved=%s turned=%s'):format(tostring(registered), tostring(entity ~= nil), tostring(moved), tostring(turned)))
end

RegisterNetEvent('vr-bankheist:client:swing', function(ids, ratio)
    if type(ids) ~= 'table' or type(ratio) ~= 'number' then return end
    CreateThread(function()
        Wait(350)
        for _, id in ipairs(ids) do
            local mine = (turns[id] or 0) + 1
            turns[id] = mine
            local function stale() return turns[id] ~= mine end
            for index, part in ipairs(doorParts(id)) do
                if not stale() then pcall(swingPart, part, ('%s:%s'):format(id, index), ratio, stale) end
            end
        end
    end)
end)

CreateThread(function()
    while true do
        Wait(2000)
        for key, info in pairs(held) do
            local entity = findEntity(info.part)
            if entity and math.abs(wrap(GetEntityHeading(entity) - info.heading)) > 2.0 then
                SetEntityHeading(entity, info.heading)
            end
        end
    end
end)

RegisterNetEvent('vr-bankheist:client:policeBlip', function(id, centre, radius, seconds)
    if type(centre) ~= 'table' then return end
    local key = 'bank' .. tostring(id)
    if BHC.blips[key] then
        for _, b in ipairs(BHC.blips[key]) do RemoveBlip(b) end
    end
    local r = AddBlipForRadius(centre.x, centre.y, centre.z, (radius or 100.0) + 0.0)
    SetBlipColour(r, 1)
    SetBlipAlpha(r, 110)
    local b = AddBlipForCoord(centre.x, centre.y, centre.z)
    SetBlipSprite(b, 161)
    SetBlipColour(b, 1)
    SetBlipScale(b, 1.0)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Bank robbery')
    EndTextCommandSetBlipName(b)
    BHC.blips[key] = { r, b }
    SetTimeout((seconds or 240) * 1000, function()
        local list = BHC.blips[key]
        if list and list[1] == r then
            for _, x in ipairs(list) do RemoveBlip(x) end
            BHC.blips[key] = nil
        end
    end)
end)

CreateThread(function()
    local deadline = GetGameTimer() + 60000
    while not Bridge.loggedIn() and GetGameTimer() < deadline do Wait(500) end
    local list = lib.callback.await('vr-bankheist:getBanks', false)
    if type(list) == 'table' and #BHC.banks == 0 then
        BHC.banks = list
        buildZones()
    end
    local all = lib.callback.await('vr-bankheist:status', false)
    if type(all) == 'table' then
        for _, st in ipairs(all) do
            if not BHC.status[st.id] then BHC.status[st.id] = st end
        end
    end
    BHC.ready = true
    if BHC.refreshProps then pcall(BHC.refreshProps, true) end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearZones()
    if BHC.clearProps then BHC.clearProps() end
    for _, list in pairs(BHC.blips) do
        for _, b in ipairs(list) do RemoveBlip(b) end
    end
end)
