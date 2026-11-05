local VRCore    = VRCore
local Config    = VRCore.Config
local Functions = VRCore.Functions
local Players   = VRCore.Players
local bridge    = Config.QBBridge

VRCore.Commands = {}
VRCore.Commands.List = {}
VRCore.Commands.IgnoreList = { god = true, user = true }

for _, permission in ipairs(Config.Server.Permissions) do
    ExecuteCommand(('add_ace vrcore.%s %s allow'):format(permission, permission))
end

local function preCommandCancelled(source, name, args, rawCommand)
    TriggerEvent('VRCore:Server:PreCommandExecution', source, name, args, rawCommand)
    if WasEventCanceled() then return true end
    if bridge then
        TriggerEvent('QBCore:Server:PreCommandExecution', source, name, args, rawCommand)
        if WasEventCanceled() then return true end
    end
    return false
end

function VRCore.Commands.Add(name, help, arguments, argsrequired, callback, permission, ...)
    permission = permission or 'user'
    local restricted = permission ~= 'user'

    RegisterCommand(name, function(source, args, rawCommand)
        if argsrequired and #args < #arguments then
            return TriggerClientEvent('chat:addMessage', source, {
                color = { 255, 0, 0 },
                multiline = true,
                args = { 'System', Lang:t('error.missing_args2') },
            })
        end
        if preCommandCancelled(source, name, args, rawCommand) then return end
        callback(source, args, rawCommand)
    end, restricted)

    local perms = { permission, ... }
    for i = 1, #perms do
        local perm = tostring(perms[i]):lower()
        perms[i] = perm
        if not VRCore.Commands.IgnoreList[perm] then
            ExecuteCommand(('add_ace vrcore.%s command.%s allow'):format(perm, name))
        end
    end

    VRCore.Commands.List[name:lower()] = {
        name = name:lower(),
        permission = #perms == 1 and perms[1] or perms,
        help = help,
        arguments = arguments,
        argsrequired = argsrequired,
        callback = callback,
    }
end

function VRCore.Commands.Refresh(source)
    if not Players[source] then return end
    local src = tostring(source)
    local suggestions = {}
    for command, info in pairs(VRCore.Commands.List) do
        if IsPlayerAceAllowed(src, 'command.' .. command) then
            suggestions[#suggestions + 1] = { name = '/' .. command, help = info.help, params = info.arguments }
        else
            TriggerClientEvent('chat:removeSuggestion', source, '/' .. command)
        end
    end
    TriggerClientEvent('chat:addSuggestions', source, suggestions)
end

local function notify(source, key, notifyType)
    TriggerClientEvent('VRCore:Notify', source, Lang:t(key), notifyType or 'error')
end

local function params(...)
    local list = {}
    for i, key in ipairs({ ... }) do
        list[i] = { name = Lang:t(key .. '.name'), help = Lang:t(key .. '.help') }
    end
    return list
end

local function num(value)
    return value and tonumber((value:gsub(',', '')))
end

VRCore.Commands.Add('tp', Lang:t('command.tp.help'), params('command.tp.params.x', 'command.tp.params.y', 'command.tp.params.z'), false, function(source, args)
    if args[1] and not args[2] and not args[3] then
        local target = tonumber(args[1])
        if target then
            local ped = GetPlayerPed(target)
            if ped == 0 then return notify(source, 'error.not_online') end
            return TriggerClientEvent('VRCore:Command:TeleportToPlayer', source, GetEntityCoords(ped))
        end
        local location = VRCore.Shared.Locations[args[1]]
        if not location then return notify(source, 'error.location_not_exist') end
        return TriggerClientEvent('VRCore:Command:TeleportToCoords', source, location.x, location.y, location.z, location.w)
    end
    if not (args[1] and args[2] and args[3]) then return notify(source, 'error.missing_args') end
    local x, y, z, h = num(args[1]), num(args[2]), num(args[3]), num(args[4])
    if not (x and y and z) then return notify(source, 'error.wrong_format') end
    TriggerClientEvent('VRCore:Command:TeleportToCoords', source, x + .0, y + .0, z + .0, h and h + .0 or false)
end, 'admin')

VRCore.Commands.Add('tpm', Lang:t('command.tpm.help'), {}, false, function(source)
    TriggerClientEvent('VRCore:Command:GoToMarker', source)
end, 'admin')

VRCore.Commands.Add('togglepvp', Lang:t('command.togglepvp.help'), {}, false, function()
    Config.Server.PVP = not Config.Server.PVP
    TriggerClientEvent('VRCore:Client:PvpHasToggled', -1, Config.Server.PVP)
end, 'admin')

VRCore.Commands.Add('addpermission', Lang:t('command.addpermission.help'), params('command.addpermission.params.id', 'command.addpermission.params.permission'), true, function(source, args)
    local player = Functions.GetPlayer(tonumber(args[1]))
    if not player then return notify(source, 'error.not_online') end
    Functions.AddPermission(player.PlayerData.source, tostring(args[2]):lower())
end, 'god')

VRCore.Commands.Add('removepermission', Lang:t('command.removepermission.help'), params('command.removepermission.params.id', 'command.removepermission.params.permission'), true, function(source, args)
    local player = Functions.GetPlayer(tonumber(args[1]))
    if not player then return notify(source, 'error.not_online') end
    Functions.RemovePermission(player.PlayerData.source, tostring(args[2]):lower())
end, 'god')

VRCore.Commands.Add('openserver', Lang:t('command.openserver.help'), {}, false, function(source)
    if not Config.Server.Closed then return notify(source, 'error.server_already_open') end
    Functions.OpenServer()
    notify(source, 'success.server_opened', 'success')
end, 'admin')

VRCore.Commands.Add('closeserver', Lang:t('command.closeserver.help'), params('command.closeserver.params.reason'), false, function(source, args)
    if Config.Server.Closed then return notify(source, 'error.server_already_closed') end
    Functions.CloseServer(args[1] and table.concat(args, ' ') or nil)
    notify(source, 'success.server_closed', 'success')
end, 'admin')

VRCore.Commands.Add('car', Lang:t('command.car.help'), params('command.car.params.model'), true, function(source, args)
    TriggerClientEvent('VRCore:Command:SpawnVehicle', source, args[1])
end, 'admin')

VRCore.Commands.Add('dv', Lang:t('command.dv.help'), {}, false, function(source)
    TriggerClientEvent('VRCore:Command:DeleteVehicle', source)
end, 'admin')

VRCore.Commands.Add('dvall', Lang:t('command.dvall.help'), {}, false, function()
    for _, vehicle in ipairs(GetAllVehicles()) do DeleteEntity(vehicle) end
end, 'admin')

VRCore.Commands.Add('dvp', Lang:t('command.dvp.help'), {}, false, function()
    for _, ped in ipairs(GetAllPeds()) do
        if not IsPedAPlayer(ped) then DeleteEntity(ped) end
    end
end, 'admin')

VRCore.Commands.Add('dvo', Lang:t('command.dvo.help'), {}, false, function()
    for _, object in ipairs(GetAllObjects()) do DeleteEntity(object) end
end, 'admin')

VRCore.Commands.Add('givemoney', Lang:t('command.givemoney.help'), params('command.givemoney.params.id', 'command.givemoney.params.moneytype', 'command.givemoney.params.amount'), true, function(source, args)
    local player = Functions.GetPlayer(tonumber(args[1]))
    if not player then return notify(source, 'error.not_online') end
    player:AddMoney(tostring(args[2]), tonumber(args[3]), 'Admin give money')
end, 'admin')

VRCore.Commands.Add('setmoney', Lang:t('command.setmoney.help'), params('command.setmoney.params.id', 'command.setmoney.params.moneytype', 'command.setmoney.params.amount'), true, function(source, args)
    local player = Functions.GetPlayer(tonumber(args[1]))
    if not player then return notify(source, 'error.not_online') end
    player:SetMoney(tostring(args[2]), tonumber(args[3]), 'Admin set money')
end, 'admin')

VRCore.Commands.Add('job', Lang:t('command.job.help'), {}, false, function(source)
    local player = Players[source]
    if not player then return end
    local job = player.PlayerData.job
    TriggerClientEvent('VRCore:Notify', source, Lang:t('info.job_info', { value = job.label, value2 = job.grade.name, value3 = job.onduty }))
end, 'user')

VRCore.Commands.Add('setjob', Lang:t('command.setjob.help'), params('command.setjob.params.id', 'command.setjob.params.job', 'command.setjob.params.grade'), true, function(source, args)
    local player = Functions.GetPlayer(tonumber(args[1]))
    if not player then return notify(source, 'error.not_online') end
    player:SetJob(tostring(args[2]), tonumber(args[3]))
end, 'admin')

VRCore.Commands.Add('gang', Lang:t('command.gang.help'), {}, false, function(source)
    local player = Players[source]
    if not player then return end
    local gang = player.PlayerData.gang
    TriggerClientEvent('VRCore:Notify', source, Lang:t('info.gang_info', { value = gang.label, value2 = gang.grade.name }))
end, 'user')

VRCore.Commands.Add('setgang', Lang:t('command.setgang.help'), params('command.setgang.params.id', 'command.setgang.params.gang', 'command.setgang.params.grade'), true, function(source, args)
    local player = Functions.GetPlayer(tonumber(args[1]))
    if not player then return notify(source, 'error.not_online') end
    player:SetGang(tostring(args[2]), tonumber(args[3]))
end, 'admin')

local function chatTo(target, label, message)
    TriggerClientEvent('chat:addMessage', target, { color = Config.Commands.OOCColor, multiline = true, args = { label, message } })
end

VRCore.Commands.Add('ooc', Lang:t('command.ooc.help'), {}, false, function(source, args)
    local message = table.concat(args, ' ')
    if message == '' then return end
    local name = GetPlayerName(source)
    local origin = GetEntityCoords(GetPlayerPed(source))
    local adminCopy = false
    for target in pairs(Players) do
        if target == source or #(origin - GetEntityCoords(GetPlayerPed(target))) < 20.0 then
            chatTo(target, 'OOC | ' .. name, message)
        elseif Functions.IsOptin(target) then
            chatTo(target, 'Proximity OOC | ' .. name, message)
            adminCopy = true
        end
    end
    if adminCopy then
        local player = Players[source]
        CoreLog('ooc', 'OOC', 'white', false, '**%s** (CitizenID: %s | ID: %s) **Message:** %s',
            name, player and player.PlayerData.citizenid or 'n/a', source, message)
    end
end, 'user')

VRCore.Commands.Add('me', Lang:t('command.me.help'), params('command.me.params.message'), false, function(source, args)
    if #args < 1 then return notify(source, 'error.missing_args2') end
    local ped = GetPlayerPed(source)
    local origin = GetEntityCoords(ped)
    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    for target in pairs(Players) do
        local targetPed = GetPlayerPed(target)
        if targetPed == ped or #(origin - GetEntityCoords(targetPed)) < 20.0 then
            TriggerClientEvent('VRCore:Command:ShowMe3D', target, source, msg)
        end
    end
end, 'user')
