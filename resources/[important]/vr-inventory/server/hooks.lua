local eventHooks = {}
local hookSeq = 0

local function itemFilter(filter, item, secondItem)
    local name = type(item) == 'table' and item.name or item
    if name and filter[name] then return true end
    return type(secondItem) == 'table' and filter[secondItem.name] == true
end

local function inventoryFilter(filter, inventory, secondInventory)
    for i = 1, #filter do
        local pattern = filter[i]
        if (inventory and inventory:match(pattern)) or (secondInventory and secondInventory:match(pattern)) then return true end
    end
    return false
end

local function postEvents(result, payload)
    payload.hookId = nil
    for i = 1, #result.ids do TriggerEvent(result.ids[i], result.success, payload) end
end

local closer = {
    __close = function(self, err)
        if err then self.success = false end
        local payload = self.payload
        if #self.ids == 0 then return end
        SetTimeout(50, function() postEvents(self, payload) end)
    end,
}

function TriggerEventHooks(event, payload)
    local result = setmetatable({ ids = {}, success = false, payload = payload }, closer)
    local hooks = eventHooks[event]

    if hooks then
        local fromInventory = payload.fromInventory and tostring(payload.fromInventory) or payload.inventoryId and tostring(payload.inventoryId) or payload.shopType and tostring(payload.shopType)
        local toInventory = payload.toInventory and tostring(payload.toInventory)

        for i = 1, #hooks do
            local hook = hooks[i]
            local pass = true

            if hook.itemFilter and not itemFilter(hook.itemFilter, payload.fromSlot or payload.item or payload.itemName or payload.recipe, payload.toSlot) then pass = false end
            if pass and hook.inventoryFilter and not inventoryFilter(hook.inventoryFilter, fromInventory, toInventory) then pass = false end
            if pass and hook.typeFilter and not hook.typeFilter[payload.inventoryType or payload.shopType or payload.fromType] then pass = false end

            if pass then
                payload.hookId = hook.hookId
                result.ids[#result.ids + 1] = hook.hookId

                if hook.print then print(('[vr-inventory] running hook "%s"'):format(hook.hookId)) end

                local started = GetGameTimer()
                local ok, response = pcall(hook.fn, payload)
                local took = GetGameTimer() - started

                if took >= 10 then print(('^3[vr-inventory] hook "%s" took %dms^0'):format(hook.hookId, took)) end

                if not ok then
                    print(('^1[vr-inventory] hook "%s" errored: %s^0'):format(hook.hookId, tostring(response)))
                elseif event == 'createItem' then
                    if type(response) == 'table' then payload.metadata = response end
                elseif response == false then
                    if hook.print or server.loghookrejection then
                        print(('[vr-inventory] hook "%s" rejected the action'):format(hook.hookId))
                    end
                    payload.hookId = nil
                    return result
                end
            end
        end
    end

    payload.hookId = nil
    if event == 'createItem' then result.result = payload.metadata end
    result.success = true
    return result
end

local function toSet(value)
    if type(value) ~= 'table' then return nil end
    local set = {}
    local array = #value > 0
    if array then
        for i = 1, #value do set[value[i]] = true end
    else
        for k, v in pairs(value) do set[k] = v and true or nil end
    end
    return set
end

local function registerHook(event, fn, options)
    if type(event) ~= 'string' then return end
    if fn == nil and type(options) ~= 'table' then return end
    if fn ~= nil and type(fn) ~= 'function' and type(fn) ~= 'table' then return end

    local resource = GetInvokingResource() or shared.resource
    eventHooks[event] = eventHooks[event] or {}
    hookSeq = hookSeq + 1

    local hook = {
        fn = fn or function() end,
        resource = resource,
        hookId = ('%s:%s:%s'):format(resource, event, hookSeq),
    }

    if type(options) == 'table' then
        hook.print = options.print == true
        hook.itemFilter = toSet(options.itemFilter)
        hook.typeFilter = toSet(options.typeFilter)
        if type(options.inventoryFilter) == 'table' then
            local list = {}
            for _, pattern in pairs(options.inventoryFilter) do
                if type(pattern) == 'string' then list[#list + 1] = pattern end
            end
            hook.inventoryFilter = list
        end
    end

    local list = eventHooks[event]
    list[#list + 1] = hook
    return hook.hookId
end

local function removeHooks(resource, id)
    for _, hooks in pairs(eventHooks) do
        for i = #hooks, 1, -1 do
            local hook = hooks[i]
            if hook.resource == resource and (not id or hook.hookId == id) then table.remove(hooks, i) end
        end
    end
end

AddEventHandler('onResourceStop', function(resource) removeHooks(resource) end)

exports('registerHook', registerHook)
exports('removeHooks', function(id) removeHooks(GetInvokingResource() or shared.resource, id) end)

InvHooks = { register = registerHook, remove = removeHooks }
