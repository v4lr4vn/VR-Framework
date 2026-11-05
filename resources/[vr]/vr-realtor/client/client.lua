local VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })
PropertiesTable = {}
UiLoaded = false

local showBlipsForSale = false
local showBlipsOwned = false

local blipsForSale = {}
local blipsOwned = {}

local UIOpen = false

local tabletObj = nil
local tabletDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
local tabletAnim = "base"
local tabletProp = Config.AnimationProp
local tabletBone = 60309
local tabletOffset = vector3(0.03, 0.002, -0.0)
local tabletRot = vector3(10.0, 160.0, 0.0)

local function doAnimation()
    if not UIOpen then return end
    RequestAnimDict(tabletDict)
    while not HasAnimDictLoaded(tabletDict) do Wait(100) end
    RequestModel(tabletProp)
    while not HasModelLoaded(tabletProp) do Wait(100) end

    local plyPed = PlayerPedId()
    tabletObj = CreateObject(tabletProp, 0.0, 0.0, 0.0, true, true, false)
    local tabletBoneIndex = GetPedBoneIndex(plyPed, tabletBone)

    AttachEntityToEntity(tabletObj, plyPed, tabletBoneIndex, tabletOffset.x, tabletOffset.y, tabletOffset.z, tabletRot.x, tabletRot.y, tabletRot.z, true, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(tabletProp)

    CreateThread(function()
        while UIOpen do
            Wait(0)
            if not IsEntityPlayingAnim(plyPed, tabletDict, tabletAnim, 3) then
                TaskPlayAnim(plyPed, tabletDict, tabletAnim, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
            end
        end

        ClearPedSecondaryTask(plyPed)
        Wait(250)
        DetachEntity(tabletObj, true, false)
        DeleteEntity(tabletObj)
    end)
end

local function toggleUI(bool)
	if bool and not UiLoaded then
		lib.notify({ description = 'UI not loaded!' , type = 'error'})
		return
	end

	UIOpen = bool
	SetNuiFocus(bool, bool)
	SendNUIMessage({
		action = "setVisible",
		data = bool
	})

	if Config.PlayAnimation then
		doAnimation()
	end
end

RegisterNUICallback("uiLoaded", function (_, cb)
	UiLoaded = true
	cb(1)
end)

RegisterNUICallback("hideUI", function(_, cb)
	toggleUI(false)
	cb(1)

end)

local function setRealtor(jobInfo)
	if RealtorJobs[jobInfo.name] then
		SendNUIMessage({
			action = "setRealtorGrade",
			data = jobInfo.grade.level
		})
	else
		SendNUIMessage({
			action = "setRealtorGrade",
			data = -1
		})
	end
end
RegisterNetEvent("VRCore:Client:OnJobUpdate", setRealtor)

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function()
	SendNUIMessage({
		action = "setConfig",
		data = Config.RealtorPerms
	})
	local PlayerData = VRCore.Functions.GetPlayerData()
	if PlayerData.job then setRealtor(PlayerData.job) end
end)

AddEventHandler("onResourceStart", function(resName)
	if (GetCurrentResourceName() == resName) then
		Wait(2000)
		SendNUIMessage({
			action = "setConfig",
			data = Config.RealtorPerms
		})

		local PlayerData = VRCore.Functions.GetPlayerData()
		if PlayerData.job then setRealtor(PlayerData.job) end
	end
end)

local function canOpen()
	if not LocalPlayer.state.isLoggedIn or IsPauseMenuActive() then return false end
	local meta = VRCore.Functions.GetPlayerData().metadata or {}
	return not meta.isdead and not meta.inlaststand and not meta.ishandcuffed
end

if Config.UseCommand then
	RegisterCommand("housing", function()
		if canOpen() then toggleUI(not UIOpen) end
	end, false)
end

RegisterNetEvent('vr-realtor:client:toggleUI', function()
	if canOpen() then toggleUI(not UIOpen) end
end)

RegisterNUICallback("setWaypoint", function (data, cb)
	lib.notify({ description = 'Waypoint was set!' , type = 'success'})
	SetNewWaypoint(data.x, data.y)
	cb("ok")
end)

RegisterNUICallback("updatePropertyData", function(data, cb)
	local property_id = data.property_id
	local newData = data.data
	local changeType = data.type

	if changeType == 'UpdateShell' then
		local currentShells = exports['vr-housing']:GetShells()
		local shellName = currentShells[newData.shell] and currentShells[newData.shell].hash

		if not shellName or not IsModelInCdimage(shellName) then
			lib.notify({ description = 'The Interior '..newData.shell..' does not exist!', type = 'error'})
			return cb("ok")
		end
	end

	TriggerServerEvent("vr-realtor:server:updateProperty", changeType, property_id, newData)
	cb("ok")
end)

RegisterNUICallback("addTenantToApartment", function(data, cb)
	TriggerServerEvent("vr-realtor:server:addTenantToApartment", data)
	cb("ok")
end)

RegisterNUICallback("getNames", function(data, cb)
	if not data then return cb({}) end
	local names = lib.callback.await("vr-realtor:server:getNames", false, data)
	cb(names)
end)

RegisterNUICallback("startZonePlacement", function (data, cb)
	 cb(1)
	SetNuiFocus(false, false)

	local type = data.type
	local property_id = data.property_id

	local newDataPromise = promise.new()
	ZoneThread(type, newDataPromise)
	local success = Citizen.Await(newDataPromise)
	if not success then return end
	local ped = cache.ped
	local newData = GetEntityCoords(ped)
	local newData = {x = newData.x, y = newData.y, z = newData.z, h = MathFloor(GetEntityHeading(ped))}
	if type == "door" then
		type = "UpdateDoor"
	elseif type == "garage" then
		type = "UpdateGarage"

		SendNUIMessage({
			action = "garageMade",
			data = {
				x = MathFloor(newData.x),
				y = MathFloor(newData.y),
				z = MathFloor(newData.z),
				h = MathFloor(newData.h),
				length = 3.0,
				width = 5.0,
			}
		})
	end

	local streetHash = GetStreetNameAtCoord(newData.x, newData.y, newData.z)
	local street = GetStreetNameFromHashKey(streetHash)

	local regionHash = GetNameOfZone(newData.x, newData.y, newData.z)
	local region = GetLabelText(regionHash)
	local data
	if type == "UpdateGarage" then
        data = {
            garage = newData,
            street = street,
            region = region,
        }
        TriggerServerEvent("vr-realtor:server:updateProperty", type, property_id, data)
	else
        data = {
            door = newData,
            street = street,
            region = region,
        }
        TriggerServerEvent("vr-realtor:server:updateProperty", type, property_id, data)
	end
end)

function SetHide(bool)
	SendNUIMessage({
		action = "setTempHide",
		data = bool
	})
	SetNuiFocus(not bool, not bool)
end

function ZoneThread(type, promise)
	local findingZone = true

	local length = 2.0
    local width = 1.0
    local zoff = 2.0
    local height = 2.5

	if type == "garage" then
		lib.notify({description="Best to get in a vehicle to see how the zone would look.", type="error"})

		length = 3.0
		width = 5.0
	end

	CreateThread(function()
		while findingZone do
			local coords = GetEntityCoords(cache.ped)
			local x = coords.x
			local y = coords.y
			local z = coords.z
			local heading = GetEntityHeading(cache.ped)
			DrawMarker(43, x, y, z + zoff, 0.0, 0.0, 0.0, 0.0, 180.0, -heading, length, width, height, 255, 0, 0, 50, false, false, 2, nil, nil, false)
			if IsDisabledControlJustPressed(0, 38) then
				findingZone = false
				SetHide(false)
				promise:resolve(true)
			end
			if IsDisabledControlJustPressed(0, 104) then
				findingZone = false
				SetHide(false)
				promise:resolve(false)
			end
			Wait(0)
			DisableControlAction(0, 199, true)
			DisableControlAction(0, 200, true)
			DisableControlAction(0, 104, true)
		end
	end)
end

RegisterNUICallback("getBlipBooleans", function (_, cb)
	cb({
		showBlipsForSale = showBlipsForSale,
		showBlipsOwned = showBlipsOwned,
	})
end)

RegisterNUICallback("showBlipsForSale", function (bool, cb)
	if bool then
		showBlipsForSale = true
		CreateBlipsOnMap("forSale")
	else
		showBlipsForSale = false
		RemoveBlipsOnMap("forSale")
	end
	cb(1)
end)

RegisterNUICallback("showBlipsOwned", function (bool, cb)
	if bool then
		showBlipsOwned = true
		CreateBlipsOnMap("owned")
	else
		showBlipsOwned = false
		RemoveBlipsOnMap("owned")
	end
	cb(1)
end)

function CreateBlipsOnMap(type)
	if type ~= "forSale" and type ~= "owned" then return end
	local blipsTable = type == "forSale" and blipsForSale or blipsOwned
	local nameType = type == "forSale" and "Property For Sale" or "Owned Property"

	RemoveBlipsOnMap(type)
	for k, data in pairs(PropertiesTable) do
		if not data.apartment then
			local isForSale = data.for_sale
			local owner = data.owner

			local coords = data.door_data
			local blipName = '('..nameType..')' .. ' ' .. data.street .. ' ' .. data.property_id
			if type == "forSale" and isForSale then
				local blip = CreateBlip(coords, blipName)
				blipsTable[#blipsTable + 1] = blip
			elseif type == "owned" and (owner and not isForSale) then
				local blip = CreateBlip(coords, blipName)
				blipsTable[#blipsTable + 1] = blip
			end
		end
	end
end

function CreateBlip(coords, blipName)
	local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
	SetBlipSprite(blip, 375)
	SetBlipDisplay(blip, 4)
	SetBlipScale(blip, 0.7)
	SetBlipColour(blip, 2)
	SetBlipAsShortRange(blip, true)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(blipName)
	EndTextCommandSetBlipName(blip)
	return blip
end

function RemoveBlipsOnMap(type)
	if type == "forSale" then
		for k, v in pairs(blipsForSale) do
			RemoveBlip(v)
		end
	elseif type == "owned" then
		for k, v in pairs(blipsOwned) do
			RemoveBlip(v)
		end
	end
end
