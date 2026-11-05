return function(ptFxName, timeout)
    if HasNamedPtfxAssetLoaded(ptFxName) then return ptFxName end
    if type(ptFxName) ~= 'string' then
        error(("expected ptFxName to be a string (received %s)"):format(type(ptFxName)), 2)
    end
    return lib.streamingRequest(RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, 'ptFxName', ptFxName, timeout)
end
