local U = InvUtil

Items = setmetatable({}, {
    __index = function(_, key) return ItemList[key] end,
    __call = function(_, name) return InvGetItem(name) end,
})

local pendingMetadata = {}

local function sendDisplayMetadata(data)
    SendNUIMessage({ action = 'displayMetadata', data = data })
end

local function displayMetadata(metadata, value)
    local data = {}
    if type(metadata) == 'string' then
        if not value then return end
        data = { { metadata = metadata, value = value } }
    elseif U.tableType(metadata) == 'array' then
        for i = 1, #metadata do
            for k, v in pairs(metadata[i]) do data[#data + 1] = { metadata = k, value = v } end
        end
    elseif type(metadata) == 'table' then
        for k, v in pairs(metadata) do data[#data + 1] = { metadata = k, value = v } end
    end

    if client.uiLoaded then return sendDisplayMetadata(data) end
    pendingMetadata[#pendingMetadata + 1] = data
end

function InvFlushMetadata()
    for i = 1, #pendingMetadata do sendDisplayMetadata(pendingMetadata[i]) end
    pendingMetadata = {}
end

exports('displayMetadata', displayMetadata)
exports('Items', function(name) return InvGetItem(name) end)
exports('ItemList', function(name) return InvGetItem(name) end)

local function effect(name, cb)
    local item = ItemList[name]
    if item and not (item.client and (item.client.export or item.client.event)) then item.effect = cb end
end

local function use(data, cb)
    return InvUseItem(data, cb)
end

effect('bandage', function(data)
    local maxHealth = GetEntityMaxHealth(cache.ped)
    local health = GetEntityHealth(cache.ped)
    use(data, function(result)
        if result then
            SetEntityHealth(cache.ped, math.min(maxHealth, math.floor(health + maxHealth / 16)))
            lib.notify({ type = 'success', description = locale('bandage_used') })
        end
    end)
end)

effect('armour', function(data)
    if GetPedArmour(cache.ped) >= 100 then return end
    use(data, function(result)
        if result then
            SetPlayerMaxArmour(PlayerData.id, 100)
            SetPedArmour(cache.ped, 100)
        end
    end)
end)

client.parachute = false

effect('parachute', function(data, slot)
    if client.parachute then return end
    use(data, function(result)
        if result then
            local chute = joaat('GADGET_PARACHUTE')
            SetPlayerParachuteTintIndex(PlayerData.id, -1)
            GiveWeaponToPed(cache.ped, chute, 0, true, false)
            SetPedGadget(cache.ped, chute, true)
            lib.requestModel(1269906701)
            local tint = slot and slot.metadata and slot.metadata.type or -1
            client.parachute = { CreateParachuteBagObject(cache.ped, true, true), tint }
            if tint ~= -1 then SetPlayerParachuteTintIndex(PlayerData.id, tint) end
        end
    end)
end)

effect('clothing', function(data, slot)
    local metadata = slot and slot.metadata or {}
    if not metadata.drawable or not metadata.texture then return end

    if metadata.prop then
        if not SetPedPreloadPropData(cache.ped, metadata.prop, metadata.drawable, metadata.texture) then return end
    elseif metadata.component then
        if not IsPedComponentVariationValid(cache.ped, metadata.component, metadata.drawable, metadata.texture) then return end
    else
        return
    end

    use(data, function(result)
        if not result then return end
        metadata = result.metadata or metadata
        if metadata.prop then
            local prop = GetPedPropIndex(cache.ped, metadata.prop)
            local texture = GetPedPropTextureIndex(cache.ped, metadata.prop)
            if metadata.drawable == prop and metadata.texture == texture then return ClearPedProp(cache.ped, metadata.prop) end
            SetPedPropIndex(cache.ped, metadata.prop, metadata.drawable, metadata.texture, false)
        elseif metadata.component then
            local drawable = GetPedDrawableVariation(cache.ped, metadata.component)
            local texture = GetPedTextureVariation(cache.ped, metadata.component)
            if metadata.drawable == drawable and metadata.texture == texture then return end
            SetPedComponentVariation(cache.ped, metadata.component, metadata.drawable, metadata.texture, 0)
        end
    end)
end)
