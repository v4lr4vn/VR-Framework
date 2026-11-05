local K = Config.Collections
local repo = {}
local busy = false

local function plateKey(p)
    return type(p) == 'string' and p:upper():gsub('^%s+', ''):gsub('%s+$', '') or nil
end

local function repoPlate(entity)
    local ok, value = pcall(function() return Entity(entity).state.vr_plate end)
    local bag = ok and plateKey(value) or nil
    if bag and repo[bag] then return bag end
    local text = plateKey(GetVehicleNumberPlateText(entity))
    if text and repo[text] then return text end
    return nil
end

RegisterNetEvent('vr-banking:client:repoPlates', function(map)
    repo = type(map) == 'table' and map or {}
end)

CreateThread(function()
    while true do
        if Bank.isCollector() then
            local res = Bank.api('collections.plates', {})
            if res.ok and type(res.data) == 'table' then repo = res.data end
            Wait(60000)
        else
            repo = {}
            Wait(15000)
        end
    end
end)

RegisterCommand('collections', function()
    if not Bank.isCollector() then return Bank.notify('Clock in as a debt collector to open the collections board', 'error') end
    Bank.show('collections', {})
end, false)

local function repossess(entity)
    if busy or not entity or entity == 0 then return end
    local plate = repoPlate(entity)
    if not plate then return end
    if GetPedInVehicleSeat(entity, -1) ~= 0 then return Bank.notify('Someone is in the driver seat', 'error') end
    busy = true
    local done = lib.progressBar({
        duration = K.repoSeconds * 1000,
        label = ('Repossessing %s'):format(plate),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { scenario = 'WORLD_HUMAN_CLIPBOARD' },
    })
    ClearPedTasks(cache.ped or PlayerPedId())
    busy = false
    if not done then return end
    if not DoesEntityExist(entity) then return Bank.notify('The vehicle is gone', 'error') end
    local res = Bank.api('collections.repo', { netId = NetworkGetNetworkIdFromEntity(entity), plate = plate })
    if res.ok then
        repo[plate] = nil
        Bank.notify(('%s repossessed and sent to the bank lot'):format(plate), 'success')
    else
        local msg = ({ too_far = 'Get closer to the vehicle', occupied = 'Someone is in the vehicle', claimed = 'Another collector has this case', no_vehicle = 'That vehicle is not on an open case' })[res.error]
        Bank.notify(msg or 'Repossession failed', 'error')
    end
end

local function requestPayment(entity)
    local idx = NetworkGetPlayerIndexFromPed(entity)
    if not idx or idx == -1 then return end
    local res = Bank.api('collections.request', { target = GetPlayerServerId(idx) })
    if res.ok then return Bank.notify('Payment request sent', 'inform') end
    local msg = ({ no_debt = 'They have no open debt', too_far = 'Get closer', claimed = 'Another collector has this case' })[res.error]
    Bank.notify(msg or 'Could not send the request', 'error')
end

CreateThread(function()
    Bridge.target.addGlobalVehicle({
        {
            name = 'vr-banking:repo',
            label = 'Repossess vehicle',
            icon = 'fa-solid fa-truck-pickup',
            distance = 3.0,
            canInteract = function(entity)
                if busy or not Bank.isCollector() then return false end
                return repoPlate(entity) ~= nil
            end,
            onSelect = function(data) repossess(type(data) == 'table' and data.entity or data) end,
        },
    })
    Bridge.target.addGlobalPlayer({
        {
            name = 'vr-banking:collect',
            label = 'Collect debt',
            icon = 'fa-solid fa-file-invoice-dollar',
            distance = K.collectDistance,
            canInteract = function() return Bank.isCollector() end,
            onSelect = function(data) requestPayment(type(data) == 'table' and data.entity or data) end,
        },
    })
end)

RegisterNetEvent('vr-banking:client:debtRequest', function(d)
    if type(d) ~= 'table' or type(d.token) ~= 'string' then return end
    local answered = false
    local function answer(method)
        if answered then return end
        answered = true
        TriggerServerEvent('vr-banking:server:debtRespond', d.token, method)
    end
    lib.registerContext({
        id = 'vr-banking:debt',
        title = ('Debt collection · $%s'):format(Fmt.money(d.amount)),
        onExit = function() answer(false) end,
        options = {
            { title = ('%s is collecting case #%d'):format(d.collector or 'A collector', d.caseId or 0), description = 'Paying clears the debt and releases any held vehicles', icon = 'fa-solid fa-circle-info', disabled = true },
            { title = 'Pay from bank', icon = 'fa-solid fa-building-columns', onSelect = function() answer('bank') end },
            { title = 'Pay in cash', icon = 'fa-solid fa-money-bill-wave', onSelect = function() answer('cash') end },
            { title = 'Refuse', icon = 'fa-solid fa-ban', onSelect = function() answer(false) end },
        },
    })
    lib.showContext('vr-banking:debt')
    SetTimeout((tonumber(d.timeout) or 30) * 1000, function()
        if not answered then
            answered = true
            pcall(lib.hideContext, false)
        end
    end)
end)

local TB = (K.tracker or {}).blip or {}
local trackBlips = {}

local function clearTrackers()
    for plate, b in pairs(trackBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
        trackBlips[plate] = nil
    end
end

local function blipName(blip, text)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandSetBlipName(blip)
end

RegisterNetEvent('vr-banking:client:trackers', function(list)
    if type(list) ~= 'table' or not Bank.isCollector() then return clearTrackers() end
    local seen = {}
    for _, t in ipairs(list) do
        local plate = type(t) == 'table' and plateKey(t.plate)
        if plate and tonumber(t.x) and tonumber(t.y) then
            seen[plate] = true
            local b = trackBlips[plate]
            if not b or not DoesBlipExist(b) then
                b = AddBlipForCoord(t.x + 0.0, t.y + 0.0, (tonumber(t.z) or 0) + 0.0)
                SetBlipSprite(b, TB.sprite or 225)
                SetBlipScale(b, TB.scale or 0.85)
                SetBlipAsShortRange(b, false)
                trackBlips[plate] = b
            else
                SetBlipCoords(b, t.x + 0.0, t.y + 0.0, (tonumber(t.z) or 0) + 0.0)
            end
            SetBlipColour(b, t.other and (TB.claimedColour or 47) or (TB.colour or 1))
            blipName(b, ('Repo · %s (%s)%s'):format(t.name or plate, plate, t.other and ' · claimed' or ''))
        end
    end
    for plate, b in pairs(trackBlips) do
        if not seen[plate] then
            if DoesBlipExist(b) then RemoveBlip(b) end
            trackBlips[plate] = nil
        end
    end
end)

RegisterNetEvent('vr-banking:client:carReleased', function(d)
    if type(d) ~= 'table' or not tonumber(d.x) or not tonumber(d.y) then return end
    local hash = GetStreetNameAtCoord(d.x + 0.0, d.y + 0.0, (tonumber(d.z) or 0) + 0.0)
    local street = hash and GetStreetNameFromHashKey(hash) or ''
    SetNewWaypoint(d.x + 0.0, d.y + 0.0)
    Bank.notify(('Your %s (%s) is yours again. It is parked on %s. Waypoint set.'):format(d.name or d.plate, d.plate or '', street ~= '' and street or 'the street'), 'success')
end)

local spotBlips = {}

RegisterNetEvent('vr-banking:client:showSpots', function(list)
    for _, b in ipairs(spotBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    spotBlips = {}
    for _, s in ipairs(type(list) == 'table' and list or {}) do
        if tonumber(s.x) and tonumber(s.y) then
            local b = AddBlipForCoord(s.x + 0.0, s.y + 0.0, (tonumber(s.z) or 0) + 0.0)
            SetBlipSprite(b, 357)
            SetBlipScale(b, 0.7)
            SetBlipColour(b, s.config and 3 or 5)
            SetBlipAsShortRange(b, false)
            blipName(b, s.config and 'Repo spot (config)' or 'Repo spot (added)')
            spotBlips[#spotBlips + 1] = b
        end
    end
    local mine = spotBlips
    SetTimeout(120000, function()
        for _, b in ipairs(mine) do
            if DoesBlipExist(b) then RemoveBlip(b) end
        end
    end)
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearTrackers()
    for _, b in ipairs(spotBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    pcall(function()
        Bridge.target.removeGlobalVehicle('vr-banking:repo')
        Bridge.target.removeGlobalPlayer('vr-banking:collect')
    end)
end)
