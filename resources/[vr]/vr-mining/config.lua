Config = {}

-- Part of the ValRavn framework. A renamed copy of this resource does not run.
do
    local expected = 'vr-mining'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end

Config.Range = 4.0       -- how far from a point the server still accepts the action
Config.Distance = 2.0    -- how close you have to be to see the target option
Config.Radius = 1.5      -- size of the target zone around a placed point

Config.Title = 'Mining'
Config.Table = 'vr_mining_points'
Config.AdminCommand = 'miningadmin'

-- Every kind of place. Admins put them down in game with /miningadmin.
--   mode        gather: do an action and roll the yield. craft: pick a recipe. sell: sell to a buyer.
--   tools       any one of these items is needed (gather). toolBreak is the chance it breaks per use.
--   consumes    items used up by one gather action
--   yield       rows of { item, min, max, chance }. pick = 'all' rolls each row, 'one' picks a single row by weight
--   nodeCooldown seconds a spot is empty for everyone after it was worked. playerCooldown is per person
--   skill       skill check difficulties after the progress bar
Config.Kinds = {
    ore = {
        label = 'Mine the rock', icon = 'fa-solid fa-mountain', mode = 'gather', duration = 9000,
        tools = { 'pickaxe', 'miningdrill', 'mininglaser' }, toolBreak = 0.02, nodeCooldown = 120, skill = { 'easy' },
        anim = { scenario = 'WORLD_HUMAN_HAMMERING' }, pick = 'all',
        yield = {
            { item = 'stone', min = 1, max = 3, chance = 100 }, { item = 'carbon', min = 1, max = 1, chance = 20 },
            { item = 'copperore', min = 1, max = 2, chance = 25 }, { item = 'ironore', min = 1, max = 2, chance = 20 },
            { item = 'goldore', min = 1, max = 1, chance = 6 }, { item = 'silverore', min = 1, max = 1, chance = 8 },
        },
    },
    crack = {
        label = 'Crack stone', icon = 'fa-solid fa-hammer', mode = 'gather', duration = 7000, consumes = { stone = 1 },
        nodeCooldown = 0, playerCooldown = 0, skill = { 'easy' }, anim = { scenario = 'WORLD_HUMAN_HAMMERING' }, pick = 'all',
        yield = {
            { item = 'carbon', min = 1, max = 2, chance = 35 }, { item = 'copperore', min = 1, max = 2, chance = 35 },
            { item = 'ironore', min = 1, max = 2, chance = 30 }, { item = 'goldore', min = 1, max = 1, chance = 10 },
            { item = 'silverore', min = 1, max = 1, chance = 12 },
            { item = 'uncut_ruby', min = 1, max = 1, chance = 2 }, { item = 'uncut_emerald', min = 1, max = 1, chance = 2 },
            { item = 'uncut_sapphire', min = 1, max = 1, chance = 2 }, { item = 'uncut_diamond', min = 1, max = 1, chance = 1 },
        },
    },
    wash = {
        label = 'Wash stone', icon = 'fa-solid fa-droplet', mode = 'gather', duration = 7000, consumes = { stone = 1 },
        nodeCooldown = 0, skill = { 'easy' }, anim = { scenario = 'WORLD_HUMAN_BUM_WASH' }, pick = 'all',
        yield = {
            { item = 'copperore', min = 1, max = 1, chance = 30 }, { item = 'ironore', min = 1, max = 1, chance = 25 },
            { item = 'goldore', min = 1, max = 1, chance = 12 }, { item = 'silverore', min = 1, max = 1, chance = 14 },
            { item = 'uncut_ruby', min = 1, max = 1, chance = 2 }, { item = 'uncut_emerald', min = 1, max = 1, chance = 2 },
            { item = 'uncut_sapphire', min = 1, max = 1, chance = 2 }, { item = 'uncut_diamond', min = 1, max = 1, chance = 1 },
        },
    },
    pan = {
        label = 'Pan for gold', icon = 'fa-solid fa-filter', mode = 'gather', duration = 8000, tools = { 'goldpan' },
        nodeCooldown = 20, playerCooldown = 10, anim = { scenario = 'WORLD_HUMAN_BUM_WASH' }, pick = 'one',
        yield = { { item = 'goldore', min = 1, max = 1, chance = 14 }, { item = 'silverore', min = 1, max = 1, chance = 10 }, { item = false, chance = 76 } },
    },
    smelt = {
        label = 'Smelter', icon = 'fa-solid fa-fire', mode = 'craft', duration = 8000, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
        skill = { 'easy' },
        recipes = {
            { label = 'Smelt copper', takes = { copperore = 2, carbon = 1 }, gives = { copper = 2 } },
            { label = 'Smelt iron', takes = { ironore = 2, carbon = 1 }, gives = { iron = 2 } },
            { label = 'Make steel', takes = { iron = 2, carbon = 2 }, gives = { steel = 1 } },
            { label = 'Smelt gold', takes = { goldore = 3, carbon = 1 }, gives = { goldingot = 1 } },
            { label = 'Smelt silver', takes = { silverore = 3, carbon = 1 }, gives = { silveringot = 1 } },
        },
    },
    cut = {
        label = 'Jeweller bench', icon = 'fa-solid fa-gem', mode = 'craft', duration = 7000, anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
        skill = { 'medium' },
        recipes = {}, -- filled below
    },
    oreBuyer = {
        label = 'Sell ore and bars', icon = 'fa-solid fa-sack-dollar', mode = 'sell',
        prices = {
            stone = 4, carbon = 10, copperore = 22, ironore = 26, goldore = 60, silverore = 48,
            copper = 40, iron = 46, steel = 95, goldingot = 190, silveringot = 150,
        },
    },
    jewelBuyer = {
        label = 'Sell gems and jewellery', icon = 'fa-solid fa-ring', mode = 'sell',
        prices = {
            uncut_ruby = 90, uncut_emerald = 100, uncut_sapphire = 95, uncut_diamond = 160,
            ruby = 180, emerald = 200, sapphire = 190, diamond = 320,
            gold_ring = 260, silver_ring = 190, goldchain = 340, silverchain = 250, goldearring = 280, silverearring = 200,
        },
    },
}

-- Gem cutting and jewellery. Edit the numbers, or add rows to Config.Kinds.cut.recipes by hand.
do
    local recipes = Config.Kinds.cut.recipes
    local gems = { ruby = 'Ruby', emerald = 'Emerald', sapphire = 'Sapphire', diamond = 'Diamond' }
    local order = { 'ruby', 'emerald', 'sapphire', 'diamond' }
    for _, g in ipairs(order) do
        recipes[#recipes + 1] = { label = ('Cut a %s'):format(gems[g]), takes = { ['uncut_' .. g] = 1 }, gives = { [g] = 1 } }
    end
    for _, g in ipairs(order) do
        local n = gems[g]
        recipes[#recipes + 1] = { label = n .. ' ring (gold)', takes = { [g] = 1, goldingot = 1 }, gives = { [g .. '_ring'] = 1 } }
        recipes[#recipes + 1] = { label = n .. ' ring (silver)', takes = { [g] = 1, silveringot = 1 }, gives = { [g .. '_ring_silver'] = 1 } }
        recipes[#recipes + 1] = { label = n .. ' necklace (gold)', takes = { [g] = 1, goldingot = 2 }, gives = { [g .. '_necklace'] = 1 } }
        recipes[#recipes + 1] = { label = n .. ' necklace (silver)', takes = { [g] = 1, silveringot = 2 }, gives = { [g .. '_necklace_silver'] = 1 } }
        recipes[#recipes + 1] = { label = n .. ' earrings (gold)', takes = { [g] = 2, goldingot = 1 }, gives = { [g .. '_earring'] = 1 } }
        recipes[#recipes + 1] = { label = n .. ' earrings (silver)', takes = { [g] = 2, silveringot = 1 }, gives = { [g .. '_earring_silver'] = 1 } }
    end
    recipes[#recipes + 1] = { label = 'Gold ring', takes = { goldingot = 1 }, gives = { gold_ring = 1 } }
    recipes[#recipes + 1] = { label = 'Silver ring', takes = { silveringot = 1 }, gives = { silver_ring = 1 } }
    recipes[#recipes + 1] = { label = 'Gold chain', takes = { goldingot = 2 }, gives = { goldchain = 1 } }
    recipes[#recipes + 1] = { label = 'Silver chain', takes = { silveringot = 2 }, gives = { silverchain = 1 } }
    recipes[#recipes + 1] = { label = 'Gold earrings', takes = { goldingot = 1 }, gives = { goldearring = 1 } }
    recipes[#recipes + 1] = { label = 'Silver earrings', takes = { silveringot = 1 }, gives = { silverearring = 1 } }
end
