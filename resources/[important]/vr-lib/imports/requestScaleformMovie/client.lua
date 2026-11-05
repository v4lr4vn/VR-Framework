return function(scaleformName, timeout)
    if type(scaleformName) ~= 'string' then
        error(("expected scaleformName to be a string (received %s)"):format(type(scaleformName)), 2)
    end
    local scaleform = RequestScaleformMovie(scaleformName)
    return lib.waitFor(function()
        if HasScaleformMovieLoaded(scaleform) then return scaleform end
    end, ("failed to load scaleformMovie '%s'"):format(scaleformName), timeout or 30000)
end
