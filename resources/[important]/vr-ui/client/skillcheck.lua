local active
local seq = 0
local PRESETS = {
    easy = { areaSize = 50, speedMultiplier = 1 },
    medium = { areaSize = 40, speedMultiplier = 1.5 },
    hard = { areaSize = 25, speedMultiplier = 1.75 },
}

local function level(d)
    if type(d) == 'string' then return PRESETS[d] or PRESETS.easy end
    if type(d) == 'table' and (d.areaSize or d.speedMultiplier) then
        return { areaSize = tonumber(d.areaSize) or 50, speedMultiplier = tonumber(d.speedMultiplier) or 1 }
    end
    return PRESETS.easy
end

local function rounds(difficulty)
    if type(difficulty) == 'table' and difficulty.areaSize == nil and difficulty.speedMultiplier == nil and difficulty[1] ~= nil then
        local out = {}
        for i = 1, #difficulty do out[i] = level(difficulty[i]) end
        return out
    end
    return { level(difficulty) }
end

local function skillCheck(difficulty, inputs)
    if active then return nil end
    local list = rounds(difficulty)
    local keys = {}
    if type(inputs) == 'table' then
        for i = 1, #inputs do keys[#keys + 1] = tostring(inputs[i]):lower():sub(1, 1) end
    elseif type(inputs) == 'string' then
        keys[1] = inputs:lower():sub(1, 1)
    end
    if #keys == 0 then keys[1] = 'e' end
    active = { owner = UI.owner(), cancelled = false }
    UI.focus('skill', false, false)
    local success = true
    for i = 1, #list do
        if active.cancelled then success = false break end
        seq = seq + 1
        local p = promise.new()
        active.id = seq
        active.promise = p
        UI.send('skill:start', { id = seq, difficulty = list[i], key = keys[math.random(#keys)], inputs = keys, round = i, total = #list })
        local ok = Citizen.Await(p)
        if not ok then success = false break end
    end
    UI.send('skill:stop')
    UI.release('skill')
    active = nil
    return success
end

local function cancel()
    if not active then return end
    active.cancelled = true
    if active.promise then active.promise:resolve(false) end
end

RegisterNUICallback('skill:result', function(data, cb)
    cb(1)
    if not active or type(data) ~= 'table' or data.id ~= active.id or not active.promise then return end
    local p = active.promise
    active.promise = nil
    p:resolve(data.success == true)
end)

UI.onOwnerStop(function(resource)
    if active and active.owner == resource then cancel() end
end)

exports('skillCheck', skillCheck)
exports('skillCheckActive', function() return active ~= nil end)
exports('cancelSkillCheck', cancel)
