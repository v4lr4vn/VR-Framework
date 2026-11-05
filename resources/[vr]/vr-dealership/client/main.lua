Dealer = { open = false, pd = {}, current = nil, mode = nil }

function Dealer.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-dealership:api', false, action, data)
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function Dealer.notify(text, kind)
    lib.notify({ title = 'Dealership', description = text, type = kind or 'inform' })
end

local function loadPlayerData()
    local pd = Bridge.playerData(true)
    if type(pd) == 'table' then Dealer.pd = pd end
end

Bridge.on('playerData', function(pd)
    if type(pd) == 'table' then Dealer.pd = pd end
end)

Bridge.on('jobChanged', function() loadPlayerData() end)
Bridge.on('dutyChanged', function() loadPlayerData() end)

Bridge.on('playerLoaded', function()
    SetTimeout(500, loadPlayerData)
end)

CreateThread(loadPlayerData)

function Dealer.isStaff()
    local job = Dealer.pd.job
    return type(job) == 'table' and job.name == Config.Job and job.onduty == true
end

function Dealer.show(mode, data)
    Dealer.open = true
    Dealer.mode = mode
    SendNUIMessage({ action = 'open', mode = mode, data = data })
    SetNuiFocus(true, true)
end

function Dealer.hide()
    if not Dealer.open then return end
    Dealer.open = false
    Dealer.mode = nil
    if Preview and Preview.active() then Preview.stop() end
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function Dealer.browse(id)
    local res = Dealer.api('open', { dealer = id })
    if not res.ok then return Dealer.notify(res.error == 'too_far' and 'Get closer to the desk' or 'The showroom is closed right now', 'error') end
    Dealer.current = id
    Dealer.show('shop', res.data)
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    local data = type(d.data) == 'table' and d.data or {}
    if Dealer.current and d.action ~= 'offer.respond' then data.dealer = Dealer.current end
    local res = Dealer.api(d.action, data)
    cb(res)
    if res.ok and (d.action == 'buy' or d.action == 'testdrive') then Dealer.hide() end
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    if Dealer.mode == 'offer' and Dealer.offerToken then
        Dealer.api('offer.respond', { token = Dealer.offerToken, accept = false })
        Dealer.offerToken = nil
    end
    Dealer.hide()
end)

local statCache = {}

RegisterNUICallback('stats', function(d, cb)
    local out = {}
    for _, model in ipairs(type(d) == 'table' and d.models or {}) do
        if type(model) == 'string' then
            if not statCache[model] then
                local hash = joaat(model)
                statCache[model] = {
                    speed = GetVehicleModelEstimatedMaxSpeed(hash) or 0,
                    accel = GetVehicleModelAcceleration(hash) or 0,
                    braking = GetVehicleModelMaxBraking(hash) or 0,
                    traction = GetVehicleModelMaxTraction(hash) or 0,
                    seats = GetVehicleModelNumberOfSeats(hash) or 0,
                }
            end
            out[model] = statCache[model]
        end
    end
    cb(out)
end)

RegisterNetEvent('vr-dealership:client:offer', function(offer)
    if type(offer) ~= 'table' or type(offer.token) ~= 'string' then return end
    Dealer.offerToken = offer.token
    Dealer.current = nil
    Dealer.show('offer', offer)
end)

RegisterNUICallback('offerAnswer', function(d, cb)
    local token = Dealer.offerToken
    Dealer.offerToken = nil
    if not token then return cb({ ok = false, error = 'no_offer' }) end
    local res = Dealer.api('offer.respond', { token = token, accept = d.accept == true, method = d.method })
    cb(res)
    if res.ok then
        Dealer.hide()
        if res.data and res.data.plate then
            Dealer.notify(res.data.delivered and ('Your %s is outside. Enjoy it!'):format(res.data.plate) or ('Paperwork done. Collect %s from the garage.'):format(res.data.plate), 'success')
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and Dealer.open then SetNuiFocus(false, false) end
end)
