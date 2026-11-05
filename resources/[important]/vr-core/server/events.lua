local VRCore    = VRCore
local Config    = VRCore.Config
local Functions = VRCore.Functions
local Players   = VRCore.Players

AddEventHandler('chatMessage', function(_, _, message)
    if message:sub(1, 1) == '/' then CancelEvent() end
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local player = Players[src]
    if not player then return end
    CoreLog('joinleave', 'Dropped', 'red', false, '**%s** (%s) left..\n **Reason:** %s', GetPlayerName(src), player.PlayerData.license, reason)
    player:Save()
    CoreEmit('Server:PlayerDropped', src)
    CoreEmit('Server:OnPlayerUnload', src)
    VRCore.Player.Forget(src)
end)

AddEventHandler('playerConnecting', function(name, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)

    if Config.Server.Closed and not IsPlayerAceAllowed(src, 'vradmin.join') then
        return deferrals.done(Config.Server.ClosedReason)
    end
    if not CoreDB.connected then return deferrals.done(Lang:t('error.connecting_database_error')) end
    if not CoreDB.tablesOk then return deferrals.done(Lang:t('error.ban_table_not_found')) end

    if Config.Server.Whitelist then
        deferrals.update(Lang:t('info.checking_whitelisted'):format(name))
        if not Functions.IsWhitelisted(src) then return deferrals.done(Lang:t('error.not_whitelisted')) end
    end

    deferrals.update(Lang:t('info.checking_license'):format(name))
    local license = Functions.GetIdentifier(src, 'license')
    if not license then return deferrals.done(Lang:t('error.no_valid_license')) end
    if Config.Server.CheckDuplicateLicense and Functions.IsLicenseInUse(license) then
        return deferrals.done(Lang:t('error.duplicate_license'))
    end

    deferrals.update(Lang:t('info.checking_ban'):format(name))
    local ok, banned, message = pcall(Functions.IsPlayerBanned, src)
    if not ok then return deferrals.done(Lang:t('error.connecting_database_error')) end
    if banned then return deferrals.done(message) end

    deferrals.update(Lang:t('info.join_server'):format(name))
    deferrals.done()
end)

function VRCore.Functions.CloseServer(reason)
    Config.Server.Closed = true
    Config.Server.ClosedReason = reason or 'No reason specified'
    for src in pairs(Players) do
        if not Functions.HasPermission(src, Config.Server.WhitelistPermission) then
            Functions.Kick(src, Config.Server.ClosedReason)
        end
    end
end

function VRCore.Functions.OpenServer()
    Config.Server.Closed = false
end

CoreOnNet('Server:CloseServer', function(reason)
    local src = source
    if not Functions.HasPermission(src, 'admin') then return Functions.Kick(src, Lang:t('error.no_permission')) end
    Functions.CloseServer(reason)
end)

CoreOnNet('Server:OpenServer', function()
    local src = source
    if not Functions.HasPermission(src, 'admin') then return Functions.Kick(src, Lang:t('error.no_permission')) end
    Functions.OpenServer()
end)

CoreOnNet('ToggleDuty', function()
    local src = source
    local player = Players[src]
    if not player then return end
    local onDuty = not player.PlayerData.job.onduty
    player:SetJobDuty(onDuty)
    player:Notify(Lang:t(onDuty and 'info.on_duty' or 'info.off_duty'))
    CoreEmit('Server:SetDuty', src, onDuty)
    TriggerClientEvent('VRCore:Client:SetDuty', src, onDuty)
end)

CoreOnNet('Server:OnPlayerLoaded', function()
    local src = source
    if not Players[src] then return end
    TriggerClientEvent('VRCore:Client:OnPlayerLoaded', src)
end)

local function vehicleInfo(eventName)
    return function(veh, seat, modelName)
        TriggerClientEvent('VRCore:Client:VehicleInfo', source, { vehicle = veh, seat = seat, name = modelName, event = eventName })
    end
end

RegisterNetEvent('baseevents:enteringVehicle', vehicleInfo('Entering'))
RegisterNetEvent('baseevents:enteredVehicle', vehicleInfo('Entered'))
RegisterNetEvent('baseevents:leftVehicle', vehicleInfo('Left'))
RegisterNetEvent('baseevents:enteringAborted', function()
    TriggerClientEvent('VRCore:Client:AbortVehicleEntering', source)
end)

CoreOnNet('CallCommand', function(command, args)
    local src = source
    if type(command) ~= 'string' then return end
    local cmd = VRCore.Commands.List[command:lower()]
    if not cmd or not Players[src] then return end
    if not Functions.HasPermission(src, 'command.' .. cmd.name) then
        return TriggerClientEvent('VRCore:Notify', src, Lang:t('error.no_access'), 'error')
    end
    args = type(args) == 'table' and args or {}
    if cmd.argsrequired and #cmd.arguments ~= 0 and args[#cmd.arguments] == nil then
        return TriggerClientEvent('VRCore:Notify', src, Lang:t('error.missing_args2'), 'error')
    end
    cmd.callback(src, args)
end)

