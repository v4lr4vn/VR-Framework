if not shared.compat then return end

local function free(resource)
    local state = GetResourceState(resource)
    if state == 'missing' or state == 'stopped' or state == 'uninitialized' or state == 'unknown' then return true end
    -- the name is a `provide` alias of this very resource
    local mine = GetCurrentResourceName()
    -- GetResourcePath only exists on the server; the client compares manifest names
    if GetResourcePath then return GetResourcePath(resource) == GetResourcePath(mine) end
    return GetResourceMetadata(resource, 'name', 0) == mine
end

if not free('ox_inventory') then return end

for name, fn in pairs(InvExports) do
    AddEventHandler(('__cfx_export_ox_inventory_%s'):format(name), function(setCB) setCB(fn) end)
end
