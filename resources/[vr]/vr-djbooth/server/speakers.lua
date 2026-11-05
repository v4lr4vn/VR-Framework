local function validPos(pos)
    if type(pos) ~= 'table' and type(pos) ~= 'vector3' then return nil end
    local x, y, z = DJ.num(pos.x), DJ.num(pos.y), DJ.num(pos.z)
    if not x or not y or not z then return nil end
    return vector3(x, y, z)
end

local function itemCount(src, item)
    return tonumber(Inv:Search(src, 'count', item)) or 0
end

local function takeItem(src, item, slot)
    slot = tonumber(slot)
    if slot and slot == math.floor(slot) and slot > 0 then
        local s = Inv:GetSlot(src, slot)
        if s and s.name == item and Inv:RemoveItem(src, item, 1, nil, slot) then return true end
    end
    return Inv:RemoveItem(src, item, 1) and true or false
end

local function groupNear(place, bucket, pos)
    local best, bestD
    for _, sp in pairs(Speakers) do
        if sp.place == place and (sp.bucket or 0) == bucket then
            local d = DJ.dist(sp, pos)
            if d <= LinkRange(place) and (not bestD or d < bestD) then best, bestD = Systems[sp.system], d end
        end
    end
    return best
end

local function newGroupName(place, label)
    if place:match('^home:') then label = Config.SystemName.home end
    local taken, n = {}, 0
    for _, sys in pairs(Systems) do
        if sys.place == place then taken[sys.name] = true; n = n + 1 end
    end
    if n == 0 and not taken[label] then return label end
    local i = n + 1
    while taken[('%s %d'):format(label, i)] do i = i + 1 end
    return ('%s %d'):format(label, i)
end

function DbAwait(kind, query, params)
    local ok, result = pcall(MySQL[kind].await, query, params)
    if not ok then
        print(('^1[vr-djbooth] database error: %s^0'):format(tostring(result)))
        return nil
    end
    return result
end

function CreateGroup(place, bucket, label)
    local name = newGroupName(place, label)
    local dbId = DbAwait('insert', 'INSERT INTO `vr_djbooth_systems` (`name`, `place`, `bucket`, `volume`) VALUES (?, ?, ?, ?)',
        { name, place, bucket, Config.DefaultVolume })
    if not dbId then return nil end
    return NewSystem('g' .. dbId, 'speakers', name, place, bucket, Config.DefaultVolume)
end

local function deleteGroup(sys)
    MySQL.update('DELETE FROM `vr_djbooth_systems` WHERE `id` = ?', { tonumber(sys.id:sub(2)) })
    RemoveSystem(sys)
end

Boomboxes = {}

local function citizenid(src)
    local Player = GetPlayer(src)
    return Player and Player.cid or nil
end

local function boomboxName(src)
    local Player = GetPlayer(src)
    local c = Player
    if c and c.firstname then return ("%s's Boombox"):format(c.firstname) end
    return Config.SystemName.boombox
end

local function addBoombox(cid, name, x, y, z, h, bucket, volume, range)
    local id = 'b' .. cid
    local sys = NewSystem(id, 'boombox', name, nil, bucket, volume)
    sys.ownerCid = cid
    sys.range = range
    Speakers[id] = { id = id, item = Config.Boombox.item, x = x, y = y, z = z, h = h, system = id, bucket = bucket, ownerCid = cid }
    sys.speakers[id] = true
    Boomboxes[cid] = id
    return sys
end

function LoadBoomboxes()
    Boomboxes = {}
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `vr_djbooth_boomboxes`') or {}) do
        local x, y, z = tonumber(row.x), tonumber(row.y), tonumber(row.z)
        if row.citizenid and x and y and z then
            addBoombox(row.citizenid, row.name, x, y, z, tonumber(row.h) or 0.0, tonumber(row.bucket) or 0,
                DJ.clamp(tonumber(row.volume) or Config.DefaultVolume, 0, 1), ValidRange(row.range_m))
        end
    end
end

function DropBoombox(cid)
    local id = Boomboxes[cid]
    if not id then return end
    Boomboxes[cid] = nil
    Speakers[id] = nil
    PushSpeakerRemoved(id)
    if Systems[id] then RemoveSystem(Systems[id]) end
end

function RemoveBoombox(cid)
    if not Boomboxes[cid] then return end
    MySQL.update('DELETE FROM `vr_djbooth_boomboxes` WHERE `citizenid` = ?', { cid })
    DropBoombox(cid)
end

function BoomboxOf(src)
    local cid = citizenid(src)
    local id = cid and Boomboxes[cid]
    return id and Speakers[id] or nil
end

local function stopIfOwnerGone(cid)
    local sys = Systems['b' .. cid]
    if sys and (sys.now or #sys.queue > 0) and not Bridge.playerByCid(cid) then
        sys.queue = {}
        StopPlayback(sys)
    end
end

Bridge.on('playerUnloaded', function(src)
    local cid = citizenid(src)
    if cid and Boomboxes[cid] then
        local sys = Systems['b' .. cid]
        if sys then
            sys.queue = {}
            StopPlayback(sys)
        end
    end
end)

CreateThread(function()
    while true do
        Wait(10000)
        for cid in pairs(Boomboxes) do stopIfOwnerGone(cid) end
    end
end)

for item in pairs(Config.Speakers) do
    Bridge.useItem(item, function(source, data)
        TriggerClientEvent('vr-djbooth:client:startPlacement', source, item, type(data) == 'table' and data.slot or nil)
    end)
end

Bridge.useItem(Config.Boombox.item, function(source, data)
    local old = BoomboxOf(source)
    TriggerClientEvent('vr-djbooth:client:startPlacement', source, Config.Boombox.item, type(data) == 'table' and data.slot or nil,
        old and { x = old.x, y = old.y, z = old.z } or nil)
end)

lib.callback.register('vr-djbooth:place', function(src, item, slot, rawPos, rawHeading, replace)
    if not Ready then return false, 'not_ready' end
    if TooFast(src, 'place', 1500) then return false, 'slow_down' end
    local info, kind = DJ.itemInfo(item)
    local pos, heading = validPos(rawPos), DJ.num(rawHeading)
    if not info or not pos or not heading then return false, 'bad_request' end
    heading = heading % 360.0

    local here = PedCoords(src)
    if not here or #(here - pos) > Config.Limits.placeDistance then return false, 'too_far' end
    if itemCount(src, item) < 1 then return false, 'no_item' end
    local bucket = GetPlayerRoutingBucket(src)

    if kind == 'boombox' then
        local cid = citizenid(src)
        if not cid then return false, 'not_loaded' end
        if Boomboxes[cid] and replace ~= true then return false, 'boombox_out' end
        if not takeItem(src, item, slot) then return false, 'no_item' end
        local name = boomboxName(src)
        local saved = DbAwait('update',
            'REPLACE INTO `vr_djbooth_boomboxes` (`citizenid`, `name`, `bucket`, `x`, `y`, `z`, `h`, `volume`, `range_m`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL)',
            { cid, name, bucket, pos.x, pos.y, pos.z, heading, Config.DefaultVolume })
        if saved == nil then
            Inv:AddItem(src, item, 1)
            return false, 'save_failed'
        end
        DropBoombox(cid)
        local sys = addBoombox(cid, name, pos.x, pos.y, pos.z, heading, bucket, Config.DefaultVolume, nil)
        PushSpeaker(Speakers[sys.id])
        PushSystem(sys)
        return true, sys.id
    end

    if kind == 'booster' then return PlaceBooster(src, slot, pos, heading, bucket, takeItem) end

    local place, label, max = ResolvePlace(src, pos, bucket)
    if not place then return false, label end
    if CountInPlace(place) >= max then return false, 'limit', max end

    if not takeItem(src, item, slot) then return false, 'no_item' end

    local sys = groupNear(place, bucket, pos) or CreateGroup(place, bucket, label)
    local Player = GetPlayer(src)
    local dbId = sys and DbAwait('insert',
        'INSERT INTO `vr_djbooth_speakers` (`item`, `system_id`, `place`, `bucket`, `x`, `y`, `z`, `h`, `owner`) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { item, tonumber(sys.id:sub(2)), place, bucket, pos.x, pos.y, pos.z, heading, Player and Player.cid or nil })
    if not dbId then
        Inv:AddItem(src, item, 1)
        if sys and Systems[sys.id] == sys and not next(sys.speakers) then deleteGroup(sys) end
        return false, 'save_failed'
    end

    if Systems[sys.id] ~= sys then
        sys = CreateGroup(place, bucket, label)
        if not sys then
            MySQL.update('DELETE FROM `vr_djbooth_speakers` WHERE `id` = ?', { dbId })
            Inv:AddItem(src, item, 1)
            return false, 'save_failed'
        end
        MySQL.update('UPDATE `vr_djbooth_speakers` SET `system_id` = ? WHERE `id` = ?', { tonumber(sys.id:sub(2)), dbId })
    end

    local id = 'p' .. dbId
    Speakers[id] = {
        id = id, dbId = dbId, item = item, system = sys.id, place = place, bucket = bucket,
        x = pos.x, y = pos.y, z = pos.z, h = heading, owner = Player and Player.cid or nil,
    }
    sys.speakers[id] = true
    Debug('%s placed %s (%s) in %s, group %s', GetPlayerName(src), item, id, place, sys.id)
    PushSpeaker(Speakers[id])
    PushSystem(sys)
    PushPanel(sys)
    return true, id, sys.name
end)

lib.callback.register('vr-djbooth:pickup', function(src, speakerId)
    if TooFast(src, 'pickup', 1000) then return false, 'slow_down' end
    local booster = type(speakerId) == 'string' and Boosters[speakerId]
    if booster then return PickupBooster(src, booster) end
    local sp = type(speakerId) == 'string' and Speakers[speakerId]
    if not sp then return false, 'gone' end

    if sp.ownerCid then
        if sp.ownerCid ~= citizenid(src) then return false, 'not_yours' end
        local here = PedCoords(src)
        if not here or (sp.bucket or 0) ~= GetPlayerRoutingBucket(src) or #(here - vector3(sp.x, sp.y, sp.z)) > 5.0 then
            return false, 'too_far'
        end
        if not Inv:CanCarryItem(src, sp.item, 1) then return false, 'inventory_full' end
        RemoveBoombox(sp.ownerCid)
        Inv:AddItem(src, sp.item, 1)
        return true
    end

    local sys = Systems[sp.system]
    local ok, reason = CanControl(src, sys)
    if not ok then return false, reason end
    local here = PedCoords(src)
    if not here or #(here - vector3(sp.x, sp.y, sp.z)) > 5.0 then return false, 'too_far' end
    if not Inv:CanCarryItem(src, sp.item, 1) then return false, 'inventory_full' end

    Speakers[sp.id] = nil
    sys.speakers[sp.id] = nil
    MySQL.update('DELETE FROM `vr_djbooth_speakers` WHERE `id` = ?', { sp.dbId })
    PushSpeakerRemoved(sp.id)
    if not next(sys.speakers) then
        deleteGroup(sys)
    else
        PushSystem(sys)
        PushPanel(sys)
    end
    Inv:AddItem(src, sp.item, 1)
    return true
end)

function OpenPanel(src, sys)
    Viewers[sys.id] = Viewers[sys.id] or {}
    Viewers[sys.id][src] = true
    return PanelPayload(sys, src)
end

lib.callback.register('vr-djbooth:open', function(src, systemId)
    if TooFast(src, 'open', 500) then return false, 'slow_down' end
    local sys = type(systemId) == 'string' and Systems[systemId]
    if not sys or sys.kind == 'vehicle' then return false, 'gone' end
    local ok, reason = CanControl(src, sys)
    if not ok then return false, reason end
    return true, OpenPanel(src, sys)
end)

RegisterNetEvent('vr-djbooth:server:close', function(systemId)
    local list = type(systemId) == 'string' and Viewers[systemId]
    if list then list[source] = nil end
end)

local function moveSpeaker(sp, to)
    local from = Systems[sp.system]
    if from then from.speakers[sp.id] = nil end
    to.speakers[sp.id] = true
    sp.system = to.id
    MySQL.update('UPDATE `vr_djbooth_speakers` SET `system_id` = ? WHERE `id` = ?', { tonumber(to.id:sub(2)), sp.dbId })
    PushSpeaker(sp)
    if from then
        if not next(from.speakers) then
            deleteGroup(from)
        else
            PushSystem(from)
            PushPanel(from)
        end
    end
    PushSystem(to)
    PushPanel(to)
end

function Actions.link(src, sys, data)
    if sys.kind ~= 'speakers' then return false, 'not_allowed' end
    local sp = type(data.speakerId) == 'string' and Speakers[data.speakerId]
    if not sp then return false, 'gone' end
    if not LinkCandidates(sys)[sp.id] then return false, 'link_range' end
    local ok, reason = CanUsePlace(src, sp.place)
    if not ok then return false, reason end
    moveSpeaker(sp, sys)
    return true
end

function Actions.unlink(_, sys, data)
    if sys.kind ~= 'speakers' then return false, 'not_allowed' end
    local sp = type(data.speakerId) == 'string' and Speakers[data.speakerId]
    if not sp or sp.system ~= sys.id then return false, 'gone' end
    if CountSpeakers(sys) < 2 then return false, 'last_speaker' end
    local group = CreateGroup(sys.place, sys.bucket, PlaceLabel(sys.place))
    if not group then return false, 'save_failed' end
    if Speakers[sp.id] ~= sp or sp.system ~= sys.id then
        deleteGroup(group)
        return false, 'gone'
    end
    moveSpeaker(sp, group)
    return true
end
