Fm = { spots = {}, plants = {}, rendered = {}, zones = {}, peds = {}, blips = {}, busy = false, actions = {} }

local ERRORS = {
    not_ready = 'Not ready yet, try again',
    no_player = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    slow_down = 'Slow down a little',
    too_far = 'You are too far away',
    too_fast = 'You did that too fast',
    failed = 'Something went wrong, try again',
    gone = 'That plant is gone',
    no_seed = 'You have no seeds for that',
    not_field = 'You can only plant inside a field',
    wrong_crop = 'That does not grow in this field',
    too_close = 'Too close to another plant',
    too_many = 'You already have as many plants as you can look after',
    field_full = 'This field is full',
    is_dead = 'That plant is dead. Dig it up',
    is_ready = 'It is ripe already',
    is_wet = 'It does not need water yet',
    irrigated = 'This field is irrigated, it waters itself',
    is_fed = 'Already fertilised',
    not_ripe = 'It is not ripe yet',
    not_yours = 'That is not yours to take yet',
    no_can = 'You need a watering can',
    empty_can = 'Your watering can is empty. Fill it at a well',
    can_full = 'Your watering can is already full',
    no_fertiliser = 'You have no fertiliser',
    no_room = 'You cannot carry that',
    no_money = 'You cannot afford that',
    not_sold = 'We do not sell that',
    not_wanted = 'We do not buy that',
    not_enough = 'You do not have that many',
    nothing = 'You have nothing we want',
}

function Fm.text(code)
    return ERRORS[code] or ERRORS.failed
end

function Fm.notify(text, kind)
    lib.notify({ title = 'Farming', description = text, type = kind or 'inform' })
end

function Fm.fail(code, extra)
    local text = Fm.text(code)
    if code == 'wrong_crop' and type(extra) == 'table' and extra.allowed and extra.allowed ~= '' then
        text = ('%s only grows %s'):format(extra.field or 'This field', extra.allowed)
    end
    Fm.notify(text, 'error')
end

function Fm.call(name, ...)
    local res = lib.callback.await('vr-farming:' .. name, false, ...)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error, res.data
end

function Fm.ped()
    return cache.ped or PlayerPedId()
end

function Fm.money(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '$' .. out
end

function Fm.cropNames(list)
    local out = {}
    for _, c in ipairs(list or {}) do out[#out + 1] = Config.Crops[c] and Config.Crops[c].label or c end
    return table.concat(out, ', ')
end

function Fm.span(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 3600 then return ('%dh %dm'):format(seconds // 3600, (seconds % 3600) // 60) end
    if seconds >= 60 then return ('%dm %02ds'):format(seconds // 60, seconds % 60) end
    return ('%ds'):format(seconds)
end

---------------------------------------------------------------------------
-- Doing things to plants
---------------------------------------------------------------------------

local LABEL = {
    plant = 'Planting', water = 'Watering', fertilise = 'Adding fertiliser', harvest = 'Harvesting',
    uproot = 'Digging up', refill = 'Filling the can',
}
local ANIM = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' }

function Fm.act(action, a, b)
    if Fm.busy then return end
    Fm.busy = true
    local began, data, extra = Fm.call('begin', action, a, b)
    if not began then
        Fm.busy = false
        return Fm.fail(data, extra)
    end
    local okAnim = pcall(lib.requestAnimDict, ANIM.dict)
    local done = lib.progressBar({
        duration = math.floor(data.seconds * 1000),
        label = LABEL[action] or 'Working',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = okAnim and { dict = ANIM.dict, clip = ANIM.clip, flag = 1 } or nil,
    })
    ClearPedTasks(Fm.ped())
    if not done then
        Fm.call('cancel')
        Fm.busy = false
        return
    end
    local good, res, extra = Fm.call('finish', action, a, b)
    Fm.busy = false
    if not good then return Fm.fail(res, extra) end
    if action == 'plant' then
        Fm.notify(('Planted %s. Water it so it grows'):format(res.label:lower()), 'success')
    elseif action == 'water' then
        Fm.notify(('Watered. %d left in the can'):format(res.left), 'success')
    elseif action == 'fertilise' then
        Fm.notify('Fertilised. It will grow faster and give more', 'success')
    elseif action == 'harvest' then
        local extra = res.seeds > 0 and (' and %d seeds'):format(res.seeds) or ''
        Fm.notify(('Harvested %dx %s (%s)%s%s'):format(res.count, res.label, res.tier, extra, res.regrows and '. It will fruit again' or ''), 'success')
    elseif action == 'uproot' then
        Fm.notify('Dug up', 'success')
    elseif action == 'refill' then
        Fm.notify('Watering can filled', 'success')
    end
end

RegisterNetEvent('vr-farming:client:useSeed', function(crop)
    if Fm.busy then return end
    local ped = Fm.ped()
    if IsPedInAnyVehicle(ped, false) then return Fm.notify('Get out of the vehicle first', 'error') end
    local c = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.9, 0.0)
    local found, gz = GetGroundZFor_3dCoord(c.x, c.y, c.z + 0.5, false)
    Fm.act('plant', crop, { x = c.x, y = c.y, z = found and gz or (c.z - 1.0) })
end)

function Fm.check(id)
    local ok, info = Fm.call('inspect', id)
    if not ok then return Fm.fail(info) end
    local rows = {}
    local function row(title, description, icon)
        rows[#rows + 1] = { title = title, description = description, icon = icon, readOnly = true }
    end
    if info.dead then
        row('Dead', 'Dig it up to clear the space', 'fa-solid fa-skull')
    elseif info.ripe then
        row('Ready to harvest', info.free and ('It will rot in about %s'):format(Fm.span(info.witherLeft)) or ('Only the owner can pick it for another %s'):format(Fm.span(info.protectLeft)), 'fa-solid fa-basket-shopping')
    else
        row(('Growing · stage %d of 4'):format(info.stage), (info.irrigated and 'Ripe in about %s' or 'Ripe in about %s if kept watered'):format(Fm.span(info.remaining or 0)), 'fa-solid fa-seedling')
        if info.irrigated then
            row('Irrigated', 'This field waters itself', 'fa-solid fa-droplet')
        elseif info.water > 0 then
            row('Water', ('%d%%'):format(info.water), 'fa-solid fa-droplet')
        else
            row('Dry', info.dryFor and ('It starts to suffer in %s'):format(Fm.span(info.dryFor)) or 'It is suffering. Water it', 'fa-solid fa-sun-plant-wilt')
        end
    end
    row('Quality so far', ('%s · health %d%%'):format(info.quality, info.health), 'fa-solid fa-star')
    row('Fertiliser', info.fert and 'Added' or 'None', 'fa-solid fa-flask')
    if info.regrow then row('Fruits again', 'This crop grows back after you harvest it', 'fa-solid fa-rotate') end
    row('Planted by', info.mine and 'You' or (info.owner or 'Someone'), 'fa-solid fa-user')
    row('Your watering can', ('%d of %d'):format(info.charges, Config.Rules.canCapacity), 'fa-solid fa-bucket')
    lib.registerContext({ id = 'vr-farming:inspect', title = info.label, options = rows })
    lib.showContext('vr-farming:inspect')
end

---------------------------------------------------------------------------
-- Drawing plants. Only the ones near you exist as objects.
---------------------------------------------------------------------------

local modelCache = {}

local function pickModel(list)
    if type(list) ~= 'table' then return nil end
    local key = table.concat(list, ',')
    if modelCache[key] ~= nil then return modelCache[key] or nil end
    for _, name in ipairs(list) do
        local hash = joaat(name)
        if IsModelInCdimage(hash) and IsModelValid(hash) then
            modelCache[key] = hash
            return hash
        end
    end
    modelCache[key] = false
    return nil
end

local function modelFor(v)
    local per = Config.CropModels[v.crop]
    if v.dead then return pickModel(Config.Models.dead) end
    if v.stage >= 4 then return pickModel(per and per.ready or Config.Models.ready) end
    return pickModel(per and per[v.stage] or Config.Models[v.stage])
end

local function sigOf(v)
    return ('%d:%s:%s'):format(v.stage, tostring(v.dead), v.crop)
end

local function plantOptions(id)
    local function state() return Fm.plants[id] end
    local function alive() local v = state() return v ~= nil and not v.dead end
    return {
        {
            name = ('vr-farming:plant:%d:check'):format(id), label = 'Check plant', icon = 'fa-solid fa-magnifying-glass',
            distance = Config.Reach,
            canInteract = function() return state() ~= nil and not Fm.busy end,
            onSelect = function() CreateThread(function() Fm.check(id) end) end,
        },
        {
            name = ('vr-farming:plant:%d:water'):format(id), label = 'Water', icon = 'fa-solid fa-droplet',
            distance = Config.Reach,
            canInteract = function() local v = state() return alive() and v.stage < 4 and not Fm.busy end,
            onSelect = function() CreateThread(function() Fm.act('water', id) end) end,
        },
        {
            name = ('vr-farming:plant:%d:fert'):format(id), label = 'Add fertiliser', icon = 'fa-solid fa-flask',
            distance = Config.Reach,
            canInteract = function() local v = state() return alive() and v.stage < 4 and not v.fert and not Fm.busy end,
            onSelect = function() CreateThread(function() Fm.act('fertilise', id) end) end,
        },
        {
            name = ('vr-farming:plant:%d:harvest'):format(id), label = 'Harvest', icon = 'fa-solid fa-basket-shopping',
            distance = Config.Reach,
            canInteract = function() local v = state() return alive() and v.stage >= 4 and not Fm.busy end,
            onSelect = function() CreateThread(function() Fm.act('harvest', id) end) end,
        },
        {
            name = ('vr-farming:plant:%d:dig'):format(id), label = 'Dig up', icon = 'fa-solid fa-trowel',
            distance = Config.Reach,
            canInteract = function() return state() ~= nil and not Fm.busy end,
            onSelect = function() CreateThread(function() Fm.act('uproot', id) end) end,
        },
    }
end

local function unrender(id)
    local r = Fm.rendered[id]
    if not r then return end
    if r.obj and DoesEntityExist(r.obj) then DeleteEntity(r.obj) end
    if r.zone then pcall(function() Bridge.target.removeZone(r.zone) end) end
    Fm.rendered[id] = nil
end

local function drawObject(v)
    local hash = modelFor(v)
    if not hash then return nil end
    local ok, got = pcall(lib.requestModel, hash)
    if not ok or not got then return nil end
    local obj = CreateObjectNoOffset(hash, v.x, v.y, v.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end
    SetEntityHeading(obj, (v.id * 47) % 360 + 0.0)
    PlaceObjectOnGroundProperly(obj)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    return obj
end

local function render(v)
    local r = Fm.rendered[v.id]
    local sig = sigOf(v)
    if r and r.sig == sig then return end
    if r and r.obj and DoesEntityExist(r.obj) then DeleteEntity(r.obj) end
    local obj = drawObject(v)
    if not r then
        r = { zone = Bridge.target.addSphereZone({
            name = ('vr-farming:plant:%d'):format(v.id),
            coords = vec3(v.x, v.y, v.z + 0.35),
            radius = 0.9,
            options = plantOptions(v.id),
        }) }
        Fm.rendered[v.id] = r
    end
    r.obj, r.sig = obj, sig
end

CreateThread(function()
    while true do
        Wait(1000)
        local here = GetEntityCoords(Fm.ped())
        local range = Config.Rules.streamDistance
        local made = 0
        for id, v in pairs(Fm.plants) do
            local near = #(here - vec3(v.x, v.y, v.z)) < range
            if near then
                if made < 8 and (not Fm.rendered[id] or Fm.rendered[id].sig ~= sigOf(v)) then
                    render(v)
                    made = made + 1
                end
            elseif Fm.rendered[id] then
                unrender(id)
            end
        end
    end
end)

RegisterNetEvent('vr-farming:client:plant', function(v)
    if type(v) ~= 'table' or not v.id then return end
    Fm.plants[v.id] = v
end)

RegisterNetEvent('vr-farming:client:plantGone', function(id)
    Fm.plants[id] = nil
    unrender(id)
end)

---------------------------------------------------------------------------
-- Stores, wells, fields: spots placed in game
---------------------------------------------------------------------------

local function clearZones()
    for _, id in ipairs(Fm.zones) do pcall(function() Bridge.target.removeZone(id) end) end
    Fm.zones = {}
end

local function clearBlips()
    for _, b in ipairs(Fm.blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    Fm.blips = {}
end

local function clearPeds()
    for _, p in pairs(Fm.peds) do
        if p.entity and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    end
    Fm.peds = {}
end

local OPTIONS = {
    store = { label = 'Farm store', icon = 'fa-solid fa-store', act = 'store' },
    well = { label = 'Fill watering can', icon = 'fa-solid fa-faucet-drip', act = 'well' },
}

local function buildZones()
    clearZones()
    for _, spot in ipairs(Fm.spots) do
        local o = OPTIONS[spot.kind]
        if o then
            local center = vec3(spot.x, spot.y, spot.z + 0.9)
            local id = Bridge.target.addSphereZone({
                name = ('vr-farming:%d'):format(spot.id),
                coords = center,
                radius = 1.6,
                options = {
                    {
                        name = ('vr-farming:%d:opt'):format(spot.id),
                        label = o.label,
                        icon = o.icon,
                        distance = Config.Reach,
                        canInteract = function() return not Fm.busy end,
                        onSelect = function()
                            if Fm.busy then return end
                            Fm.busy = true
                            CreateThread(function()
                                local fn = Fm.actions[o.act]
                                if fn then pcall(fn, spot) end
                                Fm.busy = false
                            end)
                        end,
                    },
                },
            })
            Fm.zones[#Fm.zones + 1] = id
        end
    end
end

local function buildBlips()
    clearBlips()
    for _, spot in ipairs(Fm.spots) do
        if Config.Blips[spot.kind] then
            if spot.kind == 'field' then
                local area = AddBlipForRadius(spot.x, spot.y, spot.z, spot.radius + 0.0)
                SetBlipColour(area, 2)
                SetBlipAlpha(area, 70)
                Fm.blips[#Fm.blips + 1] = area
            end
            local b = AddBlipForCoord(spot.x, spot.y, spot.z)
            SetBlipSprite(b, spot.kind == 'store' and 52 or 1)
            SetBlipScale(b, spot.kind == 'store' and 0.7 or 0.5)
            SetBlipColour(b, 2)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            local name = spot.label
            if spot.kind == 'field' and type(spot.crops) == 'table' and #spot.crops > 0 then
                name = ('%s (%s)'):format(spot.label, Fm.cropNames(spot.crops))
            end
            AddTextComponentSubstringPlayerName(name)
            EndTextCommandSetBlipName(b)
            Fm.blips[#Fm.blips + 1] = b
        end
    end
end

local function spawnPed(spot)
    local model = spot.ped
    if not model or model == '' then return nil end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    local ok, got = pcall(lib.requestModel, hash)
    if not ok or not got then return nil end
    local ped = CreatePed(4, hash, spot.x, spot.y, spot.z, spot.w + 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not ped or ped == 0 then return nil end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCanRagdoll(ped, false)
    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
    return ped
end

function Fm.syncPeds()
    local here = GetEntityCoords(Fm.ped())
    local seen = {}
    for _, spot in ipairs(Fm.spots) do
        if spot.kind ~= 'field' then
            local want = spot.ped and spot.ped ~= '' and #(here - vec3(spot.x, spot.y, spot.z)) < Config.Ped.streamDistance
            local have = Fm.peds[spot.id]
            local stale = have and (have.model ~= spot.ped or have.x ~= spot.x or have.y ~= spot.y or have.z ~= spot.z or have.w ~= spot.w)
            if have and (not want or stale or not DoesEntityExist(have.entity)) then
                if DoesEntityExist(have.entity) then DeleteEntity(have.entity) end
                Fm.peds[spot.id] = nil
                have = nil
            end
            if want and not have then
                local entity = spawnPed(spot)
                if entity then
                    Fm.peds[spot.id] = { entity = entity, model = spot.ped, x = spot.x, y = spot.y, z = spot.z, w = spot.w }
                end
            end
            seen[spot.id] = true
        end
    end
    for id, p in pairs(Fm.peds) do
        if not seen[id] then
            if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
            Fm.peds[id] = nil
        end
    end
end

local function apply(list)
    Fm.spots = type(list) == 'table' and list or {}
    buildZones()
    buildBlips()
    pcall(Fm.syncPeds)
end

RegisterNetEvent('vr-farming:client:spots', function(list)
    apply(list)
end)

CreateThread(function()
    Wait(1500)
    apply(lib.callback.await('vr-farming:spots', false))
    local plants = lib.callback.await('vr-farming:plants', false)
    for _, v in ipairs(type(plants) == 'table' and plants or {}) do Fm.plants[v.id] = v end
    while true do
        Wait(2000)
        if #Fm.spots > 0 then pcall(Fm.syncPeds) end
    end
end)

Fm.actions.well = function(spot)
    Fm.busy = false
    Fm.act('refill', spot.id)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for id in pairs(Fm.rendered) do unrender(id) end
    clearZones()
    clearBlips()
    clearPeds()
end)
