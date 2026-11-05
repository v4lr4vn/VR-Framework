Config = {}

-- Part of the ValRavn framework. A renamed copy of this resource does not run.
do
    local expected = 'vr-prison'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end

-- Who may place things and save the outfit. Admins (the framework's admin check) or anyone with the ACE command.<command>.
Config.Admin = { command = 'prisonadmin' }

-- How close a prisoner has to stand to use a station or the canteen.
Config.Interact = { distance = 2.0, radius = 1.4 }

-- Work and workouts shorten the sentence, but never by more than this share of it,
-- and the last stretch is always served. Seconds are real seconds, like the MDT's clock.
Config.Cap = { percent = 50, keepSeconds = 60 }

-- What the player sees on the canteen menu.
Config.CreditLabel = 'canteen credit'

-- Each placed station has one of these types. Add your own rows, they show up in the admin menu.
--   label      shown on the target and the progress bar
--   icon       Font Awesome name
--   duration   milliseconds of work
--   minutes    sentence removed per finished shift
--   credits    canteen credit earned per finished shift
--   cooldown   seconds before the same prisoner can use the same station again
--   skill      difficulties for the skill check at the end (nil for none)
--   anim       { scenario = '...' } or { dict = '...', clip = '...' }
Config.Stations = {
    kitchen = {
        label = 'Kitchen duty', icon = 'fa-solid fa-utensils', duration = 30000, minutes = 2, credits = 12, cooldown = 180,
        skill = { 'easy', 'easy' }, anim = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base', flag = 49 },
    },
    laundry = {
        label = 'Laundry duty', icon = 'fa-solid fa-shirt', duration = 30000, minutes = 2, credits = 10, cooldown = 180,
        skill = { 'easy' }, anim = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base', flag = 49 },
    },
    cleaning = {
        label = 'Cleaning duty', icon = 'fa-solid fa-broom', duration = 35000, minutes = 3, credits = 15, cooldown = 240,
        skill = { 'easy', 'medium' }, anim = { scenario = 'WORLD_HUMAN_JANITOR' },
    },
    workout = {
        label = 'Work out', icon = 'fa-solid fa-dumbbell', duration = 40000, minutes = 3, credits = 5, cooldown = 300,
        skill = { 'medium' }, anim = { scenario = 'world_human_muscle_free_weights' },
    },
    workshop = {
        label = 'Workshop duty', icon = 'fa-solid fa-hammer', duration = 40000, minutes = 4, credits = 20, cooldown = 300,
        skill = { 'medium', 'medium' }, anim = { scenario = 'WORLD_HUMAN_HAMMERING' },
    },
}

-- Things the canteen sells for credit. Items that do not exist in your inventory are skipped.
Config.Canteen = {
    label = 'Canteen',
    items = {
        { item = 'water',    price = 3 },
        { item = 'burger',   price = 8 },
        { item = 'sandwich', price = 6 },
        { item = 'cigarette', price = 10 },
        { item = 'coffee',   price = 4 },
    },
}

-- What a prisoner wears. Admins can save their own with /prisonadmin; this is the starting point.
-- Lists of { id, drawable, texture }. Props with drawable -1 are removed (hat, glasses).
Config.Outfits = {
    male = {
        components = {
            { id = 3, d = 0, t = 0 }, { id = 4, d = 3, t = 7 }, { id = 6, d = 12, t = 12 },
            { id = 8, d = 15, t = 0 }, { id = 11, d = 146, t = 0 },
        },
        props = { { id = 0, d = -1, t = 0 }, { id = 1, d = -1, t = 0 } },
    },
    female = {
        components = {
            { id = 3, d = 14, t = 0 }, { id = 4, d = 3, t = 15 }, { id = 6, d = 66, t = 5 },
            { id = 8, d = 3, t = 0 }, { id = 11, d = 38, t = 3 },
        },
        props = { { id = 0, d = -1, t = 0 }, { id = 1, d = -1, t = 0 } },
    },
}

-- While serving a sentence the outfit is put back on if something changes it (a relog loading the saved look, say).
Config.Outfit = { enforce = true, checkSeconds = 5, captureDelayMs = 9000 }

-- Prisoners start in a cell, picked by who has the fewest people in it. Without placed cells they stay where the MDT puts them.
Config.Cells = { enabled = true }
