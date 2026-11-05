local Config = {}

Config.debug = false

Config.useOxInventory = true

Config.clothingScript = 'vr-clothing'
Config.emsJobs = { "ambulance", "ems" }
Config.respawnTime = 0
Config.waitTimeForNewCall = 5

Config.reviveCommand = "revive"
Config.reviveAreaCommand = "revivearea"
Config.healCommand = "heal"
Config.healAreaCommand = "healarea"
Config.reviveAllCommand = "reviveall"

Config.adminPermission = "admin"
Config.maxAreaRadius = 500.0

Config.medicBagProp = "xm_prop_x17_bag_med_01a"
Config.medicBagItem = "medicalbag"

Config.tabletItem = "emstablet"
Config.defibrillatorItem = "defibrillator"

Config.injuryItems = {
	beaten = "icepack",
	stabbed = "suturekit",
	shot = "tweezers",
	burn = "burncream",
	fire = "burncream",
}

Config.helpCommand = "distress"
Config.removeItemsOnRespawn = true
Config.keepItemsOnRespawn = { "money", "WEAPON_PISTOL" }

Config.baseInjuryReward = 150
Config.reviveReward = 700
Config.rewardCooldown = 10
Config.maxInjuryRewards = 5

Config.paramedicTreatmentPrice = 4000
Config.paramedicAccounts = { "cash", "bank" }
Config.society = "ambulance"
Config.shouldRevive = false
Config.allowAlways = true

Config.ambulanceStretchers = 2
Config.consumeItemPerUse = 10

Config.timeToWaitForCommand = 2
Config.npcReviveCommand = "ambulance"

Config.usePedToDepositVehicle = false
Config.extraEffects = true

Config.maxDistance = {
	revive = 4.0,
	treat = 4.0,
	check = 5.0,
	stretcher = 6.0,
	vehicle = 10.0,
	paramedic = 5.0,
	medicalBag = 5.0,
}

Config.dispatch = {
	distress = { codeName = 'injured', code = '10-52', icon = 'fas fa-kit-medical', priority = 1, jobs = { 'ems' } },
	officerDown = { codeName = 'officerdown', code = '10-99', icon = 'fas fa-skull', priority = 1, jobs = { 'leo', 'ems' } },
	emsDown = { codeName = 'emsdown', code = '10-99', icon = 'fas fa-skull', priority = 1, jobs = { 'leo', 'ems' } },
	downCooldown = 60,
}

Config.adminMenu = {
	resource = 'vr-adminmenu',
	permission = 'mod',
	radius = 15.0,
}

Config.bossMenu = {
	resource = 'vr-management',
	event = 'vr-bossmenu:client:OpenMenu',
}

Config.fuelResource = 'vr-fuel'

Config.emsVehicles = {
	ambulance = true,
	ambulance2 = true,
}

Config.animations = {
	["death_car"] = {
		dict = "veh@low@front_ps@idle_duck",
		clip = "sit"
	},
	["death_normal"] = {
		dict = "dead",
		clip = "dead_a"
	},
	["get_up"] = {
		dict = "get_up@directional@movement@from_knees@action",
		clip = "getup_r_0"
	}
}

function Config.giveVehicleKeys(vehicle, plate)
	if GetResourceState('vr-vehiclekeys') ~= 'started' then return end
	TriggerEvent('vehiclekeys:client:SetOwner', plate)
end

function Config.removeVehicleKeys(vehicle, plate)
end

return Config
