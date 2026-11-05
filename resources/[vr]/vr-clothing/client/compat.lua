local legacyExports = { 'illenium-appearance', 'fivem-appearance' }
local NEW, OLD = 'vr-clothing:client:', 'illenium-appearance:client:'
local baseExports = exports
local baseRegisterNetEvent = RegisterNetEvent
local baseAddEventHandler = AddEventHandler
local aliased = {}

exports = setmetatable({}, {
    __index = function(_, key) return baseExports[key] end,
    __call = function(_, name, fn)
        baseExports(name, fn)
        for _, res in ipairs(legacyExports) do
            baseAddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
        end
    end,
})

local function alias(name, fn)
    if type(name) ~= 'string' or name:sub(1, #NEW) ~= NEW or fn == nil then return end
    local old = OLD .. name:sub(#NEW + 1)
    aliased[old] = aliased[old] or {}
    if aliased[old][fn] then return end
    aliased[old][fn] = true
    baseRegisterNetEvent(old)
    baseAddEventHandler(old, fn)
end

AddEventHandler = function(name, fn)
    local handle = baseAddEventHandler(name, fn)
    alias(name, fn)
    return handle
end

RegisterNetEvent = function(name, fn)
    local handle = baseRegisterNetEvent(name, fn)
    alias(name, fn)
    return handle
end
