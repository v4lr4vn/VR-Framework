Config = {}

-- The root item that appears in the radial menu (default key Z). Admins only.
Config.Radial = {
    id = 'vr_admintools',
    label = 'Admin',
    icon = 'user-shield',
}

-- How often (seconds) a client asks the server whether it is still an admin.
-- Handles promotions/demotions and the first login. Cheap; the server also rate limits it.
Config.RecheckSeconds = 30

-- Every launcher in the Admin tab. Each one just runs the command the creator already has,
-- so the creator's own permission check still applies - this is only a shortcut.
--   id        unique key
--   label     text on the radial item
--   icon      Font Awesome name without "fa-"
--   command   the command to run (without the slash)
--   resource  optional: the item is hidden while that resource is not running
-- Add your own rows to put more shortcuts in the tab. Other resources can also call
-- exports['vr-admintools']:AddTool({ id=..., label=..., icon=..., command=... }) at runtime.
Config.Tools = {
    { id = 'restaurants', label = 'Restaurants',  icon = 'utensils',           command = 'restaurantcreator', resource = 'vr-restaurant' },
    { id = 'farming',     label = 'Farming',      icon = 'wheat-awn',          command = 'farmcreator',       resource = 'vr-farming' },
    { id = 'fence',       label = 'Fence',        icon = 'mask',               command = 'fencecreator',      resource = 'vr-fence' },
    { id = 'heists',      label = 'Bank heists',  icon = 'vault',              command = 'heistcreator',      resource = 'vr-bankheist' },
    { id = 'doors',       label = 'Doors',        icon = 'door-closed',        command = 'doorlock',          resource = 'vr-doorlock' },
    { id = 'garages',     label = 'Garages',      icon = 'warehouse',          command = 'garage',            resource = 'vr-garages' },
    { id = 'civjobs',     label = 'Civ jobs',     icon = 'briefcase',          command = 'jobsetup',          resource = 'vr-civjobs' },
    { id = 'prison',      label = 'Prison',       icon = 'lock',               command = 'prisonadmin',       resource = 'vr-prison' },
    { id = 'djzones',     label = 'DJ zones',     icon = 'music',              command = 'djzones',           resource = 'vr-djbooth' },
    { id = 'housing',     label = 'Housing',      icon = 'house',              command = 'housing',           resource = 'vr-realtor' },
    { id = 'adminmenu',   label = 'Admin menu',   icon = 'screwdriver-wrench', command = 'admin',             resource = 'vr-adminmenu' },
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-admintools'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
