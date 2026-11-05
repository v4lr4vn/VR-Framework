local visible = true
RegisterNetEvent('vr-adminmenu:client:ToggleInvisible', function(data)
    visible = not visible
    SetEntityVisible(cache.ped, visible, 0)
end)

local godmode = false
RegisterNetEvent('vr-adminmenu:client:ToggleGodmode', function(data)
    godmode = not godmode

    if godmode then
        Notify(locale("godmode", "enabled"), 'primary')
        while godmode do
            Wait(0)
            SetPlayerInvincible(cache.playerId, true)
        end
        SetPlayerInvincible(cache.playerId, false)
        Notify(locale("godmode", "disabled"), 'primary')
    end
end)

RegisterNetEvent('vr-adminmenu:client:ToggleCuffs', function()
    if not ResourceUp('police') then return end
    TriggerEvent("police:client:GetCuffed", cache.serverId)
end)

local function CopyCoords(data)
    local coords = GetEntityCoords(cache.ped)
    local heading = GetEntityHeading(cache.ped)
    local formats = { vector2 = "%.2f, %.2f", vector3 = "%.2f, %.2f, %.2f", vector4 = "%.2f, %.2f, %.2f, %.2f", heading =
    "%.2f" }
    local format = formats[data]
    if not format then return end

    local clipboardText = ""
    if data == "vector2" then
        clipboardText = string.format(format, coords.x, coords.y)
    elseif data == "vector3" then
        clipboardText = string.format(format, coords.x, coords.y, coords.z)
    elseif data == "vector4" then
        clipboardText = string.format(format, coords.x, coords.y, coords.z, heading)
    elseif data == "heading" then
        clipboardText = string.format(format, heading)
    end

    lib.setClipboard(clipboardText)
end

RegisterCommand("vector2", function()
    TriggerServerEvent('vr-adminmenu:server:ValidateCommand', 'vector2')
end, false)

RegisterCommand("vector3", function()
    TriggerServerEvent('vr-adminmenu:server:ValidateCommand', 'vector3')
end, false)

RegisterCommand("vector4", function()
    TriggerServerEvent('vr-adminmenu:server:ValidateCommand', 'vector4')
end, false)

RegisterCommand("heading", function()
    TriggerServerEvent('vr-adminmenu:server:ValidateCommand', 'heading')
end, false)

RegisterNetEvent('vr-adminmenu:client:CopyCoords', function(type)
    CopyCoords(type)
end)

local InfiniteAmmo = false
RegisterNetEvent('vr-adminmenu:client:setInfiniteAmmo', function(data)
    InfiniteAmmo = not InfiniteAmmo

    if GetAmmoInPedWeapon(cache.ped, cache.weapon) < 6 then
        SetAmmoInClip(cache.ped, cache.weapon, 10)
        Wait(50)
    end

    while InfiniteAmmo do
        SetPedInfiniteAmmo(cache.ped, true, cache.weapon)
        RefillAmmoInstantly(cache.ped)
        Wait(250)
    end

    SetPedInfiniteAmmo(cache.ped, false, cache.weapon)
end)

local showCoords = false
local function showCoordsMenu()
    while showCoords do
        Wait(50)
        local coords = GetEntityCoords(PlayerPedId())
        local heading = GetEntityHeading(PlayerPedId())
        SendNUIMessage({
            action = "showCoordsMenu",
            data = {
                show = showCoords,
                x = VRCore.Shared.Round(coords.x, 2),
                y = VRCore.Shared.Round(coords.y, 2),
                z = VRCore.Shared.Round(coords.z, 2),
                heading = VRCore.Shared.Round(heading, 2)
            }
        })
    end
end

RegisterNetEvent('vr-adminmenu:client:ToggleCoords', function(data)
    showCoords = not showCoords

    if showCoords then
        CreateThread(showCoordsMenu)
    end
end)

RegisterNetEvent('vr-adminmenu:client:SetAmmo', function(data, selectedData)
    local ammo = tonumber(type(selectedData) == 'table' and selectedData["Ammo Amount"] and selectedData["Ammo Amount"].value)
    if not ammo or ammo < 0 then return Notify(locale("empty_input"), 'error') end
    local weapon = GetSelectedPedWeapon(cache.ped)

    if weapon ~= nil and weapon ~= `WEAPON_UNARMED` then
        SetPedAmmo(cache.ped, weapon, math.floor(ammo))
        Notify(locale("set_wepaon_ammo", tostring(math.floor(ammo))), 'success')
    else
        Notify(locale("no_weapon"), 'error')
    end
end)

RegisterCommand("setammo", function()
    TriggerServerEvent('vr-adminmenu:server:ValidateCommand', 'setammo')
end, false)

RegisterNetEvent('vr-adminmenu:client:SetAmmoCommand', function()
    local weapon = GetSelectedPedWeapon(cache.ped)
    local ammo = 999
    if weapon ~= nil and weapon ~= `WEAPON_UNARMED` then
        SetPedAmmo(cache.ped, weapon, ammo)
        Notify(locale("set_wepaon_ammo", tostring(ammo)), 'success')
    else
        Notify(locale("no_weapon"), 'error')
    end
end)

local ToggleDev = false

RegisterNetEvent('vr-adminmenu:client:ToggleDev', function(dataKey)
    ToggleDev = not ToggleDev

    if ResourceUp('hud') then
        TriggerEvent("vr-admin:client:ToggleDevmode")
    end
    TriggerEvent('vr-adminmenu:client:ToggleCoords', dataKey)
    TriggerEvent('vr-adminmenu:client:ToggleGodmode', dataKey)

    Notify(locale("toggle_dev"), 'success')
end)

local toogleAdmin = lib.addKeybind({
    name = 'toogleAdmin',
    description = locale("command_admin_desc"),
    defaultKey = Config.AdminKey,
    onPressed = function(self)
        ExecuteCommand('admin')
    end
})

RegisterCommand('nc', function()
    TriggerServerEvent('vr-adminmenu:server:ValidateClientAction', 'noclip')
end, false)

local toogleNoclip = lib.addKeybind({
    name = 'toogleNoclip',
    description = locale("command_noclip_desc"),
    defaultKey = Config.NoclipKey,
    onPressed = function(self)
        ExecuteCommand('nc')
    end
})

if Config.Keybindings then
    toogleAdmin:disable(false)
    toogleNoclip:disable(false)
else
    toogleAdmin:disable(true)
    toogleNoclip:disable(true)
end

RegisterNetEvent("vr-adminmenu:client:setPed", function(pedModels)
    if type(pedModels) ~= 'string' or not IsModelInCdimage(joaat(pedModels)) then return end
    lib.requestModel(pedModels, 1500)
    SetPlayerModel(cache.playerId, pedModels)
    SetPedDefaultComponentVariation(PlayerPedId())
    SetModelAsNoLongerNeeded(pedModels)
end)
