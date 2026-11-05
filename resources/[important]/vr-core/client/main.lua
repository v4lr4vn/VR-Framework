local VRCore = VRCore
local Config = VRCore.Config

TriggerServerEvent('VRCore:Server:RequestSharedSync')

CreateThread(function()
    local interval = Config.StatusInterval
    while true do
        Wait(interval)
        if LocalPlayer.state.isLoggedIn then
            local md = VRCore.PlayerData.metadata
            if md and ((md.hunger or 100) <= 0 or (md.thirst or 100) <= 0) and not (md.isdead or md.inlaststand) then
                local ped = PlayerPedId()
                SetEntityHealth(ped, GetEntityHealth(ped) - math.random(5, 10))
            end
        end
    end
end)

for name, fn in pairs(VRCore.Functions) do
    if type(fn) == 'function' and not ExportedNames[name] then
        CoreExport(name, fn)
    end
end
