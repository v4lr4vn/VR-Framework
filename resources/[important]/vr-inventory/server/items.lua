local U = InvUtil

Items = setmetatable({}, {
    __call = function(_, name) return InvGetItem(name) end,
})

Items.containers = {}

local function arrayToSet(tbl)
    local set = {}
    for i = 1, #tbl do set[tbl[i]] = true end
    return set
end

local function asSet(value, label)
    if value == nil then return nil end
    local kind = U.tableType(value)
    if kind == 'array' then return arrayToSet(value) end
    if kind == 'hash' or kind == 'empty' then return value end
    error(('expected %s to be a table (received %s)'):format(label, type(value)))
end

function Items.setContainerProperties(name, properties)
    Items.containers[name] = {
        size = { properties.slots, properties.maxWeight },
        blacklist = asSet(properties.blacklist, 'blacklist'),
        whitelist = asSet(properties.whitelist, 'whitelist'),
    }
end

Items.setContainerProperties('paperbag', { slots = 5, maxWeight = 1000, blacklist = { 'testburger' } })
Items.setContainerProperties('pizzabox', { slots = 5, maxWeight = 1000, whitelist = { 'pizza' } })

local trash = {
    { description = 'A discarded burger carton.', weight = 50, image = 'trash_burger' },
    { description = 'An empty soda can.', weight = 20, image = 'trash_can' },
    { description = 'A mouldy piece of bread.', weight = 70, image = 'trash_bread' },
    { description = 'An empty chips bag.', weight = 5, image = 'trash_chips' },
    { description = 'An old rolled up newspaper.', weight = 200, image = 'WEAPON_ACIDPACKAGE' },
}

local function randomText(len)
    local out
    repeat
        local chars = {}
        for i = 1, len do chars[i] = string.char(math.random(65, 90)) end
        out = table.concat(chars)
    until out ~= 'POL' and out ~= 'EMS'
    return out
end

Items.randomText = randomText

local function serial(text)
    if text and #tostring(text) > 3 then return text end
    return ('%s%s%s'):format(math.random(100000, 999999), text == nil and randomText(3) or text, math.random(100000, 999999))
end

local function setDurability(item, metadata)
    if item.degrade then
        metadata.durability = os.time() + (item.degrade * 60)
        metadata.degrade = item.degrade
    elseif item.durability then
        metadata.durability = 100
    end
    return metadata
end

function Items.Metadata(inv, item, metadata, count)
    if type(inv) ~= 'table' then inv = Inventory(inv) end
    if not item.weapon then
        if not metadata then metadata = {}
        elseif type(metadata) == 'string' then metadata = { type = metadata } end
    end
    count = count or 1

    if item.weapon then
        if type(metadata) ~= 'table' then metadata = {} end
        if not metadata.durability then metadata = setDurability(item, metadata) end
        if not metadata.ammo and item.ammoname then metadata.ammo = 0 end
        if not metadata.components then metadata.components = {} end

        if metadata.registered ~= false and (metadata.ammo or item.name == 'WEAPON_STUNGUN') then
            local registered = type(metadata.registered) == 'string' and metadata.registered or (inv and inv.player and inv.player.name)
            metadata.registered = registered
            metadata.serial = serial(metadata.serial)
        end

        if Hashes.isCan(item.hash) then metadata.ammo = metadata.durability end
    else
        local container = Items.containers[item.name]

        if container then
            count = 1
            metadata.container = metadata.container or (randomText(3) .. os.time())
            metadata.size = container.size
        elseif not next(metadata) then
            if item.name == 'identification' and inv and inv.player then
                count = 1
                metadata = {
                    type = inv.player.name,
                    description = locale('identification', inv.player.sex and locale('male') or locale('female'), inv.player.dateofbirth or '?'),
                }
            elseif item.name == 'garbage' then
                local pick = trash[math.random(1, #trash)]
                metadata.image = pick.image
                metadata.weight = pick.weight
                metadata.description = pick.description
            end
        end

        if not metadata.durability then metadata = setDurability(ItemList[item.name], metadata) end
    end

    if count > 1 and not item.stack then count = 1 end

    local hooks <close> = TriggerEventHooks('createItem', {
        inventoryId = inv and inv.id,
        metadata = metadata,
        item = item,
        count = count,
        resource = GetInvokingResource() or shared.resource,
    })

    if hooks.success and type(hooks.result) == 'table' then metadata = hooks.result end

    return metadata, count
end

function Items.CheckMetadata(metadata, item, name, ostime)
    if metadata.bag then
        metadata.container = metadata.bag
        metadata.size = Items.containers[name] and Items.containers[name].size or { 5, 1000 }
        metadata.bag = nil
    end

    local durability = metadata.durability

    if durability then
        if durability < 0 or (durability > 100 and ostime >= durability) then metadata.durability = 0 end
    else
        metadata = setDurability(item, metadata)
    end

    if item.weapon then
        if metadata.components then
            local list = {}
            if U.tableType(metadata.components) == 'array' then
                for i = 1, #metadata.components do
                    if ItemList[metadata.components[i]] then list[#list + 1] = metadata.components[i] end
                end
            else
                for _, component in pairs(metadata.components) do
                    if component and ItemList[component] then list[#list + 1] = component end
                end
            end
            metadata.components = list
        end

        if metadata.serial and item.throwable then metadata.serial = nil end
        if metadata.specialAmmo and type(metadata.specialAmmo) ~= 'string' then metadata.specialAmmo = nil end
    end

    return metadata
end

function Items.UpdateDurability(inv, slot, item, value, ostime)
    local durability = slot.metadata.durability or value
    if not durability then return end

    if value then
        durability = value
    elseif ostime and durability > 100 and ostime >= durability then
        durability = 0
    end

    if item and item.decay and durability == 0 then
        return Inventory.RemoveItem(inv, slot.name, slot.count, nil, slot.slot)
    end

    if slot.metadata.durability == durability then return end

    inv.changed = true
    slot.metadata.durability = durability

    inv:syncSlotsWithClients({ { item = slot, inventory = inv.id } }, true)
end

exports('Items', function(name) return InvGetItem(name) end)
exports('ItemList', function(name) return InvGetItem(name) end)
exports('setContainerProperties', Items.setContainerProperties)
