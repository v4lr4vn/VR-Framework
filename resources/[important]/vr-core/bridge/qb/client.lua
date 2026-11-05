if not VRCore.Config.QBBridge then return end

local VRCore    = VRCore
local Functions = VRCore.Functions

for _, name in ipairs({ 'Client:OnPlayerLoaded', 'Client:OnPlayerUnload', 'Client:OnMoneyChange', 'Client:SetDuty' }) do
    RegisterNetEvent('VRCore:' .. name, function(...) TriggerEvent('QBCore:' .. name, ...) end)
end

for _, name in ipairs({ 'DrawText', 'ChangeText', 'HideText', 'KeyPressed' }) do
    RegisterNetEvent('qb-core:client:' .. name, function(...) TriggerEvent('vr-core:client:' .. name, ...) end)
end

Functions.GetStreetNametAtCoords = Functions.GetStreetNameAtCoords
CoreExport('GetStreetNametAtCoords', Functions.GetStreetNameAtCoords)

-- Names older QBCore scripts still use.
Functions.LoadAnimDict = Functions.LoadAnimDict or Functions.RequestAnimDict
Functions.TriggerServerCallback = Functions.TriggerServerCallback or Functions.TriggerCallback
Functions.GetVehicleDisplayName = Functions.GetVehicleDisplayName or function(vehicle)
    return GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
end
