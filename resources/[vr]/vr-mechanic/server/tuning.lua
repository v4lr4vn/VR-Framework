Tuning = {}

local T = Config.Tuning
local P = T.prices
local PERF, BODY = {}, {}
for _, p in ipairs(T.performance) do PERF[p.key] = p end
for _, b in ipairs(T.bodyMods) do BODY[b.key] = b end

local function int(v, lo, hi)
    v = tonumber(v)
    if not v or v ~= v or v % 1 ~= 0 or v < lo or v > hi then return nil end
    return math.floor(v)
end

local function bool(v)
    if v == true or v == false then return v end
    return nil
end

local function rgb(v)
    if type(v) ~= 'table' then return nil end
    local r, g, b = int(v[1], 0, 255), int(v[2], 0, 255), int(v[3], 0, 255)
    if not (r and g and b) then return nil end
    return { r, g, b }
end

local function neons(v)
    if type(v) ~= 'table' then return nil end
    local out = {}
    for i = 1, 4 do
        local b = v[i]
        if b ~= true and b ~= false then return nil end
        out[i] = b
    end
    return out
end

local function xenon(v)
    v = tonumber(v)
    if v == 255 or v == -1 then return 255 end
    return int(v, 0, 12)
end

local COSMETIC = {
    color1 = { group = 'paint', label = 'Primary paint', check = rgb },
    color2 = { group = 'paint', label = 'Secondary paint', check = rgb },
    paintType1 = { group = 'paintType', label = 'Primary finish', check = function(v) return int(v, 0, 5) end },
    paintType2 = { group = 'paintType', label = 'Secondary finish', check = function(v) return int(v, 0, 5) end },
    pearlescentColor = { group = 'pearl', label = 'Pearlescent', check = function(v) return int(v, 0, 160) end },
    wheelColor = { group = 'wheelColor', label = 'Wheel colour', check = function(v) return int(v, 0, 160) end },
    wheels = { group = 'wheels', label = 'Wheels', check = function(v) return int(v, 0, 12) end, once = true },
    modFrontWheels = { group = 'wheels', label = 'Wheels', check = function(v) return int(v, -1, 300) end, once = true },
    modBackWheels = { group = 'wheels', label = 'Wheels', check = function(v) return int(v, -1, 300) end, once = true },
    modCustomTiresF = { group = 'wheels', label = 'Wheels', check = bool, once = true },
    windowTint = { group = 'windowTint', label = 'Window tint', check = function(v) return int(v, -1, 6) end },
    plateIndex = { group = 'plateIndex', label = 'Plate style', check = function(v) return int(v, 0, 5) end },
    neonEnabled = { group = 'neon', label = 'Neon kit', check = neons },
    neonColor = { group = 'neonColor', label = 'Neon colour', check = rgb },
    modXenon = { group = 'xenon', label = 'Xenon lights', check = bool },
    xenonColor = { group = 'xenonColor', label = 'Xenon colour', check = xenon },
    modLivery = { group = 'livery', label = 'Livery', check = function(v) return int(v, -1, 80) end, once = true },
    livery = { group = 'livery', label = 'Livery', check = function(v) return int(v, -1, 80) end, once = true },
}

local KEEP = { color1 = true, color2 = true, paintType1 = true, paintType2 = true, pearlescentColor = true, wheelColor = true }

local function clean(key, value, cosmetic)
    local perf = PERF[key]
    if perf then
        if cosmetic then return nil end
        if perf.toggle then
            local b = bool(value)
            if b == nil then return nil end
            return b, b and (perf.price or 0) or 0, b and perf.label or ('Remove ' .. perf.label:lower())
        end
        local lvl = int(value, -1, #perf.levels - 2)
        if not lvl then return nil end
        return lvl, perf.levels[lvl + 2] or 0, lvl < 0 and ('%s stock'):format(perf.label) or ('%s level %d'):format(perf.label, lvl + 1)
    end
    local body = BODY[key]
    if body then
        local v = int(value, -1, 100)
        if not v then return nil end
        local price = key == 'modHorns' and P.horn or P.body
        return v, v < 0 and 0 or price, body.label
    end
    local c = COSMETIC[key]
    if c then
        local v = c.check(value)
        if v == nil then return nil end
        return v, P[c.group] or 0, c.label, c.once and c.group or nil
    end
    return nil
end

function Tuning.quote(changes, keep, cosmetic)
    if type(changes) ~= 'table' then return false, 'bad_changes' end
    local out, items, total, n, seen = {}, {}, 0, 0, {}
    for key, value in pairs(changes) do
        if type(key) ~= 'string' then return false, 'bad_changes' end
        n = n + 1
        if n > T.maxChanges then return false, 'bad_changes' end
        local v, price, label, once = clean(key, value, cosmetic)
        if v == nil then return false, 'bad_changes', { key = key } end
        out[key] = v
        if once then
            if not seen[once] then
                seen[once] = true
                items[#items + 1] = { key = key, label = label, price = price }
                total = total + price
            end
        else
            items[#items + 1] = { key = key, label = label, price = price }
            total = total + price
        end
    end
    if n == 0 then return false, 'nothing_to_do' end
    table.sort(items, function(a, b) return a.label < b.label end)
    local kept = {}
    if type(keep) == 'table' then
        for key, value in pairs(keep) do
            if KEEP[key] and out[key] == nil then
                local v = clean(key, value)
                if v ~= nil then kept[key] = v end
            end
        end
    end
    return true, { items = items, total = math.floor(total), changes = out, keep = kept }
end

function Tuning.propsFor(task, changes, keep)
    local props = {}
    for _, k in ipairs(task.keys) do
        if changes[k] ~= nil then props[k] = changes[k] end
    end
    keep = keep or {}
    if task.id == 'paint1' then
        if props.paintType1 == nil and keep.paintType1 ~= nil then props.paintType1 = keep.paintType1 end
        local pearl = changes.pearlescentColor
        if pearl == nil then pearl = keep.pearlescentColor end
        if pearl ~= nil then props.pearlescentColor = pearl end
    elseif task.id == 'paint2' then
        if props.paintType2 == nil and keep.paintType2 ~= nil then props.paintType2 = keep.paintType2 end
    elseif task.id == 'wheels' and props.wheels == nil and changes.wheels ~= nil then
        props.wheels = changes.wheels
    end
    return props
end

function Tuning.apply(veh, props)
    exports['vr-lib']:setVehicleProperties(veh, props)
    local plate = Cars.plate(veh)
    if plate then Cars.saveMods(plate, props) end
    return plate
end
