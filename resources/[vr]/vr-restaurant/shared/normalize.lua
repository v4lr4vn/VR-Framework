Consumable = {}

Consumable.Types = { food = true, drink = true, alcohol = true, smoke = true, drug = true, pack = true }
Consumable.Effects = { heal = true, stamina = true, armor = true, stress = true }
Consumable.Screens = { turbo = true, focus = true, rampage = true, weed = true, trevor = true, nightvision = true, thermal = true }

local function isName(v)
    return type(v) == 'string' and #v > 0 and #v <= 64 and v:match('^[%w_%-]+$') ~= nil
end
Consumable.IsName = isName

local function num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

local function range(v, lo, hi, field, errors)
    if v == nil or v == false then return nil end
    if type(v) ~= 'table' then v = { v, v } end
    local a, b = num(v[1] or v.min), num(v[2] or v.max or v[1] or v.min)
    if not a or not b then
        errors[#errors + 1] = ('%s must be a number or { min, max }'):format(field)
        return nil
    end
    if a > b then a, b = b, a end
    a, b = math.max(lo, math.min(hi, a)), math.max(lo, math.min(hi, b))
    if a == 0 and b == 0 then return nil end
    return { a, b }
end

local function itemAmount(v, field, errors)
    if v == nil then return nil end
    if type(v) == 'string' then v = { item = v, amount = 1 } end
    if type(v) ~= 'table' or not isName(v.item) then
        errors[#errors + 1] = ('%s needs { item = "name", amount = 1 }'):format(field)
        return nil
    end
    local amount = math.floor(num(v.amount) or 1)
    return { item = v.item, amount = math.max(1, math.min(1000, amount)) }
end

local function text(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c<>]', ''):sub(1, max)
    return #v > 0 and v or nil
end

function Consumable.Normalize(name, data)
    local errors = {}
    if not isName(name) then return nil, { 'name must be letters, numbers, _ or - (max 64)' } end
    if type(data) ~= 'table' then return nil, { 'definition must be a table' } end

    local stats = type(data.stats) == 'table' and data.stats or {}
    local limits = Config.Limits

    local def = { name = name }

    def.type = data.type or 'food'
    if not Consumable.Types[def.type] then
        errors[#errors + 1] = ('type must be one of food, drink, alcohol, smoke, drug, pack (got %s)'):format(tostring(data.type))
        def.type = 'food'
    end

    def.label = text(data.label, 64)
    def.description = text(data.description, 200)
    def.image = text(data.image, 300)
    def.weight = num(data.weight) and math.max(0, math.min(100000, math.floor(num(data.weight)))) or nil

    local emote = data.emote
    if type(emote) ~= 'string' or not Config.Emotes[emote] then
        if emote ~= nil then errors[#errors + 1] = ('emote "%s" not found, using the %s default'):format(tostring(emote), def.type) end
        emote = Config.FallbackEmote[def.type]
    end
    def.emote = emote
    def.canRun = data.canRun == true

    def.time = range(data.time or 5000, limits.time[1], limits.time[2], 'time', errors) or { 5000, 5000 }
    def.hunger = range(data.hunger or stats.hunger, -limits.hunger, limits.hunger, 'hunger', errors)
    def.thirst = range(data.thirst or stats.thirst, -limits.thirst, limits.thirst, 'thirst', errors)
    def.stress = range(data.stress, -limits.stress, limits.stress, 'stress', errors)
    def.heal = range(data.heal, 0, limits.heal, 'heal', errors)
    def.armor = range(data.armor, 0, limits.armor, 'armor', errors)

    local effect = data.effect
    if type(effect) == 'string' then
        effect = { name = effect, time = stats.time, amount = stats.amount }
    elseif effect == nil and stats.effect then
        effect = { name = stats.effect, time = stats.time, amount = stats.amount }
    end
    if type(effect) == 'table' then
        if Consumable.Effects[effect.name] then
            def.effect = {
                name = effect.name,
                time = math.max(1000, math.min(300000, math.floor(num(effect.time) or 10000))),
                amount = math.max(0, math.min(25, num(effect.amount) or 6)),
            }
        else
            errors[#errors + 1] = ('effect must be heal, stamina, armor or stress (got %s)'):format(tostring(effect.name))
        end
    end

    local screen = data.screen or stats.screen
    if screen ~= nil then
        if Consumable.Screens[screen] then def.screen = screen
        else errors[#errors + 1] = ('screen "%s" is not a known screen effect'):format(tostring(screen)) end
    end

    def.canOD = (data.canOD == nil and stats.canOD or data.canOD) == true
    def.widepupils = (data.widepupils == nil and stats.widepupils or data.widepupils) == true

    if data.requiredItem ~= nil then
        if isName(data.requiredItem) then def.requiredItem = data.requiredItem
        else errors[#errors + 1] = 'requiredItem must be an item name' end
    end
    def.returnItem = itemAmount(data.returnItem, 'returnItem', errors)
    def.pack = itemAmount(data.pack, 'pack', errors)
    if def.type == 'pack' and not def.pack then errors[#errors + 1] = 'type "pack" needs pack = { item, amount }' end

    if data.rewards ~= nil then
        if type(data.rewards) ~= 'table' then
            errors[#errors + 1] = 'rewards must be a list'
        else
            local list = {}
            for _, r in ipairs(data.rewards) do
                if type(r) == 'table' and isName(r.item) then
                    list[#list + 1] = {
                        item = r.item,
                        max = math.max(1, math.min(100, math.floor(num(r.max) or 1))),
                        rarity = math.max(1, math.min(4, math.floor(num(r.rarity) or 4))),
                    }
                else
                    errors[#errors + 1] = 'each reward needs { item = "name", max = 1, rarity = 1-4 }'
                end
            end
            if #list > 0 then
                def.rewards = list
                def.amounttogive = math.max(1, math.min(20, math.floor(num(data.amounttogive) or 1)))
            end
        end
    end

    return def, errors
end

function Consumable.Roll(r, whole)
    if not r then return 0 end
    local a, b = r[1], r[2]
    if whole then return math.random(math.floor(a), math.floor(b)) end
    if a == b then return a end
    return math.floor((a + math.random() * (b - a)) * 10 + 0.5) / 10
end
