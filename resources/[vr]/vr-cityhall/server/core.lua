Core = {}

local last = {}

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
        job = job.name,
        grade = tonumber(job.grade) or 0,
    }
end

function Core.notify(src, text, kind)
    if not src then return end
    Bridge.notify(src, text, kind or 'inform', nil, 'City Hall')
end

function Core.throttle(src, key, seconds)
    local now = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and now - last[id] < seconds * 1000 then return true end
    last[id] = now
    return false
end

function Core.deskNear(src)
    local me = Bridge.coords(src)
    if not me then return nil end
    for _, d in ipairs(Config.Desks) do
        if #(vector3(me.x, me.y, me.z) - vector3(d.coords.x, d.coords.y, d.coords.z)) <= Config.DeskRange then return d end
    end
    return nil
end

function Core.money(src)
    return { cash = Bridge.money(src, 'cash'), bank = Bridge.money(src, 'bank') }
end

function Core.charge(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local paid = Bridge.pay(src, amount, reason)
    if not paid then return false end
    if Config.Society and Config.Society ~= '' then
        pcall(Bridge.society.add, Config.Society, amount, reason)
    end
    return true
end

function Core.refund(src, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.addMoney(src, 'bank', amount, reason)
end

function Core.licences(cid)
    if not Bridge.licences or not Bridge.licences.get then return {} end
    local ok, held = pcall(Bridge.licences.get, cid)
    if ok and type(held) == 'table' then return held end
    return {}
end

function Core.setLicence(cid, name, value)
    if not Bridge.licences or not Bridge.licences.set then return false end
    local ok, done = pcall(Bridge.licences.set, cid, name, value == true)
    return ok and done ~= false
end

function Core.countItem(src, item)
    return tonumber(Bridge.inventory.count(src, item)) or 0
end

function Core.itemExists(item)
    local ok, found = pcall(Bridge.inventory.itemExists, item)
    return ok and found == true
end

AddEventHandler('playerDropped', function()
    local prefix = ('%s:'):format(source)
    for id in pairs(last) do
        if id:sub(1, #prefix) == prefix then last[id] = nil end
    end
end)
