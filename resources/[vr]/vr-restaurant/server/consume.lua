local VRCore = exports['vr-core']:GetCoreObject({ 'Functions', 'Commands' })
local ox = exports['vr-inventory']

local Registry = {}
local FromConfig = {}
local sessions = {}

local BASE = {}
for _, item in pairs(Config.BaseItems) do BASE[item] = true end

local function debugPrint(...)
    if Config.Debug then print('^5[vr-restaurant]^7', ...) end
end

local function notify(src, msg, kind)
    TriggerClientEvent('VRCore:Notify', src, msg, kind or 'primary')
end

local function itemLabel(name)
    local item = name and ox:Items(name)
    return item and item.label or name
end

local function copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

local function rollFor(def)
    local roll = {
        time = Consumable.Roll(def.time, true),
        hunger = Consumable.Roll(def.hunger),
        thirst = Consumable.Roll(def.thirst),
        stress = Consumable.Roll(def.stress),
        heal = Consumable.Roll(def.heal, true),
        armor = Consumable.Roll(def.armor, true),
    }
    if def.effect and def.effect.name == 'stress' then
        roll.stress = roll.stress + def.effect.amount * def.effect.time / 1000
    end
    return roll
end

local function startConsume(src, name, opts)
    local def = Registry[name]
    if not def then return false, 'unknown' end
    if sessions[src] then return false, 'busy' end

    local player = exports['vr-core']:GetPlayer(src)
    if not player then return false, 'not_loaded' end
    local md = player.PlayerData.metadata
    if md.isdead or md.inlaststand then return false, 'dead' end

    if def.requiredItem and (ox:Search(src, 'count', def.requiredItem) or 0) < 1 then
        notify(src, ('You need a %s'):format(itemLabel(def.requiredItem)), 'error')
        return false, 'required_item'
    end

    local roll = rollFor(def)
    local token = math.random(1, 2147483646)
    local label = def.label or (opts.metadata and opts.metadata.label) or itemLabel(opts.item or name)

    sessions[src] = {
        token = token, name = name, def = def, roll = roll, started = GetGameTimer(),
        slot = opts.slot, item = opts.item, free = opts.free == true,
    }

    TriggerClientEvent('vr-restaurant:client:start', src, {
        token = token, name = name, label = label, type = def.type, emote = def.emote,
        canRun = def.canRun, time = roll.time,
    })

    SetTimeout(roll.time + 30000, function()
        if sessions[src] and sessions[src].token == token then sessions[src] = nil end
    end)

    debugPrint(('%s started %s (%d ms)'):format(src, name, roll.time))
    return true
end

local function onUse(src, item)
    local name = item.name
    if BASE[name] then
        name = item.metadata and item.metadata.consumable
        if not Consumable.IsName(name) then return end
    end
    if not Registry[name] then return end
    local md = item.metadata
    if type(md) == 'table' and tonumber(md.degrade) and tonumber(md.durability) and md.durability > 100 and md.durability <= os.time() then
        notify(src, 'That has gone off', 'error')
        return
    end
    startConsume(src, name, { slot = item.slot, item = item.name, metadata = item.metadata })
end

local function takeItem(src, s)
    if s.free then return true end

    local function matches(slot)
        return slot and slot.name == s.item and slot.count > 0
            and (not BASE[s.item] or (slot.metadata and slot.metadata.consumable == s.name))
    end

    if s.slot and matches(ox:GetSlot(src, s.slot)) then
        return ox:RemoveItem(src, s.item, 1, nil, s.slot) and true or false
    end

    local slots = BASE[s.item] and ox:GetSlotsWithItem(src, s.item, { consumable = s.name }, false)
        or ox:GetSlotsWithItem(src, s.item)
    for _, slot in ipairs(slots or {}) do
        if matches(slot) then return ox:RemoveItem(src, s.item, 1, nil, slot.slot) and true or false end
    end
    return false
end

local function give(src, item, amount)
    if amount < 1 then return end
    local ok = ox:AddItem(src, item, amount)
    if not ok then notify(src, ('No room for %s x%d'):format(itemLabel(item), amount), 'error') end
end

local function rollRewards(def)
    local out = {}
    for _ = 1, def.amounttogive or 1 do
        local rarity = math.random(1, 4)
        local pool = {}
        for _, r in ipairs(def.rewards) do
            if r.rarity >= rarity then pool[#pool + 1] = r end
        end
        if #pool > 0 then
            local r = pool[math.random(1, #pool)]
            out[#out + 1] = { item = r.item, amount = math.random(1, r.max) }
        end
    end
    return out
end

local function clamp(v) return math.max(0, math.min(100, v)) end

local function applyNeeds(src, roll)
    local player = exports['vr-core']:GetPlayer(src)
    if not player then return end
    local md = player.PlayerData.metadata
    if roll.hunger ~= 0 then player.Functions.SetMetaData('hunger', clamp((tonumber(md.hunger) or 100) + roll.hunger)) end
    if roll.thirst ~= 0 then player.Functions.SetMetaData('thirst', clamp((tonumber(md.thirst) or 100) + roll.thirst)) end
    if roll.stress ~= 0 then
        local stress = clamp((tonumber(md.stress) or 0) - roll.stress)
        player.Functions.SetMetaData('stress', stress)
        TriggerClientEvent('hud:client:UpdateStress', src, stress)
    end
end

local buffExports = { heal = 'AddHealthBuff', stamina = 'StaminaBuffEffect', armor = 'AddArmorBuff' }

RegisterNetEvent('vr-restaurant:server:finish', function(token)
    local src = source
    local s = sessions[src]
    if not s or s.token ~= token then return end
    sessions[src] = nil

    if GetGameTimer() - s.started < s.roll.time - 250 then
        debugPrint(('%s finished %s too early, ignored'):format(src, s.name))
        return
    end

    if not takeItem(src, s) then
        notify(src, ("You don't have %s any more"):format(itemLabel(s.item) or s.name), 'error')
        return
    end

    local def = s.def
    if def.returnItem then give(src, def.returnItem.item, def.returnItem.amount) end
    if def.pack then give(src, def.pack.item, def.pack.amount) end
    if def.rewards then
        for _, r in ipairs(rollRewards(def)) do give(src, r.item, r.amount) end
    end

    applyNeeds(src, s.roll)

    local effect = def.effect
    if effect and buffExports[effect.name] and GetResourceState('vr-buffs') == 'started' then
        local ok = pcall(function()
            exports['vr-buffs'][buffExports[effect.name]](nil, src, effect.time, effect.amount)
        end)
        if ok then effect = nil end
    end

    TriggerClientEvent('vr-restaurant:client:finished', src, {
        type = def.type, heal = s.roll.heal, armor = s.roll.armor, effect = effect,
        screen = def.screen, canOD = def.canOD, widepupils = def.widepupils,
    })

    TriggerEvent('vr-restaurant:server:consumed', src, s.name, copy(s.roll))
    -- Scripts written for vr-consumables listen for this name.
    TriggerEvent('vr-consumables:server:consumed', src, s.name, copy(s.roll))
    debugPrint(('%s finished %s'):format(src, s.name))
end)

RegisterNetEvent('vr-restaurant:server:cancel', function(token)
    local src = source
    local s = sessions[src]
    if s and s.token == token then sessions[src] = nil end
end)

AddEventHandler('playerDropped', function() sessions[source] = nil end)
AddEventHandler('VRCore:Server:OnPlayerUnload', function(src) sessions[src] = nil end)

local function register(name, def)
    Registry[name] = def
    if not BASE[name] then VRCore.Functions.CreateUseableItem(name, onUse) end
end

local function loadConfig()
    for name, data in pairs(Config.Consumables) do
        local def, errors = Consumable.Normalize(name, data)
        for _, err in ipairs(errors) do print(('^3[vr-restaurant] %s: %s^0'):format(name, err)) end
        if def then
            FromConfig[name] = def
            register(name, def)
        end
    end
end

local function loadSaved()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS `vr_consumables` (
        `name` varchar(64) NOT NULL,
        `data` longtext NOT NULL,
        `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
        PRIMARY KEY (`name`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

    local rows = MySQL.query.await('SELECT name, data FROM vr_consumables') or {}
    for _, row in ipairs(rows) do
        local ok, data = pcall(json.decode, row.data)
        local def, errors = Consumable.Normalize(row.name, ok and data or nil)
        for _, err in ipairs(errors) do print(('^3[vr-restaurant] saved %s: %s^0'):format(row.name, err)) end
        if def then register(row.name, def) end
    end
    return #rows
end

local function checkItems()
    local missing = {}
    for name in pairs(Registry) do
        if not ox:Items(name) then missing[#missing + 1] = name end
    end
    for _, item in pairs(Config.BaseItems) do
        if not ox:Items(item) then missing[#missing + 1] = item .. ' (base item)' end
    end
    if #missing > 0 then
        table.sort(missing)
        print(('^3[vr-restaurant] Not in vr-inventory/data/items.lua: %s. Those can only be handed out with GiveConsumable.^0')
            :format(table.concat(missing, ', ')))
    end
end

CreateThread(function()
    loadConfig()
    for _, item in pairs(Config.BaseItems) do VRCore.Functions.CreateUseableItem(item, onUse) end
    local ok, saved = pcall(loadSaved)
    if not ok then print(('^1[vr-restaurant] Could not load consumables saved in game: %s^0'):format(saved)) end
    checkItems()
    debugPrint(('loaded, %s saved in game'):format(ok and saved or 0))
end)

exports('GetConsumables', function() return copy(Registry) end)

exports('GetConsumable', function(name) return copy(Registry[name]) end)

local function saveConsumable(name, data)
    local def, errors = Consumable.Normalize(name, data)
    if not def then return false, errors end
    if #errors > 0 then return false, errors end
    if BASE[name] then return false, { 'that name is a base item' } end

    MySQL.query.await([[INSERT INTO vr_consumables (name, data) VALUES (?, ?)
        ON DUPLICATE KEY UPDATE data = VALUES(data)]], { name, json.encode(data) })
    register(name, def)
    return true
end
exports('SaveConsumable', saveConsumable)

exports('DeleteConsumable', function(name)
    if not Consumable.IsName(name) then return false end
    MySQL.query.await('DELETE FROM vr_consumables WHERE name = ?', { name })
    if FromConfig[name] then
        Registry[name] = FromConfig[name]
    else
        Registry[name] = nil
    end
    return true
end)

exports('IsConsuming', function(src) return sessions[src] ~= nil end)

exports('Consume', function(src, name)
    return startConsume(src, name, { free = true })
end)

exports('CancelConsume', function(src)
    if not sessions[src] then return false end
    sessions[src] = nil
    TriggerClientEvent('vr-restaurant:client:cancel', src)
    return true
end)

local function giveConsumable(src, name, count, metadata)
    local def = Registry[name]
    if not def then return false, 'unknown' end
    count = math.max(1, math.min(1000, math.floor(tonumber(count) or 1)))

    if ox:Items(name) then return ox:AddItem(src, name, count, metadata) end

    local base = (def.type == 'drink' or def.type == 'alcohol') and Config.BaseItems.drink or Config.BaseItems.food
    local meta = type(metadata) == 'table' and copy(metadata) or {}
    meta.consumable = name
    meta.label = meta.label or def.label or name
    meta.description = meta.description or def.description
    meta.weight = meta.weight or def.weight
    if def.image and not meta.image and not meta.imageurl then
        if def.image:find('^https://') then meta.imageurl = def.image
        else meta.image = (def.image:gsub('%.png$', '')) end
    end
    return ox:AddItem(src, base, count, meta)
end
exports('GiveConsumable', giveConsumable)

-- Used by the kitchen to make the dishes an owner designs.
RestConsume = { save = saveConsumable, give = giveConsumable }

VRCore.Commands.Add('giveconsumable', 'Give a consumable (works for ones made in game too)', {
    { name = 'id', help = 'Player id' },
    { name = 'name', help = 'Consumable name' },
    { name = 'amount', help = 'How many (default 1)' },
}, false, function(source, args)
    local target = tonumber(args[1])
    local name = args[2]
    if not target or not exports['vr-core']:GetPlayer(target) then
        return notify(source, 'Player not online', 'error')
    end
    if not Registry[name] then return notify(source, ('No consumable called %s'):format(tostring(name)), 'error') end
    local ok = giveConsumable(target, name, tonumber(args[3]) or 1)
    notify(source, ok and ('Gave %s'):format(name) or 'Could not give it (inventory full?)', ok and 'success' or 'error')
end, 'admin')
