return function(animDict, timeout)
    if HasAnimDictLoaded(animDict) then return animDict end
    if type(animDict) ~= 'string' or not DoesAnimDictExist(animDict) then
        error(("attempted to load invalid animDict '%s'"):format(tostring(animDict)), 2)
    end
    return lib.streamingRequest(RequestAnimDict, HasAnimDictLoaded, 'animDict', animDict, timeout)
end
