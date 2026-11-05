local U = Bridge.util
local Vo = {}
Bridge.voice = Vo

local function res()
    local r = Bridge.detect('voice')
    return r and U.started(r) and r or nil
end

function Vo.resource() return res() end

function Vo.call(fn, ...)
    local r = res()
    if not r then return nil end
    local args = table.pack(...)
    local ok, out = pcall(function() return exports[r][fn](nil, table.unpack(args, 1, args.n)) end)
    if ok then return out end
    return nil
end

function Vo.setRadio(channel)
    if (tonumber(channel) or 0) > 0 then Vo.call('setVoiceProperty', 'radioEnabled', true) end
    return Vo.call('setRadioChannel', tonumber(channel) or 0)
end

function Vo.radioChannel()
    return tonumber(LocalPlayer.state.radioChannel) or 0
end

function Vo.setProperty(key, value) return Vo.call('setVoiceProperty', key, value) end
function Vo.setRadioAnim(enabled) return Vo.call('setDisableRadioAnim', enabled == false) end

return Vo
