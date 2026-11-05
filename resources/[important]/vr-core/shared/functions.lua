local VRCore = VRCore
local Shared = VRCore.Shared
local random, char, concat = math.random, string.char, table.concat

Shared.StarterItems = {
    phone          = { amount = 1, item = 'phone' },
    id_card        = { amount = 1, item = 'id_card' },
    driver_license = { amount = 1, item = 'driver_license' },
}

function Shared.RandomStr(length)
    local out = {}
    for i = 1, length do
        local n = random(1, 52)
        out[i] = char(n <= 26 and 64 + n or 70 + n)
    end
    return concat(out)
end

function Shared.RandomInt(length)
    local out = {}
    for i = 1, length do out[i] = char(random(48, 57)) end
    return concat(out)
end

function Shared.SplitStr(str, delimiter)
    local result, from = {}, 1
    local dFrom, dTo = string.find(str, delimiter, from)
    while dFrom do
        result[#result + 1] = string.sub(str, from, dFrom - 1)
        from = dTo + 1
        dFrom, dTo = string.find(str, delimiter, from)
    end
    result[#result + 1] = string.sub(str, from)
    return result
end

function Shared.Trim(value)
    if not value then return nil end
    return (string.gsub(value, '^%s*(.-)%s*$', '%1'))
end

function Shared.FirstToUpper(value)
    if not value then return nil end
    return (value:gsub('^%l', string.upper))
end

function Shared.Round(value, numDecimalPlaces)
    if not numDecimalPlaces then return math.floor(value + 0.5) end
    local power = 10 ^ numDecimalPlaces
    return math.floor((value * power) + 0.5) / power
end

function Shared.IsFunction(value)
    local t = type(value)
    if t == 'function' then return true end
    return t == 'table' and type(rawget(value, '__cfx_functionReference')) == 'string'
end

function Shared.ChangeVehicleExtra(vehicle, extra, enable)
    if not DoesExtraExist(vehicle, extra) then return end
    enable = not not enable
    for _ = 1, 3 do
        SetVehicleExtra(vehicle, extra, not enable)
        if (not not IsVehicleExtraTurnedOn(vehicle, extra)) == enable then return end
    end
end

function Shared.SetDefaultVehicleExtras(vehicle, config)
    for i = 1, 20 do
        if DoesExtraExist(vehicle, i) then SetVehicleExtra(vehicle, i, true) end
    end
    for id, enabled in pairs(config) do
        Shared.ChangeVehicleExtra(vehicle, tonumber(id), type(enabled) ~= 'boolean' or enabled)
    end
end

function Shared.GetGroupsFromData(pd)
    local groups = {}
    local job, gang = pd and pd.job, pd and pd.gang
    if job and job.name then groups[job.name] = job.grade and tonumber(job.grade.level) or 0 end
    if gang and gang.name and gang.name ~= 'none' then groups[gang.name] = gang.grade and tonumber(gang.grade.level) or 0 end
    return groups
end

function Shared.MatchGroup(groups, filter)
    local t = type(filter)
    if t == 'string' then
        local grade = groups[filter]
        if grade then return filter, grade end
    elseif t == 'table' then
        if filter[1] ~= nil then
            for i = 1, #filter do
                local grade = groups[filter[i]]
                if grade then return filter[i], grade end
            end
        else
            for name, minGrade in pairs(filter) do
                local grade = groups[name]
                if grade and grade >= (tonumber(minGrade) or 0) then return name, grade end
            end
        end
    end
end

local function set(...)
    local t = {}
    for _, range in ipairs({ ... }) do
        if type(range) == 'table' then
            for i = range[1], range[2] do t[i] = true end
        else
            t[range] = true
        end
    end
    return t
end

Shared.MaleNoGloves   = set({ 0, 15 }, 18, 26, { 52, 62 }, 112, 113, 114, 118, 125, 132)
Shared.FemaleNoGloves = set({ 0, 15 }, 19, { 59, 71 }, 129, 130, 131, 135, 142, 149, 153, 157, 161, 165)

local function tPrint(tbl, indent)
    indent = indent or 0
    if type(tbl) ~= 'table' then
        return print(('%s ^0%s'):format(string.rep('  ', indent), tostring(tbl)))
    end
    for k, v in pairs(tbl) do
        local t = type(v)
        local prefix = ('%s ^3%s:^0'):format(string.rep('  ', indent), k)
        if t == 'table' then
            print(prefix)
            tPrint(v, indent + 1)
        elseif t == 'boolean' then
            print(('%s ^1%s^0'):format(prefix, v))
        elseif t == 'number' then
            print(('%s ^5%s^0'):format(prefix, v))
        elseif t == 'string' then
            print(('%s ^2\'%s\'^0'):format(prefix, v))
        else
            print(('%s ^9%s^0'):format(prefix, tostring(v)))
        end
    end
end

function VRCore.Debug(tbl, indent, extra)
    if type(tbl) == 'string' and type(indent) == 'table' then tbl, indent = indent, extra end
    print(('^4[ %s : DEBUG ]^0'):format(GetInvokingResource() or GetCurrentResourceName()))
    tPrint(tbl, indent)
    print('^4[ END DEBUG ]^0')
end

function VRCore.ShowError(resource, msg)
    print(('^1[%s:ERROR]^0 %s'):format(resource, msg))
end

function VRCore.ShowSuccess(resource, msg)
    print(('^2[%s:LOG]^0 %s'):format(resource, msg))
end
