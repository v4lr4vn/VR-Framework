local bySign, byItem = {}, {}
for i, sign in ipairs(Config.Signs) do
    sign.hash = joaat(sign.model)
    sign.index = i
    bySign[i] = sign
    byItem[sign.item] = sign
end

local taken = {}        -- signs removed from the world: { coords, model }
local open = {}         -- [src] = theft in progress
local lastTheft = {}    -- [src] = game time of the last completed theft
local perHour = {}      -- [cid] = list of theft times
local scrapping = {}    -- [src] = true while a scrap is processed

local function clock() return GetGameTimer() end

local function vec(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' then return nil end
    local x, y, z = tonumber(c.x), tonumber(c.y), tonumber(c.z)
    if not x or not y or not z or x ~= x or y ~= y or z ~= z then return nil end
    return vector3(x + 0.0, y + 0.0, z + 0.0)
end

local function removedAlready(hash, at)
    for i = 1, #taken do
        if taken[i].model == hash and #(taken[i].coords - at) < 1.5 then return true end
    end
    return false
end

local function thefts(cid)
    local list, kept = perHour[cid] or {}, {}
    local t = clock()
    for i = 1, #list do if t - list[i] < 3600000 then kept[#kept + 1] = list[i] end end
    perHour[cid] = kept
    return #kept
end

local function near(src, at, dist)
    local pos = Bridge.coords(src)
    return pos and #(vector3(pos.x, pos.y, pos.z) - at) <= dist
end

lib.callback.register('vr-signrobbery:begin', function(src, index, at)
    local player = Bridge.player(src)
    local sign = bySign[tonumber(index) or 0]
    at = vec(at)
    if not player or not sign or not at then return false end
    if not near(src, at, Config.Steal.distance + 1.0) then return false end
    if removedAlready(sign.hash, at) then return false, 'gone' end

    local cur = open[src]
    if cur and clock() - cur.started < cur.duration + 15000 then return false end
    if lastTheft[src] and clock() - lastTheft[src] < Config.Steal.cooldown * 1000 then return false, 'cooldown' end
    if thefts(player.cid) >= Config.Steal.maxPerHour then return false, 'limit' end
    if not Bridge.inventory.canCarry(src, sign.item, 1) then return false, 'full' end

    local duration = math.random(Config.Steal.time[1], Config.Steal.time[2])
    open[src] = { sign = sign, at = at, started = clock(), duration = duration }
    return true, duration
end)

lib.callback.register('vr-signrobbery:abort', function(src)
    open[src] = nil
    return true
end)

local function alert(at, sign)
    if not Config.Dispatch.enabled or math.random() > Config.Dispatch.chance then return end
    if GetResourceState('vr-mdt') ~= 'started' then return end
    pcall(function()
        exports['vr-mdt']:SendAlert({
            message = 'Sign Theft', codeName = 'signrobbery', code = '10-10', icon = 'fas fa-triangle-exclamation',
            priority = 2, coords = at, information = sign.label .. ' being stolen', jobs = { 'leo' },
        })
    end)
end

lib.callback.register('vr-signrobbery:complete', function(src)
    local job = open[src]
    open[src] = nil
    if not job or clock() - job.started < job.duration - 500 then return false end
    local player = Bridge.player(src)
    if not player or not near(src, job.at, Config.Steal.distance + 1.0) then return false end
    if removedAlready(job.sign.hash, job.at) then return false, 'gone' end
    if not Bridge.inventory.add(src, job.sign.item, 1) then return false, 'full' end

    taken[#taken + 1] = { coords = job.at, model = job.sign.hash }
    lastTheft[src] = clock()
    perHour[player.cid] = perHour[player.cid] or {}
    table.insert(perHour[player.cid], clock())

    TriggerClientEvent('vr-signrobbery:client:gone', -1, { coords = job.at, model = job.sign.hash })
    alert(job.at, job.sign)
    return true
end)

lib.callback.register('vr-signrobbery:list', function() return taken end)

lib.callback.register('vr-signrobbery:count', function(src, item)
    return tonumber(Bridge.inventory.count(src, item)) or 0
end)

lib.callback.register('vr-signrobbery:scrap', function(src, item)
    local sign = byItem[item]
    if not sign or scrapping[src] then return false end
    if not near(src, Config.Scrap.coords, Config.Scrap.distance) then return false end
    if (tonumber(Bridge.inventory.count(src, sign.item)) or 0) < 1 then return false end

    scrapping[src] = true
    local rewards = {}
    for _ = 1, math.random(Config.Scrap.rolls[1], Config.Scrap.rolls[2]) do
        local name = Config.Scrap.items[math.random(1, #Config.Scrap.items)]
        rewards[name] = (rewards[name] or 0) + math.random(Config.Scrap.amount[1], Config.Scrap.amount[2])
    end

    local fits, any = {}, false
    for name, n in pairs(rewards) do
        if Bridge.inventory.canCarry(src, name, n) then fits[name] = n any = true end
    end
    if not any then
        scrapping[src] = nil
        Bridge.notify(src, "You can't carry the materials", 'error')
        return false
    end
    if not Bridge.inventory.remove(src, sign.item, 1) then
        scrapping[src] = nil
        return false
    end
    local gave = false
    for name, n in pairs(fits) do
        if Bridge.inventory.add(src, name, n) then gave = true end
    end
    scrapping[src] = nil
    return gave
end)

for _, sign in ipairs(Config.Signs) do
    Bridge.useItem(sign.item, function(src)
        TriggerClientEvent('vr-signrobbery:client:hold', src, sign.index)
    end)
end

AddEventHandler('playerDropped', function()
    local src = source
    open[src], lastTheft[src], scrapping[src] = nil, nil, nil
end)
