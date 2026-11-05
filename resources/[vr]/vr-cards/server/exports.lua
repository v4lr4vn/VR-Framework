local function givePack(src, pack, count)
    return Packs.give(tonumber(src), pack or Config.DefaultPack, count or 1)
end

local function giveCard(src, cardId, foil)
    src = tonumber(src)
    local info = Core.info(src)
    if not info or not Catalog.get(cardId) then return false end
    if not Core.canCarry(src, Config.Items.card, 1) then return false end
    local c = Copies.create(cardId, foil, info.cid)
    if not c then return false end
    Copies.markDex(info.cid, cardId)
    return Copies.give(src, c, info.cid), c.uid
end

local function catalog()
    local out = {}
    for _, c in ipairs(Cards.List) do
        if Catalog.get(c.id) then out[#out + 1] = Catalog.view(c) end
    end
    return out
end

local function collection(cid)
    local rows = MySQL.query.await('SELECT card FROM vr_cards_dex WHERE citizenid = ?', { cid }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = r.card end
    return out
end

exports('GivePack', givePack)
exports('GiveCard', giveCard)
exports('GetCatalog', catalog)
exports('GetCollection', collection)
exports('givePack', givePack)
exports('giveCard', giveCard)
exports('getCatalog', catalog)
exports('getCollection', collection)
