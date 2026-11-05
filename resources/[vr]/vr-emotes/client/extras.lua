if Config.RagdollEnabled then
    local ragdolling = false

    local function startRagdoll()
        if IsInAnimation then return end
        local ped = PlayerPedId()
        if not IsPedOnFoot(ped) then return end
        if Config.RagdollAsToggle then ragdolling = not ragdolling else ragdolling = true end
        if not ragdolling then return end
        CreateThread(function()
            while ragdolling do
                SetPedToRagdoll(PlayerPedId(), 1000, 1000, 0, false, false, false)
                Wait(0)
            end
        end)
    end

    local function stopRagdoll()
        if Config.RagdollAsToggle then return end
        ragdolling = false
    end

    Keybinds.add({
        name = 'ragdoll',
        label = 'Fall over (ragdoll)',
        description = Config.RagdollAsToggle and 'Press again to get up' or 'Hold to stay down',
        suggested = Config.Suggested.ragdoll,
        order = 40,
        onPressed = startRagdoll,
        onReleased = stopRagdoll,
    })
end

local function setIdleCam(off)
    DisableIdleCamera(off)
    SetPedCanPlayAmbientAnims(PlayerPedId(), not off)
    SetResourceKvp('idleCam', off and 'off' or 'on')
end

RegisterCommand('idlecamoff', function()
    setIdleCam(true)
    Notify('Idle camera is off.', 'success')
end, false)

RegisterCommand('idlecamon', function()
    setIdleCam(false)
    Notify('Idle camera is on.', 'success')
end, false)

CreateThread(function()
    TriggerEvent('chat:addSuggestion', '/idlecamon', 'Turn the idle camera back on')
    TriggerEvent('chat:addSuggestion', '/idlecamoff', 'Turn off the camera that moves when you stand still')
    DisableIdleCamera(GetResourceKvpString('idleCam') == 'off')
end)
