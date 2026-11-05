Core = {}

local last = {}
local alerted = {}

function Core.info(src)
    src = tonumber(src)
    if not src then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    local job = p.job or {}
    return {
        src = src,
        cid = p.cid,
        name = p.name or 'Citizen',
        job = job.name or Config.FallbackJob,
        grade = tonumber(job.grade) or 0,
        onduty = job.onduty == true,
    }
end

function Core.notify(src, text, kind, title)
    if not src or src <= 0 then return print(('[vr-civjobs] %s'):format(tostring(text))) end
    Bridge.notify(src, text, kind or 'inform', nil, title or 'Civilian work')
end

function Core.throttle(src, key, ms)
    ms = tonumber(ms) or 0
    if ms <= 0 then return false end
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < ms then return true end
    last[id] = now
    return false
end

function Core.near(src, coords, radius)
    local p = Bridge.coords(src)
    if not p or not coords then return false, nil end
    local d = Civ.dist(p, coords)
    return d <= radius, d
end

function Core.defined(def)
    if not Config.RequireJob then return false end
    local jobs = Bridge.jobs() or {}
    return jobs[def.job] ~= nil
end

function Core.qualifies(info, def)
    if not Core.defined(def) then return true end
    return info.job == def.job
end

function Core.pay(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.addMoney(src, Config.Account, amount, reason or 'Civilian work') == true
end

function Core.give(src, item, count)
    count = math.floor(tonumber(count) or 0)
    if count <= 0 then return false end
    if Bridge.inventory.itemExists and not Bridge.inventory.itemExists(item) then return false end
    if Bridge.inventory.canCarry and not Bridge.inventory.canCarry(src, item, count) then return false, 'full' end
    return Bridge.inventory.add(src, item, count) ~= false
end

function Core.count(src, item)
    return tonumber(Bridge.inventory.count(src, item)) or 0
end

function Core.take(src, item, count)
    return Bridge.inventory.remove(src, item, count) ~= false
end

function Core.alert(src, title, text, coords)
    local cfg = Config.Police
    if not cfg.enabled then return false end
    local t = os.time()
    if alerted[src] and t - alerted[src] < cfg.cooldownSeconds then return false end
    if GetResourceState('vr-mdt') ~= 'started' then return false end
    local me = coords or Bridge.coords(src)
    if not me then return false end
    alerted[src] = t
    return (pcall(function()
        exports['vr-mdt']:SendAlert({
            codeName = 'custom',
            title = title,
            description = text,
            priority = 2,
            coords = { x = me.x, y = me.y, z = me.z },
            jobs = cfg.jobs,
        }, src)
    end))
end

function Core.weighted(list, luck)
    local total = 0
    for i = 1, #list do total = total + (list[i].weight or 1) end
    local roll = math.random() * total
    for i = 1, #list do
        roll = roll - (list[i].weight or 1)
        if roll <= 0 then return list[i], i end
    end
    return list[#list], #list
end

function Core.between(range)
    if type(range) ~= 'table' then return tonumber(range) or 0 end
    return math.random(range[1], range[2] or range[1])
end

function Core.num(v, min, max)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if min and v < min then return nil end
    if max and v > max then return nil end
    return v
end

function Core.vec(t)
    if type(t) ~= 'table' then return nil end
    local x, y, z = Core.num(t.x), Core.num(t.y), Core.num(t.z)
    if not x or not y or not z then return nil end
    return vec3(x, y, z)
end

AddEventHandler('playerDropped', function()
    local src = source
    alerted[src] = nil
    local prefix = ('%s:'):format(src)
    for id in pairs(last) do
        if id:sub(1, #prefix) == prefix then last[id] = nil end
    end
end)

function Core.sellAll(info, jobId, prices, only)
    local level = Progress.level(info.cid, jobId)
    local mult = Civ.mult(level)
    local total, lines = 0, {}
    for item, price in pairs(prices) do
        if not only or only[item] then
            local have = Core.count(info.src, item)
            if have > 0 and Core.take(info.src, item, have) then
                local value = math.floor(have * price * mult)
                total = total + value
                lines[#lines + 1] = { item = item, count = have, value = value }
            end
        end
    end
    table.sort(lines, function(a, b) return a.item < b.item end)
    if total > 0 then
        Core.pay(info.src, total, 'Sold goods')
        Progress.record(info.cid, jobId, total, 0)
    end
    return total, lines
end

function Core.carried(info, prices)
    local out = {}
    for item, price in pairs(prices) do
        local have = Core.count(info.src, item)
        if have > 0 then
            out[#out + 1] = { item = item, label = Bridge.inventory.label and Bridge.inventory.label(item) or item, count = have, price = price }
        end
    end
    table.sort(out, function(a, b) return a.item < b.item end)
    return out
end
