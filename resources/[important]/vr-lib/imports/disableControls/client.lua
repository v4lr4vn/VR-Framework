local controls = {}
local counts = {}

local disable = setmetatable({}, {
    __call = function()
        for control in pairs(counts) do
            DisableControlAction(0, control, true)
        end
    end,
})

local function each(args, fn)
    for i = 1, #args do
        local v = args[i]
        if type(v) == 'table' then
            for j = 1, #v do fn(v[j]) end
        else
            fn(v)
        end
    end
end

function disable:Add(...)
    each({ ... }, function(c) counts[c] = (counts[c] or 0) + 1 end)
end

function disable:Remove(...)
    each({ ... }, function(c)
        local n = (counts[c] or 0) - 1
        counts[c] = n > 0 and n or nil
    end)
end

function disable:Clear(...)
    each({ ... }, function(c) counts[c] = nil end)
end

controls = disable
return controls
