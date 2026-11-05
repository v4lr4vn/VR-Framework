RegisterNetEvent('vr-adminmenu:client:copyToClipboard', function(data, selectedData)
    local dropdown = type(selectedData) == 'table' and selectedData["Copy Coords"] and selectedData["Copy Coords"].value
    local ped = PlayerPedId()
    local string = nil
    if dropdown == 'vector2' then
        local coords = GetEntityCoords(ped)
        local x = VRCore.Shared.Round(coords.x, 2)
        local y = VRCore.Shared.Round(coords.y, 2)
        string = "vector2(".. x ..", ".. y ..")"
        Notify(locale("copy_vector2"), 'success')
    elseif dropdown == 'vector3' then
        local coords = GetEntityCoords(ped)
        local x = VRCore.Shared.Round(coords.x, 2)
        local y = VRCore.Shared.Round(coords.y, 2)
        local z = VRCore.Shared.Round(coords.z, 2)
        string = "vector3(".. x ..", ".. y ..", ".. z ..")"
        Notify(locale("copy_vector3"), 'success')
    elseif dropdown == 'vector4' then
        local coords = GetEntityCoords(ped)
        local x = VRCore.Shared.Round(coords.x, 2)
        local y = VRCore.Shared.Round(coords.y, 2)
        local z = VRCore.Shared.Round(coords.z, 2)
        local heading = GetEntityHeading(ped)
        local h = VRCore.Shared.Round(heading, 2)
        string = "vector4(".. x ..", ".. y ..", ".. z ..", ".. h ..")"
        Notify(locale("copy_vector4"), 'success')
    elseif dropdown == 'heading' then
        local heading = GetEntityHeading(ped)
        local h = VRCore.Shared.Round(heading, 2)
        string = tostring(h)
        Notify(locale("copy_heading"), 'success')
    end

    if string == nil then
        return Notify(locale("empty_input"), 'error')
    end

    lib.setClipboard(string)
end)
