VRCore = exports['vr-core']:GetCoreObject({ 'Functions', 'Commands' })

VRCore.Commands.Add('admin', locale('command_admin_desc'), {}, false, function(source)
    local src = source
    if src <= 0 or not CheckPerms(src, Config.MenuPerms) then return end
    if Config.RequireAdminDuty and VRCore.Functions.HasPermission(src, 'admin') and not VRCore.Functions.IsOptin(src) then
        return VRCore.Functions.Notify(src, 'You are not on admin duty', 'error')
    end
    TriggerClientEvent('vr-adminmenu:client:OpenUI', src)
end, Config.MenuPerms)

RegisterNetEvent('vr-adminmenu:server:ValidateClientAction', function(key, selectedData)
    local src = source
    local action = GetActionByKey(key)
    if not action or action.type ~= 'client' or type(action.event) ~= 'string' then return end
    if not CheckPerms(src, action.perms) then return end
    if selectedData ~= nil and type(selectedData) ~= 'table' then selectedData = nil end
    AdminLog(src, key, selectedData)
    TriggerClientEvent(action.event, src, key, selectedData)
end)

local commandEvents = {
    vector2 = 'vr-adminmenu:client:copyToClipboard',
    vector3 = 'vr-adminmenu:client:copyToClipboard',
    vector4 = 'vr-adminmenu:client:copyToClipboard',
    heading = 'vr-adminmenu:client:copyToClipboard',
    setammo = 'vr-adminmenu:client:SetAmmo',
}

RegisterNetEvent('vr-adminmenu:server:ValidateCommand', function(command)
    local src = source
    local event = type(command) == 'string' and commandEvents[command]
    if not event or not Authorize(src, event) then return end

    if command == 'setammo' then
        TriggerClientEvent('vr-adminmenu:client:SetAmmoCommand', src)
    else
        TriggerClientEvent('vr-adminmenu:client:CopyCoords', src, command)
    end
end)
