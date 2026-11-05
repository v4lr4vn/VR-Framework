return function(textureDict, timeout)
    if HasStreamedTextureDictLoaded(textureDict) then return textureDict end
    if type(textureDict) ~= 'string' then
        error(("expected textureDict to be a string (received %s)"):format(type(textureDict)), 2)
    end
    return lib.streamingRequest(RequestStreamedTextureDict, HasStreamedTextureDictLoaded, 'textureDict', textureDict, timeout, false)
end
