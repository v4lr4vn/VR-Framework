Config.Jobs.newspaper = {
    label = 'Paper Round',
    job = 'newspaper',
    icon = 'fa-newspaper',
    description = 'Take a bike, deliver the morning paper to every mailbox on your round',
    depot = {
        ped = 'a_m_y_stbla_01',
        coords = vec4(368.3, -374.1, 46.4, 340.0),
        blip = { sprite = 280, colour = 3, scale = 0.8, label = 'Newspaper Depot' },
    },
    vehicle = {
        model = 'bmx',
        coords = vec4(372.0, -371.0, 46.4, 340.0),
        returnRadius = 30.0,
    },
    mailboxModel = 'prop_postbox_01a',
    paperModel = 'prop_cs_newspaper',
    throwRange = 14.0,
    pricePerPaper = 20,
    xpPerPaper = 10,
    routes = {
        {
            id = 'easy', label = 'Easy round', level = 1, pay = 200, xp = 300,
            stops = { vec3(341.0, -283.0, 54.1), vec3(321.0, -267.0, 54.1), vec3(284.0, -247.0, 53.9), vec3(259.0, -263.0, 53.9), vec3(227.0, -279.0, 53.8), vec3(200.0, -268.0, 54.0) },
        },
        {
            id = 'hills', label = 'Hills round', level = 3, pay = 380, xp = 500,
            stops = { vec3(-175.0, 497.0, 137.0), vec3(-190.0, 424.0, 111.0), vec3(-231.0, 417.0, 111.0), vec3(-312.0, 474.0, 111.0), vec3(-354.0, 515.0, 120.0), vec3(-445.0, 534.0, 121.0), vec3(-497.0, 551.0, 120.6) },
        },
        {
            id = 'restaurants', label = 'Restaurants round', level = 1, pay = 700, xp = 1500, daily = true,
            stops = { vec3(127.0, -1030.0, 29.3), vec3(-49.0, -1081.0, 26.7), vec3(-183.0, -1163.0, 23.0), vec3(-322.0, -1280.0, 31.0), vec3(-457.0, -1185.0, 25.0), vec3(-590.0, -1089.0, 22.3), vec3(-662.0, -937.0, 21.8), vec3(-540.0, -885.0, 25.0) },
        },
    },
}
