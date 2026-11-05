-- Closes the loading screen once, the first time this player spawns.
-- loadscreen_manual_shutdown is on, so the screen stays up through the whole
-- connect + character select flow until then.
local closed = false

AddEventHandler('playerSpawned', function()
    if closed then return end
    closed = true
    ShutdownLoadingScreenNui()
end)
