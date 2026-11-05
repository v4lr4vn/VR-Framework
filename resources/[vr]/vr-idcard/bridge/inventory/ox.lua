if GetResourceState('vr-inventory') ~= 'started' then return end

local vrInventory = exports['vr-inventory']

function setMetaDataInventory(src, item, mugShot)
    item.metadata.mugShot = mugShot
    vrInventory:SetMetadata(src, item.slot, item.metadata)
end

function addItemInventory(src, itemName, metadata)
    vrInventory:AddItem(src, itemName, 1, metadata)
end

function removeItemInventory(src, itemName, slot)
    if slot then
        vrInventory:RemoveItem(src, itemName, 1, nil, slot)
        return
    end
    local item = vrInventory:GetSlotWithItem(src, itemName)
    if not item then return end
    vrInventory:RemoveItem(src, itemName, 1, nil, item.slot)
end
