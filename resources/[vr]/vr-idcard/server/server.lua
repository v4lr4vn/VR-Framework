local function isOwnCard(src, metadata)
    local player = getPlayerFramework(src)
    local citizenid = player and player.PlayerData.citizenid
    return citizenid ~= nil and (metadata.citizenid == nil or metadata.citizenid == citizenid)
end

function SendIDCardData(src, item, afterPhoto)
    local metadata = item?.info or item.metadata

    if not (metadata and next(metadata) and metadata?.cardtype) then
        if metadata and not isOwnCard(src, metadata) then return end
        lib.notify(src, {
            title = locale('renew.title'),
            description = locale('renew.description'),
            icon = 'id-card',
            iconColor = 'yellow'
        })
        return DeleteAndRenewLicense(src, item)
    end

    local mugshot = metadata.mugShot

    local isBase64 = mugshot and mugshot:find('^data:image')

    local stored = mugshot and mugshot:find('^db:') and ResolveStoredMugshot and ResolveStoredMugshot(mugshot)
    if mugshot and mugshot:find('^db:') and not stored then mugshot = 'none' end

    local needsPhoto = not mugshot or mugshot == 'none' or isBase64
    if needsPhoto and not isOwnCard(src, metadata) then
        needsPhoto, mugshot, stored = false, 'none', nil
        metadata = lib.table.deepclone(metadata)
        metadata.mugShot = 'none'
    end

    if needsPhoto then
        if afterPhoto then return end
        lib.notify(src, {
            title = locale('update_mugshot.title'),
            description = locale('update_mugshot.description'),
            icon = 'camera',
            iconColor = 'yellow'
        })
        if UpdateMugShot(src, item) then return SendIDCardData(src, item, true) end
        return
    end

    local closestPlayer = lib.getClosestPlayer(GetEntityCoords(GetPlayerPed(src)), 2, src)

    if closestPlayer then
        lib.notify(src, {
            title = locale('show_idcard.title'),
            description = locale('show_idcard.description'),
            icon = 'id-card',
            iconColor = 'green'
        })
    end

    local shown = metadata
    if stored then
        shown = lib.table.deepclone(metadata)
        shown.mugShot = stored
    end

    TriggerClientEvent('vr-idcard:client:animStart', src, metadata)
    TriggerClientEvent('vr-idcard:client:sendData', closestPlayer or src, shown)
end
