Security = {}

local HUGE = math.huge
local cooldowns = {}

function Security.onCooldown(key, src)
    local list = cooldowns[key]
    local ends = list and list[src]
    return ends ~= nil and GetGameTimer() < ends
end

function Security.startCooldown(key, src, seconds)
    local list = cooldowns[key]
    if not list then
        list = {}
        cooldowns[key] = list
    end
    list[src] = GetGameTimer() + math.floor((tonumber(seconds) or 0) * 1000)
end

function Security.cooldown(key, src, seconds)
    if Security.onCooldown(key, src) then return false end
    Security.startCooldown(key, src, seconds)
    return true
end

function Security.clearSource(src)
    for _, list in pairs(cooldowns) do list[src] = nil end
end

function Security.int(value, min, max)
    if type(value) ~= 'number' or value ~= value or value == HUGE or value == -HUGE then return nil end
    if value ~= math.floor(value) then return nil end
    value = math.floor(value)
    if min and value < min then return nil end
    if max and value > max then return nil end
    return value
end

function Security.text(value, maxLen, truncate)
    if type(value) ~= 'string' then return nil end
    if #value > 8192 then
        if not truncate then return nil end
        value = value:sub(1, 8192)
    end
    if not utf8.len(value) then value = value:gsub('[\128-\255]', '') end

    value = value
        :gsub('%c', ' ')
        :gsub('\194[\128-\159]', '')
        :gsub('\226\128[\139-\143]', '')
        :gsub('\226\128[\168-\174]', '')
        :gsub('\226\129[\160-\175]', '')
        :gsub('\239\187\191', '')
        :gsub('%s+', ' ')
    value = value:match('^%s*(.-)%s*$')

    if value == '' then return nil end
    if maxLen and utf8.len(value) > maxLen then
        if not truncate then return nil end
        value = value:sub(1, utf8.offset(value, maxLen + 1) - 1):match('^(.-)%s*$')
    end
    return value
end

function Security.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Security.distanceTo(src, point)
    local c = Security.coords(src)
    if not c or not point then return nil end
    local dx, dy, dz = c.x - point.x, c.y - point.y, c.z - point.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function Security.distance(a, b)
    local cb = Security.coords(b)
    return cb and Security.distanceTo(a, cb) or nil
end

function Security.target(src, target, maxDist)
    target = Security.int(target, 1)
    if not target or target == src then return nil end
    if not GetPlayerName(target) then return nil end
    local tPlayer = getPlayer(target)
    if not tPlayer then return nil end
    if maxDist then
        local dist = Security.distance(src, target)
        if not dist or dist > maxDist then return nil end
    end
    return target, tPlayer
end

function Security.flag(src, what)
    print(('^3[vr-policejob] rejected %s from %s (%s)^7'):format(tostring(what), tostring(src), tostring(GetPlayerName(src))))
end
