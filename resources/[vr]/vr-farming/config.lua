Config = {}

Config.Admin = {
    command = 'farmcreator',
}

-- Money for the store goes through this account.
Config.Account = 'cash'

-- How close you must be to a plant, store or well.
Config.Reach = 4.0

Config.Rules = {
    -- 1.0 is real time. 0.1 makes everything ten times faster, handy for testing.
    growthScale = 1.0,

    maxPlantsPerPlayer = 40,
    maxPlantsPerField = 150,
    -- Closest two plants may be, in metres.
    spacing = 0.9,

    -- Nobody else may harvest your crop until it has been ready this long.
    protectMinutes = 30,
    -- A ripe crop nobody picks dies after this long.
    witherMinutes = 90,
    -- A dead plant disappears on its own after this long.
    deadClearMinutes = 10,

    -- A plant can be dry this long (over its whole life) before it starts to suffer,
    -- then it takes this long to die. Dry time lowers quality.
    graceMinutes = 8,
    dieMinutes = 30,

    -- Fertiliser: grows faster and gives more.
    fertiliserGrowth = 1.25,
    fertiliserYield = 1.3,

    -- Chance of getting seeds back when you harvest, and how many.
    seedBack = 0.4,
    seedBackAmount = { 1, 2 },

    -- Watering can capacity and refill time.
    canCapacity = 8,

    -- How long each action takes, in seconds.
    seconds = { plant = 3.5, water = 2.5, fertilise = 2.5, harvest = 4.0, uproot = 2.0, refill = 4.0 },

    minGapMs = 500,
    -- The server looks at every plant this often.
    tickSeconds = 15,
    -- Growth is written to the database this often.
    saveSeconds = 300,
    -- Plants closer than this to you are drawn.
    streamDistance = 45.0,
}

Config.Items = {
    can = 'watering_can',
    fertiliser = 'fertiliser',
}

-- Quality comes from how well the plant was looked after (its health at harvest).
-- It is stored on the item as metadata.quality (1, 2 or 3).
Config.Quality = {
    [1] = { label = 'Poor', yield = 0.7, price = 0.7 },
    [2] = { label = 'Good', yield = 1.0, price = 1.0 },
    [3] = { label = 'Great', yield = 1.2, price = 1.3 },
}
Config.QualityHealth = { great = 80, good = 50 }

-- Every crop. growMinutes: time to ripen while watered. waterMinutes: how long one watering lasts.
-- sell: store price per item at Good quality. seedPrice: price of one seed at the store.
-- regrow: after harvest the plant goes back to this share of its growth and fruits again.
Config.Crops = {
    wheat      = { label = 'Wheat',      growMinutes = 40, waterMinutes = 22, yield = { 5, 9 },  sell = 7,  seedPrice = 12 },
    corn       = { label = 'Corn',       growMinutes = 50, waterMinutes = 25, yield = { 4, 8 },  sell = 9,  seedPrice = 14 },
    potato     = { label = 'Potatoes',   growMinutes = 45, waterMinutes = 25, yield = { 5, 9 },  sell = 8,  seedPrice = 13 },
    carrot     = { label = 'Carrots',    growMinutes = 35, waterMinutes = 20, yield = { 5, 10 }, sell = 7,  seedPrice = 11 },
    onion      = { label = 'Onions',     growMinutes = 40, waterMinutes = 22, yield = { 4, 8 },  sell = 7,  seedPrice = 11 },
    lettuce    = { label = 'Lettuce',    growMinutes = 25, waterMinutes = 15, yield = { 3, 6 },  sell = 10, seedPrice = 12 },
    cucumber   = { label = 'Cucumbers',  growMinutes = 35, waterMinutes = 18, yield = { 4, 8 },  sell = 9,  seedPrice = 13 },
    tomato     = { label = 'Tomatoes',   growMinutes = 55, waterMinutes = 20, yield = { 5, 9 },  sell = 11, seedPrice = 18 },
    pumpkin    = { label = 'Pumpkins',   growMinutes = 70, waterMinutes = 30, yield = { 2, 4 },  sell = 22, seedPrice = 25 },
}
-- Item names: the crop is its own key (wheat), the seed is <key>_seed (wheat_seed).

Config.Store = {
    -- The store pays this share of the price. Players can do better selling to a business.
    rate = 0.8,
    minGapMs = 500,
    -- Other things the store sells: item = price
    goods = {
        watering_can = 120,
        fertiliser = 25,
    },
}

-- Models for each growth stage. The first one that exists in your game is used,
-- so a missing prop never breaks anything. A crop can set its own models = { [1] = {...}, ... }.
Config.Models = {
    [1] = { 'prop_plant_01a', 'prop_cs_plant_01' },
    [2] = { 'prop_plant_01b', 'prop_bush_neat_01' },
    [3] = { 'prop_plant_01b', 'prop_bush_neat_02' },
    ready = { 'prop_plant_01b' },
    dead = { 'prop_bush_dead_02', 'prop_plant_fern_02a' },
}
Config.CropModels = {
    corn = { ready = { 'prop_veg_corn_01' } },
    lettuce = { ready = { 'prop_veg_crop_03_cab' } },
    pumpkin = { ready = { 'prop_veg_crop_03_pump' } },
    carrot = { ready = { 'prop_veg_crop_04' } },
}

Config.Ped = {
    store = 's_m_y_construct_01',
    streamDistance = 60.0,
}

Config.Blips = {
    field = true,
    store = true,
    well = false,
}

-- Only used by old round fields. New fields are drawn corner by corner.
Config.DefaultFieldRadius = 20.0

-- How far above and below the corners a field reaches, in metres.
Config.FieldDepth = { below = 3.0, above = 8.0 }

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-farming'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
