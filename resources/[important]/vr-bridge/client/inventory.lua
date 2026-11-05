local U = Bridge.util
local I = {}
Bridge.inventory = I

local kind = Bridge.inventoryName
local RES = Bridge.inventoryResource

local function matches(md, want)
    if type(want) ~= 'table' then return true end
    if type(md) ~= 'table' then return next(want) == nil end
    for k, v in pairs(want) do
        if md[k] ~= v then return false end
    end
    return true
end

local function coreItems()
    if Bridge.framework == 'esx' then
        local ok, pd = pcall(function() return exports['es_extended']:getSharedObject().GetPlayerData() end)
        local out = {}
        for _, s in pairs(ok and pd and pd.inventory or {}) do
            if (tonumber(s.count) or 0) > 0 then out[#out + 1] = { name = s.name, count = tonumber(s.count), metadata = s.metadata or {}, slot = s.slot, label = s.label } end
        end
        return out
    end
    local pd = Bridge.playerData(true)
    local out = {}
    for key, s in pairs(pd and pd.items or {}) do
        if type(s) == 'table' and s.name then
            out[#out + 1] = { name = s.name, count = tonumber(s.amount or s.count) or 0, metadata = s.info or s.metadata or {}, slot = tonumber(s.slot) or tonumber(key), label = s.label }
        end
    end
    return out
end

function I.items()
    if kind == 'ox' and U.started(RES) then
        local ok, list = pcall(function() return exports[RES]:GetPlayerItems() end)
        local out = {}
        for _, s in pairs(ok and type(list) == 'table' and list or {}) do
            if type(s) == 'table' and s.name then out[#out + 1] = { name = s.name, count = tonumber(s.count) or 0, metadata = s.metadata or {}, slot = s.slot, label = s.label } end
        end
        return out
    end
    if kind == 'qs' and U.started(RES) then
        local ok, list = pcall(function() return exports[RES]:getUserInventory() end)
        local out = {}
        for key, s in pairs(ok and type(list) == 'table' and list or {}) do
            if type(s) == 'table' and s.name then out[#out + 1] = { name = s.name, count = tonumber(s.amount) or 0, metadata = s.info or {}, slot = tonumber(s.slot) or tonumber(key), label = s.label } end
        end
        return out
    end
    return coreItems()
end

function I.count(item, metadata)
    if kind == 'ox' and U.started(RES) then
        local ok, n = pcall(function() return exports[RES]:Search('count', item, metadata) end)
        return ok and tonumber(n) or 0
    end
    if kind == 'qs' and U.started(RES) and metadata == nil then
        local ok, n = pcall(function() return exports[RES]:Search(item) end)
        if ok and tonumber(n) then return tonumber(n) end
    end
    local n = 0
    for _, s in ipairs(I.items()) do
        if s.name == item and matches(s.metadata, metadata) then n = n + s.count end
    end
    return n
end

function I.has(item, count, metadata)
    if type(item) == 'table' then
        for k, v in pairs(item) do
            local name, need = k, v
            if type(k) == 'number' then name, need = v, count or 1 end
            if I.count(name, metadata) < (tonumber(need) or 1) then return false end
        end
        return true
    end
    return I.count(item, metadata) >= (tonumber(count) or 1)
end

function I.search(item, metadata)
    if kind == 'ox' and U.started(RES) then
        local ok, list = pcall(function() return exports[RES]:Search('slots', item, metadata) end)
        local out = {}
        for _, s in pairs(ok and type(list) == 'table' and list or {}) do
            out[#out + 1] = { name = s.name, count = tonumber(s.count) or 0, metadata = s.metadata or {}, slot = s.slot, label = s.label }
        end
        table.sort(out, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
        return out
    end
    local out = {}
    for _, s in ipairs(I.items()) do
        if s.name == item and matches(s.metadata, metadata) then out[#out + 1] = s end
    end
    table.sort(out, function(a, b) return (a.slot or 0) < (b.slot or 0) end)
    return out
end

function I.label(item)
    if kind == 'ox' and U.started(RES) then
        local ok, d = pcall(function() return exports[RES]:Items(item) end)
        if ok and d then return d.label end
    end
    for _, s in ipairs(I.items()) do
        if s.name == item and s.label then return s.label end
    end
    return item
end

function I.image(item)
    if kind == 'ox' then return ('nui://%s/web/images/%s.png'):format(RES, item) end
    if kind == 'qs' then return ('nui://%s/html/images/%s.png'):format(RES, item) end
    if kind == 'qb' or kind == 'core' then return ('nui://%s/html/images/%s.png'):format(RES or 'qb-inventory', item) end
    return nil
end

function I.isOpen()
    if kind == 'ox' and U.started(RES) then
        local ok, v = pcall(function() return LocalPlayer.state.invOpen end)
        return ok and v == true
    end
    return LocalPlayer.state.invOpen == true or LocalPlayer.state.inv_busy == true
end

function I.openStash(id, data)
    if kind == 'ox' then
        return exports[RES or 'ox_inventory']:openInventory('stash', id)
    end
    data = data or {}
    if kind == 'qs' then
        pcall(function() exports[RES]:RegisterStash(id, data.slots or 50, data.weight or 100000) end)
    end
    TriggerServerEvent('inventory:server:OpenInventory', 'stash', id, { maxweight = data.weight, slots = data.slots })
    TriggerEvent('inventory:client:SetCurrentStash', id)
end

RegisterNetEvent('__vrb_inv_stash:' .. Bridge.resource, function(id, data)
    I.openStash(id, data)
end)

if kind == 'ox' and RES then
    AddEventHandler(RES .. ':itemCount', function(name, count) Bridge.emit('itemCount', name, tonumber(count) or 0) end)
    if RES ~= 'ox_inventory' then
        AddEventHandler('ox_inventory:itemCount', function(name, count) Bridge.emit('itemCount', name, tonumber(count) or 0) end)
    end
end

return I
