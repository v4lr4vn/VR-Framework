Boosters = {}

Bridge.useItem(Config.Booster.item, function(source, data)
    TriggerClientEvent('vr-djbooth:client:startPlacement', source, Config.Booster.item, type(data) == 'table' and data.slot or nil)
end)

function BoostersInPlace(place)
    local n = 0
    for _, b in pairs(Boosters) do
        if b.place == place then n = n + 1 end
    end
    return n
end

function LinkRange(place)
    if place and BoostersInPlace(place) > 0 then return Config.Booster.linkRange end
    return Config.Limits.linkRange
end

function BoosterPayload(b)
    return {
        id = b.id, item = b.item, x = b.x, y = b.y, z = b.z, h = b.h, bucket = b.bucket or 0,
        place = b.place, job = PlaceJob(b.place), home = b.place:match('^home:') and true or nil, booster = true,
    }
end

function LoadBoosters()
    Boosters = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `vr_djbooth_boosters`') or {}) do
        local id = 'r' .. row.id
        Boosters[id] = {
            id = id, dbId = row.id, item = Config.Booster.item, place = row.place, bucket = tonumber(row.bucket) or 0,
            x = tonumber(row.x), y = tonumber(row.y), z = tonumber(row.z), h = tonumber(row.h) or 0.0, owner = row.owner,
        }
    end
end

function PlaceBooster(src, slot, pos, heading, bucket, takeItem)
    local place, reason = ResolvePlace(src, pos, bucket)
    if not place then return false, reason end
    if BoostersInPlace(place) >= Config.Booster.perPlace then return false, 'booster_limit' end
    if not takeItem(src, Config.Booster.item, slot) then return false, 'no_item' end
    local Player = GetPlayer(src)
    local owner = Player and Player.cid or nil
    local dbId = DbAwait('insert', 'INSERT INTO `vr_djbooth_boosters` (`place`, `bucket`, `x`, `y`, `z`, `h`, `owner`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { place, bucket, pos.x, pos.y, pos.z, heading, owner })
    if not dbId then
        Inv:AddItem(src, Config.Booster.item, 1)
        return false, 'save_failed'
    end
    local id = 'r' .. dbId
    Boosters[id] = { id = id, dbId = dbId, item = Config.Booster.item, place = place, bucket = bucket, x = pos.x, y = pos.y, z = pos.z, h = heading, owner = owner }
    TriggerClientEvent('vr-djbooth:client:speaker', -1, BoosterPayload(Boosters[id]))
    for _, sys in pairs(Systems) do
        if sys.place == place then PushPanel(sys) end
    end
    return true, id
end

function RemoveBooster(b, refundTo)
    Boosters[b.id] = nil
    MySQL.update('DELETE FROM `vr_djbooth_boosters` WHERE `id` = ?', { b.dbId })
    PushSpeakerRemoved(b.id)
    for _, sys in pairs(Systems) do
        if sys.place == b.place then PushPanel(sys) end
    end
    if refundTo then Inv:AddItem(refundTo, b.item, 1) end
end

function PickupBooster(src, b)
    local allowed, reason = CanUsePlace(src, b.place)
    if not allowed then return false, reason end
    local here = PedCoords(src)
    if not here or (b.bucket or 0) ~= GetPlayerRoutingBucket(src) or #(here - vector3(b.x, b.y, b.z)) > 5.0 then
        return false, 'too_far'
    end
    if not Inv:CanCarryItem(src, b.item, 1) then return false, 'inventory_full' end
    RemoveBooster(b, src)
    return true
end
