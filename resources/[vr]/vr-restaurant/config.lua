Config = Config or {}

Config.Debug = false

Config.CancelKeys = { 177, 73 }
Config.CancelHint = 'Stop'

Config.SprintControl = 21

Config.FallbackEmote = { food = 'burger', drink = 'drink', alcohol = 'beer', smoke = 'smoke3', drug = 'oxy', pack = 'uncuff' }

Config.Verbs = { food = 'Eating', drink = 'Drinking', alcohol = 'Drinking', smoke = 'Smoking', drug = 'Taking', pack = 'Opening' }

Config.Intoxication = {
    decayMinutes = 15,
    alcohol = {
        tipsy = 2,
        drunk = 4,
        overdose = 5,
    },
    drug = {
        high = 7,
        overdose = 4,
    },
    overdoseDamage = { 5, 10 },
}

Config.BaseItems = {
    food = 'vr_food',
    drink = 'vr_drink',
}

Config.Limits = {
    hunger = 100, thirst = 100, stress = 100, heal = 200, armor = 100,
    time = { 500, 60000 },
}

---------------------------------------------------------------------------
-- Restaurants
---------------------------------------------------------------------------

Config.Admin = {
    command = 'restaurantcreator',
}

-- Every restaurant is also a real job in the framework (rest_<id>): its ranks are the grades and the owner is the
-- top grade. Staff see it in the job menu under Whitelisted, and clocking in and out follows the job menu's duty button.
-- Wages stay with the business (paid from its account while clocked in), so the framework's own paycheck is 0.
Config.Jobs = {
    enabled = true,
    prefix = 'rest_',
    syncSeconds = 15,          -- how often the job list is checked against the restaurants
    whitelisted = true,        -- shown under Whitelisted in the job menu
    icon = 'fa-solid fa-utensils',
    ownerGrade = 'Owner',
}

-- Staff are paid this often (minutes) while they are online and clocked in.
Config.Pay = {
    minutes = 15,
    account = 'bank',
}

Config.Business = {
    maxRanks = 10,
    maxStaff = 40,
    defaultMaxWage = 1500,   -- the most an owner can earn per payday, until an admin changes it for that restaurant
    hireRange = 8.0,         -- how close a player must be to be offered a job
    reach = 3.0,             -- how close you must be to the office
    inviteSeconds = 30,
    minGapMs = 400,
}

-- What a rank can be allowed to do. Staff only ever hand out what they have themselves.
Config.Perms = {
    { id = 'staff', label = 'Hire, fire and promote staff' },
    { id = 'ranks', label = 'Create and edit ranks' },
    { id = 'money', label = 'Use the business account' },
    { id = 'menu',  label = 'Change dishes and prices' },
    { id = 'cook',  label = 'Use the kitchen' },
    { id = 'till',  label = 'Run the till' },
}

-- Ranks every new restaurant starts with (the owner can change them).
Config.DefaultRanks = {
    { label = 'Manager', level = 80, wage = 0, perms = { 'staff', 'menu', 'cook', 'till' } },
    { label = 'Chef',    level = 50, wage = 0, perms = { 'cook' } },
    { label = 'Server',  level = 30, wage = 0, perms = { 'till' } },
    { label = 'Trainee', level = 10, wage = 0, perms = {} },
}

Config.Blip = { sprite = 93, colour = 5, scale = 0.7 }

---------------------------------------------------------------------------
-- Licences, hygiene and inspections (all times are real time)
---------------------------------------------------------------------------

-- Fines and licence fees are paid into this society account. Use the same one as vr-cityhall.
Config.Society = 'government'

-- Where the City Hall clerks stand. Copy these from vr-cityhall's Config.Desks.
Config.CityHall = {
    range = 10.0,
    desks = { vec3(-265.0, -963.6, 31.2) },
}

-- The food licence. Each business has its own length between minDays and maxDays (an admin sets it),
-- a real week standing in for a game month, so 21 to 42 days is 3 to 6 months.
Config.Licence = {
    prefix = 'FD-',
    fee = 3500,
    minDays = 21,
    maxDays = 42,
    defaultDays = 30,
    renewWindowDays = 7,   -- renewing is allowed this close to the end, or after it ran out
}

-- Buying and handing back a business at City Hall.
Config.Sale = {
    refundPercent = 0,     -- share of the price paid back when the owner hands a business back
}

Config.Hygiene = {
    tickSeconds = 60,
    dirtPerHour = 14,      -- how dirty each cleaning point gets per hour of someone being clocked in
    perStaff = 0.2,        -- extra dirt for each additional person working
    saveSeconds = 300,
    noPointCap = 40,       -- the best rating a place with no cleaning points can have
    cleanSeconds = 6.0,
    minDirtToClean = 5,
    ratings = {
        { min = 90, stars = 5, label = 'Very good' },
        { min = 75, stars = 4, label = 'Good' },
        { min = 55, stars = 3, label = 'Generally satisfactory' },
        { min = 35, stars = 2, label = 'Improvement necessary' },
        { min = 15, stars = 1, label = 'Major improvement necessary' },
        { min = 0,  stars = 0, label = 'Urgent improvement necessary' },
    },
}

Config.Inspect = {
    job = 'foodstandards',
    randomMinutes = 30,        -- how often the game decides whether an inspector drops in
    chance = 0.2,              -- chance per business per check, when somebody is clocked in
    dirtyChanceMultiplier = 2, -- applies when the rating is under warnBelow
    cooldownMinutes = 120,     -- the same place is not inspected again inside this time
    warnBelow = 55,            -- a warning to clean up
    failBelow = 35,            -- an offence
    fines = { unlicensed = 1500, unhygienic = 1000 },
    closeHours = 2,            -- temporary closure for dirt; each extra strike adds this much again
    maxStrikes = 3,            -- the third strike closes the business for good
    strikeDecayDays = 7,       -- one strike is forgiven for each clean stretch of this length
    permanent = {
        revokesOwnership = true, -- the owner loses the business and cannot buy one for banDays
        banDays = 14,
        relistDays = 14,         -- then it goes back on sale (admins can relist sooner)
    },
    officer = { maxFine = 5000, maxCloseHours = 72, revokeGrade = 3 },
    history = 20,
}

-- Crafting areas an admin places for each business. `cook` kinds are where dishes are made.
Config.Stations = {
    { id = 'prep',    label = 'Prep counter',       icon = 'fa-solid fa-utensils',        radius = 1.2, cook = true },
    { id = 'grill',   label = 'Grill',              icon = 'fa-solid fa-fire',            radius = 1.2, cook = true },
    { id = 'fryer',   label = 'Fryer',              icon = 'fa-solid fa-drumstick-bite',  radius = 1.0, cook = true },
    { id = 'oven',    label = 'Oven',               icon = 'fa-solid fa-fire-burner',     radius = 1.2, cook = true },
    { id = 'hob',     label = 'Hob',                icon = 'fa-solid fa-kitchen-set',     radius = 1.2, cook = true },
    { id = 'bar',     label = 'Bar',                icon = 'fa-solid fa-martini-glass',   radius = 1.5, cook = true, drinks = true },
    { id = 'dispenser', label = 'Drinks dispenser', icon = 'fa-solid fa-glass-water',     radius = 1.0, cook = true, drinks = true },
    { id = 'brew',    label = 'Brewing station',    icon = 'fa-solid fa-beer-mug-empty',  radius = 1.5, cook = true, drinks = true },
    { id = 'fridge',  label = 'Fridge and storage', icon = 'fa-solid fa-snowflake',      radius = 1.2 },
    { id = 'hotbox',  label = 'Hot box',            icon = 'fa-solid fa-temperature-high', radius = 1.0 },
    { id = 'tray',    label = 'Serving tray',       icon = 'fa-solid fa-plate-wheat',     radius = 1.0 },
    { id = 'till',    label = 'Till',               icon = 'fa-solid fa-cash-register',   radius = 1.0 },
    { id = 'counter', label = 'Self-serve counter', icon = 'fa-solid fa-bell-concierge',  radius = 1.5 },
    { id = 'clean',   label = 'Cleaning point',     icon = 'fa-solid fa-broom',           radius = 1.5 },
}
Config.MaxStations = 40

---------------------------------------------------------------------------
-- Kitchen: storage, cooking, the menu, the till and wholesale orders
---------------------------------------------------------------------------

-- Storage areas. Each one is a real inventory stash that opens on the normal inventory screen.
-- `mult` is how much slower things go off in there (3 means three times longer). `slots` and
-- `weight` (grams) are the size of the stash. Staff put things in; staffOnly areas are closed to
-- customers. The tray is free to take from (the customer has already paid at the till). The
-- self-serve counter charges the menu price when a customer takes something.
Config.Storage = {
    fridge  = { mult = 3.0, accepts = 'ingredient', staffOnly = true,  slots = 40, weight = 200000 },
    hotbox  = { mult = 2.0, accepts = 'dish',       staffOnly = true,  slots = 20, weight = 60000 },
    tray    = { mult = 1.0, accepts = 'dish',       staffOnly = false, slots = 12, weight = 30000 },
    counter = { mult = 1.0, accepts = 'dish',       staffOnly = false, slots = 20, weight = 50000 },
    tickSeconds = 60,          -- how often the slower spoiling is applied
    -- Things made or delivered get their spoil time rounded to this many seconds, so batches made close
    -- together are identical and stack. The fridge and hot box also move spoil times in steps of this size.
    stackSeconds = 600,
}

Config.Cook = {
    baseMs = 4000,             -- every dish takes this long plus extraMs for each ingredient
    extraMs = 1000,
    mess = 2.0,                -- dirt added to the cleaning points for every dish made
    prepMess = 1.0,            -- and for every prep step
    minGapMs = 400,
    dishLifeMinutes = 180,     -- how long a freshly made dish keeps (real minutes), unless the recipe says
    maxDishes = 30,            -- dishes an owner can design per business
    maxIngredients = 8,        -- different ingredients in one designed dish
    maxPerIngredient = 10,
    maxPrice = 5000,
    maxBatch = 20,             -- how many you can make in one go
    batchFactor = 0.6,         -- each extra one adds this share of the single-item time (so batches save a little time)
    maxMs = 180000,            -- no single job takes longer than this
}

-- Pictures owners can give their dishes. They paste a link; it is shown on the item in the inventory.
-- Only https links to these sites (or their subdomains) that end in an image type are accepted, so nobody
-- can point a dish at a random page. Add your own image host here, or set allowAny = true to allow any https link.
Config.Images = {
    enabled = true,
    allowAny = false,
    hosts = { 'i.imgur.com', 'cdn.discordapp.com', 'media.discordapp.net', 'i.postimg.cc', 'i.ibb.co', 'files.catbox.moe', 'raw.githubusercontent.com' },
    extensions = { 'png', 'jpg', 'jpeg', 'webp', 'gif' },
    maxLength = 250,
}

-- Taking money at the till.
Config.Till = { range = 8.0, askSeconds = 30, maxLines = 12, maxTotal = 20000 }

-- Ordering stock for the fridge. Paid from the business account. This stands in for the
-- supplier deliveries, which come in a later update.
Config.Wholesale = { maxOrder = 100 }

-- Everything a fridge accepts, with the wholesale price, how long it keeps (real minutes, nil
-- means it does not go off) and what it adds to a dish an owner designs.
Config.Ingredients = {
    -- staples
    flour        = { price = 3,  hunger = 4 },
    sugar        = { price = 3,  hunger = 3 },
    salt         = { price = 1 },
    cooking_oil  = { price = 4,  hunger = 2 },
    bread_bun    = { price = 4,  hunger = 8,  life = 720 },
    bread_loaf   = { price = 5,  hunger = 10, life = 1440 },
    cheese       = { price = 6,  hunger = 6,  life = 2880 },
    butter       = { price = 5,  hunger = 4,  life = 2880 },
    coffee_beans = { price = 6,  thirst = 2 },
    soda_syrup   = { price = 4,  thirst = 6 },
    cola_syrup   = { price = 4,  thirst = 6 },
    mustard_seed = { price = 3 },
    water        = { price = 1,  thirst = 12 },
    -- made at the prep counter (not sold wholesale, so no price)
    potato_cut       = { hunger = 3, life = 720 },
    ground_meat      = { hunger = 8, life = 360 },
    tomato_sliced    = { hunger = 1, life = 720 },
    lettuce_shredded = { hunger = 1, life = 480 },
    onion_chopped    = { hunger = 1, life = 1440 },
    -- from the farms
    wheat        = { price = 3,  hunger = 3 },
    corn         = { price = 4,  hunger = 5,  life = 1440 },
    potato       = { price = 3,  hunger = 5,  life = 2880 },
    carrot       = { price = 3,  hunger = 4,  life = 2880 },
    cucumber     = { price = 3,  hunger = 3,  thirst = 1, life = 1440 },
    onion        = { price = 2,  hunger = 2,  life = 4320 },
    lettuce      = { price = 3,  hunger = 2,  life = 720 },
    tomato       = { price = 3,  hunger = 3,  life = 1440 },
    pumpkin      = { price = 6,  hunger = 8,  life = 4320 },
    strawberry   = { price = 5,  hunger = 3,  thirst = 1, life = 720 },
    grapes       = { price = 5,  hunger = 3,  thirst = 2, life = 1440 },
    hops         = { price = 4,  life = 4320 },
    -- meat and fish
    meat_boar    = { price = 14, hunger = 14, life = 480 },
    meat_deer    = { price = 16, hunger = 15, life = 480 },
    meat_coyote  = { price = 8,  hunger = 10, life = 480 },
    meat_rabbit  = { price = 10, hunger = 10, life = 480 },
    fish_carp    = { price = 8,  hunger = 9,  life = 360 },
    fish_perch   = { price = 9,  hunger = 9,  life = 360 },
    fish_trout   = { price = 11, hunger = 11, life = 360 },
    fish_pike    = { price = 12, hunger = 11, life = 360 },
    fish_salmon  = { price = 16, hunger = 13, life = 360 },
    fish_mackerel = { price = 10, hunger = 10, life = 360 },
    fish_snapper = { price = 14, hunger = 12, life = 360 },
    fish_grouper = { price = 15, hunger = 12, life = 360 },
    fish_tuna    = { price = 20, hunger = 14, life = 360 },
    fish_marlin  = { price = 28, hunger = 15, life = 360 },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-restaurant'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
