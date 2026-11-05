local api = {}

function api.GetDealers()
    local out = {}
    for id, d in pairs(Dealers.list) do out[id] = { label = d.label, shop = d.shop } end
    return out
end

function api.IsStaff(src)
    return Sales.isStaff(Core.info(src))
end

function api.IsTestDriving(src)
    return TestDrive.active[tonumber(src)] ~= nil
end

for name, fn in pairs(api) do
    exports(name, fn)
    exports(name:sub(1, 1):lower() .. name:sub(2), fn)
end
