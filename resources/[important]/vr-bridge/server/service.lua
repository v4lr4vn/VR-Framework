local code = LoadResourceFile(GetCurrentResourceName(), 'import.lua')
local Hub = load(code, ('@@%s/import.lua'):format(GetCurrentResourceName()))()

local usable = {}

exports('registerUsable', function(name)
    if type(name) ~= 'string' then return false end
    usable[name] = GetInvokingResource() or GetCurrentResourceName()
    return true
end)

exports('isUsable', function(name)
    local owner = usable[name]
    return owner ~= nil and GetResourceState(owner) == 'started'
end)

AddEventHandler('onResourceStop', function(res)
    for name, owner in pairs(usable) do
        if owner == res then usable[name] = nil end
    end
end)

exports('info', function() return Hub.info() end)
exports('adminGroups', function() return Hub.adminGroups() end)
exports('framework', function() return Hub.framework end)
exports('societyBalance', function(name) return Hub.society.balance(name) end)
exports('addSocietyMoney', function(name, amount, reason) return Hub.society.add(name, amount, reason) end)
exports('removeSocietyMoney', function(name, amount, reason) return Hub.society.remove(name, amount, reason) end)

CreateThread(function()
    Wait(2000)
    local info = Hub.info()
    print(('[vr-bridge] framework: %s | inventory: %s | target: %s | database: %s'):format(
        info.core or info.framework, info.inventoryResource or info.inventory, info.targetResource or info.target, info.database or 'none'))
end)

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-bridge'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
