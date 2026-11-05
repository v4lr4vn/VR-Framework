Config = Config or {}

Config.MaxJobs = 3

Config.AllowSelfRemove = true

Config.ActionCooldown = 1

Config.FallbackJob = "unemployed"

Config.Hint = "Look for new work at the City Hall Job Centre."

Config.IgnoredJobs = {
	["unemployed"] = true,
}

Config.DenyDuty = {
	["ambulance"] = true,
	["police"] = true,
}

-- Jobs listed under Whitelisted in the menu. A job is also whitelisted when the script that made it says so
-- (every restaurant does), or when it has a job type such as leo, ems, dispatch or doj (see WhitelistByType).
Config.WhitelistJobs = {
	["police"] = true,
	["ambulance"] = true,
	["dispatch"] = true,
	["mechanic"] = true,
	["judge"] = true,
	["prosecutor"] = true,
	["lawyer"] = true,
	["debtcollector"] = true,
	["foodstandards"] = true,
	["cardealer"] = true,
}

Config.WhitelistByType = true

-- Job types that are open to anyone even though they have a type.
Config.OpenJobTypes = {}

Config.Descriptions = {
	["police"] = "Shoot some criminals or maybe be a good cop and arrest them",
	["ambulance"] = "Fix the bullet holes",
	["mechanic"] = "Fix the bullet holes",
	["tow"] = "Pickup the tow truck and steal some vehicles",
	["taxi"] = "Pickup people around the city and drive them to their destination",
	["bus"] = "Pickup multiple people around the city and drive them to their destination",
	["realestate"] = "Sell houses or something",
	["cardealer"] = "Sell cars or something",
	["judge"] = "Decide if people are guilty",
	["prosecutor"] = "Bring the case against the accused",
	["lawyer"] = "Help the good or the bad",
	["dispatch"] = "Answer the calls and send help where it is needed",
	["debtcollector"] = "Chase the debts that were never paid",
	["foodstandards"] = "Inspect kitchens and keep the city's food safe",
	["reporter"] = "Lowkey useless",
	["trucker"] = "Drive a truck",
	["garbage"] = "Drive a garbage truck",
	["vineyard"] = "Get them vines",
	["hotdog"] = "Sell them glizzys",
}

Config.FontAwesomeIcons = {
	["police"] = "fa-solid fa-handcuffs",
	["ambulance"] = "fa-solid fa-user-doctor",
	["mechanic"] = "fa-solid fa-wrench",
	["tow"] = "fa-solid fa-truck-tow",
	["taxi"] = "fa-solid fa-taxi",
	["bus"] = "fa-solid fa-bus",
	["realestate"] = "fa-solid fa-sign-hanging",
	["cardealer"] = "fa-solid fa-cards",
	["judge"] = "fa-solid fa-gavel",
	["prosecutor"] = "fa-solid fa-scale-balanced",
	["lawyer"] = "fa-solid fa-gavel",
	["dispatch"] = "fa-solid fa-headset",
	["debtcollector"] = "fa-solid fa-file-invoice-dollar",
	["foodstandards"] = "fa-solid fa-clipboard-check",
	["reporter"] = "fa-solid fa-microphone",
	["trucker"] = "fa-solid fa-truck-front",
	["garbage"] = "fa-solid fa-trash-can",
	["vineyard"] = "fa-solid fa-wine-bottle",
	["hotdog"] = "fa-solid fa-hotdog",
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-multijob'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
