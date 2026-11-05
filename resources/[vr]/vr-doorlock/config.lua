DoorConfig = {
    command = 'doorlock',
    commandPrincipal = 'group.admin',
    playerAceAuthorised = false,
    interactKey = 38,
    notify = false,
    textUI = false,
    icons = true,
    iconSize = 0.02,
    lockDifficulty = { 'easy', 'easy', 'medium' },
    canPickUnlockedDoors = false,
    lockpickItems = { 'lockpick' },
    lockpickBreakChance = { success = 1, fail = 20 },
    lockSound = 'bolt',
    unlockSound = 'unbolt',
    sounds = { 'bolt', 'unbolt', 'latch', 'keypad-lock', 'keypad-unlock', 'gate' },
    maxStateDistance = 6.0,
}

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-doorlock'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
