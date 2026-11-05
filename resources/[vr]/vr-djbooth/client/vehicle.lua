RegisterNetEvent('vr-djbooth:client:installStereo', function()
    local veh = cache.vehicle
    if not veh or GetPedInVehicleSeat(veh, -1) ~= cache.ped then
        return Notify(Lang.get('not_driver'), 'error')
    end
    if Entity(veh).state.djStereo then return Notify(Lang.get('already_installed'), 'error') end
    local done = lib.progressBar({
        duration = Config.CarStereo.installTime,
        label = 'Installing sound system',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
    })
    if not done then return end
    if cache.vehicle ~= veh then return Notify(Lang.get('not_in_vehicle'), 'error') end
    local ok, reason = lib.callback.await('vr-djbooth:vehicle:install', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then return Notify(ReasonText(reason), 'error') end
    Notify(('Sound system installed. Use /%s to open it.'):format(Config.CarStereo.command), 'success')
end)

local function openStereo()
    if PanelSystem then return end
    local veh = cache.vehicle
    if not veh then return Notify(Lang.get('not_in_vehicle'), 'error') end
    local ok, data = lib.callback.await('vr-djbooth:vehicle:open', false, NetworkGetNetworkIdFromEntity(veh))
    if not ok then return Notify(ReasonText(data), 'error') end
    ShowPanel(data)
end

RegisterCommand(Config.CarStereo.command, openStereo, false)
Keybinds.add({
    name = 'stereo',
    label = 'Open the car stereo',
    description = ('Same as /%s'):format(Config.CarStereo.command),
    suggested = Config.CarStereo.key,
    order = 10,
    onPressed = openStereo,
})
AddEventHandler('vr-djbooth:client:openStereo', openStereo)

CreateThread(function()
    while true do
        Wait(500)
        if PanelSystem and PanelSystem:sub(1, 1) == 'v' and not cache.vehicle then ClosePanel() end
    end
end)
