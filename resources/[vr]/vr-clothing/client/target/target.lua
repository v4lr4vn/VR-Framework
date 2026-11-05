if not Config.UseTarget then
	return
end

local TargetPeds = {
	Store = {},
	ClothingRoom = {},
	PlayerOutfitRoom = {},
}

Target = {}

function Target.IsOX()
	return GetResourceState("vr-target") ~= "missing"
end


local function RemoveTargetPeds(peds)
	for i = 1, #peds, 1 do
		DeletePed(peds[i])
	end
end

local function RemoveTargets()
	if Config.EnablePedsForShops then
		RemoveTargetPeds(TargetPeds.Store)
	else
		for i = 1, #Config.Stores do
			local v = Config.Stores[i]

			Target.RemoveZone(v.type .. i)
		end
	end

	if Config.EnablePedsForClothingRooms then
		RemoveTargetPeds(TargetPeds.ClothingRoom)
	else
		for i = 1, #Config.Stores do
			local v = Config.Stores[i]

			Target.RemoveZone("clothing_" .. (v.job or v.gang) .. i)
		end
	end

	if Config.EnablePedsForPlayerOutfitRooms then
		RemoveTargetPeds(TargetPeds.PlayerOutfitRoom)
	else
		for i = 1, #Config.PlayerOutfitRooms do
			Target.RemoveZone("playeroutfitroom_" .. i)
		end
	end
end

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		if Target.IsTargetStarted() then
			RemoveTargets()
		end
	end
end)

local function CreatePedAtCoords(pedModel, coords, scenario)
	pedModel = type(pedModel) == "string" and joaat(pedModel) or pedModel
	lib.requestModel(pedModel)
	local ped = CreatePed(0, pedModel, coords.x, coords.y, coords.z - 0.98, coords.w, false, false)
	TaskStartScenarioInPlace(ped, scenario, 0, false)
	FreezeEntityPosition(ped, true)
	SetEntityVisible(ped, true, false)
	SetEntityInvincible(ped, true)
	PlaceObjectOnGroundProperly(ped)
	SetBlockingOfNonTemporaryEvents(ped, true)
	return ped
end

local function SetupStoreTarget(targetConfig, action, k, v)
	local parameters = {
		options = { {
			type = "client",
			action = action,
			icon = targetConfig.icon,
			label = targetConfig.label,
		} },
		distance = targetConfig.distance,
		rotation = v.rotation,
	}

	if Config.EnablePedsForShops then
		TargetPeds.Store[k] = CreatePedAtCoords(v.targetModel or targetConfig.model, v.coords,
			v.targetScenario or targetConfig.scenario)
		Target.AddTargetEntity(TargetPeds.Store[k], parameters)
	elseif v.usePoly then
		Target.AddPolyZone(v.type .. k, v.points, parameters)
	else
		Target.AddBoxZone(v.type .. k, v.coords, v.size, parameters)
	end
end

local function SetupStoreTargets()
	for i = 1, #Config.Stores do
		local v = Config.Stores[i]
		local targetConfig = Config.TargetConfig[v.type]
		local actions = {
			["barber"] = OpenBarberShop,
			["clothing"] = function()
				TriggerEvent("vr-clothing:client:openClothingShopMenu")
			end,
			["tattoo"] = OpenTattooShop,
			["surgeon"] = OpenSurgeonShop,
		}

		local action

		action = actions[v.type]

		if not (Config.RCoreTattoosCompatibility and v.type == "tattoo") then
			SetupStoreTarget(targetConfig, action, i, v)
		end
	end
end

local function SetupClothingRoomTargets()
	for i = 1, #Config.ClothingRooms do
		local v = Config.ClothingRooms[i]

		local targetConfig = Config.TargetConfig["clothingroom"]
		local action = function()
			local outfits = GetPlayerJobOutfits(v.job)
			TriggerEvent("vr-clothing:client:openJobOutfitsMenu", outfits)
		end

		local parameters = {
			options = {
				{
					type = "client",
					action = action,
					icon = targetConfig.icon,
					label = targetConfig.label,
					canInteract = v.job and CheckDuty or nil,
					job = v.job,
					gang = v.gang,
				},
			},
			distance = targetConfig.distance,
			rotation = v.rotation,
		}

		local key = "clothing_" .. (v.job or v.gang) .. i

		if Config.EnablePedsForClothingRooms then
			TargetPeds.ClothingRoom[i] = CreatePedAtCoords(v.targetModel or targetConfig.model, v.coords,
				v.targetScenario or targetConfig.scenario)
			Target.AddTargetEntity(TargetPeds.ClothingRoom[i], parameters)
			return
		end

		if v.usePoly then
			return Target.AddPolyZone(key, v.points, parameters)
		end

		Target.AddBoxZone(key, v.coords, v.size, parameters)
	end
end

local function SetupPlayerOutfitRoomTargets()
	for i = 1, #Config.PlayerOutfitRooms do
		local v = Config.PlayerOutfitRooms[i]

		local targetConfig = Config.TargetConfig["playeroutfitroom"]

		local parameters = {
			options = {
				{
					type = "client",
					action = function()
						OpenOutfitRoom(v)
					end,
					icon = targetConfig.icon,
					label = targetConfig.label,
					canInteract = function()
						return IsPlayerAllowedForOutfitRoom(v)
					end,
				},
			},
			distance = targetConfig.distance,
			rotation = v.rotation,
		}

		if Config.EnablePedsForPlayerOutfitRooms then
			TargetPeds.PlayerOutfitRoom[i] = CreatePedAtCoords(v.targetModel or targetConfig.model, v.coords,
				v.targetScenario or targetConfig.scenario)
			Target.AddTargetEntity(TargetPeds.PlayerOutfitRoom[i], parameters)
			return
		end

		if v.usePoly then
			return Target.AddPolyZone("playeroutfitroom_" .. i, v.points, parameters)
		end

		Target.AddBoxZone("playeroutfitroom_" .. i, v.coords, v.size, parameters)
	end
end

local function SetupTargets()
	SetupStoreTargets()
	SetupClothingRoomTargets()
	SetupPlayerOutfitRoomTargets()
end

CreateThread(function()
	if Config.UseTarget then
		SetupTargets()
	end
end)
