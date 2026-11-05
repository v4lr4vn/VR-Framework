Config = {}

-- Part of the ValRavn framework. A renamed copy of this resource does not run.
do
    local expected = 'vr-recycle'
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

Config.Title = 'Recycling'
Config.Table = 'vr_recycle_points'
Config.AdminCommand = 'recycleadmin'

-- Every kind of place. Admins put them down in game with /recycleadmin.
-- Kinds with `models` are not placed: every prop with one of those models gets the option.
--   mode        gather: do an action and roll the yield. craft: pick a recipe. sell: sell to a buyer.
--   yield       rows of { item, min, max, chance }. pick = 'all' rolls each row, 'one' picks a single row by weight (item = false is a miss)
--   nodeCooldown seconds a spot is empty for everyone after it was worked
Config.Kinds = {
    dumpster = {
        label = 'Search the dumpster', icon = 'fa-solid fa-dumpster', mode = 'gather', duration = 6000, nodeCooldown = 900, skill = nil,
        models = { 'prop_dumpster_01a', 'prop_dumpster_02a', 'prop_dumpster_02b', 'prop_dumpster_3a', 'prop_dumpster_4a', 'prop_dumpster_4b', 'prop_cs_dumpster_01a' },
        anim = { dict = 'amb@prop_human_bum_bin@idle_b', clip = 'idle_d', flag = 49 }, pick = 'one',
        yield = {
            { item = false, chance = 30 }, { item = 'bottle', min = 1, max = 3, chance = 22 }, { item = 'can', min = 1, max = 3, chance = 22 },
            { item = 'plastic', min = 1, max = 2, chance = 8 }, { item = 'metalscrap', min = 1, max = 2, chance = 8 },
            { item = 'glass', min = 1, max = 2, chance = 5 }, { item = 'rubber', min = 1, max = 1, chance = 5 },
        },
    },
    scrap = {
        label = 'Search the scrap', icon = 'fa-solid fa-car-burst', mode = 'gather', duration = 8000, nodeCooldown = 600,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }, pick = 'one', skill = { 'easy' },
        yield = {
            { item = false, chance = 15 }, { item = 'metalscrap', min = 1, max = 3, chance = 30 }, { item = 'steel', min = 1, max = 1, chance = 12 },
            { item = 'aluminum', min = 1, max = 2, chance = 15 }, { item = 'rubber', min = 1, max = 2, chance = 14 }, { item = 'copper', min = 1, max = 1, chance = 8 },
            { item = 'iron', min = 1, max = 1, chance = 6 },
        },
    },
    sort = {
        label = 'Work the sorting line', icon = 'fa-solid fa-recycle', mode = 'gather', duration = 10000, nodeCooldown = 15, playerCooldown = 0,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 }, pick = 'all', skill = { 'easy' },
        yield = { { item = 'recyclablematerial', min = 2, max = 4, chance = 100 } },
    },
    trader = {
        label = 'Trade materials', icon = 'fa-solid fa-right-left', mode = 'craft', duration = 4000,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 49 },
        recipes = {
            { label = 'Plastic', takes = { recyclablematerial = 6 }, gives = { plastic = 4 } },
            { label = 'Glass', takes = { recyclablematerial = 6 }, gives = { glass = 4 } },
            { label = 'Rubber', takes = { recyclablematerial = 8 }, gives = { rubber = 3 } },
            { label = 'Aluminium', takes = { recyclablematerial = 8 }, gives = { aluminum = 3 } },
            { label = 'Metal scrap', takes = { recyclablematerial = 5 }, gives = { metalscrap = 4 } },
            { label = 'Copper', takes = { recyclablematerial = 12 }, gives = { copper = 2 } },
            { label = 'Iron', takes = { recyclablematerial = 12 }, gives = { iron = 2 } },
            { label = 'Steel', takes = { recyclablematerial = 16 }, gives = { steel = 2 } },
        },
    },
    buyer = {
        label = 'Sell materials', icon = 'fa-solid fa-sack-dollar', mode = 'sell',
        prices = {
            recyclablematerial = 3, metalscrap = 8, copper = 30, iron = 28, steel = 45, aluminum = 22, glass = 10, plastic = 9, rubber = 12,
        },
    },
    bottlebank = {
        label = 'Bottle bank', icon = 'fa-solid fa-wine-bottle', mode = 'sell',
        prices = { bottle = 3, can = 2 },
    },
}
