local registered = {}
local suggestions = {}

local function chatSuggest(target)
    if next(suggestions) == nil then return end
    local list = {}
    for _, s in pairs(suggestions) do list[#list + 1] = s end
    TriggerClientEvent('chat:addSuggestions', target or -1, list)
end

AddEventHandler('playerJoining', function()
    local src = source
    SetTimeout(1000, function() chatSuggest(src) end)
end)

local function parseArgs(source, args, raw, params)
    if not params then return args end
    local out = {}
    for i = 1, #params do
        local p = params[i]
        local value = args[i]
        local kind = p.type
        if kind == 'number' then
            value = tonumber(value)
        elseif kind == 'string' then
            value = value ~= nil and tostring(value) or nil
            if value == '' then value = nil end
        elseif kind == 'playerId' then
            if value == 'me' then value = source end
            value = tonumber(value)
            if value and not DoesPlayerExist(tostring(value)) then value = nil end
        elseif kind == 'longString' and i == #params then
            if value ~= nil then
                local start = raw:find(tostring(args[i]), 1, true)
                value = start and raw:sub(start) or table.concat(args, ' ', i)
            end
        end
        if value == nil and not p.optional then
            local msg = ("Invalid or missing argument '%s'%s"):format(p.name, kind and (' (' .. kind .. ')') or '')
            if source > 0 then
                TriggerClientEvent('vr-ui:notify', source, { type = 'error', title = 'Command', message = msg })
            else
                print(msg)
            end
            return false
        end
        out[p.name] = value
    end
    return out
end

local function adminGroups()
    if GetResourceState('vr-bridge') == 'started' then
        local ok, list = pcall(function() return exports['vr-bridge']:adminGroups() end)
        if ok and type(list) == 'table' and #list > 0 then return list end
    end
    return { 'group.admin' }
end

local function aceFor(restricted)
    if restricted == nil or restricted == false then return nil end
    if restricted == true then return adminGroups() end
    if type(restricted) == 'string' then return { restricted } end
    if type(restricted) == 'table' then return restricted end
    return nil
end

return function(commandName, properties, cb, ...)
    if type(properties) == 'function' then
        cb, properties = properties, nil
    end
    properties = type(properties) == 'table' and properties or {}
    local names = type(commandName) == 'table' and commandName or { commandName }
    local restricted = aceFor(properties.restricted)

    for i = 1, #names do
        local name = names[i]
        local handler = function(source, args, raw)
            source = tonumber(source) or 0
            local parsed = parseArgs(source, args, raw, properties.params)
            if parsed == false then return end
            local ok, err = pcall(cb, source, parsed, raw)
            if not ok then print(('^1[vr-lib] command /%s failed: %s^0'):format(name, err)) end
        end
        RegisterCommand(name, handler, restricted ~= nil)
        registered[name] = true
        if restricted then
            for _, principal in ipairs(restricted) do
                ExecuteCommand(('add_ace %s command.%s allow'):format(principal, name))
            end
        end
        if properties.help or properties.params then
            local params = {}
            for _, p in ipairs(properties.params or {}) do
                params[#params + 1] = { name = p.name, help = p.help and (p.optional and (p.help .. ' (optional)') or p.help) or p.type }
            end
            suggestions[name] = { name = '/' .. name, help = properties.help or '', params = params }
        end
    end

    SetTimeout(500, function() chatSuggest() end)
end
