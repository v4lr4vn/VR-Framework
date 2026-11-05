Core = {}

local inv = Bridge.inventory

function Core.player(src)
    src = tonumber(src)
    if not src then return nil end
    return Bridge.player(src)
end

function Core.info(src)
    local p = Core.player(src)
    if not p then return nil end
    return { src = tonumber(src), cid = p.cid, name = p.name }
end

function Core.money(src, kind)
    return Bridge.money(src, kind)
end

function Core.take(src, amount, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.removeMoney(src, kind, amount, reason)
end

function Core.give(src, amount, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return Bridge.addMoney(src, kind, amount, reason)
end

function Core.notify(src, text, kind)
    if not src then return end
    Bridge.notify(src, text, kind or 'inform', nil, 'Cards')
end

function Core.coords(src)
    return Bridge.coords(src)
end

function Core.slots(src, item, metadata)
    local ok, r = pcall(inv.search, src, item, metadata)
    return ok and type(r) == 'table' and r or {}
end

function Core.slot(src, slot)
    local ok, r = pcall(inv.getSlot, src, slot)
    return ok and type(r) == 'table' and r or nil
end

function Core.canCarry(src, item, count)
    local ok, r = pcall(inv.canCarry, src, item, count or 1)
    return ok and r == true
end

function Core.addItem(src, item, count, metadata)
    local ok, r = pcall(inv.add, src, item, count or 1, metadata)
    return ok and r == true
end

function Core.removeSlot(src, item, slot, count)
    local ok, r = pcall(inv.remove, src, item, count or 1, nil, slot)
    return ok and r == true
end

function Core.removeWhere(src, item, metadata)
    local found = Core.slots(src, item, metadata)[1]
    if not found then return false end
    return Core.removeSlot(src, item, found.slot, 1)
end
