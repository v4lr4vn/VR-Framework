CreateThread(function()
    Wait(1000)

    exports['vr-ui']:registerRadial({ id = 'test_vehicle', label = 'Vehicle', items = {
        { label = 'Engine', icon = 'power-off', onSelect = function() print('engine') end },
        { label = 'Lock',   icon = 'key',       onSelect = function() print('lock') end },
        { label = 'Doors',  icon = 'door-open', onSelect = function() print('doors') end },
    }})

    exports['vr-ui']:addRadialItem({
        { id = 't_citizen', label = 'Citizen', icon = 'user',          onSelect = function() print('citizen') end },
        { id = 't_vehicle', label = 'Vehicle', icon = 'car',           menu = 'test_vehicle' },
        { id = 't_emotes',  label = 'Emotes',  icon = 'face-smile',    onSelect = function() print('emotes') end },
        { id = 't_police',  label = 'Police',  icon = 'shield-halved', onSelect = function() print('police') end },
    })
end)
