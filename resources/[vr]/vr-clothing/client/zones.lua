if Config.UseTarget then
	return
end

local log = require("modules.utility.shared.logger")

local currentZone = nil

local Zones = {
	Store = {},
	ClothingRoom = {},
	PlayerOutfitRoom = {},
}

local ZONE_ACTIONS = {
	clothingRoom = function()
		local clothingRoom = Config.ClothingRooms[currentZone.index]
		local outfits = GetPlayerJobOutfits(clothingRoom.job)
		TriggerEvent("vr-clothing:client:openJobOutfitsMenu", outfits)
	end,
	playerOutfitRoom = function()
		local outfitRoom = Config.PlayerOutfitRooms[currentZone.index]
		OpenOutfitRoom(outfitRoom)
	end,
	clothing = function()
		TriggerEvent("vr-clothing:client:openClothingShopMenu")
	end,
	barber = function()
		OpenBarberShop()
	end,
	tattoo = function()
		OpenTattooShop()
	end,
	surgeon = function()
		OpenSurgeonShop()
	end
}

local function RemoveZones()
	for i = 1, #Zones.Store do
		if Zones.Store[i]["remove"] then
			Zones.Store[i]:remove()
		end
	end
	for i = 1, #Zones.ClothingRoom do
		Zones.ClothingRoom[i]:remove()
	end
	for i = 1, #Zones.PlayerOutfitRoom do
		Zones.PlayerOutfitRoom[i]:remove()
	end
end

local function lookupZoneIndexFromID(zones, id)
	for i = 1, #zones do
		if zones[i].id == id then
			return i
		end
	end
end

local function onStoreEnter(data)
	local index = lookupZoneIndexFromID(Zones.Store, data.id)
	local store = Config.Stores[index]

	log.debugf(
		"[client] [zones] [onStoreEnter] data.id: (%s), index: (%s), store: (%s)",
		data.id,
		index,
		json.encode(store, {
			indent = true,
		})
	)

	local jobName = (store.job and client.job.name) or (store.gang and client.gang.name)

	if jobName ~= (store.job or store.gang) then
		return log.info("[client] [onStoreEnter] jobName doesn't match `store.job` or `store.gang`, returning")
	end

	currentZone = {
		name = store.type,
		index = index,
	}

	local prefix = Config.UseRadialMenu and "" or "[E] "

	local actions = {
		["clothing"] = function()
			lib.showTextUI(prefix .. string.format(_L("textUI.clothing"), Config.ClothingCost), Config.TextUIOptions)
		end,
		["barber"] = function()
			lib.showTextUI(prefix .. string.format(_L("textUI.barber"), Config.BarberCost), Config.TextUIOptions)
		end,
		["tattoo"] = function()
			lib.showTextUI(prefix .. string.format(_L("textUI.tattoo"), Config.TattooCost), Config.TextUIOptions)
		end,
		["surgeon"] = function()
			lib.showTextUI(prefix .. string.format(_L("textUI.surgeon"), Config.SurgeonCost), Config.TextUIOptions)
		end
	}

	local action = actions[currentZone.name]

	if not action then
		return log.errorf("[client] [onStoreEnter] unable to find action with name: %s", currentZone.name)
	end

	action()

	Radial.AddOption(currentZone)
end

local function onClothingRoomEnter(data)
	local index = lookupZoneIndexFromID(Zones.ClothingRoom, data.id)
	local clothingRoom = Config.ClothingRooms[index]

	local jobName = clothingRoom.job and client.job.name or client.gang.name
	if jobName == (clothingRoom.job or clothingRoom.gang) then
		if CheckDuty() or clothingRoom.gang then
			currentZone = {
				name = "clothingRoom",
				index = index,
			}
			local prefix = Config.UseRadialMenu and "" or "[E] "
			lib.showTextUI(prefix .. _L("textUI.clothingRoom"), Config.TextUIOptions)
			Radial.AddOption(currentZone)
		end
	end
end

local function onPlayerOutfitRoomEnter(data)
	local index = lookupZoneIndexFromID(Zones.PlayerOutfitRoom, data.id)
	local playerOutfitRoom = Config.PlayerOutfitRooms[index]

	local isAllowed = IsPlayerAllowedForOutfitRoom(playerOutfitRoom)
	if isAllowed then
		currentZone = {
			name = "playerOutfitRoom",
			index = index,
		}
		local prefix = Config.UseRadialMenu and "" or "[E] "
		lib.showTextUI(prefix .. _L("textUI.playerOutfitRoom"), Config.TextUIOptions)
		Radial.AddOption(currentZone)
	end
end

local function onZoneExit()
	currentZone = nil
	Radial.RemoveOption()
	lib.hideTextUI()
end

local function SetupZone(store, onEnter, onExit)
	if Config.RCoreTattoosCompatibility and store.type == "tattoo" then
		return {}
	end

	if Config.UseRadialMenu or store.usePoly then
		return lib.zones.poly({
			points = store.points,
			debug = Config.Debug,
			onEnter = onEnter,
			onExit = onExit,
		})
	end

	return lib.zones.box({
		coords = store.coords,
		size = store.size,
		rotation = store.rotation,
		debug = Config.Debug,
		onEnter = onEnter,
		onExit = onExit,
	})
end

local function SetupStoreZones()
	for i = 1, #Config.Stores do
		Zones.Store[#Zones.Store + 1] = SetupZone(Config.Stores[i], onStoreEnter, onZoneExit)
	end
end

local function SetupClothingRoomZones()
	for i = 1, #Config.ClothingRooms do
		Zones.ClothingRoom[#Zones.ClothingRoom + 1] = SetupZone(Config.ClothingRooms[i], onClothingRoomEnter, onZoneExit)
	end
end

local function SetupPlayerOutfitRoomZones()
	for i = 1, #Config.PlayerOutfitRooms do
		Zones.PlayerOutfitRoom[#Zones.PlayerOutfitRoom + 1] = SetupZone(Config.PlayerOutfitRooms[i],
			onPlayerOutfitRoomEnter, onZoneExit)
	end
end

local function SetupZones()
	SetupStoreZones()
	SetupClothingRoomZones()
	SetupPlayerOutfitRoomZones()
end

local function ZonesLoop()
	Wait(1000)
	while true do
		local sleep = 1000
		if currentZone then
			sleep = 5
			if IsControlJustReleased(0, 38) then
				local action = ZONE_ACTIONS[currentZone.name]
				if not action then
					log.warningf("[client] [zones] [func::ZonesLoop] unable to find action using name: %s",
						currentZone.name)

					goto continue
				end

				action()

				::continue::
			end
		end
		Wait(sleep)
	end
end

CreateThread(function()
	SetupZones()

	if Config.UseRadialMenu then return end

	ZonesLoop()
end)

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		RemoveZones()
	end
end)

RegisterNetEvent("vr-clothing:client:OpenClothingRoom", function()
	local clothingRoom = Config.ClothingRooms[currentZone.index]
	local outfits = GetPlayerJobOutfits(clothingRoom.job)
	TriggerEvent("vr-clothing:client:openJobOutfitsMenu", outfits)
end)

RegisterNetEvent("vr-clothing:client:OpenPlayerOutfitRoom", function()
	local outfitRoom = Config.PlayerOutfitRooms[currentZone.index]
	OpenOutfitRoom(outfitRoom)
end)
