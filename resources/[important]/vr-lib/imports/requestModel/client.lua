return function(model, timeout)
    if type(model) ~= 'number' then model = joaat(model) end
    if HasModelLoaded(model) then return model end
    if not IsModelValid(model) and not IsModelInCdimage(model) then
        error(("attempted to load invalid model '%s'"):format(model), 2)
    end
    return lib.streamingRequest(RequestModel, HasModelLoaded, 'model', model, timeout)
end
