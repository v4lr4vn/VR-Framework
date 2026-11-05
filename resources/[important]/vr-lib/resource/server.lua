exports('cache', function() return nil end)

exports('setVehicleProperties', function(vehicle, props)
    if not DoesEntityExist(vehicle) or type(props) ~= 'table' then return false end
    Entity(vehicle).state:set('vr_lib:vehicleProperties', props, true)
    return true
end)
