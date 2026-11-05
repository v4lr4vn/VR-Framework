GU = {}

function GU.plate(p)
    if type(p) ~= 'string' then return nil end
    p = p:upper():gsub('^%s+', ''):gsub('%s+$', '')
    if p == '' then return nil end
    return p
end

local typeCategory = { boat = 'boat', submarine = 'boat', heli = 'air', plane = 'air', blimp = 'air' }

function GU.categoryOfType(vtype)
    return typeCategory[vtype] or 'car'
end

local classCategory = { [14] = 'boat', [15] = 'air', [16] = 'air' }

function GU.categoryOfClass(class)
    return classCategory[class] or 'car'
end

function GU.money(n)
    n = math.floor(tonumber(n) or 0)
    local s = tostring(math.abs(n)):reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (n < 0 and '-' or '') .. s
end

function GU.resolveGarage(id)
    if type(id) ~= 'string' then return nil end
    return Config.GarageAliases[id] or id
end
