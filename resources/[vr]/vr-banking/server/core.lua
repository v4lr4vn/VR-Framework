Core = {}

local inv = Bridge.inventory

function Core.nameOf(p)
    return type(p) == 'table' and p.name or 'Unknown'
end

function Core.player(src)
    src = tonumber(src)
    if not src then return nil end
    return Bridge.player(src)
end

function Core.data(src)
    return Core.player(src)
end

function Core.cid(src)
    return Bridge.cid(tonumber(src))
end

function Core.online(cid)
    if type(cid) ~= 'string' then return nil end
    return Bridge.playerByCid(cid)
end

function Core.sourceOf(cid)
    if type(cid) ~= 'string' then return nil end
    return Bridge.source(cid)
end

function Core.info(src)
    local p = Core.player(src)
    if not p then return nil end
    local job, gang = p.job or {}, p.gang or {}
    return {
        src = tonumber(src),
        cid = p.cid,
        name = p.name,
        cash = p.money and p.money.cash or 0,
        bank = p.money and p.money.bank or 0,
        job = { name = job.name, label = job.label, grade = tonumber(job.grade) or 0, isboss = job.isboss == true, onduty = job.onduty == true },
        gang = { name = gang.name, label = gang.label, grade = tonumber(gang.grade) or 0, isboss = gang.isboss == true },
    }
end

function Core.nameByCid(cid)
    return Bridge.chars.name(cid)
end

function Core.exists(cid)
    if Core.online(cid) then return true end
    return Bridge.chars.exists ~= nil and Bridge.chars.exists(cid) == true
end

function Core.cash(src)
    return Bridge.money(src, 'cash')
end

function Core.addCash(src, amount, reason)
    return Bridge.addMoney(src, 'cash', amount, reason)
end

function Core.removeCash(src, amount, reason)
    return Bridge.removeMoney(src, 'cash', amount, reason)
end

function Core.bank(cid)
    return Bridge.chars.bank(cid)
end

function Core.addBank(cid, amount, reason)
    return Bridge.chars.addBank(cid, amount, reason)
end

function Core.removeBank(cid, amount, reason)
    local src = Core.sourceOf(cid)
    if src then return Bridge.removeMoney(src, 'bank', amount, reason) end
    return Bridge.chars.takeBank(cid, amount, reason)
end

function Core.setDuty(src, on)
    return Bridge.setDuty(src, on == true)
end

function Core.societyBalance(name)
    return Bridge.society.balance(name)
end

function Core.addSociety(name, amount, reason)
    return Bridge.society.add(name, amount, reason)
end

function Core.removeSociety(name, amount, reason)
    return Bridge.society.remove(name, amount, reason)
end

function Core.jobLabel(name)
    return Bridge.groupLabel(name, 'job')
end

function Core.gangLabel(name)
    return Bridge.groupLabel(name, 'gang')
end

function Core.isJob(name)
    return Bridge.isJob(name)
end

function Core.isGang(name)
    return Bridge.isGang(name)
end

function Core.vehiclePrice(model)
    local v = Bridge.vehicleData(model)
    return v and tonumber(v.price) or 0
end

function Core.vehicleName(model)
    if Bridge.vehicleData(model) then return Bridge.vehicleLabel(model) end
    return model
end

function Core.notify(src, text, kind, title)
    if not src then return end
    Bridge.notify(src, text, kind or 'inform', nil, title or Config.BankName)
end

function Core.coords(src)
    return Bridge.coords(src)
end

function Core.cards(src)
    local out = {}
    for _, slot in ipairs(inv.search(src, Config.CardItem)) do
        local md = slot.metadata
        if type(md) == 'table' and md.cardId then out[#out + 1] = { slot = slot.slot, metadata = md } end
    end
    return out
end

function Core.giveCard(src, metadata)
    if not inv.canCarry(src, Config.CardItem, 1, metadata) then return false end
    return inv.add(src, Config.CardItem, 1, metadata)
end

function Core.takeCard(src, slot)
    return inv.remove(src, Config.CardItem, 1, nil, slot)
end
