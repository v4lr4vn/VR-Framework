Shop = {}

local ITEMS = {}
for _, it in ipairs(Config.Shop.items) do ITEMS[it.item] = it end

function Shop.companyAllowed(info)
    return info.job.isboss or info.job.grade >= Config.Shop.companyGrade
end

function Shop.data(info, w)
    local items = {}
    for i, it in ipairs(Config.Shop.items) do
        items[i] = { item = it.item, label = it.label, price = it.price, have = Core.count(info.src, it.item) }
    end
    return {
        workshop = { id = w.id, label = w.label },
        items = items,
        me = {
            cash = Core.money(info.src, 'cash'),
            bank = Core.money(info.src, 'bank'),
            company = Shop.companyAllowed(info) and { label = info.job.label, balance = Core.societyBalance(info.job.name) } or nil,
        },
    }
end

function Shop.buy(info, w, item, count, payment)
    local def = ITEMS[item]
    if not def then return false, 'bad_item' end
    count = math.floor(tonumber(count) or 0)
    if count < 1 or count > 20 then return false, 'bad_count' end
    if not Core.isMechanic(info) or info.job.name ~= w.job then return false, 'not_mechanic' end
    local total = def.price * count
    if payment == 'company' then
        if not Shop.companyAllowed(info) then return false, 'not_allowed' end
        if Core.societyBalance(info.job.name) < total or not Core.removeSociety(info.job.name, total, 'mechanic-parts') then return false, 'no_company_money' end
    else
        payment = payment == 'cash' and 'cash' or 'bank'
        if not Core.take(info.src, total, payment, 'mechanic-parts') then return false, 'no_money' end
    end
    if not Core.addItem(info.src, item, count) then
        if payment == 'company' then Core.addSociety(info.job.name, total, 'mechanic-parts-refund')
        else Core.give(info.src, total, payment, 'mechanic-parts-refund') end
        return false, 'cant_carry'
    end
    return true, { item = item, count = count, total = total, have = Core.count(info.src, item) }
end
