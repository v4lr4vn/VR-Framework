Config = {}

Config.Admin = {
    command = 'heistcreator',
}

Config.Account = 'cash'

Config.Police = {
    enabled = true,
    jobs = { 'police' },
    onDutyOnly = true,
}

Config.Defaults = {
    minPolice = 0,
    cooldownMinutes = 60,
    maxMinutes = 30,
    alertSeconds = 25,
    radius = 120.0,
    blip = true,
}

Config.Items = {
    laptop = 'hack_laptop',
    kit = 'exploit_kit',
    drill = 'bank_drill',
    cash = 'black_money',
    gold = 'gold_bar',
}

Config.Hack = {
    provider = 'builtin',
    seconds = { 330, 290, 250, 215, 180 },
    traceRate = { 0.10, 0.14, 0.18, 0.24, 0.30 },
    wordlists = { 4, 5, 6, 6, 7 },
    decoys = { 1, 2, 2, 3, 4 },
    needToken = { false, false, true, true, true },
    needDeepScan = { false, false, true, true, true },
    consumeKitFromTier = 4,
    wipeDelayBonus = 60,
    failCooldownSeconds = 90,
    failTraceCut = 100,
}

Config.Drill = {
    breakChanceOnJam = 25,
    minFraction = 0.5,
    animDict = 'anim@heists@fleeca_bank@drilling',
    animClip = 'drill_straight_idle',
    model = 'hei_prop_heist_drill',
}

Config.Grab = {
    seconds = 3.2,
    minGapMs = 2200,
    cash = { model = 'prop_cash_pile_01', animDict = 'anim@heists@ornate_bank@grab_cash', animClip = 'grab', bagModel = 'hei_p_m_bag_var22_arm_s' },
    gold = { model = 'ch_prop_gold_bar_01a', animDict = 'anim@heists@ornate_bank@grab_cash', animClip = 'grab' },
}

Config.Till = {
    animDict = 'oddjobs@shop_robbery@rob_till',
    animClip = 'loop',
    fallbackDict = 'anim@heists@ornate_bank@grab_cash',
    fallbackClip = 'grab',
    minFraction = 0.6,
}

Config.Case = {
    dict = 'missheist_jewel',
    clips = {
        necklace = 'smash_case_necklace',
        tray_a = 'smash_case_tray_a',
        tray_b = 'smash_case_tray_b',
        d = 'smash_case_d',
        e = 'smash_case_e',
        f = 'smash_case_f',
        b = 'smash_case_b',
        c = 'smash_case_c',
        skull = 'smash_case_necklace_skull',
        plain = 'smash_case',
    },
    needWeapon = true,
    hitAt = 0.3,
    minSeconds = 2.0,
    ptfxAsset = 'scr_jewelheist',
    ptfx = 'scr_jewel_cab_smash',
    findRadius = 1.5,
    swaps = {
        { 'des_jewel_cab_start', 'des_jewel_cab_end' },
        { 'des_jewel_cab2_start', 'des_jewel_cab2_end' },
        { 'des_jewel_cab3_start', 'des_jewel_cab3_end' },
        { 'des_jewel_cab4_start', 'des_jewel_cab4_end' },
    },
}

Config.Interact = {
    extraRange = 4.0,
}

Config.Vault = {
    rate = 0.6,
}

Config.RelockSeconds = 45

Config.ClearCooldownsOnStart = false

Config.Blips = true

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-bankheist'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
