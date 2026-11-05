local function principal(p)
    if type(p) == 'number' then return ('player.%s'):format(p) end
    return tostring(p)
end

return function(child, parent)
    ExecuteCommand(('add_principal %s %s'):format(principal(child), principal(parent)))
end
