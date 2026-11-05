if Keybinds then return end

Keybinds = {}

local RES = GetCurrentResourceName()
local HOST = 'vr-keybinds'
local list = {}

local Bind = {}
Bind.__index = Bind

function Bind:disable(state)
    self.disabled = state == true
end

function Bind:isControlPressed()
    return self.isPressed == true
end

local function host(name, ...)
    if GetResourceState(HOST) ~= 'started' then return false end
    local args = table.pack(...)
    return pcall(function() return exports[HOST][name](exports[HOST], table.unpack(args, 1, args.n)) end)
end

function Bind:getCurrentKey()
    local ok, label = host('getKeyLabel', self.id)
    return ok and label or ''
end

function Bind:isBound()
    local ok, bind = host('getBind', self.id)
    return ok and bind ~= nil
end

local function send(self)
    return (host('register', {
        id = self.id,
        label = self.label,
        description = self.description,
        category = self.category,
        suggested = self.suggested,
        suggestedMod = self.suggestedMod,
        essential = self.essential,
        allowInUi = self.allowInUi,
        order = self.order,
    }))
end

local function flush()
    for _, self in pairs(list) do
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

function Keybinds.add(def)
    if type(def) ~= 'table' or type(def.name) ~= 'string' then
        error('Keybinds.add needs a name', 2)
    end
    local self = setmetatable(def, Bind)
    self.id = RES .. ':' .. def.name
    self.label = def.label or def.description or def.name
    list[self.id] = self
    if GetResourceState(HOST) ~= 'missing' and not send(self) then retry() end
    return self
end

function Keybinds.remove(name)
    local id = RES .. ':' .. name
    list[id] = nil
    host('unregister', id)
end

AddEventHandler('vr-keybinds:fire', function(id, state)
    local self = list[id]
    if not self then return end
    if state then
        if self.disabled then return end
        self.isPressed = true
        if self.onPressed then self:onPressed() end
    else
        if not self.isPressed then return end
        self.isPressed = false
        if self.disabled then return end
        if self.onReleased then self:onReleased() end
    end
end)

AddEventHandler('onClientResourceStart', function(res)
    if res ~= HOST then return end
    if not flush() then retry() end
end)
