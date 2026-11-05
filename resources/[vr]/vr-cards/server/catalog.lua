Catalog = { byId = {}, bySet = {}, totals = {} }

function Catalog.build()
    Catalog.byId, Catalog.bySet, Catalog.totals = {}, {}, {}
    for _, c in ipairs(Cards.List) do
        if Cards.Sets[c.set] and Config.Rarities[c.rarity] then
            Catalog.byId[c.id] = c
            local s = Catalog.bySet[c.set]
            if not s then s = {} Catalog.bySet[c.set] = s end
            s[c.rarity] = s[c.rarity] or {}
            table.insert(s[c.rarity], c)
            Catalog.totals[c.set] = (Catalog.totals[c.set] or 0) + 1
        else
            print(('^3[vr-cards] card %s skipped: unknown set or rarity^0'):format(tostring(c.id)))
        end
    end
end

function Catalog.get(id)
    return type(id) == 'string' and Catalog.byId[id] or nil
end

function Catalog.view(c)
    local set = Cards.Sets[c.set]
    return {
        id = c.id, set = set.code, setId = c.set, setLabel = set.label, year = set.year, number = c.number, total = Catalog.totals[c.set] or 0,
        name = c.name, title = c.title, group = c.group, rarity = c.rarity, image = c.image, quote = c.quote,
    }
end

function Catalog.meta()
    return { rarities = Config.Rarities, groups = Config.Groups, foils = Config.Foils.labels, grades = Config.Grading.names, company = Config.Grading.company, companyName = Config.Grading.companyName }
end

function Catalog.setList()
    local out = {}
    for id, s in pairs(Cards.Sets) do out[#out + 1] = { id = id, code = s.code, label = s.label, total = Catalog.totals[id] or 0 } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

Catalog.build()
