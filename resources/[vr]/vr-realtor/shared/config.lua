Config = Config or {}

Config.RealtorJobNames = {
    "realestate",
}

Config.UseCommand = true

Config.UseItem = false

Config.PlayAnimation = true

Config.AnimationProp = 'prop_cs_tablet'

Config.ItemName = "tablet"

Config.RealtorPerms = {
    manageProperty = 1,
    changePropertyForSale = 0,
    sellProperty = 0,
    listNewProperty = 2,
    deleteProperty = 2,
    setApartments = 2,
}

RealtorJobs = {}

for i = 1, #Config.RealtorJobNames do
    RealtorJobs[Config.RealtorJobNames[i]] = true
end
