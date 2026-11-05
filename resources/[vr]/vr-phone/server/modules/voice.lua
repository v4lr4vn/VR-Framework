-- The link to the voice script. A call is a channel number: both players are put on it, and it is cleared (0) when the call ends.
-- vr-voice and pma-voice both answer to setPlayerCall(source, channel). If no voice script is running the call still works, only silent.
local Voice = {}
Phone.Voice = Voice

local warned = false

local function resource()
    local calls = Config.Phone.Calls or {}
    local name = calls.voice
    if type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started' then return name end
    return nil
end

function Voice.available()
    return resource() ~= nil
end

-- Puts the player on a call channel (0 takes them off). Returns true when the voice script took it.
function Voice.set(src, channel)
    if not src then return false end
    local name = resource()
    if not name then
        if not warned then
            warned = true
            print('^3[vr-phone] The voice script is not running, so phone calls will be silent. Set Config.Phone.Calls.voice.^0')
        end
        return false
    end
    local ok, err = pcall(function() exports[name]:setPlayerCall(src, channel) end)
    if not ok then print(('^1[vr-phone] could not move player %s to call channel %s: %s^0'):format(tostring(src), tostring(channel), tostring(err))) end
    return ok
end
