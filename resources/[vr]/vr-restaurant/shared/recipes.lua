-- Prep steps. These turn one ingredient into another, at a crafting area of the kind named by
-- `station`. They do not make finished dishes: every dish on a menu is designed by the business
-- (staff office, Menu and dishes) out of ingredients, including the ones made here.
--   needs  what is used from the fridges
--   out    the ingredient that comes out, `count` of it, into your pockets (put it in a fridge)
--   ms     how long it takes

Config.Recipes = {
    cut_potatoes = { label = 'Cut potatoes',        station = 'prep', needs = { potato = 1 },      out = 'potato_cut',       count = 2, ms = 4000 },
    grind_boar   = { label = 'Grind boar meat',     station = 'prep', needs = { meat_boar = 1 },   out = 'ground_meat',      count = 2, ms = 5000 },
    grind_deer   = { label = 'Grind venison',       station = 'prep', needs = { meat_deer = 1 },   out = 'ground_meat',      count = 2, ms = 5000 },
    grind_coyote = { label = 'Grind coyote meat',   station = 'prep', needs = { meat_coyote = 1 },  out = 'ground_meat',     count = 2, ms = 5000 },
    grind_rabbit = { label = 'Grind rabbit meat',   station = 'prep', needs = { meat_rabbit = 1 },  out = 'ground_meat',     count = 2, ms = 5000 },
    slice_tomato = { label = 'Slice tomatoes',      station = 'prep', needs = { tomato = 1 },      out = 'tomato_sliced',    count = 3, ms = 3000 },
    shred_lettuce = { label = 'Shred lettuce',      station = 'prep', needs = { lettuce = 1 },     out = 'lettuce_shredded', count = 3, ms = 3000 },
    chop_onion   = { label = 'Chop onions',         station = 'prep', needs = { onion = 1 },       out = 'onion_chopped',    count = 3, ms = 3000 },
}

-- Handy dishes an owner can add to their own menu with one click (staff office, Menu and dishes,
-- Our dishes, Add starter dishes). They become the business's own dishes and can be edited or
-- deleted like any other.
Config.Starters = {
    { label = 'Burger',   station = 'grill',     items = { bread_bun = 1, ground_meat = 1, lettuce_shredded = 1, tomato_sliced = 1, cheese = 1 } },
    { label = 'Fries',    station = 'fryer',     items = { potato_cut = 2, cooking_oil = 1 } },
    { label = 'Sandwich', station = 'prep',      items = { bread_loaf = 1, cheese = 1, lettuce_shredded = 1, tomato_sliced = 1 } },
    { label = 'Tosti',    station = 'grill',     items = { bread_loaf = 1, cheese = 1, butter = 1 } },
    { label = 'Water',    station = 'dispenser', items = { water = 1 } },
    { label = 'Soda',     station = 'dispenser', items = { soda_syrup = 1, water = 1 } },
    { label = 'Cola',     station = 'dispenser', items = { cola_syrup = 1, water = 1 } },
    { label = 'Coffee',   station = 'bar',       items = { coffee_beans = 1, water = 1 } },
}

-- Dishes an owner designs are named dN (N is the dish id).
function Config.IsDishKey(key)
    return type(key) == 'string' and key:match('^d%d+$') ~= nil
end
