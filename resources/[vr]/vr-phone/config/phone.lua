Config = Config or {}

Config.Phone = {
    -- Key that takes the phone out and puts it away. Players can rebind it in the FiveM key settings.
    OpenKey = 'F1',

    -- The phone must be an inventory item. Set RequireItem = false to give everyone a phone.
    RequireItem = true,
    ItemName = 'phone',
    -- Name of the item metadata field that holds the phone's unique ID.
    MetadataKey = 'phoneId',

    -- What the phone looks like when it is taken out: 'cover', 'flex' or 'open'.
    DefaultFoldState = 'cover',
    -- Let the player walk while the phone is out. Typing in a text box pauses movement.
    KeepInput = true,
    -- While the phone is out, the mouse moves the cursor on the phone instead of turning the camera.
    LockLook = true,

    -- Turn fold states off if you do not want them.
    Fold = { cover = true, flex = true, splitScreen = true, appContinuity = true },

    -- Which clock the phone shows on the status bar, lock screen, home screen and Clock app:
    --   'pc'   the time on the player's own computer (their real local time)
    --   'game' the in-game clock
    -- Players can change it in Settings > Display. Reminders, Calendar and Weather always use the game clock.
    TimeSource = 'pc',

    Theme = { accent = '#7a5cff', darkMode = false, scale = 0.85 },
    -- Battery. Rates are percent per minute. The server keeps the level, so players cannot change it.
    Battery = {
        enabled = true,
        startLevel = 100,         -- a brand new phone
        lowPowerThreshold = 20,   -- Low Power Mode switches on by itself here (players can turn it off)
        bootLevel = 2,            -- a dead phone needs this much charge before it switches on again
        drain = {
            idle = 0.05,          -- phone in your pocket
            screen = 0.30,        -- extra while the screen is in use
            bluetooth = 0.02,     -- extra while Bluetooth is on
            searching = 1.6,      -- idle drain is multiplied by this when there is no signal
            airplane = 0.7,       -- ... and by this in airplane mode
            lowPower = 0.5,       -- ... and by this in Low Power Mode
            -- Extra drain while an app is open (percent per minute). Apps not listed use no extra.
            apps = { camera = 0.6, maps = 0.5, music = 0.2, watch = 0.5, pulse = 0.5, lens = 0.3, phone = 0.15 },
        },
        -- Ways to charge, in percent per minute. The best one counts (they do not add up).
        charge = {
            vehicle = 1.0,        -- sitting in a vehicle with the engine running (a USB port). 0 = off
            indoors = 1.5,        -- inside any building (an interior): there is a socket on the wall. 0 = off
            home = 3.0,           -- inside a property from vr-housing (it has a proper charger). 0 = off
            -- Charging points. Add your own, or let other scripts call exports['vr-phone']:SetCharging().
            -- { coords = vector3(0.0, 0.0, 0.0), radius = 2.0, rate = 4.0 },
            points = {},
            -- A power bank is an inventory item (add it to your shops). Using it charges the phone at once and uses it up.
            powerbank = { item = 'powerbank', amount = 40, seconds = 5, cooldownSeconds = 20 },
        },
    },

    -- Signal. Zones are in config/signal.lua.
    Signal = {
        enabled = true,
        defaultLevel = 'full',    -- 'full', 'low' or 'none' outside every zone
        carrier = 'Raven Mobile', -- name of the built-in provider, shown in Settings
    },

    -- How often the server checks signal, charging and battery for players (seconds).
    StatusSeconds = 10,
    Calls = {
        ringTimeoutMs = 20000,       -- how long it rings before it counts as missed
        voicemail = true,            -- the caller can leave a typed message when nobody picks up
        voicemailSeconds = 60,       -- how long the caller has to leave it
        voice = 'vr-voice',          -- the voice script that carries the call audio (pma-voice works too). Calls still work without it, only silent.
        channelBase = 50000,         -- call channel numbers start here, so they never clash with radio channels
        lowSignalDropChance = 0.10,  -- chance per status check (StatusSeconds) that a call on weak signal drops
        answerKey = 'Y',             -- key to answer a call when the phone is away (players can rebind it in the game settings)
        hangupKey = 'U',             -- key to decline or hang up
    },
    Messages = {
        maxLength = 500,             -- characters in one message
        perMinute = 20,              -- messages one phone can send in a minute
        keepPerThread = 300,         -- older messages in a conversation are deleted
        -- Not used yet. Sending money and GIFs in messages come in a later step.
        paymentAccount = 'money',
        gifProvider = '',
        gifApiKey = '',
    },
    Contacts = { max = 500 },

    -- Photos. The screen shrinks every photo before it is saved, so a photo is small (roughly 60 to 120 KB).
    Media = {
        maxPhotos = 120,            -- per phone, counting the ones in Recently deleted
        maxBytes = 450000,          -- the biggest photo the server accepts (as text)
        maxThumbBytes = 30000,      -- ... and its thumbnail
        maxWidth = 960,             -- photos are shrunk to this width on the screen
        quality = 0.72,             -- JPEG quality, 0.3 to 0.95
        thumbWidth = 200,
        pageSize = 24,              -- photos per "Load more" in the Gallery
        keepDeletedDays = 30,       -- Recently deleted is emptied after this many days
        cooldownSeconds = 2,        -- least time between two photos from one phone
        timerSeconds = { 3, 10 },   -- the camera timer choices
        -- The front (selfie) camera. distance: metres from the face. aimHeight: where the camera points, in metres above (+) or below (-)
        -- the head bone: lower it to move the face UP the screen, raise it to move the face down. startPitch: degrees above eye level.
        selfie = { distance = 0.62, aimHeight = -0.06, startPitch = 3.0 },
        -- The camera takes pictures with the screenshot-basic resource (the game's picture, without the phone).
        screenshotResource = 'screenshot-basic',
        -- Optional picture host. Give a function that takes (source, dataUri) and returns a link (https://...), and only the
        -- link is saved. Return nil to keep the photo in the database. Leave it nil to always use the database.
        upload = nil,
    },

    -- Nearby share (contacts and photos to a player standing close by).
    Share = {
        range = 10.0,               -- metres
        timeoutSeconds = 60,        -- how long the other player has to answer
        maxItems = 20,              -- photos or contacts in one share
        requireBluetooth = true,    -- both phones need Bluetooth on
    },

    -- Notes, Reminders and Calendar.
    Notes = { max = 100, titleLength = 80, bodyLength = 4000 },
    Planner = {
        maxReminders = 200,
        maxEvents = 300,
        remindChoices = { 0, 5, 15, 30, 60, 1440 },  -- "alert me" choices for a calendar event, in minutes before
        defaultAlertMinute = 540,                    -- a reminder or all-day event with a date but no time alerts at 09:00 game time
    },

    -- Weather. The game has no temperatures, so the phone works one out from the weather and the hour. These are degrees Celsius.
    Weather = {
        place = 'Los Santos',        -- the name at the top of the Weather app
        fahrenheit = false,          -- the starting unit (players can switch in the app)
        base = { clear = 21, cloud = 17, rain = 13, storm = 12, fog = 11, snow = -1 },
        daySwing = 5,                -- how much warmer the afternoon is than the early morning
    },

    -- Mail (name@ravenmail.io).
    Mail = {
        domain = 'ravenmail.io',
        maxPerFolder = 300,          -- messages in the inbox (and in sent) before the oldest are deleted
        subjectLength = 100,
        bodyLength = 4000,
        perMinute = 6,               -- messages one phone can send in a minute
        keepTrashDays = 30,
        pageSize = 30,
        -- Addresses nobody can register (checked before the name is taken).
        reserved = { 'admin', 'administrator', 'support', 'noreply', 'no-reply', 'postmaster', 'system', 'staff', 'ravenmail', 'police', 'ems', 'news', 'help', 'mail' },
    },

    -- Wallet. Money moves between bank accounts, by phone number. Amounts are whole dollars.
    Wallet = {
        minSend = 1,
        maxSend = 25000,            -- most one transfer or request can be
        dailyLimit = 50000,         -- most one phone can send in 24 hours
        noteLength = 60,
        historyLimit = 40,          -- transfers shown in the app
        bankHistory = 30,           -- lines of bank activity shown (when vr-banking is running)
        recents = 6,                -- numbers offered as quick picks
        maxOpenRequests = 10,       -- requests one phone can have waiting
        requestHours = 48,          -- an unpaid request closes after this long
        cooldownSeconds = 3,        -- between two transfers from one phone
    },

    -- Maps. The game map cannot be drawn on the phone, so the app has its own radar-style map with a grid, the places below
    -- and the player's own position, drawn over the same road map the MDT uses (html/tiles, copied from vr-mdt).
    Maps = {
        maxPlaces = 50,             -- saved places per phone
        nameLength = 40,
        range = 250.0,              -- metres from you at the closest zoom level (the map zooms out from here)
        -- The map pictures (html/tiles/{zoom}/{x}/{y}.jpg, zoom 0 to 5) and how they line up with the game world. These are the
        -- same numbers as Config.Map in vr-mdt. Set `tiles = false` for the plain grid instead.
        tiles = { path = 'tiles', size = 8192, maxZoom = 5, originX = 3753.6, originY = 5529.6, scaleX = 0.66304, scaleY = -0.656 },
        -- Places everyone can find in the app (the positions are close, not exact. Stand where you want one and copy your coordinates). category: 'services', 'shops', 'travel', 'places'. icon: see the Maps app.
        places = {
            { label = 'Central Hospital',  category = 'services', icon = 'cross',   x = 298.0,   y = -584.0,  z = 43.0 },
            { label = 'Central Police Station',     category = 'services', icon = 'shield',  x = 441.0,   y = -982.0,  z = 30.0 },
            { label = 'Sandy Shores Sheriff',   category = 'services', icon = 'shield',  x = 1853.0,  y = 3687.0,  z = 34.0 },
            { label = 'Paleto Bay Sheriff',     category = 'services', icon = 'shield',  x = -447.0,  y = 6012.0,  z = 31.0 },
            { label = 'Bank, Legion Square', category = 'services', icon = 'bank',    x = 149.0,   y = -1040.0, z = 29.0 },
            { label = 'City Hall',              category = 'services', icon = 'pin',     x = -544.0,  y = -204.0,  z = 38.0 },
            { label = 'Legion Square',          category = 'places',   icon = 'pin',     x = 195.0,   y = -934.0,  z = 30.0 },
            { label = 'Vinewood Boulevard',     category = 'places',   icon = 'pin',     x = 300.0,   y = 190.0,   z = 104.0 },
            { label = 'Vespucci Beach',         category = 'places',   icon = 'pin',     x = -1305.0, y = -1520.0, z = 4.0 },
            { label = 'Del Perro Pier',         category = 'places',   icon = 'pin',     x = -1850.0, y = -1230.0, z = 13.0 },
            { label = 'Mirror Park',            category = 'places',   icon = 'pin',     x = 1060.0,  y = -690.0,  z = 57.0 },
            { label = 'Sandy Shores',           category = 'places',   icon = 'pin',     x = 1860.0,  y = 3720.0,  z = 33.0 },
            { label = 'Paleto Bay',             category = 'places',   icon = 'pin',     x = -150.0,  y = 6290.0,  z = 31.0 },
            { label = 'International Airport',     category = 'travel',   icon = 'plane',   x = -1037.0, y = -2737.0, z = 20.0 },
            { label = 'Harbour Docks',     category = 'travel',   icon = 'anchor',  x = 1000.0,  y = -2960.0, z = 6.0 },
            { label = 'Truck Stop, Alamo Sea',   category = 'travel',   icon = 'fuel',    x = 1700.0,  y = 4920.0,  z = 42.0 },
            { label = 'Gun Store, Pillbox Hill',   category = 'shops',    icon = 'bag',     x = 22.0,    y = -1107.0, z = 29.0 },
            { label = 'Customs Garage, Burton',     category = 'shops',    icon = 'wrench',  x = -365.0,  y = -131.0,  z = 38.0 },
            { label = 'Corner Store, Strawberry',       category = 'shops',    icon = 'bag',     x = 25.0,    y = -1347.0, z = 29.0 },
            { label = 'Roadside Diner, Route 68',           category = 'shops',    icon = 'food',    x = 2540.0,  y = 2590.0,  z = 37.0 },
        },
    },

    -- Health. Steps are counted from the player's own walking and running while they hold the phone. Heart rate is an estimate.
    Health = {
        stepGoal = 8000,            -- the starting daily goal (players can change it in the app)
        goalRange = { 1000, 40000 },
        walkStride = 0.75,          -- metres per step walking
        runStride = 1.1,            -- metres per step running or sprinting
        kcalPerStep = 0.045,
        maxStepsPerSecond = 4.0,    -- the server drops anything faster than this (no one runs that fast)
        reportSeconds = 10,         -- how often the game reports movement
        keepDays = 60,              -- days of history kept
        restingRate = 64,           -- beats per minute at rest
    },

    -- Music. Players paste a YouTube link; the song plays on their phone and, with the speaker on, nearby players hear it too.
    -- The sound is played by each listener's own game through YouTube's embedded player (no audio is copied or stored).
    Music = {
        range = 8.0,                -- metres the speaker carries by default
        rangeChoices = { 5.0, 8.0, 10.0 }, -- what players can pick in the app
        volume = 60,                -- the starting volume (0 to 100)
        maxLibrary = 100,           -- saved songs per phone
        maxQueue = 30,
        titleLength = 120,
        needService = true,         -- streaming needs signal: with none (or airplane mode) the music stops
        maxPlayers = 3,             -- the most phones one player hears at once (the nearest ones)
        -- Where the YouTube player page comes from. YouTube refuses to play for a page with no web address, so the default
        -- 'auto' serves the page from this server's own web address (https://<your cfx domain>/vr-phone/player, or http://ip:port).
        -- If the music shows "error 153" or never starts, put the file html/player.html on any web page you own and put its
        -- address here, e.g. 'https://example.com/player.html'. 'nui' loads it from the phone itself (works only if YouTube allows it).
        player = 'auto',
    },

    -- Veil: anonymous chat. Players pick an alias (no name, no number is ever shown), join rooms and message other aliases.
    Veil = {
        needService = true,
        -- Rooms that always exist. Players can make their own too (a room with a password is not listed: people join it by name and password).
        rooms = {
            { name = 'lobby', topic = 'Say hello.' },
            { name = 'market', topic = 'Buy and sell. No questions.' },
            { name = 'work', topic = 'Jobs, favours and gigs.' },
            { name = 'rumours', topic = 'You did not hear it from me.' },
        },
        aliasMin = 3, aliasMax = 16,
        aliasCooldownHours = 24,     -- how long before an alias can be changed again
        reserved = { 'admin', 'system', 'staff', 'police', 'mod', 'moderator', 'support', 'veil', 'anonymous' },
        maxMessage = 300,
        roomNameMax = 20,
        maxOwnedRooms = 2,           -- rooms one phone can make
        maxJoinedRooms = 15,
        pageSize = 40,
        keepRoomMessages = 300,      -- messages kept in each room
        keepRoomDays = 7,
        keepDmDays = 30,
        roomExpireDays = 14,         -- a player-made room with no messages for this long is deleted
    },

    -- Hearth: dating. The profile starts from the character (first name, age, gender), the rest is the player's own.
    Hearth = {
        needService = true,
        minAge = 18, maxAge = 99,
        -- true: the age comes from the character's date of birth (a character under minAge cannot sign up).
        -- false: the player types an age (minAge to maxAge). Handy for testing with a young character.
        ageFromCharacter = false,
        nameMax = 20, bioMax = 240,
        maxTags = 5, maxPhotos = 3,
        tags = { 'Music', 'Cars', 'Gym', 'Food', 'Gaming', 'Travel', 'Dogs', 'Cats', 'Movies', 'Nightlife', 'Reading', 'Cooking', 'Fishing', 'Racing', 'Art', 'Outdoors' },
        dailyLikes = 40,             -- likes one phone can give in 24 hours
        deckSize = 5,                -- profiles loaded at a time
        activeDays = 30,             -- profiles not opened for this long are not shown
        maxMessage = 300,
        pageSize = 40,
        keepMessageDays = 60,
    },

    -- Numbers for new phones. A character's own number (charinfo.phone) is used first when it is free.
    -- '#' becomes a random digit.
    Number = { format = '555-####', tries = 25 },

    Lock = {
        pinLengths = { 4, 6 },
        -- Seconds after putting the phone away before the PIN is needed again. 0 = every time.
        autoLockSeconds = 30,
        -- Wrong PIN attempts in a row -> seconds locked out. The last entry repeats.
        lockouts = { [5] = 30, [6] = 60, [7] = 300, [8] = 900 },
    },

    Home = {
        -- Apps pinned to the dock the first time a phone is set up (max 5).
        dock = { 'phone', 'messages', 'camera', 'settings' },
    },

    Wallpapers = { 'aurora', 'dusk', 'ember', 'tide', 'paper', 'night' },

    -- Ringtones players can pick in Settings. The files are yours (nothing is bundled).
    -- { id = 'classic', label = 'Classic', file = 'sounds/classic.ogg' }
    Ringtones = {},

    -- Sounds are your own audio files, so nothing is bundled. Use a path inside this resource's
    -- html folder, for example 'sounds/hinge.ogg' (add it to the manifest files list). false = silent.
    Sounds = { notify = false, hinge = false, lock = false, tap = false, ring = false, ended = false },

    Debug = false,
}
