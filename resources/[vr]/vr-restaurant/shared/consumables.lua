Config = Config or {}

Config.Consumables = {
    burger        = { type = 'food', emote = 'burger', time = { 4000, 5000 }, hunger = { 18, 24 }, canRun = true },
    sandwich      = { type = 'food', emote = 'sandwich', time = { 5000, 6000 }, hunger = 20 },
    tosti         = { type = 'food', emote = 'sandwich', time = { 5000, 6000 }, hunger = { 10, 15 }, stress = { 2, 4 } },
    twerks_candy  = { type = 'food', emote = 'egobar', time = { 3000, 4000 }, hunger = { 10, 15 }, canRun = true },
    snikkel_candy = { type = 'food', emote = 'egobar', time = { 3000, 4000 }, hunger = { 10, 15 }, canRun = true },
    mustard       = { type = 'drink', emote = 'drink', time = 2500, hunger = 3, thirst = 3 },

    water         = { type = 'drink', emote = 'drink', time = { 4000, 5000 }, thirst = { 18, 24 }, canRun = true },
    water_bottle  = { type = 'drink', emote = 'drink', time = { 4000, 5000 }, thirst = 20, canRun = true },
    sprunk        = { type = 'drink', emote = 'sprunk', time = { 4000, 5000 }, thirst = { 15, 20 }, stress = { 1, 2 }, canRun = true },
    kurkakola     = { type = 'drink', emote = 'ecola', time = { 4000, 5000 }, thirst = { 10, 20 }, stress = { 2, 4 } },
    coffee        = { type = 'drink', emote = 'coffee', time = { 5000, 6000 }, thirst = { 10, 15 },
                      effect = { name = 'stamina', time = 30000 } },

    beer          = { type = 'alcohol', emote = 'beer', time = { 5000, 6000 }, thirst = { 10, 20 }, stress = { 2, 4 }, canOD = true },
    whiskey       = { type = 'alcohol', emote = 'whiskey', time = { 5000, 6000 }, thirst = { 10, 20 }, stress = { 2, 4 }, canOD = true },
    vodka         = { type = 'alcohol', emote = 'vodkab', time = { 5000, 6000 }, thirst = { 10, 20 }, stress = { 8, 12 }, canOD = true },
}
