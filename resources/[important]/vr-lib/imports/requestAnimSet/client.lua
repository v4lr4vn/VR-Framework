return function(animSet, timeout)
    if HasAnimSetLoaded(animSet) then return animSet end
    if type(animSet) ~= 'string' then
        error(("expected animSet to be a string (received %s)"):format(type(animSet)), 2)
    end
    return lib.streamingRequest(RequestAnimSet, HasAnimSetLoaded, 'animSet', animSet, timeout)
end
