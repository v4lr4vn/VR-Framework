local config = require('config')

local providerName = config.mugshotsUpload:lower()
if providerName == 'local' then providerName = 'database' end
local success, uploadProvider = pcall(require, ('server.upload.%s'):format(providerName))

if not success or not uploadProvider then
    warn(('Failed to load upload provider: %s'):format(providerName))
    uploadProvider = nil
end

local function resolveMugShot(src, identifier, itemName)
    if not uploadProvider then return nil end

    local result = lib.callback.await('vr-idcard:client:callBack:getMugShot', src)
    if not result then return nil end

    return uploadProvider(result, identifier, itemName)
end

function UpdateMugShot(src, item)
    if not item or not item.slot then return end
    local metadata = item.metadata or item.info

    local identifier = metadata.citizenid or metadata.identifier or tostring(src)
    local mugShot = resolveMugShot(src, identifier, item.name)
    if not mugShot then return end
    setMetaDataInventory(src, item, mugShot)
    return true
end
