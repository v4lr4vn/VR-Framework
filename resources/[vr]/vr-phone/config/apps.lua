Config = Config or {}

-- Built-in apps. Other scripts will add their own through the custom app API.
-- The look of each built-in app (colour and icon) lives in web/src/lib/apps.js.
-- preinstalled = true puts the app on a new phone. Others come from the App Store.
-- essential = true: the app can never be removed (and is not in the store).
-- listed = false: not in the App Store yet (the app has no screen yet).
Config.Apps = {
    -- Core
    { id = 'phone',     label = 'Phone',     category = 'Core', preinstalled = true, essential = true },
    { id = 'messages',  label = 'Messages',  category = 'Core', preinstalled = true, essential = true },
    { id = 'contacts',  label = 'Contacts',  category = 'Core', preinstalled = true, essential = true },
    { id = 'camera',    label = 'Camera',    category = 'Core', preinstalled = true, essential = true },
    { id = 'gallery',   label = 'Gallery',   category = 'Core', preinstalled = true, essential = true },
    { id = 'mail',      label = 'Mail',      category = 'Core', preinstalled = true },
    { id = 'maps',      label = 'Maps',      category = 'Core', preinstalled = true },
    { id = 'music',     label = 'Music',     category = 'Core', preinstalled = true },
    { id = 'notes',     label = 'Notes',     category = 'Core', preinstalled = true },
    { id = 'calendar',  label = 'Calendar',  category = 'Core', preinstalled = true },
    { id = 'reminders', label = 'Reminders', category = 'Core', preinstalled = true },
    { id = 'clock',     label = 'Clock',     category = 'Core', preinstalled = true },
    { id = 'calculator', label = 'Calculator', category = 'Core', preinstalled = true },
    { id = 'weather',   label = 'Weather',   category = 'Core', preinstalled = true },
    { id = 'wallet',    label = 'Wallet',    category = 'Core', preinstalled = true },
    { id = 'health',    label = 'Health',    category = 'Core', preinstalled = true },
    { id = 'settings',  label = 'Settings',  category = 'Core', preinstalled = true, essential = true },
    { id = 'store',     label = 'App Store', category = 'Core', preinstalled = true, essential = true },

    -- Social
    { id = 'lens',      label = 'Lens',      category = 'Social', preinstalled = false, listed = false },
    { id = 'saga',      label = 'Saga',      category = 'Social', preinstalled = false, listed = false },
    { id = 'hearth',    label = 'Hearth',    category = 'Social', preinstalled = false },
    { id = 'pulse',     label = 'Pulse',     category = 'Social', preinstalled = false, listed = false },
    { id = 'freyja',    label = 'Freyja',    category = 'Social', preinstalled = false, listed = false },
    { id = 'veil',      label = 'Veil',      category = 'Social', preinstalled = false },
    { id = 'watch',     label = 'Watch',     category = 'Social', preinstalled = false, listed = false },

    -- Services
    { id = 'bazaar',    label = 'Bazaar',      category = 'Services', preinstalled = false, listed = false },
    { id = 'noticeboard', label = 'Notice Board', category = 'Services', preinstalled = false, listed = false },
    { id = 'garage',    label = 'Garage',      category = 'Services', preinstalled = false, listed = false },
    { id = 'jobs',      label = 'Jobs',        category = 'Services', preinstalled = false, listed = false },
}

-- The App Store.
Config.Store = {
    -- Installing needs signal (the phone downloads the app).
    needService = true,
    -- Apps shown at the top of the store, in this order.
    featured = { 'veil', 'hearth' },
    -- Per app: price (bank money, charged once: installing it again later is free) and listed.
    -- Example:  veil = { price = 250 },
    apps = {},
}
