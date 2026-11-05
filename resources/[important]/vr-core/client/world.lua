local W = VRCore.Config.World or {}

local function noPolice()
    return W.AIPolice == false
end

local function applyOnce()
    local player = PlayerId()
    if W.WantedLevel == false then
        SetMaxWantedLevel(0)
        SetPoliceIgnorePlayer(player, true)
        SetDispatchCopsForPlayer(player, false)
    end
    if noPolice() then
        for _, id in ipairs(W.DisabledDispatch or {}) do EnableDispatchService(id, false) end
        SetCreateRandomCops(false)
        SetCreateRandomCopsNotOnScenarios(false)
        SetCreateRandomCopsOnScenarios(false)
        DistantCopCarSirens(false)
        for _, model in ipairs(W.BlockedVehicles or {}) do SetVehicleModelIsSuppressed(joaat(model), true) end
        for _, model in ipairs(W.BlockedPeds or {}) do SetPedModelIsSuppressed(joaat(model), true) end
        for _, name in ipairs(W.BlockedScenarioTypes or {}) do SetScenarioTypeEnabled(name, false) end
        for _, name in ipairs(W.BlockedScenarioGroups or {}) do
            if DoesScenarioGroupExist(name) then SetScenarioGroupEnabled(name, false) end
        end
    end
    if W.PoliceScanner == false then
        SetAudioFlag('PoliceScannerDisabled', true)
    end
end

CreateThread(function()
    applyOnce()
    local player = PlayerId()
    while true do
        Wait(1000)
        if W.WantedLevel == false and GetPlayerWantedLevel(player) ~= 0 then
            ClearPlayerWantedLevel(player)
            SetPlayerWantedLevelNow(player, false)
        end
        if W.WantedLevel == false then SetMaxWantedLevel(0) end
    end
end)

AddEventHandler('playerSpawned', applyOnce)
RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function() SetTimeout(500, applyOnce) end)
