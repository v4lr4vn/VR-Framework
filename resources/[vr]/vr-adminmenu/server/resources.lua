local function getResources()
    local resources = {}

    for i = 0, GetNumResources() - 1 do
        local resourceName = GetResourceByFindIndex(i)
        if resourceName then
            resources[#resources + 1] = {
                name = resourceName,
                author = GetResourceMetadata(resourceName, "author", 0),
                version = GetResourceMetadata(resourceName, "version", 0),
                description = GetResourceMetadata(resourceName, "description", 0),
                resourceState = GetResourceState(resourceName),
            }
        end
    end

    return resources
end

lib.callback.register('vr-adminmenu:callback:GetResources', function(source)
    if not HasPerms(source, Config.ResourceListPerms) then return {} end
    return getResources()
end)

local validStates = { start = true, stop = true, restart = true }

lib.callback.register('vr-adminmenu:callback:ChangeResourceState', function(source, data)
    if not CheckPerms(source, Config.ResourcePerms) then return end
    if type(data) ~= 'table' or type(data.name) ~= 'string' or not validStates[data.state] then return end

    local name = data.name
    local state = GetResourceState(name)
    if state == 'missing' or state == 'unknown' then return getResources() end

    AdminLog(source, ('%s resource %s'):format(data.state, name))

    if data.state == "start" then
        StartResource(name)
        print(("[vr-adminmenu] %s started %s"):format(GetPlayerName(source) or source, name))
    elseif data.state == "stop" then
        StopResource(name)
        print(("[vr-adminmenu] %s stopped %s"):format(GetPlayerName(source) or source, name))
    elseif data.state == "restart" then
        StopResource(name)
        Wait(200)
        StartResource(name)
        print(("[vr-adminmenu] %s restarted %s"):format(GetPlayerName(source) or source, name))
    end

    return getResources()
end)
