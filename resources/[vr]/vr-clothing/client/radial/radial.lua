Radial = {}

Radial.MenuID = "open_clothing_menu"

local radialOptionAdded = false

function Radial.IsOX()
	local resName = "vr-lib"
	if GetResourceState(resName) ~= "missing" and Config.UseOxRadial then
		Radial.ResourceName = resName
		return true
	end
	return false
end



function Radial.AddOption(currentZone)
	if not Config.UseRadialMenu then
		return
	end

	if not currentZone then
		Radial.Remove()
		return
	end
	local event, title
	local zoneEvents = {
		clothingRoom = { "vr-clothing:client:OpenClothingRoom", _L("menu.title") },
		playerOutfitRoom = { "vr-clothing:client:OpenPlayerOutfitRoom", _L("menu.outfitsTitle") },
		clothing = { "vr-clothing:client:openClothingShopMenu", _L("menu.clothingShopTitle") },
		barber = { "vr-clothing:client:OpenBarberShop", _L("menu.barberShopTitle") },
		tattoo = { "vr-clothing:client:OpenTattooShop", _L("menu.tattooShopTitle") },
		surgeon = { "vr-clothing:client:OpenSurgeonShop", _L("menu.surgeonShopTitle") },
	}
	if zoneEvents[currentZone.name] then
		event, title = table.unpack(zoneEvents[currentZone.name])
	end

	Radial.Add(title, event)
	radialOptionAdded = true
end

function Radial.RemoveOption()
	if radialOptionAdded then
		Radial.Remove()
		radialOptionAdded = false
	end
end

AddEventHandler("onResourceStop", function(resource)
	if resource == GetCurrentResourceName() then
		if Config.UseOxRadial and GetResourceState("vr-lib") == "started" then
			Radial.RemoveOption()
		end
	end
end)
