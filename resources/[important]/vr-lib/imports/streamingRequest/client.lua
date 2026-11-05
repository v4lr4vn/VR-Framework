return function(request, hasLoaded, assetType, asset, timeout, ...)
    if hasLoaded(asset) then return asset end
    request(asset, ...)
    return lib.waitFor(function()
        if hasLoaded(asset) then return asset end
    end, ("failed to load %s '%s' - this may be caused by too many loaded assets or an invalid asset"):format(assetType, tostring(asset)), timeout or 30000)
end
