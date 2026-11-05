Stress = { value = 0, seatbelt = false }

local S = Config.Stress
if not S.enabled then return end

local function noStress(weapon)
    for i = 1, #S.noStressWeapons do
        if S.noStressWeapons[i] == weapon then return true end
    end
    return false
end

CreateThread(function()
    local nextAt = 0
    while true do
        Wait(1000)
        local v = Stress.value
        if v >= S.minimum and GetGameTimer() > nextAt then
            for i = 1, #S.levels do
                local lv = S.levels[i]
                if v >= lv[1] and v < lv[2] then
                    TriggerScreenblurFadeIn(500.0)
                    Wait(lv[3])
                    TriggerScreenblurFadeOut(500.0)
                    nextAt = GetGameTimer() + math.random(lv[4], lv[5]) * 1000
                    break
                end
            end
        end
    end
end)

CreateThread(function()
    local lastAmmo, lastWeapon = 0, 0
    while true do
        Wait(150)
        local ped = PlayerPedId()
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= `WEAPON_UNARMED` then
            local ammo = GetAmmoInPedWeapon(ped, weapon)
            if weapon == lastWeapon and ammo < lastAmmo and not noStress(weapon) and math.random() < S.chance then
                TriggerServerEvent('hud:server:GainStress', math.random(1, 3))
            end
            lastAmmo = ammo
        else
            lastAmmo = 0
        end
        lastWeapon = weapon
    end
end)

CreateThread(function()
    while true do
        Wait(3000)
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            local class = GetVehicleClass(veh)
            local mph = GetEntitySpeed(veh) * 2.23694
            if class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16 then
                local belted = Stress.seatbelt or class == 8
                local limit = belted and S.speedAny or S.speedUnbuckled
                if mph > limit and math.random() < S.chance * 2 then
                    TriggerServerEvent('hud:server:GainStress', math.random(1, 2))
                end
            end
        end
    end
end)
