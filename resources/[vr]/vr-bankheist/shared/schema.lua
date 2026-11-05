BH = BH or {}

BH.typeOrder = { 'hack', 'drill', 'cash', 'gold', 'till', 'case', 'door' }

BH.types = {
    hack = {
        label = 'Hack terminal',
        icon = 'fa-terminal',
        color = { 90, 169, 255 },
        r = 1.6,
        hint = 'Players connect a laptop here and hack the bank network',
        fields = {
            { key = 'host', label = 'Host name', kind = 'text', max = 30, default = 'FLEECA-VAULT-01', hint = 'Shown in the terminal' },
            { key = 'tier', label = 'Security tier', kind = 'number', min = 1, max = 5, default = 2, hint = '1 Bronze Ward up to 5 Aegis' },
            { key = 'goal', label = 'Goal', kind = 'choice', options = { 'vault', 'alarm' }, default = 'vault', hint = 'vault completes the step, alarm silences the police alert' },
        },
    },
    drill = {
        label = 'Lock box',
        icon = 'fa-screwdriver-wrench',
        color = { 245, 165, 36 },
        r = 1.4,
        hint = 'Players drill the box open for cash and loot',
        fields = {
            { key = 'seconds', label = 'Drill time (s)', kind = 'number', min = 8, max = 180, default = 28 },
            { key = 'difficulty', label = 'Difficulty', kind = 'number', min = 1, max = 3, default = 2, hint = 'How fast the drill overheats' },
            { key = 'cashMin', label = 'Cash min', kind = 'number', min = 0, max = 500000, default = 1500 },
            { key = 'cashMax', label = 'Cash max', kind = 'number', min = 0, max = 500000, default = 4500 },
            { key = 'item', label = 'Bonus item', kind = 'text', max = 40, default = '', hint = 'Item name, leave empty for none' },
            { key = 'itemMin', label = 'Item min', kind = 'number', min = 1, max = 50, default = 1 },
            { key = 'itemMax', label = 'Item max', kind = 'number', min = 1, max = 50, default = 1 },
            { key = 'itemChance', label = 'Item chance %', kind = 'number', min = 0, max = 100, default = 25 },
        },
    },
    cash = {
        label = 'Cash area',
        icon = 'fa-money-bill-wave',
        color = { 61, 214, 140 },
        r = 1.5,
        radius = true,
        hint = 'Aim at the counter. A row of cash stacks appears there and players grab from it',
        fields = {
            { key = 'grabs', label = 'Grabs', kind = 'number', min = 1, max = 60, default = 8, hint = 'Total grabs before the area is empty' },
            { key = 'cashMin', label = 'Cash min', kind = 'number', min = 0, max = 100000, default = 700 },
            { key = 'cashMax', label = 'Cash max', kind = 'number', min = 0, max = 100000, default = 1600 },
            { key = 'model', label = 'Pile prop', kind = 'text', max = 50, default = 'prop_cash_pile_01', presets = { 'prop_cash_pile_01', 'prop_cash_pile_02', 'bkr_prop_money_sorted_01', 'bkr_prop_money_unsorted_01', 'prop_money_bag_01' } },
        },
    },
    gold = {
        label = 'Gold area',
        icon = 'fa-gem',
        color = { 255, 200, 92 },
        r = 1.5,
        radius = true,
        hint = 'Aim at the counter. A row of gold bars appears there and players grab from it',
        fields = {
            { key = 'grabs', label = 'Grabs', kind = 'number', min = 1, max = 40, default = 6 },
            { key = 'barsMin', label = 'Bars min', kind = 'number', min = 1, max = 10, default = 1 },
            { key = 'barsMax', label = 'Bars max', kind = 'number', min = 1, max = 10, default = 2 },
            { key = 'model', label = 'Bar prop', kind = 'text', max = 50, default = 'ch_prop_gold_bar_01a', presets = { 'ch_prop_gold_bar_01a', 'h4_prop_h4_gold_bar_01a', 'prop_gold_bar' } },
        },
    },
    till = {
        label = 'Cash register',
        icon = 'fa-cash-register',
        color = { 120, 220, 120 },
        r = 1.2,
        hint = 'Aim at the register. Players force it open once for the cash inside',
        fields = {
            { key = 'seconds', label = 'Time to force it (s)', kind = 'number', min = 3, max = 120, default = 8 },
            { key = 'cashMin', label = 'Cash min', kind = 'number', min = 0, max = 100000, default = 150 },
            { key = 'cashMax', label = 'Cash max', kind = 'number', min = 0, max = 100000, default = 450 },
            { key = 'tool', label = 'Tool needed', kind = 'text', max = 40, default = '', hint = 'Item name, leave empty for none. It is not used up' },
            { key = 'item', label = 'Bonus item', kind = 'text', max = 40, default = '', hint = 'Item name, leave empty for none' },
            { key = 'itemMin', label = 'Item min', kind = 'number', min = 1, max = 50, default = 1 },
            { key = 'itemMax', label = 'Item max', kind = 'number', min = 1, max = 50, default = 1 },
            { key = 'itemChance', label = 'Item chance %', kind = 'number', min = 0, max = 100, default = 15 },
        },
    },
    case = {
        label = 'Display case',
        icon = 'fa-ring',
        color = { 120, 210, 255 },
        r = 0.4,
        radius = true,
        rMin = 0.1,
        rMax = 3.0,
        rStep = 0.05,
        hint = 'Aim at the middle of the glass. The radius is how much of the cabinet area is swapped to broken glass, keep it small so neighbouring cases stay whole',
        fields = {
            { key = 'anim', label = 'Smash animation', kind = 'choice', options = { 'necklace', 'tray_a', 'tray_b', 'd', 'e', 'f', 'b', 'c', 'skull', 'plain' }, default = 'necklace', hint = 'Matches the case type: necklace for the tall cases, tray for the flat ones' },
            { key = 'item', label = 'Loot item', kind = 'text', max = 40, default = 'goldchain', presets = { 'goldchain', 'gold_ring', 'goldearring', 'silverchain', 'silver_ring', 'diamond_ring', 'diamond_necklace', 'ruby_necklace', 'emerald_ring', 'sapphire_necklace' } },
            { key = 'itemMin', label = 'Item min', kind = 'number', min = 1, max = 50, default = 2 },
            { key = 'itemMax', label = 'Item max', kind = 'number', min = 1, max = 50, default = 4 },
            { key = 'rareItem', label = 'Rare item', kind = 'text', max = 40, default = 'diamond_necklace', presets = { 'diamond_ring', 'diamond_necklace', 'ruby_necklace', 'emerald_ring', 'sapphire_necklace', 'gold_bar' }, hint = 'Leave empty for none' },
            { key = 'rareChance', label = 'Rare chance %', kind = 'number', min = 0, max = 100, default = 12 },
            { key = 'cashMin', label = 'Cash min', kind = 'number', min = 0, max = 100000, default = 0 },
            { key = 'cashMax', label = 'Cash max', kind = 'number', min = 0, max = 100000, default = 0 },
        },
    },
    door = {
        label = 'Vault door',
        icon = 'fa-door-closed',
        color = { 183, 156, 255 },
        r = 2.0,
        hint = 'Opens the vr-doorlock doors once its requirement is done',
        fields = {
            { key = 'doors', label = 'Doors', kind = 'doors', max = 6, hint = 'Aim at a door to add it, or pick one that already exists' },
            { key = 'swing', label = 'Opens', kind = 'choice', options = { 'forward', 'reverse', 'unlock' }, default = 'forward', hint = 'forward and reverse swing the door open by themselves, unlock only frees it' },
            { key = 'openSeconds', label = 'Stay open (s)', kind = 'number', min = 0, max = 3600, default = 0, hint = '0 keeps it open until the heist resets' },
            { key = 'made', label = 'Made here', kind = 'doors', max = 6, hidden = true },
        },
    },
}

BH.kinds = { bank = 'Bank robbery', store = 'Store robbery', jewelry = 'Jewelry store robbery' }

BH.bankFields = {
    { key = 'label', label = 'Display name', kind = 'text', max = 40 },
    { key = 'kind', label = 'Heist type', kind = 'choice', options = { 'bank', 'store', 'jewelry' }, hint = 'Sets what the police alert says' },
    { key = 'enabled', label = 'Enabled', kind = 'bool' },
    { key = 'minPolice', label = 'Police needed', kind = 'number', min = 0, max = 30 },
    { key = 'cooldownMinutes', label = 'Cooldown (min)', kind = 'number', min = 0, max = 2880 },
    { key = 'maxMinutes', label = 'Heist length (min)', kind = 'number', min = 3, max = 180 },
    { key = 'alertSeconds', label = 'Police alert delay (s)', kind = 'number', min = 0, max = 600 },
    { key = 'radius', label = 'Map radius', kind = 'number', min = 20, max = 600 },
    { key = 'blip', label = 'Show map blip while active', kind = 'bool' },
}

local function num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

BH.num = num

function BH.clean(f, v)
    if f.kind == 'number' then
        v = num(v)
        if not v then return nil, 'bad_value' end
        if f.min and v < f.min then v = f.min end
        if f.max and v > f.max then v = f.max end
        return math.floor(v * 100 + 0.5) / 100
    elseif f.kind == 'text' then
        if type(v) ~= 'string' then return nil, 'bad_value' end
        v = v:gsub('[%c]', ''):sub(1, f.max or 40)
        return v
    elseif f.kind == 'choice' then
        for _, o in ipairs(f.options) do if o == v then return v end end
        return nil, 'bad_value'
    elseif f.kind == 'bool' then
        return v == true
    elseif f.kind == 'doors' then
        if type(v) ~= 'table' then return nil, 'bad_value' end
        local out, seen = {}, {}
        for _, name in ipairs(v) do
            if type(name) == 'string' and #name > 0 and #name <= 50 and not seen[name] and #out < (f.max or 6) then
                seen[name] = true
                out[#out + 1] = name
            end
        end
        return out
    end
    return nil, 'bad_value'
end

local function byId(bank, id)
    for _, el in ipairs(bank.elements) do
        if el.id == id then return el end
    end
    return nil
end

BH.byId = byId

function BH.canNeed(el)
    return el.type == 'hack' or el.type == 'drill' or el.type == 'door'
end

local function reaches(bank, from, target, depth)
    if depth > 32 then return true end
    local el = byId(bank, from)
    if not el or not el.needs then return false end
    if el.needs == target then return true end
    return reaches(bank, el.needs, target, depth + 1)
end

function BH.cleanNeeds(bank, el, v)
    if v == nil or v == false or v == 0 or v == '' then return nil end
    v = math.floor(num(v) or 0)
    local dep = byId(bank, v)
    if not dep or dep.id == el.id or not BH.canNeed(dep) then return nil, 'bad_needs' end
    if reaches(bank, v, el.id, 0) then return nil, 'needs_loop' end
    return v
end

function BH.defaults(def)
    local out = {}
    for _, f in ipairs(def.fields) do
        if f.default ~= nil then out[f.key] = f.default end
    end
    return out
end

function BH.newElement(bank, kind, pos)
    local def = BH.types[kind]
    if not def then return nil end
    local el = BH.defaults(def)
    if kind == 'door' then el.doors = {} el.made = {} end
    bank.nextId = (bank.nextId or 1)
    el.id = bank.nextId
    bank.nextId = bank.nextId + 1
    el.type = kind
    el.label = def.label
    el.x, el.y, el.z, el.w = pos.x + 0.0, pos.y + 0.0, pos.z + 0.0, (pos.w or 0.0) + 0.0
    el.r = def.r
    return el
end

function BH.patchElement(bank, el, patch)
    local def = BH.types[el.type]
    if type(patch) ~= 'table' then return false, 'bad_request' end
    if patch.label ~= nil then
        local v, err = BH.clean({ kind = 'text', max = 40 }, patch.label)
        if v == nil then return false, err end
        el.label = v ~= '' and v or def.label
    end
    if patch.r ~= nil and def.radius then
        local v, err = BH.clean({ kind = 'number', min = def.rMin or 1.0, max = def.rMax or 25.0 }, patch.r)
        if v == nil then return false, err end
        el.r = v
    end
    if patch.needs ~= nil then
        local v, err = BH.cleanNeeds(bank, el, patch.needs)
        if v == nil and err then return false, err end
        el.needs = v
    end
    for _, f in ipairs(def.fields) do
        if patch[f.key] ~= nil then
            local v, err = BH.clean(f, patch[f.key])
            if v == nil then return false, err end
            el[f.key] = v
        end
    end
    if el.cashMin and el.cashMax and el.cashMax < el.cashMin then el.cashMax = el.cashMin end
    if el.itemMin and el.itemMax and el.itemMax < el.itemMin then el.itemMax = el.itemMin end
    if el.barsMin and el.barsMax and el.barsMax < el.barsMin then el.barsMax = el.barsMin end
    return true
end

function BH.newBank(name, pos)
    local d = Config.Defaults
    return {
        name = name,
        label = name,
        kind = 'bank',
        enabled = true,
        minPolice = d.minPolice,
        cooldownMinutes = d.cooldownMinutes,
        maxMinutes = d.maxMinutes,
        alertSeconds = d.alertSeconds,
        radius = d.radius,
        blip = d.blip,
        center = { x = pos.x + 0.0, y = pos.y + 0.0, z = pos.z + 0.0 },
        nextId = 1,
        elements = {},
    }
end

function BH.patchBank(bank, patch)
    if type(patch) ~= 'table' then return false, 'bad_request' end
    for _, f in ipairs(BH.bankFields) do
        if patch[f.key] ~= nil then
            local v, err = BH.clean(f, patch[f.key])
            if v == nil then return false, err end
            if f.key == 'label' and v == '' then v = bank.name end
            bank[f.key] = v
        end
    end
    return true
end

function BH.sanitiseBank(name, raw)
    if type(raw) ~= 'table' then return nil end
    local c = type(raw.center) == 'table' and raw.center or {}
    local bank = BH.newBank(name, { x = num(c.x) or 0.0, y = num(c.y) or 0.0, z = num(c.z) or 0.0 })
    BH.patchBank(bank, raw)
    local maxId = 0
    local list = {}
    if type(raw.elements) == 'table' then
        for _, e in ipairs(raw.elements) do
            if type(e) == 'table' and BH.types[e.type] and num(e.x) and num(e.y) and num(e.z) and num(e.id) then
                local el = BH.newElement(bank, e.type, { x = e.x, y = e.y, z = e.z, w = num(e.w) or 0.0 })
                el.id = math.floor(e.id)
                if el.id > maxId then maxId = el.id end
                list[#list + 1] = { el = el, raw = e }
            end
        end
    end
    bank.nextId = math.max(maxId + 1, math.floor(num(raw.nextId) or 1))
    for _, item in ipairs(list) do bank.elements[#bank.elements + 1] = item.el end
    for _, item in ipairs(list) do
        local patch = {}
        for k, v in pairs(item.raw) do
            if k ~= 'needs' and k ~= 'id' and k ~= 'type' then patch[k] = v end
        end
        if item.el.type == 'case' and num(patch.r) == 1.2 then patch.r = nil end
        BH.patchElement(bank, item.el, patch)
    end
    for _, item in ipairs(list) do
        if item.raw.needs ~= nil then
            local v = BH.cleanNeeds(bank, item.el, item.raw.needs)
            item.el.needs = v
        end
    end
    return bank
end

function BH.describe()
    local out = { types = {}, bank = BH.bankFields }
    for _, k in ipairs(BH.typeOrder) do
        local d = BH.types[k]
        out.types[#out.types + 1] = { id = k, label = d.label, icon = d.icon, color = d.color, radius = d.radius == true, rMin = d.rMin or 1.0, rMax = d.rMax or 25.0, rStep = d.rStep or 0.5, hint = d.hint, fields = d.fields }
    end
    return out
end
