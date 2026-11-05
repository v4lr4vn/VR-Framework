Fc = { spots = {}, zones = {}, peds = {}, blips = {}, busy = false }

local ERRORS = {
    not_ready = 'Not ready yet, try again',
    no_player = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    slow_down = 'Slow down a little',
    too_far = 'You are too far away',
    too_small = 'That is too little to bother with',
    too_big = 'That is too much for one deal',
    limit = 'You have cleaned enough for now. Come back later',
    not_enough = 'You do not have that much',
    not_wanted = 'We do not buy that',
    nothing = 'You have nothing we want',
    too_fast = 'You did that too fast',
    too_many = 'You already have money being cleaned. Collect it first',
    not_done = 'That is not ready yet, come back later',
    failed = 'Something went wrong, try again',
}

function Fc.text(code)
    return ERRORS[code] or ERRORS.failed
end

function Fc.notify(text, kind)
    lib.notify({ title = 'Fence', description = text, type = kind or 'inform' })
end

function Fc.fail(code)
    Fc.notify(Fc.text(code), 'error')
end

function Fc.call(name, ...)
    local res = lib.callback.await('vr-fence:' .. name, false, ...)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error
end

function Fc.ped()
    return cache.ped or PlayerPedId()
end

function Fc.money(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '$' .. out
end

function Fc.sees(center, tolerance)
    local ped = Fc.ped()
    local from = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, center.x, center.y, center.z, 1, ped, 4)
    local _, hit, point = GetShapeTestResult(handle)
    if hit ~= 1 or not point then return true end
    return #(vec3(point.x, point.y, point.z) - center) <= tolerance
end

local function clearZones()
    for _, id in ipairs(Fc.zones) do
        pcall(function() Bridge.target.removeZone(id) end)
    end
    Fc.zones = {}
end

local function clearBlips()
    for _, b in ipairs(Fc.blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    Fc.blips = {}
end

local function clearPeds()
    for _, p in pairs(Fc.peds) do
        if p.entity and DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
    end
    Fc.peds = {}
end

local OPTIONS = {
    launder = { label = 'Clean dirty money', icon = 'fa-solid fa-money-bill-transfer', act = 'launder' },
    pawn = { label = 'Sell valuables', icon = 'fa-solid fa-gem', act = 'pawn' },
}

Fc.actions = {}

local function buildZones()
    clearZones()
    for _, spot in ipairs(Fc.spots) do
        local o = OPTIONS[spot.kind]
        if o then
            local center = vec3(spot.x, spot.y, spot.z + 0.9)
            local id = Bridge.target.addSphereZone({
                name = ('vr-fence:%d'):format(spot.id),
                coords = center,
                radius = 1.6,
                options = {
                    {
                        name = ('vr-fence:%d:opt'):format(spot.id),
                        label = o.label,
                        icon = o.icon,
                        distance = Config.Reach,
                        canInteract = function() return not Fc.busy and Fc.sees(center, 0.9) end,
                        onSelect = function()
                            if Fc.busy then return end
                            Fc.busy = true
                            CreateThread(function()
                                local fn = Fc.actions[o.act]
                                if fn then pcall(fn, spot) end
                                Fc.busy = false
                            end)
                        end,
                    },
                },
            })
            Fc.zones[#Fc.zones + 1] = id
        end
    end
end

local function buildBlips()
    clearBlips()
    for _, spot in ipairs(Fc.spots) do
        if Config.Blips[spot.kind] then
            local b = AddBlipForCoord(spot.x, spot.y, spot.z)
            SetBlipSprite(b, spot.kind == 'pawn' and 267 or 500)
            SetBlipScale(b, 0.7)
            SetBlipColour(b, spot.kind == 'pawn' and 5 or 2)
            SetBlipAsShortRange(b, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(spot.label)
            EndTextCommandSetBlipName(b)
            Fc.blips[#Fc.blips + 1] = b
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

function Fc.syncPeds()
    local here = GetEntityCoords(Fc.ped())
    local seen = {}
    for _, spot in ipairs(Fc.spots) do
        local want = spot.ped and spot.ped ~= '' and #(here - vec3(spot.x, spot.y, spot.z)) < Config.Ped.streamDistance
        local have = Fc.peds[spot.id]
        local stale = have and (have.model ~= spot.ped or have.x ~= spot.x or have.y ~= spot.y or have.z ~= spot.z or have.w ~= spot.w)
        if have and (not want or stale or not DoesEntityExist(have.entity)) then
            if DoesEntityExist(have.entity) then DeleteEntity(have.entity) end
            Fc.peds[spot.id] = nil
            have = nil
        end
        if want and not have then
            local entity = spawnPed(spot)
            if entity then
                Fc.peds[spot.id] = { entity = entity, model = spot.ped, x = spot.x, y = spot.y, z = spot.z, w = spot.w }
            end
        end
        seen[spot.id] = true
    end
    for id, p in pairs(Fc.peds) do
        if not seen[id] then
            if DoesEntityExist(p.entity) then DeleteEntity(p.entity) end
            Fc.peds[id] = nil
        end
    end
end

local function apply(list)
    Fc.spots = type(list) == 'table' and list or {}
    buildZones()
    buildBlips()
    pcall(Fc.syncPeds)
end

RegisterNetEvent('vr-fence:client:spots', function(list)
    apply(list)
end)

CreateThread(function()
    Wait(1500)
    local list = lib.callback.await('vr-fence:spots', false)
    apply(list)
    while true do
        Wait(2000)
        if #Fc.spots > 0 then pcall(Fc.syncPeds) end
    end
end)

local function span(seconds)
    seconds = math.max(0, math.floor(seconds))
    if seconds >= 3600 then return ('%dh %dm'):format(seconds // 3600, (seconds % 3600) // 60) end
    if seconds >= 60 then return ('%dm %02ds'):format(seconds // 60, seconds % 60) end
    return ('%ds'):format(seconds)
end

local function handOver(spot, info)
    local most = math.min(info.dirty, info.maxDeal, info.left)
    local input = lib.inputDialog(spot.label, {
        { type = 'number', label = 'How much dirty money', description = ('You carry %s. They keep %d%%. You can clean up to %s more right now.'):format(Fc.money(info.dirty), math.floor((1.0 - info.rate) * 100 + 0.5), Fc.money(info.left)), default = most, min = info.min, max = most, required = true },
    })
    if not input or not input[1] then return end
    local amount = math.floor(tonumber(input[1]) or 0)
    local began, data = Fc.call('launder:begin', spot.id, amount)
    if not began then return Fc.fail(data) end
    local cfg = Config.Launder
    local okAnim = pcall(lib.requestAnimDict, cfg.animDict)
    local done = lib.progressBar({
        duration = math.floor(data.seconds * 1000),
        label = 'Handing over the money',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = okAnim and { dict = cfg.animDict, clip = cfg.animClip, flag = 49 } or nil,
    })
    ClearPedTasks(Fc.ped())
    if not done then
        Fc.call('launder:cancel')
        return
    end
    local good, res = Fc.call('launder:finish', spot.id)
    if not good then return Fc.fail(res) end
    Fc.notify(('Handed over %s. Come back in about %s for %s clean.'):format(Fc.money(res.dirty), span(res.wait), Fc.money(res.paid)), 'success')
end

Fc.actions.launder = function(spot)
    local ok, info = Fc.call('launder:info', spot.id)
    if not ok then return Fc.fail(info) end
    local jobs = info.jobs or {}
    local most = math.min(info.dirty, info.maxDeal, info.left)
    local canHand = info.dirty >= info.min and most >= info.min and #jobs < info.maxOpen
    local why
    if #jobs >= info.maxOpen then why = 'You already have the most deals open. Collect one first'
    elseif info.dirty < info.min then why = ('Come back with at least %s in dirty money'):format(Fc.money(info.min))
    elseif most < info.min then why = 'You have cleaned enough for now. Come back later' end
    local id = ('vr-fence:launder:%d'):format(spot.id)
    local options = {
        {
            title = 'Hand over dirty money',
            description = why or ('You carry %s. They keep %d%%.'):format(Fc.money(info.dirty), math.floor((1.0 - info.rate) * 100 + 0.5)),
            icon = 'fa-solid fa-money-bill-transfer',
            disabled = not canHand,
            onSelect = function() handOver(spot, info) end,
        },
    }
    for _, job in ipairs(jobs) do
        local ready = job.wait <= 0
        options[#options + 1] = {
            title = ready and ('Collect %s clean'):format(Fc.money(job.paid)) or ('%s clean, not ready'):format(Fc.money(job.paid)),
            description = ready and ('From %s handed over'):format(Fc.money(job.amount)) or ('Ready in %s. You can leave and come back'):format(span(job.wait)),
            icon = ready and 'fa-solid fa-hand-holding-dollar' or 'fa-solid fa-hourglass-half',
            disabled = not ready,
            onSelect = function()
                local good, res = Fc.call('launder:collect', spot.id, job.id)
                if not good then return Fc.fail(res) end
                Fc.notify(('You got %s clean for %s'):format(Fc.money(res.paid), Fc.money(res.dirty)), 'success')
            end,
        }
    end
    lib.registerContext({ id = id, title = spot.label, options = options })
    lib.showContext(id)
end

Fc.actions.pawn = function(spot)
    local ok, data = Fc.call('pawn:list', spot.id)
    if not ok then return Fc.fail(data) end
    local items = data.items or {}
    if #items == 0 then return Fc.notify('You have nothing we want', 'inform') end
    local total = 0
    for _, row in ipairs(items) do total = total + row.price * row.count end
    local id = ('vr-fence:pawn:%d'):format(spot.id)
    local options = {
        {
            title = ('Sell everything · %s'):format(Fc.money(total)),
            icon = 'fa-solid fa-hand-holding-dollar',
            onSelect = function()
                local good, res = Fc.call('pawn:sellAll', spot.id)
                if not good then return Fc.fail(res) end
                Fc.notify(('Sold %d items for %s'):format(res.pieces, Fc.money(res.total)), 'success')
            end,
        },
    }
    for _, row in ipairs(items) do
        options[#options + 1] = {
            title = ('%s · %d'):format(row.label, row.count),
            description = ('%s each'):format(Fc.money(row.price)),
            icon = 'fa-solid fa-gem',
            onSelect = function()
                local amount = row.count
                if row.count > 1 then
                    local input = lib.inputDialog(row.label, {
                        { type = 'number', label = 'How many', description = ('%s each'):format(Fc.money(row.price)), default = row.count, min = 1, max = row.count, required = true },
                    })
                    if not input or not input[1] then return end
                    amount = math.floor(tonumber(input[1]) or 0)
                end
                if amount < 1 then return end
                local good, res = Fc.call('pawn:sell', spot.id, row.item, amount)
                if not good then return Fc.fail(res) end
                Fc.notify(('Sold %dx %s for %s'):format(res.count, row.label, Fc.money(res.total)), 'success')
            end,
        }
    end
    lib.registerContext({ id = id, title = spot.label, options = options })
    lib.showContext(id)
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearZones()
    clearBlips()
    clearPeds()
end)
