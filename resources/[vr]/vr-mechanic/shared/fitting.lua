Fitting = {}

local GROUPS = {
    { id = 'paint1', label = 'Primary paint', keys = { 'color1', 'paintType1' }, work = 'paint' },
    { id = 'paint2', label = 'Secondary paint', keys = { 'color2', 'paintType2' }, work = 'paint' },
    { id = 'pearl', label = 'Pearlescent', keys = { 'pearlescentColor' }, work = 'paint' },
    { id = 'livery', label = 'Livery', keys = { 'livery', 'modLivery' }, work = 'paint' },
    { id = 'wheels', label = 'Wheels', keys = { 'wheels', 'modFrontWheels', 'modBackWheels', 'modCustomTiresF' }, work = 'wheel' },
    { id = 'wheelColor', label = 'Wheel colour', keys = { 'wheelColor' }, work = 'paint' },
    { id = 'neon', label = 'Neon kit', keys = { 'neonEnabled', 'neonColor' }, work = 'under' },
    { id = 'xenon', label = 'Xenon lights', keys = { 'modXenon', 'xenonColor' }, work = 'lights' },
    { id = 'windowTint', label = 'Window tint', keys = { 'windowTint' }, work = 'glass' },
    { id = 'plateIndex', label = 'Plate', keys = { 'plateIndex' }, work = 'rear' },
    { id = 'modHorns', label = 'Horn', keys = { 'modHorns' }, work = 'engine' },
}

local PERF_WORK = { modEngine = 'engine', modTransmission = 'engine', modTurbo = 'engine', modBrakes = 'wheel', modSuspension = 'under', modArmor = 'body' }

local function perfLabel(p, v)
    if p.toggle then return v and p.label or ('Remove ' .. p.label:lower()) end
    return v < 0 and ('%s stock'):format(p.label) or ('%s level %d'):format(p.label, v + 1)
end

function Fitting.tasks(changes)
    local out, used = {}, {}
    for _, p in ipairs(Config.Tuning.performance) do
        if changes[p.key] ~= nil then
            used[p.key] = true
            out[#out + 1] = { id = p.key, label = perfLabel(p, changes[p.key]), keys = { p.key }, work = PERF_WORK[p.key] or 'engine' }
        end
    end
    for _, g in ipairs(GROUPS) do
        local keys = {}
        for _, k in ipairs(g.keys) do
            if changes[k] ~= nil then
                keys[#keys + 1] = k
                used[k] = true
            end
        end
        if #keys > 0 then out[#out + 1] = { id = g.id, label = g.label, keys = keys, work = g.work } end
    end
    for _, b in ipairs(Config.Tuning.bodyMods) do
        if changes[b.key] ~= nil and not used[b.key] then
            used[b.key] = true
            out[#out + 1] = { id = b.key, label = b.label, keys = { b.key }, work = 'body' }
        end
    end
    for i, t in ipairs(out) do
        t.seconds = Config.FitSeconds[t.work] or 10
        t.n = i
    end
    return out
end

function Fitting.price(task, items)
    local set, total = {}, 0
    for _, k in ipairs(task.keys) do set[k] = true end
    for _, it in ipairs(items) do
        if set[it.key] then total = total + (it.price or 0) end
    end
    return total
end
