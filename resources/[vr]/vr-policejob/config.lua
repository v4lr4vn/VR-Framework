lib.locale()

Config = {}

Config.Debug = false

Config.ClothingScript = 'vr-clothing'
Config.PrisonSystem = 'pickle_prisons'
Config.ItemCuffs = 'handcuffs'
Config.CanBreakCuffs = true
Config.BreakCuffsItem = 'lockpick'
Config.DutyPoints = true
Config.AccessToMenu = { 'police' }
Config.JobTypes = { 'leo' }
Config.OpenMenuKey = 'F6'
Config.MettingMenuGrade = 3

Config.VehicleKeys = 'vr-vehiclekeys'
Config.Fuel = 'vr-fuel'
Config.BossMenu = { resource = 'qb-management', event = 'qb-bossmenu:client:OpenMenu' }
Config.AdminCuffPermissions = { 'mod', 'admin', 'god' }

Config.Security = {
	interactDistance = 4.0,
	armoryDistance = 3.0,
	armoryCooldown = 1,
	statusCooldown = 5,
	broadcastCooldown = 30,
	meetingCooldown = 60,
	interdictCooldown = 60,
	alertCooldown = 30,
}

Config.Fines = {
	max = 25000,
	cooldown = 10,
	distance = 5.0,
	reasonMax = 200,
	society = 'police'
}

Config.Broadcast = { jobs = { 'leo', 'ems' }, maxLength = 500 }
Config.Meeting = { maxLength = 500 }
Config.InterdictArea = {
	jobs = { 'leo', 'ems' },
	maxLength = 200,
	maxMinutes = 60,
	radii = { 100, 200, 300, 400 },
	types = { 1, 2, 3 },
}

Config.StatusCodes = {
	{ label = 'Patrolling',                     description = 'Status Code: 10-8',  code = '10-8',  icon = 'fas fa-user-clock' },
	{ label = 'On Scene',                       description = 'Status Code: 10-97', code = '10-97', icon = 'fas fa-map-marked-alt' },
	{ label = 'Busy',                           description = 'Status Code: 10-6',  code = '10-6',  icon = 'fas fa-user-clock' },
	{ label = 'Responding',                     description = 'Status Code: 10-8',  code = '10-8',  icon = 'fas fa-user-clock' },
	{ label = 'Pursuit in Progress',            description = 'Status Code: 10-80', code = '10-80', icon = 'fas fa-car-crash' },
	{ label = 'Needs Backup',                   description = 'Status Code: 11-99', code = '11-99', icon = 'fas fa-exclamation-triangle', alert = 'backup' },
	{ label = 'Taking a Break',                 description = 'Status Code: 10-7',  code = '10-7',  icon = 'fas fa-coffee' },
	{ label = 'Accident, Serious Injury',       description = 'Code 11-80',         code = '11-80', icon = 'fas fa-car-crash' },
	{ label = 'Accident, Minor Injury',         description = 'Code 11-81',         code = '11-81', icon = 'fas fa-car-crash' },
	{ label = 'Accident, Property Damage Only', description = 'Code 11-82',         code = '11-82', icon = 'fas fa-car-crash' },
	{ label = 'Needs Medical Assistance',       description = 'Code 11-47',         code = '11-47', icon = 'fas fa-hospital' },
	{ label = 'Investigating',                  description = 'Status Code: 10-29', code = '10-29', icon = 'fas fa-search' },
	{ label = 'In Custody',                     description = 'Status Code: 10-15', code = '10-15', icon = 'fas fa-male' },
	{ label = 'Officer Down',                   description = 'Code 11-45',         code = '11-45', icon = 'fas fa-skull-crossbones', alert = 'panic' },
	{ label = 'Emergency Response',             description = 'Status Code: 10-3',  code = '10-3',  icon = 'fas fa-exclamation' },
}

Config.Interactions = {
	enable = true,

	handcuffs = true,
	search = true,
	escort = true,
	put_out_vehicle = true,
	fines = true,
	prison = false, -- booking now lives in vr-mdt (third eye "Book suspect" or /book)
	jobs = { 'police' },
}

Config.PoliceVehicles = {
	'police',
	'police2',
	'police3',
	'policeb',
}

Config.PoliceStations = {
	["station_1"] = {
		jobs = { 'police' },
		bossmenu = {
			pos = vector3(447.08, -974.44, 30.68),
			min_grade = 4
		},
		duty = vector3(440.92, -980.76, 30.72),
		zone = {
			pos = vec3(448.0, -997.0, 44.0),
			size = vec3(96.0, 79.0, 65.0),
		},
		blip = {
			enable = true,
			name = 'Los Santos Police Department',
			type = 60,
			scale = 0.8,
			color = 38,
			pos = vector3(440.8360, -982.6481, 30.6896),
		},
		armory = {
			pedPos = vector4(454.1804, -980.1198, 29.6896, 90.0000),
			playerPos = vector4(452.3223, -980.0303, 29.7002, 270.0000),
			model = 's_m_y_cop_01',
			require_storage = true,
			storage = {
				stashId = 'podsalice_armory_storage',
				stashLabel = 'LSPD Armory Storage',
				minGradeAccess = 2,
			},
			equipment = {
				[1] = {
					{
						item = 'weapon_pistol',
						label = 'Pistol',
						quantity = 1,
						prop = {
							model = 'w_pi_pistol',
							placePos = vector3(453.24318450195, -979.99542724609 - 0.1, 30.615884399414),
						},
					},
					{
						item = 'weapon_assaultrifle',
						label = 'Rifle',
						quantity = 1,
						prop = {
							model = 'w_ar_carbinerifle',
							placePos = vector3(453.24318450195, -979.99542724609 - 0.1, 30.615884399414),
						},
					},
					{
						item = 'water',
						label = 'Water',
						quantity = 5,
						prop = {
							model = 'prop_ld_flow_bottle',
							placePos = vector3(453.24318450195, -979.99542724609 - 0.1, 30.615884399414),
						},
					},
				},
			},
		},
		garage = {},
		stash = {
			['police_stash_1'] = {
				slots = 50,
				weight = 50,
				min_grade = 0,
				label = 'Lspd stash',
				shared = true,
				pos = vector3(451.70455932617, -974.02062988281, 30.689004898071)
			}
		},
		cameras = {
			pos = vector3(441.64836425781, -979.58472167969, 30.75832862854),
			views = {
				{
					pos = vector3(433.63613891602, -978.21331787109, 33.510547637939),
					rot = vector3(-2.2620145045948e-07, 1.3051226233074e-06, 125.97998046875)
				},
				{
					pos = vector3(424.19268798828, -996.83068847656, 34.037242889404),
					rot = vector3(9.8608965345193e-05, 2.7001857233699e-05, 124.36595153809)
				},
				{
					pos = vector3(438.27066040039, -999.63421630859, 32.715244293213),
					rot = vector3(0.0, -0.0, -154.93447875977)
				},
				{
					pos = vector3(489.390625, -1004.2265014648, 30.153388977051),
					rot = vector3(0.0, 0.0, -56.987983703613)
				},
				{
					pos = vector3(482.24676513672, -978.32403564453, 30.483800888062),
					rot = vector3(0.0, 0.0, 25.241655349731)
				},
				{
					pos = vector3(455.39239501953, -971.02227783203, 33.162532806396),
					rot = vector3(1.9254218841525e-07, -1.1291083268361e-07, 22.17286491394)
				},
			}
		},
		clothes = {
			enable = true,
			pos = vector4(452.6250, -991.7988, 29.6896, 357.0948),
			model = 'a_f_m_bevhills_01',
			male = {
				[1] = {
					['mask_1']    = 0,
					['mask_2']    = 0,
					['arms']      = 0,
					['tshirt_1']  = 15,
					['tshirt_2']  = 0,
					['torso_1']   = 86,
					['torso_2']   = 0,
					['bproof_1']  = 0,
					['bproof_2']  = 0,
					['decals_1']  = 0,
					['decals_2']  = 0,
					['chain_1']   = 0,
					['chain_2']   = 0,
					['pants_1']   = 10,
					['pants_2']   = 2,
					['shoes_1']   = 56,
					['shoes_2']   = 0,
					['helmet_1']  = 34,
					['helmet_2']  = 0,
					['glasses_1'] = 34,
					['glasses_2'] = 1,
				},
				[2] = {
					['mask_1']    = 0,
					['mask_2']    = 0,
					['arms']      = 0,
					['tshirt_1']  = 15,
					['tshirt_2']  = 0,
					['torso_1']   = 86,
					['torso_2']   = 0,
					['bproof_1']  = 0,
					['bproof_2']  = 0,
					['decals_1']  = 0,
					['decals_2']  = 0,
					['chain_1']   = 0,
					['chain_2']   = 0,
					['pants_1']   = 10,
					['pants_2']   = 2,
					['shoes_1']   = 56,
					['shoes_2']   = 0,
					['helmet_1']  = 34,
					['helmet_2']  = 0,
					['glasses_1'] = 34,
					['glasses_2'] = 1,
				},
			},
			female = {
				[1] = {
					['mask_1']    = 0,
					['mask_2']    = 0,
					['arms']      = 0,
					['tshirt_1']  = 15,
					['tshirt_2']  = 0,
					['torso_1']   = 86,
					['torso_2']   = 0,
					['bproof_1']  = 0,
					['bproof_2']  = 0,
					['decals_1']  = 0,
					['decals_2']  = 0,
					['chain_1']   = 0,
					['chain_2']   = 0,
					['pants_1']   = 10,
					['pants_2']   = 2,
					['shoes_1']   = 56,
					['shoes_2']   = 0,
					['helmet_1']  = 34,
					['helmet_2']  = 0,
					['glasses_1'] = 34,
					['glasses_2'] = 1,
				},
			},
		},
	},

}
