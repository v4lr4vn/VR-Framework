Config = {}

Config.Job = 'cardealer'
Config.DefaultGarage = 'alta'

Config.SelfService = {
    mode = 'offline',
    markupPercent = 0,
    societyPercent = 10,
}

Config.Sales = {
    commissionPercent = 10,
    societyPercent = 25,
    maxMarkupPercent = 25,
    discountByGrade = { [0] = 0, [1] = 5, [2] = 10, [3] = 15 },
    displayGrade = 2,
    offerSeconds = 60,
    offerDistance = 6.0,
}

Config.TestDrive = {
    seconds = 120,
    cooldownSeconds = 60,
    maxDistance = 2500.0,
    leaveSeconds = 1,
}

Config.Colors = {
    { id = 0, label = 'Black', hex = '#0D1116' },
    { id = 111, label = 'White', hex = '#F2F2EE' },
    { id = 4, label = 'Silver', hex = '#9CA1A6' },
    { id = 6, label = 'Graphite', hex = '#4C5157' },
    { id = 27, label = 'Red', hex = '#B6111B' },
    { id = 38, label = 'Orange', hex = '#F78616' },
    { id = 88, label = 'Yellow', hex = '#F5D21A' },
    { id = 55, label = 'Lime', hex = '#66B81F' },
    { id = 49, label = 'Racing Green', hex = '#16362A' },
    { id = 70, label = 'Ultra Blue', hex = '#1B6BD8' },
    { id = 64, label = 'Navy', hex = '#22314F' },
    { id = 145, label = 'Purple', hex = '#62129A' },
    { id = 137, label = 'Pink', hex = '#DF5891' },
    { id = 96, label = 'Brown', hex = '#4E3424' },
}

Config.Categories = {
    compacts = 'Compacts', sedans = 'Sedans', suvs = 'SUVs', coupes = 'Coupes', muscle = 'Muscle', sportsclassics = 'Sports Classics',
    sports = 'Sports', super = 'Super', motorcycles = 'Motorcycles', offroad = 'Off-road', vans = 'Vans', cycles = 'Bicycles',
    commercial = 'Commercial', industrial = 'Industrial', utility = 'Utility', service = 'Service', boats = 'Boats',
    helicopters = 'Helicopters', planes = 'Planes', openwheel = 'Open Wheel',
}

Config.Dealers = {
    pdm = {
        label = 'Premium Deluxe Motorsport',
        shop = 'pdm',
        center = vec3(-45.6, -1098.3, 26.4),
        radius = 26.0,
        kiosk = vec3(-45.67, -1098.34, 26.42),
        delivery = vec4(-56.79, -1109.85, 26.43, 71.5),
        testDrive = vec4(-56.79, -1109.85, 26.43, 71.5),
        returnPoint = vec3(-44.74, -1082.58, 26.68),
        preview = vec4(-44.5, -1097.6, 25.44, 160.0),
        garage = 'alta',
        blip = { sprite = 326, colour = 3 },
        display = {
            { coords = vec4(-45.65, -1093.66, 25.44, 69.5), model = 'adder' },
            { coords = vec4(-48.27, -1101.86, 25.44, 294.5), model = 'schafter2' },
            { coords = vec4(-39.60, -1096.01, 25.44, 66.5), model = 'comet2' },
            { coords = vec4(-51.21, -1096.77, 25.44, 254.5), model = 'vigero' },
            { coords = vec4(-40.18, -1104.13, 25.44, 338.5), model = 't20' },
            { coords = vec4(-43.31, -1099.02, 25.44, 52.5), model = 'bati' },
            { coords = vec4(-50.66, -1093.05, 25.44, 222.5), model = 'italigtb' },
            { coords = vec4(-44.28, -1102.47, 25.44, 298.5), model = 'nero' },
        },
    },
    luxury = {
        label = 'Luxury Autos',
        shop = 'luxury',
        center = vec3(-1255.6, -361.16, 36.91),
        radius = 22.0,
        kiosk = vec3(-1255.6, -361.16, 36.91),
        delivery = vec4(-1231.46, -349.86, 37.33, 26.61),
        testDrive = vec4(-1231.46, -349.86, 37.33, 26.61),
        returnPoint = vec3(-1252.0, -357.0, 36.9),
        preview = vec4(-1231.46, -349.86, 37.33, 26.61),
        garage = 'alta',
        blip = { sprite = 326, colour = 5 },
        display = {},
    },
    boats = {
        label = 'Puerto del Sol Marine',
        shop = 'boats',
        center = vec3(-738.25, -1334.38, 1.6),
        radius = 25.0,
        kiosk = vec3(-738.25, -1334.38, 1.6),
        delivery = vec4(-727.87, -1353.10, -0.17, 137.09),
        testDrive = vec4(-727.87, -1353.10, -0.17, 137.09),
        returnPoint = vec3(-738.25, -1334.38, 1.6),
        preview = vec4(-727.87, -1353.10, -0.17, 137.09),
        garage = 'lsymc',
        blip = { sprite = 410, colour = 3 },
        display = {},
    },
    air = {
        label = 'Elitas Aircraft Sales',
        shop = 'air',
        center = vec3(-1652.76, -3143.40, 13.99),
        radius = 30.0,
        kiosk = vec3(-1652.76, -3143.40, 13.99),
        delivery = vec4(-1713.02, -3110.55, 15.00, 240.0),
        testDrive = vec4(-1713.02, -3110.55, 15.00, 240.0),
        returnPoint = vec3(-1652.76, -3143.40, 13.99),
        preview = vec4(-1713.02, -3110.55, 15.00, 240.0),
        garage = 'lsia_hangar',
        blip = { sprite = 251, colour = 3 },
        display = {},
    },
    truck = {
        label = 'Commercial Vehicles',
        shop = 'truck',
        center = vec3(900.47, -1155.74, 25.16),
        radius = 25.0,
        kiosk = vec3(900.47, -1155.74, 25.16),
        delivery = vec4(909.67, -1181.79, 25.55, 177.67),
        testDrive = vec4(909.67, -1181.79, 25.55, 177.67),
        returnPoint = vec3(900.47, -1155.74, 25.16),
        preview = vec4(909.67, -1181.79, 25.55, 177.67),
        garage = 'alta',
        blip = { sprite = 477, colour = 3 },
        display = {},
    },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-dealership'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
