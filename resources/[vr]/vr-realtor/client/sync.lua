local PSHousing = exports['vr-housing']

local function initialiseData()
	local properties = PSHousing:GetProperties()

	PropertiesTable = {}
	for _, property in pairs(properties) do
		PropertiesTable[#PropertiesTable+1] = property.propertyData
	end

	local apartments = PSHousing:GetApartments()

	local ApartmentsTable = {}

	for _, apartment in pairs(apartments) do
		ApartmentsTable[#ApartmentsTable+1] = apartment
	end

	lib.waitFor(function()
		if UiLoaded then return true end
	end, 'ui loading timeout', 5000)

	SendNUIMessage({
		action = "setShells",
		data = exports['vr-housing']:GetShells()
	})

	SendNUIMessage({
		action = "setProperties",
		data = PropertiesTable
	})

	SendNUIMessage({
		action = "setApartments",
		data = ApartmentsTable
	})
end

CreateThread(function()
	if GetResourceState('vr-housing') ~= 'started' then return end
	initialiseData()
end)

AddEventHandler('vr-housing:client:initialisedProperties', initialiseData)

AddEventHandler('vr-housing:client:updatedProperty', function(property_id)
	local property = exports['vr-housing']:GetProperty(property_id)

	for i = 1, #PropertiesTable do
		if PropertiesTable[i].property_id == property_id then
			PropertiesTable[i] = property.propertyData
			break
		end
	end

	SendNUIMessage({
		action = "updateProperty",
		data = property.propertyData
	})
end)

AddEventHandler("vr-housing:client:updateApartment", function(old, new)

	local oldApt = PSHousing:GetApartment(old)

	SendNUIMessage({
		action = "updateApartment",
		data = oldApt
	})

	local newApt = PSHousing:GetApartment(new)

	SendNUIMessage({
		action = "updateApartment",
		data = newApt
	})
end)

RegisterNetEvent('vr-housing:client:addProperty', function(propertyData)
	PropertiesTable[#PropertiesTable+1] = propertyData

	SendNUIMessage({
		action = "updateProperty",
		data = propertyData
	})
end)
