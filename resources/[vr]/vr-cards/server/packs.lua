Packs = {}

local ORDER = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

local function rarityFor(set, slotKind)
    local odds = Config.SlotOdds[slotKind] or Config.SlotOdds.common
    local pool = Catalog.bySet[set] or {}
    local weights = {}
    for r, w in pairs(odds) do
        if pool[r] and #pool[r] > 0 then weights[r] = w end
    end
    local r = CU.pick(weights)
    if r then return r end
    for name in pairs(pool) do return name end
    return nil
end

local function foilFor(rarity)
    local roll = math.random() * 100
    local holo = Config.Foils.holo[rarity] or 0
    if roll < holo then return 'holo' end
    if roll < holo + (Config.Foils.shiny[rarity] or 0) then return 'shiny' end
    return 'none'
end

function Packs.def(id)
    return type(id) == 'string' and Config.Packs[id] or nil
end

function Packs.roll(packId)
    local p = Packs.def(packId)
    if not p then return nil end
    local out = {}
    for _, kind in ipairs(p.slots) do
        local rarity = rarityFor(p.set, kind)
        local list = rarity and Catalog.bySet[p.set][rarity]
        if list and #list > 0 then
            local card = list[math.random(1, #list)]
            out[#out + 1] = { card = card.id, foil = foilFor(rarity), rarity = rarity }
        end
    end
    return out
end

function Packs.meta(id)
    local p = Packs.def(id)
    return { pack = id, label = p.label, description = ('%d cards from %s. Use it to open.'):format(#p.slots, Cards.Sets[p.set].label) }
end

function Packs.give(src, id, count)
    if not Packs.def(id) then return false, 'bad_pack' end
    count = math.max(1, math.min(50, math.floor(tonumber(count) or 1)))
    if not Core.canCarry(src, Config.Items.pack, count) then return false, 'cant_carry' end
    for _ = 1, count do
        if not Core.addItem(src, Config.Items.pack, 1, Packs.meta(id)) then return false, 'cant_carry' end
    end
    return true
end

function Packs.open(info, slot)
    slot = tonumber(slot)
    local item = slot and Core.slot(info.src, slot)
    if not item or item.name ~= Config.Items.pack then return false, 'no_pack' end
    local id = type(item.metadata) == 'table' and item.metadata.pack or Config.DefaultPack
    local p = Packs.def(id) or Packs.def(Config.DefaultPack)
    if not p then return false, 'no_pack' end
    id = Packs.def(id) and id or Config.DefaultPack
    local n = #p.slots
    if not Core.canCarry(info.src, Config.Items.card, n) then return false, 'no_room', { need = n } end
    local pulls = Packs.roll(id)
    if not pulls or #pulls == 0 then return false, 'empty_set' end
    if not Core.removeSlot(info.src, Config.Items.pack, slot, 1) then return false, 'no_pack' end
    local cards = {}
    for _, pull in ipairs(pulls) do
        local c = Copies.create(pull.card, pull.foil, info.cid)
        if c then
            if not Copies.give(info.src, c, info.cid) then Copies.set(c.uid, { state = 'unclaimed', holder = info.cid }) end
            local v = Copies.view(c)
            v.new = Copies.markDex(info.cid, c.card)
            cards[#cards + 1] = v
        end
    end
    table.sort(cards, function(a, b)
        local ra, rb = ORDER[a.rarity] or 0, ORDER[b.rarity] or 0
        if ra ~= rb then return ra < rb end
        local fa, fb = a.foil == 'holo' and 2 or a.foil == 'shiny' and 1 or 0, b.foil == 'holo' and 2 or b.foil == 'shiny' and 1 or 0
        return fa < fb
    end)
    TriggerEvent('vr-cards:server:packOpened', info.src, id, cards)
    return true, { pack = { id = id, label = p.label, set = Cards.Sets[p.set].label, code = Cards.Sets[p.set].code }, cards = cards, meta = Catalog.meta() }
end
