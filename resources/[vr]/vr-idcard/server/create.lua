local config = require('config')

local function getBadge(src, itemName)
    local license = config.licenses[itemName]
    if not license or not license.badge then return 'none' end
    local badge = license.badge
    return {
        img = badge,
        grade = getGradeName(src)
    }
end

local function CreateMetaLicense(src, itemTable)
    local metadata = {}

    if type(itemTable) == "string" then
        itemTable = { itemTable }
    end

    local data = getPlayerLicenseData(src)
    if not data then return false end

    if type(itemTable) == "table" then
        for _, v in pairs(itemTable) do
            if config.licenses[v] then
                metadata = {
                    cardtype = v,
                    mugShot = 'none',
                    badge = getBadge(src, v)
                }
                lib.table.merge(metadata, data)
                metadata.description = ('%s %s | %s | %s'):format(data.firstname or '', data.lastname or '',
                    data.birthdate or '', data.citizenid or '')
                addItemInventory(src, v, metadata)
            end
        end
    end
    return true
end

exports('CreateMetaLicense', CreateMetaLicense)

exports('IsCard', function(itemName)
    return config.licenses[itemName] ~= nil
end)

function DeleteAndRenewLicense(src, item)
    removeItemInventory(src, item.name, item.slot)
    return CreateMetaLicense(src, item.name)
end

CreateThread(function()
    for k, _ in pairs(config.licenses) do
        registerItemCreate(k)
    end
end)
