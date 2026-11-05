Config = {}

Config.Admin = {
    command = 'fencecreator',
}

Config.Account = 'cash'

Config.DirtyItem = 'black_money'

Config.Reach = 4.0

Config.Launder = {
    rate = 0.7,
    min = 500,
    maxPerDeal = 25000,
    maxPerWindow = 75000,
    windowMinutes = 60,
    -- You hand the money over, then come back for the clean cash.
    handoverSeconds = 3.0,
    minutesBase = 2,
    minutesPer1000 = 1.5,
    minutesMax = 30,
    maxOpen = 3,
    minFraction = 0.8,
    animDict = 'mp_common',
    animClip = 'givetake1_a',
}

Config.Pawn = {
    rate = 1.0,
    minGapMs = 700,
    items = {
        gold_bar = 1200,
        goldingot = 800,
        silveringot = 300,
        gold_ring = 180,
        goldchain = 250,
        goldearring = 150,
        silver_ring = 70,
        silverchain = 90,
        silverearring = 60,
        diamond_ring = 900,
        diamond_ring_silver = 750,
        diamond_necklace = 1400,
        diamond_necklace_silver = 1150,
        diamond_earring = 700,
        diamond_earring_silver = 580,
        ruby_ring = 600,
        ruby_ring_silver = 500,
        ruby_necklace = 950,
        ruby_necklace_silver = 800,
        ruby_earring = 450,
        ruby_earring_silver = 380,
        emerald_ring = 620,
        emerald_ring_silver = 520,
        emerald_necklace = 980,
        emerald_necklace_silver = 820,
        emerald_earring = 470,
        emerald_earring_silver = 400,
        sapphire_ring = 640,
        sapphire_ring_silver = 540,
        sapphire_necklace = 1000,
        sapphire_necklace_silver = 850,
        sapphire_earring = 480,
        sapphire_earring_silver = 410,
    },
}

Config.Ped = {
    launder = 'a_m_m_business_01',
    pawn = 'a_m_o_soucent_02',
    streamDistance = 60.0,
}

Config.Blips = {
    launder = false,
    pawn = true,
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-fence'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
