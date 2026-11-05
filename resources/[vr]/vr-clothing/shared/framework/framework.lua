Framework = {}

function Framework.QBCore()
    return GetResourceState("vr-core") ~= "missing"
end
