return {
	['testburger'] = {
		label = 'Test Burger',
		weight = 220,
		degrade = 60,
		client = {
			image = 'burger_chicken.png',
			status = { hunger = 200000 },
			anim = 'eating',
			prop = 'burger',
			usetime = 2500,
			export = 'ox_inventory_examples.testburger'
		},
		server = {
			export = 'ox_inventory_examples.testburger',
			test = 'what an amazingly delicious burger, amirite?'
		},
		buttons = {
			{
				label = 'Lick it',
				action = function(slot)
					print('You licked the burger')
				end
			},
			{
				label = 'Squeeze it',
				action = function(slot)
					print('You squeezed the burger :(')
				end
			},
			{
				label = 'What do you call a vegan burger?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('A misteak.')
				end
			},
			{
				label = 'What do frogs like to eat with their hamburgers?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('French flies.')
				end
			},
			{
				label = 'Why were the burger and fries running?',
				group = 'Hamburger Puns',
				action = function(slot)
					print('Because they\'re fast food.')
				end
			}
		},
		consume = 0.3
	},

	['null_ecu_tablet'] = {
			label = 'Null ECU Tablet',
			weight = 500,
			stack = false,
			close = true,
			consume = 0,
			description = 'Null Modifications ECU tuning tablet',
			client = {export = 'NullAntiLag.useTablet'},
		},

	['cigarette'] = {
		label = 'Cigarette',
		weight = 10,
		stack = true,
		close = true,
		description = 'Takes the edge off. You need a lighter.',
	},

	['lighter'] = {
		label = 'Lighter',
		weight = 30,
		stack = false,
		close = true,
		description = 'A cheap disposable lighter.',
	},

	['bandage'] = {
		label = 'Bandage',
		weight = 115,
		client = {
			anim = { dict = 'missheistdockssetup1clipboard@idle_a', clip = 'idle_a', flag = 49 },
			prop = { model = `prop_rolled_sock_02`, pos = vec3(-0.14, -0.14, -0.08), rot = vec3(-50.0, -50.0, 0.0) },
			disable = { move = true, car = true, combat = true },
			usetime = 2500,
		}
	},

	['black_money'] = {
		label = 'Dirty Money',
	},

	['burger'] = {
		label = 'Burger',
		weight = 220,
		close = true,
	},

	['sprunk'] = {
		label = 'Sprunk',
		weight = 350,
		close = true,
	},

	['parachute'] = {
		label = 'Parachute',
		weight = 8000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 1500
		}
	},

	['garbage'] = {
		label = 'Garbage',
	},

	['paperbag'] = {
		label = 'Paper Bag',
		weight = 1,
		stack = false,
		close = false,
		consume = 0
	},

	['identification'] = {
		label = 'Identification',
		client = {
			image = 'card_id.png'
		}
	},

	['panties'] = {
		label = 'Knickers',
		weight = 10,
		consume = 0,
		client = {
			status = { thirst = -100000, stress = -25000 },
			anim = { dict = 'mp_player_intdrink', clip = 'loop_bottle' },
			prop = { model = `prop_cs_panties_02`, pos = vec3(0.03, 0.0, 0.02), rot = vec3(0.0, -13.5, -1.5) },
			usetime = 2500,
		}
	},

	['lockpick'] = {
		label = 'Lockpick',
		weight = 160,
		client = { export = 'vr-policejob.breakCuffs' },
	},

	['hack_laptop'] = {
		label = 'Hacking Laptop',
		weight = 1800,
		stack = false,
		close = true,
		description = 'A rugged laptop loaded with Odin\'s Eye',
	},

	['exploit_kit'] = {
		label = 'Exploit Kit',
		weight = 150,
		close = true,
		description = 'Single use access tools for hardened targets',
	},

	['bank_drill'] = {
		label = 'Heavy Drill',
		weight = 2500,
		stack = false,
		close = true,
		description = 'Built to cut through a deposit box',
	},

	['gold_bar'] = {
		label = 'Gold Bar',
		weight = 1000,
		close = true,
		description = 'Heavy, and very hard to explain',
	},

	['id_card'] = {
		label = 'ID Card',
		weight = 0,
		stack = false,
		close = true,
		description = 'A card containing all your information to identify yourself',
	},

	['driver_license'] = {
		label = 'Drivers License',
		weight = 0,
		stack = false,
		close = true,
		description = 'Permit to show you can drive a vehicle',
	},

	['weaponlicense'] = {
		label = 'Weapon License',
		weight = 0,
		stack = false,
		close = true,
		description = 'Permit to carry a firearm',
	},

	['lawyerpass'] = {
		label = 'Lawyer Pass',
		weight = 0,
		stack = false,
		close = true,
		description = 'Pass exclusive to lawyers to show they can represent a suspect',
	},

	['business_license'] = {
		label = 'Business Licence',
		weight = 0,
		stack = false,
		close = true,
		description = 'A council certificate showing a business is licensed to trade',
	},

	['meat_boar'] = {
		label = 'Boar Meat',
		weight = 700,
		description = 'Fresh cut of wild boar',
	},

	['meat_deer'] = {
		label = 'Venison',
		weight = 650,
		description = 'Fresh venison from a deer',
	},

	['meat_coyote'] = {
		label = 'Coyote Meat',
		weight = 500,
		description = 'Lean, gamey coyote meat',
	},

	['meat_rabbit'] = {
		label = 'Rabbit Meat',
		weight = 300,
		description = 'A small cut of rabbit',
	},

	['pelt_boar'] = {
		label = 'Boar Pelt',
		weight = 900,
		description = 'A coarse boar hide',
	},

	['pelt_deer'] = {
		label = 'Deer Pelt',
		weight = 800,
		description = 'A soft deer hide',
	},

	['pelt_coyote'] = {
		label = 'Coyote Pelt',
		weight = 600,
		description = 'A thick coyote pelt',
	},

	['pelt_cougar'] = {
		label = 'Mountain Lion Pelt',
		weight = 1500,
		description = 'A rare mountain lion pelt',
	},

	['fish_carp'] = {
		label = 'Carp',
		weight = 900,
		description = 'A freshwater carp',
	},

	['fish_perch'] = {
		label = 'Perch',
		weight = 500,
		description = 'A freshwater perch',
	},

	['fish_trout'] = {
		label = 'Trout',
		weight = 600,
		description = 'A river trout',
	},

	['fish_pike'] = {
		label = 'Pike',
		weight = 1500,
		description = 'A long freshwater pike',
	},

	['fish_salmon'] = {
		label = 'Salmon',
		weight = 2200,
		description = 'A river salmon',
	},

	['fish_mackerel'] = {
		label = 'Mackerel',
		weight = 500,
		description = 'A sea mackerel',
	},

	['fish_snapper'] = {
		label = 'Snapper',
		weight = 1200,
		description = 'A red sea snapper',
	},

	['fish_grouper'] = {
		label = 'Grouper',
		weight = 2800,
		description = 'A heavy reef grouper',
	},

	['fish_tuna'] = {
		label = 'Tuna',
		weight = 4500,
		description = 'A deep sea tuna',
	},

	['fish_marlin'] = {
		label = 'Marlin',
		weight = 9000,
		description = 'A trophy marlin',
	},

	['fishing_bait'] = {
		label = 'Fishing Bait',
		weight = 20,
		description = 'Bait for the hook',
	},

	['junk_can'] = {
		label = 'Rusty Can',
		weight = 50,
		description = 'Somebody threw this away',
	},

	['junk_bottle'] = {
		label = 'Old Bottle',
		weight = 200,
		description = 'A glass bottle, worn smooth',
	},

	['old_coin'] = {
		label = 'Old Coin',
		weight = 10,
		description = 'A worn coin from long ago',
	},

	['pocket_watch'] = {
		label = 'Pocket Watch',
		weight = 120,
		description = 'A stopped pocket watch',
	},

	['gold_nugget'] = {
		label = 'Gold Nugget',
		weight = 150,
		description = 'A small lump of raw gold',
	},

	['ancient_coin'] = {
		label = 'Ancient Coin',
		weight = 15,
		description = 'A coin from a sunken ship',
	},

	['relic_idol'] = {
		label = 'Relic Idol',
		weight = 800,
		description = 'A small idol covered in barnacles',
	},

	['police_stormram'] = {
		label = 'Stormram',
		weight = 18000,
		stack = false,
		description = 'A good tool to break open doors',
	},

	['phone'] = {
		label = 'Phone',
		weight = 190,
		stack = false,
		consume = 0,
		client = {
			add = function(total)
				if total > 0 then
					pcall(function() return exports.npwd:setPhoneDisabled(false) end)
				end
			end,

			remove = function(total)
				if total < 1 then
					pcall(function() return exports.npwd:setPhoneDisabled(true) end)
				end
			end
		}
	},

	['money'] = {
		label = 'Money',
	},

	['mustard'] = {
		label = 'Mustard',
		weight = 500,
		close = true,
	},

	['water'] = {
		label = 'Water',
		weight = 500,
		close = true,
	},

	['radio'] = {
		label = 'Radio',
		weight = 1000,
		stack = false,
		allowArmed = true
	},

	['armour'] = {
		label = 'Bulletproof Vest',
		weight = 3000,
		stack = false,
		client = {
			anim = { dict = 'clothingshirt', clip = 'try_shirt_positive_d' },
			usetime = 3500
		}
	},

	['clothing'] = {
		label = 'Clothing',
		consume = 0,
	},

	['bank_card'] = {
		label = 'Bank Card',
		weight = 10,
		stack = false,
		close = true,
		description = 'A debit card. Use it at any ATM with your PIN.',
		client = {
			image = 'card_bank.png'
		}
	},

	['mastercard'] = {
		label = 'Fleeca Card',
		stack = false,
		weight = 10,
		client = {
			image = 'card_bank.png'
		}
	},

	['scrapmetal'] = {
		label = 'Scrap Metal',
		weight = 80,
	},

	['sandwich'] = { label = 'Sandwich', weight = 200, close = true, description = 'Nice bread for your stomach' },
	['tosti'] = { label = 'Grilled Cheese Sandwich', weight = 200, close = true, description = 'Nice to eat' },
	['twerks_candy'] = { label = 'Twerks', weight = 100, close = true, description = 'Some delicious candy :O' },
	['snikkel_candy'] = { label = 'Snikkel', weight = 100, close = true, description = 'Some delicious candy :O' },
	['water_bottle'] = { label = 'Bottle of Water', weight = 500, close = true, description = 'For all the thirsty out there' },
	['coffee'] = { label = 'Coffee', weight = 200, close = true, description = 'Pump 4 Caffeine' },
	['kurkakola'] = { label = 'Cola', weight = 500, close = true, description = 'For all the thirsty out there' },
	['beer'] = { label = 'Beer', weight = 500, close = true, description = 'Nothing like a good cold beer!' },
	['whiskey'] = { label = 'Whiskey', weight = 500, close = true, description = 'For all the thirsty out there' },
	['vodka'] = { label = 'Vodka', weight = 500, close = true, description = 'For all the thirsty out there' },

	['vr_food'] = { label = 'Food', weight = 0, close = true, client = { image = 'burger.png' } },
	['vr_drink'] = { label = 'Drink', weight = 0, close = true, client = { image = 'water.png' } },

	['stone'] = { label = 'Stone', weight = 1000 },
	['carbon'] = { label = 'Carbon', weight = 1000 },
	['copperore'] = { label = 'Copper Ore', weight = 1000 },
	['ironore'] = { label = 'Iron Ore', weight = 1000 },
	['goldore'] = { label = 'Gold Ore', weight = 1000 },
	['silverore'] = { label = 'Silver Ore', weight = 1000 },
	['uncut_ruby'] = { label = 'Uncut Ruby', weight = 100 },
	['ruby'] = { label = 'Ruby', weight = 100 },
	['uncut_emerald'] = { label = 'Uncut Emerald', weight = 100 },
	['emerald'] = { label = 'Emerald', weight = 100 },
	['uncut_diamond'] = { label = 'Uncut Diamond', weight = 100 },
	['diamond'] = { label = 'Diamond', weight = 100 },
	['uncut_sapphire'] = { label = 'Uncut Sapphire', weight = 100 },
	['sapphire'] = { label = 'Sapphire', weight = 100 },
	['goldingot'] = { label = 'Gold Ingot', weight = 1000 },
	['silveringot'] = { label = 'Silver Ingot', weight = 1000 },
	['gold_ring'] = { label = 'Gold Ring', weight = 50 },
	['silver_ring'] = { label = 'Silver Ring', weight = 50 },
	['goldchain'] = { label = 'Gold Chain', weight = 100 },
	['silverchain'] = { label = 'Silver Chain', weight = 100 },
	['goldearring'] = { label = 'Gold Earrings', weight = 50, client = { image = 'gold_earring.png' } },
	['silverearring'] = { label = 'Silver Earrings', weight = 50 },
	['ruby_ring'] = { label = 'Ruby Ring', weight = 50 },
	['ruby_ring_silver'] = { label = 'Ruby Ring (Silver)', weight = 50 },
	['ruby_necklace'] = { label = 'Ruby Necklace', weight = 100 },
	['ruby_necklace_silver'] = { label = 'Ruby Necklace (Silver)', weight = 100 },
	['ruby_earring'] = { label = 'Ruby Earrings', weight = 50 },
	['ruby_earring_silver'] = { label = 'Ruby Earrings (Silver)', weight = 50 },
	['emerald_ring'] = { label = 'Emerald Ring', weight = 50 },
	['emerald_ring_silver'] = { label = 'Emerald Ring (Silver)', weight = 50 },
	['emerald_necklace'] = { label = 'Emerald Necklace', weight = 100 },
	['emerald_necklace_silver'] = { label = 'Emerald Necklace (Silver)', weight = 100 },
	['emerald_earring'] = { label = 'Emerald Earrings', weight = 50 },
	['emerald_earring_silver'] = { label = 'Emerald Earrings (Silver)', weight = 50 },
	['diamond_ring'] = { label = 'Diamond Ring', weight = 50 },
	['diamond_ring_silver'] = { label = 'Diamond Ring (Silver)', weight = 50 },
	['diamond_necklace'] = { label = 'Diamond Necklace', weight = 100 },
	['diamond_necklace_silver'] = { label = 'Diamond Necklace (Silver)', weight = 100 },
	['diamond_earring'] = { label = 'Diamond Earrings', weight = 50 },
	['diamond_earring_silver'] = { label = 'Diamond Earrings (Silver)', weight = 50 },
	['sapphire_ring'] = { label = 'Sapphire Ring', weight = 50 },
	['sapphire_ring_silver'] = { label = 'Sapphire Ring (Silver)', weight = 50 },
	['sapphire_necklace'] = { label = 'Sapphire Necklace', weight = 100 },
	['sapphire_necklace_silver'] = { label = 'Sapphire Necklace (Silver)', weight = 100 },
	['sapphire_earring'] = { label = 'Sapphire Earrings', weight = 50 },
	['sapphire_earring_silver'] = { label = 'Sapphire Earrings (Silver)', weight = 50 },
	['pickaxe'] = { label = 'Pickaxe', weight = 1500, stack = false, description = 'For mining ore' },
	['miningdrill'] = { label = 'Mining Drill', weight = 2500, stack = false, description = 'Needs drill bits' },
	['mininglaser'] = { label = 'Mining Laser', weight = 2000, stack = false, description = 'Cuts through rock in seconds' },
	['drillbit'] = { label = 'Drill Bit', weight = 50, description = 'For the mining drill' },
	['goldpan'] = { label = 'Gold Pan', weight = 500, stack = false, description = 'Pan for gold in rivers' },
	['recyclablematerial'] = { label = 'Recyclable Material', weight = 100 },
	['metalscrap'] = { label = 'Metal Scrap', weight = 100 },
	['copper'] = { label = 'Copper', weight = 100 },
	['iron'] = { label = 'Iron', weight = 100 },
	['steel'] = { label = 'Steel', weight = 100 },
	['aluminum'] = { label = 'Aluminium', weight = 100 },
	['glass'] = { label = 'Glass', weight = 100 },
	['plastic'] = { label = 'Plastic', weight = 100 },
	['rubber'] = { label = 'Rubber', weight = 100 },
	['bottle'] = { label = 'Empty Bottle', weight = 50 },
	['can'] = { label = 'Empty Can', weight = 30 },
	['payticket'] = { label = 'Receipt', weight = 10, description = 'Cash these in at your workplace' },
	['terminal'] = { label = 'Card Terminal', weight = 800, stack = false, close = true, description = 'Charge customers' },
	['notepad'] = { label = 'Notepad', weight = 100, close = true, description = 'Write a note and leave it somewhere' },
	['skateboard_01'] = { label = 'Skateboard', weight = 3000, stack = false, close = true },
	['surfboard_01'] = { label = 'Surfboard', weight = 5000, stack = false, close = true },
	['surfboard_02'] = { label = 'Surfboard', weight = 5000, stack = false, close = true },
	['surfboard_03'] = { label = 'Surfboard', weight = 5000, stack = false, close = true },
	['surfboard_04'] = { label = 'Surfboard', weight = 5000, stack = false, close = true },
	['surfboard_05'] = { label = 'Surfboard (Rescue)', weight = 5000, stack = false, close = true },
	['chair1'] = { label = 'Chair 1', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair2'] = { label = 'Chair 2', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair3'] = { label = 'Chair 3', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair4'] = { label = 'Chair 4', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair5'] = { label = 'Chair 5', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair6'] = { label = 'Chair 6', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair7'] = { label = 'Chair 7', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair8'] = { label = 'Chair 8', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair9'] = { label = 'Chair 9', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair10'] = { label = 'Chair 10', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair11'] = { label = 'Chair 11', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair12'] = { label = 'Chair 12', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair13'] = { label = 'Chair 13', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair14'] = { label = 'Chair 14', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair15'] = { label = 'Chair 15', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair16'] = { label = 'Chair 16', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair17'] = { label = 'Chair 17', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair18'] = { label = 'Chair 18', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair19'] = { label = 'Chair 19', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair20'] = { label = 'Chair 20', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair21'] = { label = 'Chair 21', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair22'] = { label = 'Chair 22', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair23'] = { label = 'Chair 23', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair24'] = { label = 'Chair 24', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair25'] = { label = 'Chair 25', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair26'] = { label = 'Chair 26', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair27'] = { label = 'Chair 27', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair28'] = { label = 'Chair 28', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair29'] = { label = 'Chair 29', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair30'] = { label = 'Chair 30', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair31'] = { label = 'Chair 31', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair32'] = { label = 'Chair 32', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair33'] = { label = 'Chair 33', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair34'] = { label = 'Chair 34', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair35'] = { label = 'Chair 35', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair36'] = { label = 'Chair 36', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair37'] = { label = 'Chair 37', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair38'] = { label = 'Chair 38', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair39'] = { label = 'Chair 39', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair40'] = { label = 'Chair 40', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair41'] = { label = 'Chair 41', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair42'] = { label = 'Chair 42', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair43'] = { label = 'Chair 43', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair44'] = { label = 'Chair 44', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair45'] = { label = 'Chair 45', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair46'] = { label = 'Chair 46', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair47'] = { label = 'Chair 47', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair48'] = { label = 'Chair 48', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair49'] = { label = 'Chair 49', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair50'] = { label = 'Chair 50', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair51'] = { label = 'Chair 51', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair52'] = { label = 'Chair 52', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair53'] = { label = 'Chair 53', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair54'] = { label = 'Chair 54', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair55'] = { label = 'Chair 55', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair56'] = { label = 'Chair 56', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair57'] = { label = 'Chair 57', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair58'] = { label = 'Chair 58', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair59'] = { label = 'Chair 59', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair60'] = { label = 'Chair 60', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair61'] = { label = 'Chair 61', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair62'] = { label = 'Chair 62', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair63'] = { label = 'Chair 63', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair64'] = { label = 'Chair 64', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair65'] = { label = 'Chair 65', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair66'] = { label = 'Chair 66', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair67'] = { label = 'Chair 67', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair68'] = { label = 'Chair 68', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair69'] = { label = 'Chair 69', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair70'] = { label = 'Chair 70', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair71'] = { label = 'Chair 71', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair72'] = { label = 'Chair 72', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair73'] = { label = 'Chair 73', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair74'] = { label = 'Chair 74', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair75'] = { label = 'Chair 75', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair76'] = { label = 'Chair 76', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair77'] = { label = 'Chair 77', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair78'] = { label = 'Chair 78', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair79'] = { label = 'Chair 79', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair80'] = { label = 'Chair 80', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair81'] = { label = 'Chair 81', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair82'] = { label = 'Chair 82', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair83'] = { label = 'Chair 83', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair84'] = { label = 'Chair 84', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair85'] = { label = 'Chair 85', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair86'] = { label = 'Chair 86', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair87'] = { label = 'Chair 87', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair88'] = { label = 'Chair 88', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair89'] = { label = 'Chair 89', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair90'] = { label = 'Chair 90', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair91'] = { label = 'Chair 91', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair92'] = { label = 'Chair 92', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair93'] = { label = 'Chair 93', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair94'] = { label = 'Chair 94', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair95'] = { label = 'Chair 95', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair96'] = { label = 'Chair 96', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair97'] = { label = 'Chair 97', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair98'] = { label = 'Chair 98', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair99'] = { label = 'Chair 99', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair100'] = { label = 'Chair 100', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair101'] = { label = 'Chair 101', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair102'] = { label = 'Chair 102', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair103'] = { label = 'Chair 103', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair104'] = { label = 'Chair 104', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair105'] = { label = 'Chair 105', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair106'] = { label = 'Chair 106', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair107'] = { label = 'Chair 107', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair108'] = { label = 'Chair 108', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair109'] = { label = 'Chair 109', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },
	['chair110'] = { label = 'Chair 110', weight = 3000, close = true, description = 'A portable chair. Use it to sit down.' },

	['medicalbag'] = { label = 'Medical Bag', weight = 220, stack = true, close = true, description = 'A comprehensive medical kit for treating injuries and ailments. On-duty EMS can place it.' },
	['emstablet'] = { label = 'EMS Tablet', weight = 200, stack = false, close = true, description = 'Distress calls, MDT and dispatch for on-duty EMS.' },
	['defibrillator'] = { label = 'Defibrillator', weight = 100, stack = false, close = true, description = 'Used for reviving patients.' },
	['tweezers'] = { label = 'Tweezers', weight = 100, stack = false, close = true, description = 'Precision tweezers for safely removing foreign objects, such as bullets, from wounds.' },
	['burncream'] = { label = 'Burn Cream', weight = 100, stack = true, close = true, description = 'Specialized cream for treating and soothing minor burns and skin irritations.' },
	['suturekit'] = { label = 'Suture Kit', weight = 100, stack = true, close = true, description = 'A kit containing surgical tools and materials for stitching and closing wounds.' },
	['icepack'] = { label = 'Ice Pack', weight = 200, stack = true, close = true, description = 'An ice pack used to reduce swelling and provide relief from pain and inflammation.' },
	['stretcher'] = { label = 'Stretcher', weight = 200, stack = true, close = true, description = 'A stretcher used to move patients who require medical care.' },

	['handcuffs'] = { label = 'Handcuffs', weight = 100, stack = true, close = true, description = 'Steel handcuffs for restraining suspects.' },

	['camera'] = { label = 'Camera', weight = 1000, stack = false, close = true, description = 'A camera to take photos with.' },
	['photo'] = { label = 'Photo', weight = 50, stack = false, close = true, description = 'A printed photo.' },

	['megaphone'] = { label = 'Megaphone', weight = 1500, stack = false, close = true, description = 'A loudspeaker to make yourself heard.' },
	['powerbank'] = { label = 'Power Bank', weight = 250, stack = true, close = true, description = 'Charges your phone when there is no socket around.' },

	['stopsign'] = { label = 'Stop Sign', weight = 2500, stack = true, close = true, description = 'A stolen stop sign.' },
	['walkingmansign'] = { label = 'Pedestrian Sign', weight = 2500, stack = true, close = true, description = 'A stolen pedestrian sign.' },
	['dontblockintersectionsign'] = { label = 'Intersection Sign', weight = 2500, stack = true, close = true, description = "A stolen \"don't block the intersection\" sign." },
	['uturnsign'] = { label = 'U Turn Sign', weight = 2500, stack = true, close = true, description = 'A stolen U-turn sign.' },
	['noparkingsign'] = { label = 'No Parking Sign', weight = 2500, stack = true, close = true, description = 'A stolen no parking sign.' },
	['leftturnsign'] = { label = 'Left Turn Sign', weight = 2500, stack = true, close = true, description = 'A stolen left turn sign.' },
	['rightturnsign'] = { label = 'Right Turn Sign', weight = 2500, stack = true, close = true, description = 'A stolen right turn sign.' },
	['notrespassingsign'] = { label = 'No Trespassing Sign', weight = 2500, stack = true, close = true, description = 'A stolen no trespassing sign.' },
	['yieldsign'] = { label = 'Yield Sign', weight = 2500, stack = true, close = true, description = 'A stolen yield sign.' },

	['speaker_wall'] = { label = 'Wall Speaker', weight = 300, stack = true, close = true, description = 'Goes on a wall in your home or at your business.' },
	['speaker_ceiling'] = { label = 'Ceiling Speaker', weight = 200, stack = true, close = true, description = 'Hangs from a ceiling in your home or at your business.' },
	['speaker_floor'] = { label = 'Floor Speaker', weight = 800, stack = true, close = true, description = 'Stands on a floor or table in your home or at your business.' },
	['speaker_large'] = { label = 'Large Speaker', weight = 200, stack = true, close = true, description = 'A big club speaker for your business or home.' },
	['boombox'] = { label = 'Boombox', weight = 250, stack = false, close = true, description = 'A portable speaker. Use it to set it down anywhere.' },
	['car_stereo'] = { label = 'Car Sound System', weight = 300, stack = true, close = true, description = 'Install it from the driver seat of a vehicle.' },
	['range_booster'] = { label = 'Range Booster', weight = 200, stack = true, close = true, description = 'Goes on a wall in your home or business. Lets its speakers link up to 100 m apart.' },

	['engine_parts'] = { label = 'Engine Parts', weight = 3000, stack = true, close = true, description = 'Pistons, gaskets and belts. A mechanic can rebuild a worn engine with these.' },
	['brake_pads'] = { label = 'Brake Pads', weight = 800, stack = true, close = true, description = 'A set of brake pads and discs for one car.' },
	['clutch_kit'] = { label = 'Clutch Kit', weight = 2500, stack = true, close = true, description = 'Clutch plate, pressure plate and bearing.' },
	['suspension_parts'] = { label = 'Suspension Parts', weight = 3000, stack = true, close = true, description = 'Springs, dampers and bushings for one car.' },
	['tyre_set'] = { label = 'Tyre Set', weight = 5000, stack = true, close = true, description = 'Four fresh tyres.' },
	['radiator_parts'] = { label = 'Radiator Parts', weight = 2000, stack = true, close = true, description = 'Radiator core, hoses and coolant.' },
	['body_panel'] = { label = 'Body Panels', weight = 4000, stack = true, close = true, description = 'Panels and filler to fix bodywork.' },
	['repair_kit'] = {
		label = 'Repair Kit',
		weight = 1500,
		stack = true,
		close = true,
		consume = 0,
		description = 'Patches up a broken engine well enough to reach a workshop.',
		client = { export = 'vr-mechanic.repairKit' },
	},
	['mechanic_order'] = {
		label = 'Order Sheet',
		weight = 10,
		stack = false,
		close = true,
		consume = 0,
		description = 'A workshop order sheet.',
		client = { export = 'vr-mechanic.orderSheet' },
	},
	['card_pack'] = {
		label = 'Card Pack',
		weight = 20,
		stack = true,
		close = true,
		consume = 0,
		description = 'A sealed ValRavn trading card pack.',
		client = { export = 'vr-cards.openPack' },
	},
	['tcg_card'] = {
		label = 'Trading Card',
		weight = 1,
		stack = false,
		close = true,
		consume = 0,
		description = 'An ValRavn trading card.',
		client = { export = 'vr-cards.viewCard' },
	},
	['card_binder'] = {
		label = 'Card Binder',
		weight = 400,
		stack = false,
		close = true,
		consume = 0,
		description = 'A binder for trading cards.',
		client = { export = 'vr-cards.openBinder' },
	},

	-- vr-farming items (crops, seeds and tools)
	['wheat'] = { label = 'Wheat', weight = 300, close = true, description = 'Golden wheat, ready to be milled or brewed' },
	['corn'] = { label = 'Corn', weight = 350, close = true, description = 'Fresh sweetcorn on the cob' },
	['potato'] = { label = 'Potatoes', weight = 300, close = true, description = 'Muddy potatoes from the field' },
	['carrot'] = { label = 'Carrots', weight = 250, close = true, description = 'Crunchy orange carrots' },
	['cucumber'] = { label = 'Cucumbers', weight = 250, close = true, description = 'Cool crunchy cucumbers' },
	['onion'] = { label = 'Onions', weight = 250, close = true, description = 'Pungent onions' },
	['lettuce'] = { label = 'Lettuce', weight = 250, close = true, description = 'A crisp head of lettuce' },
	['tomato'] = { label = 'Tomatoes', weight = 250, close = true, description = 'Ripe tomatoes' },
	['pumpkin'] = { label = 'Pumpkins', weight = 900, close = true, description = 'A heavy pumpkin' },
	['strawberry'] = { label = 'Strawberries', weight = 150, close = true, description = 'Sweet strawberries' },
	['grapes'] = { label = 'Grapes', weight = 200, close = true, description = 'Bunches of grapes' },
	['hops'] = { label = 'Hops', weight = 150, close = true, description = 'Fresh hops for brewing' },
	['wheat_seed'] = { label = 'Wheat Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['corn_seed'] = { label = 'Corn Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['potato_seed'] = { label = 'Potatoe Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['carrot_seed'] = { label = 'Carrot Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['cucumber_seed'] = { label = 'Cucumber Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['onion_seed'] = { label = 'Onion Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['lettuce_seed'] = { label = 'Lettuce Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['tomato_seed'] = { label = 'Tomatoe Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['pumpkin_seed'] = { label = 'Pumpkin Seeds', weight = 10, close = true, description = 'Plant these in a field' },
	['watering_can'] = { label = 'Watering Can', weight = 900, stack = false, close = true, description = 'Fill it at a well, then water your crops' },
	['fertiliser'] = { label = 'Fertiliser', weight = 500, close = true, description = 'Makes a crop grow faster and give more' },
	['flour'] = { label = 'Flour', weight = 500, close = true, description = 'Plain flour for baking' },
	['sugar'] = { label = 'Sugar', weight = 500, close = true, description = 'A bag of sugar' },
	['salt'] = { label = 'Salt', weight = 300, close = true, description = 'Table salt' },
	['cooking_oil'] = { label = 'Cooking Oil', weight = 600, close = true, description = 'For frying' },
	['bread_bun'] = { label = 'Bread Bun', weight = 80, close = true, description = 'A soft bun' },
	['bread_loaf'] = { label = 'Loaf of Bread', weight = 450, close = true, description = 'A sliced loaf' },
	['cheese'] = { label = 'Cheese', weight = 200, close = true, description = 'A block of cheese' },
	['butter'] = { label = 'Butter', weight = 250, close = true, description = 'A block of butter' },
	['coffee_beans'] = { label = 'Coffee Beans', weight = 300, close = true, description = 'Roasted coffee beans' },
	['soda_syrup'] = { label = 'Soda Syrup', weight = 500, close = true, description = 'Fruity syrup for fizzy drinks' },
	['cola_syrup'] = { label = 'Cola Syrup', weight = 500, close = true, description = 'Syrup for cola' },
	['mustard_seed'] = { label = 'Mustard Seed', weight = 100, close = true, description = 'Seeds to make mustard' },
	['potato_cut'] = { label = 'Cut Potatoes', weight = 250, close = true, description = 'Potatoes cut ready for frying' },
	['ground_meat'] = { label = 'Ground Meat', weight = 300, close = true, description = 'Freshly ground meat' },
	['tomato_sliced'] = { label = 'Sliced Tomato', weight = 120, close = true, description = 'Sliced tomato' },
	['lettuce_shredded'] = { label = 'Shredded Lettuce', weight = 100, close = true, description = 'Shredded lettuce' },
	['onion_chopped'] = { label = 'Chopped Onion', weight = 100, close = true, description = 'Chopped onion' },
}
