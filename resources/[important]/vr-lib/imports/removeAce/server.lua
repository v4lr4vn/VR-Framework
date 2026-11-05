local function principal(p)
    if type(p) == 'number' then return ('player.%s'):format(p) end
    return tostring(p)
end

return function(p, ace, allow)
    ExecuteCommand(('remove_ace %s %s %s'):format(principal(p), ace, allow == false and 'deny' or 'allow'))
end
