local messages = {}
local MAX_MESSAGES = 100
local MAX_LENGTH = 500

RegisterNetEvent('vr-adminmenu:server:sendMessageServer', function(message)
    local src = source
    if not CheckPerms(src, Config.StaffChatPerms) then return end

    message = CleanText(message, MAX_LENGTH)
    if not message or message == '' then return end

    local player = VRCore.Functions.GetPlayer(src)
    if not player then return end

    local time = os.time() * 1000
    local players = VRCore.Functions.GetPlayers()

    for i = 1, #players do
        local target = players[i]
        if target ~= src and HasPerms(target, Config.StaffChatPerms) then
            VRCore.Functions.Notify(target, locale("new_staffchat"), 'primary', 7500)
        end
    end

    messages[#messages + 1] = { message = message, citizenid = player.PlayerData.citizenid, fullname = FullName(player), time = time }
    if #messages > MAX_MESSAGES then table.remove(messages, 1) end
end)

lib.callback.register('vr-adminmenu:callback:GetMessages', function(source)
    if not HasPerms(source, Config.StaffChatPerms) then return {} end
    return messages
end)
