Config = {}

-- Part of the ValRavn framework. A renamed copy of this resource does not run.
do
    local expected = 'vr-notepad'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end

Config.Item = 'notepad'          -- the usable item. Add it to your inventory items
Config.Command = 'notepad'       -- chat command, set to false for none
Config.RequireItem = true        -- the command only works while you carry the item
Config.MaxLength = 400           -- characters per note
Config.MaxPerPlayer = 5          -- notes one character can have out at once
Config.MaxNotes = 150            -- notes on the whole server
Config.ExpireMinutes = 60        -- notes crumble after this long. 0 keeps them until a restart
Config.ReadDistance = 3.0        -- how close you must be to read or tear up a note
Config.StreamDistance = 60.0     -- notes further away than this are not drawn
Config.Prop = 'prop_paper_ball'  -- what a note looks like on the ground
Config.WriteSeconds = 4          -- how long writing takes
