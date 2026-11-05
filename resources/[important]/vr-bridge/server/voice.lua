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
    local ok, out, extra = pcall(function() return exports[r][fn](nil, table.unpack(args, 1, args.n)) end)
    if ok then return out, extra end
    return nil
end

function Vo.has(fn)
    local r = res()
    if not r then return false end
    local ok = pcall(function() return exports[r][fn] end)
    return ok
end

function Vo.playersInRadio(channel)
    return Vo.call('getPlayersInRadioChannel', channel) or {}
end

function Vo.setRadio(src, channel)
    return Vo.call('setPlayerRadio', src, channel)
end

return Vo
