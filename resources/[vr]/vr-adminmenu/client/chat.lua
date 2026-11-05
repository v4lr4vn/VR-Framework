local function getMessagesCallBack()
	return lib.callback.await('vr-adminmenu:callback:GetMessages', false) or {}
end

RegisterNUICallback("GetMessages", function(_, cb)
	local data = getMessagesCallBack()
	if next(data) then
		SendNUIMessage({
			action = "setMessages",
			data = data
		})
	end
	cb(1)
end)

RegisterNUICallback("SendMessage", function(msgData, cb)
	local message = type(msgData) == 'table' and msgData.message

	if type(message) == 'string' and message ~= '' then
		TriggerServerEvent("vr-adminmenu:server:sendMessageServer", message)
	end

	local data = getMessagesCallBack()
	SendNUIMessage({
		action = "setMessages",
		data = data
	})
	cb(1)
end)
