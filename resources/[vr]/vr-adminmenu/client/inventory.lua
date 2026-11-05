RegisterNetEvent('vr-adminmenu:client:openInventory', function(data, selectedData)
    local player = type(selectedData) == 'table' and selectedData["Player"] and selectedData["Player"].value
    if not player then return end

    TriggerServerEvent("vr-adminmenu:server:OpenInv", player)
end)

RegisterNetEvent('vr-adminmenu:client:openStash', function(data, selectedData)
    local stash = type(selectedData) == 'table' and selectedData["Stash"] and selectedData["Stash"].value
    if not stash then return end

    TriggerServerEvent("vr-adminmenu:server:OpenStash", stash)
end)

RegisterNetEvent('vr-adminmenu:client:openTrunk', function(data, selectedData)
    local vehiclePlate = type(selectedData) == 'table' and selectedData["Plate"] and selectedData["Plate"].value
    if not vehiclePlate then return end

    TriggerServerEvent("vr-adminmenu:server:OpenTrunk", vehiclePlate)
end)
