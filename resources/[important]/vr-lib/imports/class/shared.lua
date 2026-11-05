local mixins = {}

function mixins.new(class, ...)
    local private = {}
    local obj = setmetatable({ private = private }, class)
    local ctor = class.constructor
    if ctor then
        local parent = class.__super
        local function super(self, ...)
            local fn = parent and parent.constructor
            parent = parent and parent.__super
            if fn then return fn(self, ...) end
        end
        rawset(obj, 'super', super)
        local ok, err = pcall(ctor, obj, ...)
        rawset(obj, 'super', nil)
        if not ok then error(err, 2) end
    end
    if next(private) == nil then rawset(obj, 'private', nil) end
    return obj
end

function mixins.isClass(obj, class)
    local mt = getmetatable(obj)
    while mt do
        if mt == class then return true end
        mt = rawget(mt, '__super')
    end
    return false
end

mixins.instanceOf = mixins.isClass

return function(name, super)
    local class = {}
    class.__name = name
    class.__index = class
    class.__super = super
    class.new = mixins.new
    class.isClass = mixins.isClass
    class.instanceOf = mixins.instanceOf
    if super then
        setmetatable(class, { __index = super })
    end
    return class
end
