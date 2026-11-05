local owner = GetCurrentResourceName()
local order = { 'vr-core', 'vr-bridge', 'vr-lib' }

local function inCharge()
    for _, res in ipairs(order) do
        if res == owner then return true end
        local state = GetResourceState(res)
        if state == 'started' or state == 'starting' then return false end
    end
    return true
end

local function expectedName(res)
    local named = GetResourceMetadata(res, 'vr_name', 0)
    if type(named) == 'string' and named ~= '' then return named end
    local author = GetResourceMetadata(res, 'author', 0)
    if type(author) == 'string' and author:lower():find('valravn', 1, true) and res:sub(1, 3) ~= 'vr-' then
        return 'vr-' .. (res:match('^[^%-]+%-(.+)$') or res)
    end
    return nil
end

local function renamed(res)
    if type(res) ~= 'string' then return nil end
    local want = expectedName(res)
    if want and want ~= res then return want end
    return nil
end

local function warn(res, want)
    print(('^1[%s] %s was blocked. It is a ValRavn resource %s under another name, and renamed copies do not run.^0'):format(owner, res, want))
end

AddEventHandler('onResourceStarting', function(res)
    if not inCharge() then return end
    local want = renamed(res)
    if not want then return end
    warn(res, want)
    CancelEvent()
end)

CreateThread(function()
    Wait(0)
    if not inCharge() then return end
    for i = 0, GetNumResources() - 1 do
        local res = GetResourceByFindIndex(i)
        local want = renamed(res)
        if want and GetResourceState(res) == 'started' then
            warn(res, want)
            StopResource(res)
        end
    end
end)
