Locales["en"] = {
	UI = {
		header = {
			title = "Appearance Editor",
			alt_text = "Hmm, looking very demure.",
		},
		actions = {
			save = "Save",
			cancel = "Cancel",
		},
		common_words = {
			component = "Component",
			fade = "Fade",
			opacity = "Opacity",
			hair = "Hair",
			variant = "Variant",
			color = "Color",
			primary = "Primary",
			secondary = "Secondary",
			select = "Select",
			highlight = "Highlight",
			base = "Base",
			face = "Face",
			skin = "Skin",
			face_and_skin = "Face & Skin",
			import = "Import",
			export = "Export",
			copy = "Copy",
			non_freemode = "Non Freemode",
			ped_variants = "Ped Variant",
		},
		export_panel = {
			title = "Export & Import Panel",
			description = "Simplifying character data management.",
			paste_json_placeholder = "Paste your JSON here...",
			paste_xml_placeholder = "Paste your XML here...",
			messages = {
				ped_model_not_allowed = "This ped model is not allowed.",
				missing_key = "Missing Key: %s",
				type_missmatch = "Type missmatch for key: %s",
				unexpected_key = "Unexpected key: %s",
				unexpected_error = "Something went wrong, check the console (F8) for more details.",
				success = "Successfully Imported Character!",
				empty_value = "Value cannot be empty!",
				invalid_xml = "Invalid XML Format!",
				invalid_model = "Invalid Model Hash",
				missing_section = "Missing Section: %s",
				success_copy = "Successfully copied %s data!"
			}
		},
		tabs = {
			characters = {
				title = "Characters",
				sections = {
					ped = "Characters",
					custom_ped = "Custom Ped",
				},
			},
			face = {
				title = "Face",
				sections = {
					mixes = {
						face = "Face Mix",
						skin = "Skin Mix",
						secondary = "Secondary Mix",
					},
				},
			},
			features = {
				title = "Features",
				components = {
					nose = {
						title = "Nose",
						properties = {
							width = "Width",
							peakHeight = "Peak Height",
							peakSize = "Peak Size",
							peakLowering = "Peak Lowering",
							boneHeight = "Bone Height",
							boneTwist = "Bone Twist",
						},
					},
					eyebrows = {
						title = "Eyebrows",
						properties = {
							height = "Height",
							depth = "Depth",
						},
					},
					cheeks = {
						title = "Cheeks",
						properties = {
							boneHeight = "Bone Height",
							boneWidth = "Bone Width",
							width = "Width",
						},
					},
					eyesAndMouth = {
						title = "Eyes & Mouth",
						properties = {
							eyesOpening = "Eyes Opening",
							lipThickness = "Lip Thickness",
							color = "Color",
						},
					},
					jaw = {
						title = "Jaw",
						properties = {
							boneWidth = "Bone Width",
							backBoneSize = "Back Bone Size",
						},
					},
					chin = {
						title = "Chin",
						properties = {
							boneLowering = "Bone Lowering",
							boneLength = "Bone Length",
							boneSize = "Bone Size",
							holeSize = "Hole Size",
						},
					},
					neck = {
						title = "Neck",
						properties = {
							thickness = "Thickness",
						},
					},
				},
			},
			skin = {
				title = "Skin",
				components = {
					blemishes = {
						title = "Blemishes",
					},
					body_blemishes = {
						title = "Body Blemishes",
					},
					ageing = {
						title = "Ageing",
					},
					complexion = {
						title = "Complexion",
					},
					sun_damage_and_scars = {
						title = "Sun Damage & Scars",
					},
					moles_and_freckles = {
						title = "Moles & Freckles",
					},
				},
			},
			hair = {
				title = "Hair",
				components = {
					facial_hair = {
						title = "Facial Hair",
					},
					eyebrows = {
						title = " Eyebrows",
					},
					chest_hair = {
						title = "Chest Hair",
					},
				},
			},
			makeup = {
				title = "Makeup",
				components = {
					makeup = {
						title = "Makeup",
					},
					blush = {
						title = "Blush",
					},
					lipstick = {
						title = "Lipstick",
					},
				},
			},
			clothing = {
				title = "Clothing",
				components = {
					jacket = {
						title = "Jacket",
					},
					undershirt = {
						title = "Undershirt",
					},
					arms_and_gloves = {
						title = "Arms & Gloves",
					},
					pants = {
						title = "Pants",
					},
					shoes = {
						title = "Shoes",
					},
					decals = {
						title = "Decals",
					},
				},
			},
			accessories = {
				title = "Accessories",
				components = {
					mask = {
						title = "Mask",
					},
					scarfs_and_necklaces = {
						title = "Scarfs & Necklaces",
					},
					vest = {
						title = "Vest",
					},
					bag = {
						title = "Bag",
					},
					hat = {
						title = "Hat",
					},
					glasses = {
						title = "Glasses",
					},
					earring = {
						title = "Earring",
					},
					watch = {
						title = "Watch",
					},
					bracelet = {
						title = "Bracelet",
					},
				},
			},
			tattoos = {
				title = "Tattoos",
				components = {
					ZONE_HEAD = {
						title = "Head",
					},
					ZONE_LEFT_ARM = {
						title = "Left Arm",
					},
					ZONE_LEFT_LEG = {
						title = "Left Leg",
					},
					ZONE_RIGHT_ARM = {
						title = "Right Arm",
					},
					ZONE_RIGHT_LEG = {
						title = "Right Leg",
					},
					ZONE_TORSO = {
						title = "Torso",
					},
				},
			},
		},
	},
	outfitManagement = {
		title = "Outfit Management",
		jobText = "Manage outfits for Job",
		gangText = "Manage outfits for Gang",
	},
	cancelled = {
		title = "Cancelled Customization",
		description = "Customization not saved",
	},
	outfits = {
		import = {
			title = "Enter outfit code",
			menuTitle = "Import Outfit",
			description = "Import an outfit from a sharing code",
			name = {
				label = "Name the Outfit",
				placeholder = "A nice outfit",
				default = "Imported Outfit",
			},
			code = {
				label = "Outfit Code",
			},
			success = {
				title = "Outfit Imported",
				description = "You can now change to the outfit using the outfit menu",
			},
			failure = {
				title = "Import Failure",
				description = "Invalid outfit code",
			},
		},
		generate = {
			title = "Generate Outfit Code",
			description = "Generate an outfit code for sharing",
			failure = {
				title = "Something went wrong",
				description = "Code generation failed for the outfit",
			},
			success = {
				title = "Outfit Code Generated",
				description = "Here is your outfit code",
			},
		},
		save = {
			menuTitle = "Save current Outfit",
			menuDescription = "Save your current outfit as %s outfit",
			description = "Save your current outfit",
			title = "Name your outfit",
			managementTitle = "Management Outfit Details",
			name = {
				label = "Outfit Name",
				placeholder = "Very cool outfit",
			},
			gender = {
				label = "Gender",
				male = "Male",
				female = "Female",
			},
			rank = {
				label = "Minimum Rank",
			},
			failure = {
				title = "Save Failed",
				description = "Outfit with this name already exists",
			},
			success = {
				title = "Success",
				description = "Outfit %s has been saved",
			},
		},
		update = {
			title = "Update Outfit",
			description = "Save your current clothing to an existing outfit",
			failure = {
				title = "Update Failed",
				description = "That outfit does not exist",
			},
			success = {
				title = "Success",
				description = "Outfit %s has been updated",
			},
		},
		change = {
			title = "Change Outfit",
			description = "Pick from any of your currently saved %s outfits",
			pDescription = "Pick from any of your currently saved outfits",
			failure = {
				title = "Something went wrong",
				description = "The outfit that you're trying to change to, does not have a base appearance",
			},
		},
		delete = {
			title = "Delete Outfit",
			description = "Delete a saved %s outfit",
			mDescription = "Delete any of your saved outfits",
			item = {
				title = 'Delete "%s"',
				description = "Model: %s%s",
			},
			success = {
				title = "Success",
				description = "Outfit Deleted",
			},
		},
		manage = {
			title = "👔 | Manage %s Outfits",
		},
	},
	jobOutfits = {
		title = "Work Outfits",
		description = "Pick from any of your work outfits",
	},
	menu = {
		returnTitle = "Return",
		title = "Clothing Room",
		outfitsTitle = "Player Outfits",
		clothingShopTitle = "Clothing Shop",
		barberShopTitle = "Barber Shop",
		tattooShopTitle = "Tattoo Shop",
		surgeonShopTitle = "Surgeon Shop",
	},
	clothing = {
		title = "Buy Clothing - $%d",
		titleNoPrice = "Change Clothing",
		options = {
			title = "👔 | Clothing Store Options",
			description = "Pick from a wide range of items to wear",
		},
		outfits = {
			title = "👔 | Outfit Options",
			civilian = {
				title = "Civilian Outfit",
				description = "Put on your clothes",
			},
		},
	},
	commands = {
		reloadskin = {
			title = "Reloads your character",
			failure = {
				title = "Error",
				description = "You cannot use reloadskin right now",
			},
		},
		clearstuckprops = {
			title = "Removes all the props attached to the entity",
			failure = {
				title = "Error",
				description = "You cannot use clearstuckprops right now",
			},
		},
		pedmenu = {
			title = "Open / Give Clothing Menu",
			failure = {
				title = "Error",
				description = "Player not online",
			},
		},
		joboutfits = {
			title = "Opens Job Outfits Menu",
		},
		gangoutfits = {
			title = "Opens Gang Outfits Menu",
		},
		bossmanagedoutfits = {
			title = "Opens Boss Managed Outfits Menu",
		},
	},
	textUI = {
		clothing = "Clothing Store - Price: $%d",
		barber = "Barber - Price: $%d",
		tattoo = "Tattoo Shop - Price: $%d",
		surgeon = "Plastic Surgeon - Price: $%d",
		clothingRoom = "Clothing Room",
		playerOutfitRoom = "Outfits",
	},
	migrate = {
		success = {
			title = "Success",
			description = "Migration finished. %s skins migrated",
			descriptionSingle = "Migrated Skin",
		},
		skip = {
			title = "Information",
			description = "Skipped skin",
		},
		typeError = {
			title = "Error",
			description = "Invalid type",
		},
	},
	purchase = {
		tattoo = {
			success = {
				title = "Success",
				description = "Purchased %s tattoo for %s$",
			},
			failure = {
				title = "Tattoo apply failed",
				description = "You don't have enough money!",
			},
		},
		store = {
			success = {
				title = "Success",
				description = "Gave $%s to %s!",
			},
			failure = {
				title = "Exploit!",
				description = "You didn't have enough money! Tried to exploit the system!",
			},
		},
	},
}
