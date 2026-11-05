VRCore = exports['vr-core']:GetCoreObject()
PlayerData = {}

local dataSent = false

local function setupMenu(delay)
	if delay then Wait(delay) end
	PlayerData = VRCore.Functions.GetPlayerData() or {}
	local resources = lib.callback.await('vr-adminmenu:callback:GetResources', false)
	local commands = lib.callback.await('vr-adminmenu:callback:GetCommands', false)
	if not dataSent then
		dataSent = GetData()
	end
	SendNUIMessage({
		action = "setupUI",
		data = {
			actions = Config.Actions,
			resources = resources,
			playerData = PlayerData,
			commands = commands
		}
	})
end

RegisterNetEvent("VRCore:Client:OnPlayerLoaded", function()
	setupMenu(500)
end)

AddEventHandler("onResourceStart", function(resourceName)
	if (GetCurrentResourceName() == resourceName) then
		setupMenu(500)
	end
end)

RegisterNUICallback("hideUI", function(_, cb)
	ToggleUI(false)
	cb(1)
end)

RegisterNUICallback("clickButton", function(data, cb)
	cb(1)
	if type(data) ~= 'table' then return end
	local selectedData = data.selectedData
	local key = data.data
	local action = CheckDataFromKey(key)
	if not action then return end

	if action.type == "client" then
		TriggerServerEvent('vr-adminmenu:server:ValidateClientAction', key, selectedData)
	elseif action.type == "server" then
		TriggerServerEvent(action.event, key, selectedData)
	elseif action.type == "command" then
		ExecuteCommand(action.event)
	end
end)

RegisterNetEvent('vr-adminmenu:client:OpenUI', function()
	setupMenu()
	ToggleUI(true)
end)

RegisterNetEvent('vr-adminmenu:client:CloseUI', function()
	ToggleUI(false)
end)

RegisterNUICallback("setResourceState", function(data, cb)
	local resources = lib.callback.await('vr-adminmenu:callback:ChangeResourceState', false, data)
	cb(resources)
end)

RegisterNUICallback("getPlayers", function(data, cb)
	local players = lib.callback.await('vr-adminmenu:callback:GetPlayers', false)
	cb(players)
end)
