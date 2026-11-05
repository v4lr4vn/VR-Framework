Config = {}

Config.Items = { pack = 'card_pack', card = 'tcg_card', binder = 'card_binder' }

Config.Shop = {
    label = 'ValRavn Cards & Collectibles',
    coords = vec4(195.17, -934.14, 30.69, 145.0),
    radius = 3.0,
    ped = 'a_m_y_hipster_01',
    blip = { sprite = 52, colour = 27, scale = 0.7 },
}

Config.DefaultPack = 'origins'

Config.Packs = {
    origins = { label = 'ValRavn Origins Booster', set = 'evo', price = 750, slots = { 'common', 'common', 'common', 'uncommon', 'hit' } },
}

Config.SlotOdds = {
    common = { common = 80, uncommon = 17, rare = 3 },
    uncommon = { uncommon = 80, rare = 16, epic = 4 },
    hit = { rare = 76, epic = 19, legendary = 5 },
}

Config.Rarities = {
    common = { label = 'Common', order = 1, color = '#AAB4C0', sell = 25 },
    uncommon = { label = 'Uncommon', order = 2, color = '#3DD68C', sell = 60 },
    rare = { label = 'Rare', order = 3, color = '#5AA9FF', sell = 200 },
    epic = { label = 'Epic', order = 4, color = '#B79CFF', sell = 750 },
    legendary = { label = 'Legendary', order = 5, color = '#F5A524', sell = 3000 },
}

Config.Foils = {
    holo = { common = 2, uncommon = 4, rare = 10, epic = 18, legendary = 30 },
    shiny = { common = 8, uncommon = 10, rare = 15, epic = 20, legendary = 25 },
    labels = { none = 'Standard', shiny = 'Shiny', holo = 'Holo foil' },
    sell = { none = 1.0, shiny = 1.6, holo = 3.0 },
}

Config.Groups = {
    dev = { label = 'Development', icon = 'code', color = '#5AA9FF' },
    staff = { label = 'Staff', icon = 'shield-halved', color = '#FF6F91' },
    community = { label = 'Community', icon = 'people-group', color = '#3DD68C' },
}

Config.Binder = { price = 1500, pages = 20, perPage = 9, titleLength = 32 }

Config.Sell = { enabled = true, maxPerSale = 25 }

Config.Grading = {
    company = 'EGC',
    companyName = 'ValRavn Grading Co.',
    maxPerSubmit = 10,
    tiers = {
        standard = { label = 'Standard', fee = 250, minutes = 30 },
        express = { label = 'Express', fee = 1000, minutes = 5 },
    },
    subgrades = { [10] = 28, [9] = 34, [8] = 20, [7] = 9, [6] = 4, [5] = 2, [4] = 1.2, [3] = 0.8, [2] = 0.6, [1] = 0.4 },
    names = { [10] = 'Gem Mint', [9] = 'Mint', [8] = 'NM-MT', [7] = 'Near Mint', [6] = 'EX-MT', [5] = 'Excellent', [4] = 'VG-EX', [3] = 'Very Good', [2] = 'Good', [1] = 'Poor' },
    sell = { [10] = 8.0, [9] = 3.0, [8] = 1.8, [7] = 1.3, [6] = 1.1, [5] = 1.0, [4] = 0.9, [3] = 0.8, [2] = 0.7, [1] = 0.6 },
}

Config.Sound = { volume = 0.6 }

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-cards'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
