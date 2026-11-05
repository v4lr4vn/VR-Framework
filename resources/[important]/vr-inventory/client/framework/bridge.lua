Bridge.on('playerUnloaded', function()
    client.onLogout()
end)

local function refreshGroups()
    client.setPlayerData('groups', Bridge.groups())
end

Bridge.on('jobChanged', refreshGroups)
Bridge.on('gangChanged', refreshGroups)

local warned = false

function client.setPlayerStatus(values)
    if Bridge.framework == 'esx' and type(values) == 'table' then
        for name, value in pairs(values) do
            value = tonumber(value) or 0
            if value > 0 then TriggerEvent('esx_status:add', name, value) else TriggerEvent('esx_status:remove', name, -value) end
        end
        return
    end
    if warned then return end
    warned = true
    print(('^3[vr-inventory] items with client.status do nothing on %s, use a consumables script instead^0'):format(Bridge.framework))
end
