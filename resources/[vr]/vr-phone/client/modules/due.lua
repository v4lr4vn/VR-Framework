-- Reminder and calendar alerts. The server keeps the alerts; only this game knows the game clock, so it does the watching:
-- it fetches the list of alerts that are waiting, compares them with the game clock, and tells the server when one is due.
-- The server then sends the notification (so it respects silent mode, signal, and the player's notification rules).
local Due = {}
Phone.Due = Due

local pending = {}   -- { { kind, id, at }, ... } soonest first
local dirty = true   -- fetch the list again as soon as the server allows it
local nextPoll = 0

local function now()
    local date = ('%04d-%02d-%02d'):format(GetClockYear(), GetClockMonth() + 1, GetClockDayOfMonth())
    return Phone.stamp(date, GetClockHours() * 60 + GetClockMinutes())
end

-- The screen changed a reminder or an event.
function Due.refresh()
    dirty = true
end

local function poll()
    local r = lib.callback.await('vr-phone:due:list', false)
    if type(r) == 'table' and r.ok and type(r.due) == 'table' then
        pending = r.due
        dirty = false
        nextPoll = GetGameTimer() + 60000
    elseif type(r) == 'table' and r.reason == 'busy' then
        -- asked a moment ago: try again on the next round
        dirty = true
    else
        -- no phone, phone off: look again later
        pending = {}
        dirty = false
        nextPoll = GetGameTimer() + 60000
    end
end

CreateThread(function()
    Wait(8000)
    while true do
        if dirty or GetGameTimer() >= nextPoll then poll() end
        local t = now()
        if t and #pending > 0 then
            local fired = 0
            while pending[1] and pending[1].at <= t and fired < 5 do
                local item = table.remove(pending, 1)
                lib.callback.await('vr-phone:due:fire', false, { kind = item.kind, id = item.id })
                fired = fired + 1
            end
        end
        Wait(2000)
    end
end)
