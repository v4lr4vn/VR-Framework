function ToggleUI(bool)
	SetNuiFocus(bool, bool)
	SendNUIMessage({
		action = "setVisible",
		data = bool
	})
end

function CheckDataFromKey(key)
	if type(key) ~= 'string' then return nil end
	local actions = Config.Actions[key]
	if actions then
		local data = nil

		if actions.event then
			data = actions
		end

		if actions.dropdown then
			for _, v in pairs(actions.dropdown) do
				if v.event then
					data = { label = actions.label, type = v.type, event = v.event, perms = actions.perms }
					break
				end
			end
		end

		return data
	end

	local playerActions = Config.PlayerActions[key]
	if playerActions then
		return playerActions
	end

	local otherActions = Config.OtherActions[key]
	if otherActions then
		return otherActions
	end
end

function ResourceUp(key)
	local name = Config.Resources[key]
	return type(name) == 'string' and GetResourceState(name) == 'started'
end

function Notify(text, notifyType, length)
	if notifyType == 'inform' then notifyType = 'primary' end
	VRCore.Functions.Notify(text, notifyType, length)
end

function SetFuel(vehicle, amount)
	if not vehicle or vehicle == 0 then return end
	local fuel = Config.Fuel
	if fuel == 'ox_fuel' and GetResourceState('ox_fuel') == 'started' then
		Entity(vehicle).state.fuel = amount
	elseif type(fuel) == 'string' and GetResourceState(fuel) == 'started' then
		pcall(function() exports[fuel]:SetFuel(vehicle, amount) end)
	end
	SetVehicleFuelLevel(vehicle, amount + 0.0)
end

function GiveKeys(plate)
	if not plate or not ResourceUp('vehiclekeys') then return end
	TriggerEvent("vehiclekeys:client:SetOwner", plate)
end
