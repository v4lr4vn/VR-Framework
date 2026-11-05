local W = VRCore.Config.World or {}
local blocked = {}

if W.AIPolice == false then
    for _, model in ipairs(W.BlockedVehicles or {}) do blocked[joaat(model)] = true end
    for _, model in ipairs(W.BlockedPeds or {}) do blocked[joaat(model)] = true end
end

AddEventHandler('entityCreating', function(entity)
    if not next(blocked) then return end
    local model = GetEntityModel(entity)
    if not blocked[model] then return end
    local pop = GetEntityPopulationType(entity)
    if pop >= 1 and pop <= 5 then CancelEvent() end
end)

local expected = 'vr-core'
local current = GetCurrentResourceName()
if current ~= expected then
    local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
    print(message)
    if IsDuplicityVersion() then
        CreateThread(function() StopResource(current) end)
    end
    error(message, 0)
end