-- Booking: an officer sentences a suspect at the station, with no court case.
-- The suspect gets an MDT report, a sentence on their record, a fine taken from the bank and, if the sentence has
-- jail time, they are sent to prison like any other sentence.
Config.Booking = {
    enabled = true,
    command = 'book',          -- /book [id]  (no id: the closest person)
    range = 6.0,               -- how close the suspect must stand to the officer
    interactDistance = 3.0,    -- third eye distance
    requireRestrained = false, -- true: the suspect must be handcuffed
    notesMax = 600,
    -- Where booking is allowed. Admins can add more in game with /bookingarea add <radius> <name>.
    areas = {
        { label = 'Mission Row PD', coords = vector3(441.0, -982.0, 30.7), radius = 70.0 },
    },
}
