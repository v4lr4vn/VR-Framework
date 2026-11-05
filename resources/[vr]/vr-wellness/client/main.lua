local VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })
local busy = false

local function notify(msg, kind)
    if msg then VRCore.Functions.Notify(msg, kind or 'primary') end
end

local function await(name, ...)
    local p = promise.new()
    VRCore.Functions.TriggerCallback(name, function(...) p:resolve({ ... }) end, ...)
    local r = Citizen.Await(p)
    return table.unpack(r)
end

local function activity(label, duration, scenario)
    busy = true
    CreateThread(function()
        while busy do
            if IsControlJustPressed(0, Config.CancelKey) then exports['vr-ui']:cancelProgress() end
            Wait(0)
        end
    end)
    local done = exports['vr-ui']:progressBar({
        duration = duration,
        label = label,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { scenario = scenario },
    })
    busy = false
    return done == true
end

local function startYoga(index)
    if busy then return notify(Config.Text.busy, 'error') end
    if IsPedInAnyVehicle(PlayerPedId(), false) then return notify(Config.Text.inVehicle, 'error') end
    local ok, reason = await('vr-wellness:yogaStart', index)
    if not ok then return notify(reason, 'error') end
    local Y = Config.Yoga
    if activity(Config.Text.yogaLabel, Y.duration, Y.scenario) then
        local good, msg = await('vr-wellness:yogaFinish')
        notify(msg, good and 'success' or 'error')
    else
        TriggerServerEvent('vr-wellness:server:cancel')
        notify(Config.Text.stopped)
    end
end

CreateThread(function()
    for i, spot in ipairs(Config.Yoga.spots) do
        exports['vr-target']:addSphereZone({
            coords = spot.coords,
            radius = Config.Yoga.radius,
            options = {
                {
                    name = ('vr_wellness_yoga_%d'):format(i),
                    icon = 'fa-solid fa-spa',
                    label = Config.Text.yogaTarget,
                    distance = 2.0,
                    onSelect = function() startYoga(i) end,
                },
            },
        })
        local b = Config.Yoga.blip
        if b.enabled then
            local blip = AddBlipForCoord(spot.coords.x, spot.coords.y, spot.coords.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.colour)
            SetBlipScale(blip, b.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(spot.label or b.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

RegisterNetEvent('vr-wellness:client:smoke', function()
    if busy then return TriggerServerEvent('vr-wellness:server:cancel') end
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        TriggerServerEvent('vr-wellness:server:cancel')
        return notify(Config.Text.inVehicle, 'error')
    end
    local S = Config.Smoking
    if activity(Config.Text.smokeLabel, S.duration, S.scenario) then
        local good, msg = await('vr-wellness:smokeFinish')
        notify(msg, good and 'success' or 'error')
    else
        TriggerServerEvent('vr-wellness:server:cancel')
        notify(Config.Text.stopped)
    end
end)

RegisterCommand('yogaspot', function()
    local c = GetEntityCoords(PlayerPedId())
    local line = ("{ label = 'New spot', coords = vec3(%.2f, %.2f, %.2f) },"):format(c.x, c.y, c.z - 1.0)
    print('[vr-wellness] ' .. line)
    pcall(function() exports['vr-ui']:setClipboard(line) end)
    notify('Spot line copied, also printed in F8')
end, true)
