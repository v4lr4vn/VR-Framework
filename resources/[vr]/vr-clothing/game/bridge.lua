local log = require("modules.utility.shared.logger")

return {
	onPropChange = function(self, prop)
	end,

	onComponentChange = function(self, component)
	end,

	onCustomizationStart = function(self)
	end,

	onCustomizationExit = function(self)
	end,

	getRgbColors = function(self)
		local colors = {
			hair = {},
			makeUp = {},
		}

		for i = 0, GetNumHairColors() - 1 do
			colors.hair[i + 1] = { GetPedHairRgbColor(i) }
		end

		for i = 0, GetNumMakeupColors() - 1 do
			colors.makeUp[i + 1] = { GetPedMakeupRgbColor(i) }
		end

		log.verbosef("[game] [customization] [getRgbColors] returning with value: (%s)", json.encode(colors))

		return colors
	end,

	listContains = function(self, items, item)
		for i = 1, #items do
			if items[i] == item then
				return true
			end
		end
		return false
	end,

	getHairSettings = function(self, ped)
		local colors = self:getRgbColors()
		local gender = client.getPedDecorationType()
		local blacklistSettings = {
			drawables = {},
			textures = {},
		}

		if client.isPedFreemodeModel(ped) then
			blacklistSettings = self:filterBlacklistSettings(Config.Blacklist[gender].hair,
				GetPedDrawableVariation(ped, 2))
		end

		local settings = {
			style = {
				min = 0,
				max = GetNumberOfPedDrawableVariations(ped, 2) - 1,
			},
			color = {
				items = colors.hair,
			},
			highlight = {
				items = colors.hair,
			},
			texture = {
				min = 0,
				max = GetNumberOfPedTextureVariations(ped, 2, GetPedDrawableVariation(ped, 2)) - 1,
			},
			blacklist = blacklistSettings,
		}

		return settings
	end,

	listContainsAny = function(self, items, containedItems)
		for i = 1, #items do
			if self:listContains(containedItems, items[i]) then
				return true
			end
		end

		return false
	end,

	allowedForPlayer = function(self, item, allowedAces)
		return (item.jobs and self:listContains(item.jobs, client.job.name))
			or (item.gangs and self:listContains(item.gangs, client.gang.name))
			or
			(item.aces and self:listContainsAny(item.aces, allowedAces) or (item.citizenids and self:listContains(item.citizenids, client.citizenid)))
	end,

	componentBlacklistMap = function(self, gender, componentId)
		local componentMap = {
			[1] = "masks",
			[3] = "upperBody",
			[4] = "lowerBody",
			[5] = "bags",
			[6] = "shoes",
			[7] = "scarfAndChains",
			[8] = "shirts",
			[9] = "bodyArmor",
			[10] = "decals",
			[11] = "jackets",
		}

		local genderSettings = Config.Blacklist[gender].components
		local settingKey = componentMap[componentId]
		return settingKey and genderSettings[settingKey] or {}
	end,

	propBlacklistMap = function(self, gender, propId)
		local genderSettings = Config.Blacklist[gender].props

		local propIds = {
			[0] = genderSettings.hats,
			[1] = genderSettings.glasses,
			[2] = genderSettings.ear,
			[6] = genderSettings.watches,
			[7] = genderSettings.bracelets,
		}

		local value = propIds[propId]

		return value and value or {}
	end,

	getPropSettings = function(self, ped, propId)
		local drawableId = GetPedPropIndex(ped, propId)
		local gender = client.getPedDecorationType()

		local blacklistSettings = {
			drawables = {},
			textures = {},
		}

		if client.isPedFreemodeModel(ped) then
			blacklistSettings = self:filterBlacklistSettings(self:propBlacklistMap(gender, propId), drawableId)
		end

		local settings = {
			prop_id = propId,
			drawable = {
				min = -1,
				max = GetNumberOfPedPropDrawableVariations(ped, propId) - 1,
			},
			texture = {
				min = -1,
				max = GetNumberOfPedPropTextureVariations(ped, propId, drawableId) - 1,
			},
			blacklist = blacklistSettings,
		}
		return settings
	end,

	getComponentSettings = function(self, ped, componentId)
		local drawableId = GetPedDrawableVariation(ped, componentId)
		local gender = client.getPedDecorationType()

		local blacklistSettings = {
			drawables = {},
			textures = {},
		}

		if client.isPedFreemodeModel(ped) then
			blacklistSettings = self:filterBlacklistSettings(self:componentBlacklistMap(gender, componentId), drawableId)
		end

		return {
			component_id = componentId,
			drawable = {
				min = 0,
				max = GetNumberOfPedDrawableVariations(ped, componentId) - 1,
			},
			texture = {
				min = 0,
				max = GetNumberOfPedTextureVariations(ped, componentId, drawableId) - 1,
			},
			blacklist = blacklistSettings,
		}
	end,

	filterPedModelsForPlayer = function(self, pedConfigs)
		local playerPeds = {}
		local allowedAces = lib.callback.await("vr-clothing:server:GetPlayerAces", false)

		for i = 1, #pedConfigs do
			local config = pedConfigs[i]
			if (not config.jobs and not config.gangs and not config.aces and not config.citizenids) or self:allowedForPlayer(config, allowedAces) then
				for j = 1, #config.peds do
					playerPeds[#playerPeds + 1] = config.peds[j]
				end
			end
		end

		return playerPeds
	end,

	addToBlacklist = function(self, item, drawable, drawableId, blacklistSettings)
		if drawable == drawableId and item.textures then
			for i = 1, #item.textures do
				blacklistSettings.textures[#blacklistSettings.textures + 1] = item.textures[i]
			end
		end
		if not item.textures or #item.textures == 0 then
			blacklistSettings.drawables[#blacklistSettings.drawables + 1] = drawable
		end
	end,

	filterBlacklistSettings = function(self, items, drawableId)
		local blacklistSettings = {
			drawables = {},
			textures = {},
		}

		local allowedAces = lib.callback.await("vr-clothing:server:GetPlayerAces", false)

		for i = 1, #items do
			local item = items[i]
			if not self:allowedForPlayer(item, allowedAces) and item.drawables then
				for j = 0, #item.drawables do
					self:addToBlacklist(item, item.drawables[j], drawableId, blacklistSettings)
				end
			end
		end

		return blacklistSettings
	end,

	filterTattoosByGender = function(self, tattoos)
		local filtered = {}
		local gender = client.getPedDecorationType()

		for k, v in pairs(tattoos) do
			filtered[k] = {}
			for i = 1, #v do
				local tattoo = v[i]
				if tattoo["hash" .. gender:gsub("^%l", string.upper)] ~= "" then
					filtered[k][#filtered[k] + 1] = tattoo
				end
			end
		end

		return filtered
	end,

	getAppearanceSettings = function(self)
		local ped = {
			model = {
				items = self:filterPedModelsForPlayer(Config.Peds.pedConfig),
			},
		}

		local tattoos = {
			items = self:filterTattoosByGender(Config.Tattoos),
			opacity = {
				min = 0.1,
				max = 1,
				factor = 0.1,
			},
		}

		local components = {}

		for i = 1, #constants.PED_COMPONENTS_IDS do
			components[i] = self:getComponentSettings(cache.ped, constants.PED_COMPONENTS_IDS[i])
		end

		local props = {}

		for i = 1, #constants.PED_PROPS_IDS do
			props[i] = self:getPropSettings(cache.ped, constants.PED_PROPS_IDS[i])
		end

		local headBlend = constants.HEAD_BLEND

		local size = #constants.FACE_FEATURES
		local faceFeatures = table.create(0, size)

		for i = 1, size do
			local feature = constants.FACE_FEATURES[i]
			faceFeatures[feature] = { min = -1, max = 1, factor = 0.1 }
		end

		local colors = self:getRgbColors()

		local colorMap = {
			beard = colors.hair,
			eyebrows = colors.hair,
			chestHair = colors.hair,
			makeUp = colors.makeUp,
			blush = colors.makeUp,
			lipstick = colors.makeUp,
		}

		size = #constants.HEAD_OVERLAYS
		local headOverlays = table.create(0, size)

		for i = 1, size do
			local overlay = constants.HEAD_OVERLAYS[i]
			local settings = {
				style = {
					min = 0,
					max = GetPedHeadOverlayNum(i - 1) - 1,
				},
				opacity = {
					min = 0,
					max = 1,
					factor = 0.1,
				},
			}

			if colorMap[overlay] then
				settings.color = {
					items = colorMap[overlay],
				}
			end

			headOverlays[overlay] = settings
		end

		local eyeColor = {
			min = 0,
			max = 30,
		}

		return {
			ped = ped,
			components = components,
			props = props,
			headBlend = headBlend,
			faceFeatures = faceFeatures,
			headOverlays = headOverlays,
			hair = self:getHairSettings(cache.ped),
			eyeColor = eyeColor,
			tattoos = tattoos,
		}
	end,
}
