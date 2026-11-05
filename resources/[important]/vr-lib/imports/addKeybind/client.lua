local keybinds = {}
local resource = GetCurrentResourceName()
local HOST = 'vr-keybinds'
local hosted = GetResourceState(HOST) ~= 'missing'

local Keybind = {}
Keybind.__index = Keybind

function Keybind:disable(state)
    self.disabled = state == true
end

function Keybind:isControlPressed()
    return self.isPressed == true
end

local function host(name, ...)
    if GetResourceState(HOST) ~= 'started' then return false end
    local args = table.pack(...)
    return pcall(function() return exports[HOST][name](exports[HOST], table.unpack(args, 1, args.n)) end)
end

function Keybind:getCurrentKey()
    if hosted then
        local ok, label = host('getKeyLabel', self.id)
        return ok and label or ''
    end
    return GetControlInstructionalButton(0, self.hash, true):sub(3)
end

local function press(self)
    if self.disabled or IsPauseMenuActive() then return end
    self.isPressed = true
    if self.onPressed then self:onPressed() end
end

local function release(self)
    if not self.isPressed then return end
    self.isPressed = false
    if self.disabled or IsPauseMenuActive() then return end
    if self.onReleased then self:onReleased() end
end

local function send(self)
    return (host('register', {
        id = self.id,
        label = self.label or self.description,
        description = self.help,
        category = self.category,
        suggested = self.defaultKey ~= '' and self.defaultKey or nil,
        essential = self.essential,
        allowInUi = self.allowInUi,
        order = self.order,
    }))
end

local function flush()
    for _, self in pairs(keybinds) do
        if not send(self) then return false end
    end
    return true
end

local retrying = false

local function retry()
    if retrying then return end
    retrying = true
    CreateThread(function()
        for _ = 1, 240 do
            Wait(500)
            if GetResourceState(HOST) == 'missing' or flush() then break end
        end
        retrying = false
    end)
end

if hosted then
    AddEventHandler('vr-keybinds:fire', function(id, state)
        local self = keybinds[id]
        if not self then return end
        if state then
            if self.disabled then return end
            self.isPressed = true
            if self.onPressed then self:onPressed() end
        else
            release(self)
        end
    end)

    AddEventHandler('onClientResourceStart', function(res)
        if res ~= HOST then return end
        if not flush() then retry() end
    end)
end

return function(data)
    if type(data) ~= 'table' or type(data.name) ~= 'string' then
        error('keybind requires a name', 2)
    end
    local self = setmetatable(data, Keybind)
    self.resource = resource
    self.hash = joaat('+' .. self.name) | 0x80000000
    self.defaultMapper = self.defaultMapper or 'keyboard'
    self.defaultKey = self.defaultKey or ''
    self.description = self.description or self.name

    if hosted then
        self.id = resource .. ':' .. self.name
        keybinds[self.id] = self
        if GetResourceState(HOST) ~= 'missing' and not send(self) then retry() end
        return self
    end

    keybinds[self.name] = self
    RegisterCommand('+' .. self.name, function() press(self) end, false)
    RegisterCommand('-' .. self.name, function() release(self) end, false)
    RegisterKeyMapping('+' .. self.name, self.description, self.defaultMapper, self.defaultKey)
    if self.secondaryKey then
        RegisterKeyMapping('~!+' .. self.name, self.description, self.secondaryMapper or self.defaultMapper, self.secondaryKey)
    end
    SetTimeout(500, function()
        TriggerEvent('chat:removeSuggestion', ('/+%s'):format(self.name))
        TriggerEvent('chat:removeSuggestion', ('/-%s'):format(self.name))
    end)
    return self
end
