if not Framework.QBCore() then
	return
end

local client = client

RegisterNetEvent("qb-clothing:client:openMenu", function()
	local config = GetDefaultConfig()
	config.ped = true
	config.headBlend = true
	config.faceFeatures = true
	config.headOverlays = true
	config.components = true
	config.props = true
	config.tattoos = true
	OpenShop(config, true, "all")
end)

RegisterNetEvent("qb-clothing:client:openOutfitMenu", function()
	OpenMenu(nil, "outfit")
end)

RegisterNetEvent("qb-clothing:client:loadOutfit", LoadJobOutfit)

RegisterNetEvent("vr-multicharacter:client:chooseChar", function()
	client.setPedTattoos(cache.ped, {})
	ClearPedDecorations(cache.ped)

	TriggerServerEvent("vr-clothing:server:resetOutfitCache")
end)
