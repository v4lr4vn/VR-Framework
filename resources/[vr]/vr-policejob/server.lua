local stashStations = {}

local function groupsFor(jobs, minGrade)
    local groups = {}
    for _, name in ipairs(jobs or {}) do
        groups[name] = minGrade or 0
    end
    return groups
end

local function toVec3(pos)
    return pos and vec3(pos.x, pos.y, pos.z) or nil
end

for _, station in pairs(Config.PoliceStations) do
    local armory = station.armory
    if armory and armory.require_storage and armory.storage then
        stashStations[armory.storage.stashId] = { station = station, minGrade = 0 }
    end
    for stashId, stash in pairs(station.stash or {}) do
        stashStations[stashId] = { station = station, minGrade = stash.min_grade or 0 }
    end
end

local function escapePattern(s)
    return (s:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0'))
end

local function stashEntry(inventoryId)
    if type(inventoryId) ~= 'string' then return nil end
    local entry = stashStations[inventoryId]
    if entry then return entry end
    for id, e in pairs(stashStations) do
        if inventoryId:sub(1, #id) == id then return e end
    end
    return nil
end

CreateThread(function()
    for _, station in pairs(Config.PoliceStations) do
        local armory = station.armory

        if armory and armory.require_storage and armory.storage then
            local storage = armory.storage
            exports['vr-inventory']:RegisterStash(storage.stashId, storage.stashLabel, 500, 1000 * 1000, nil,
                groupsFor(station.jobs, storage.minGradeAccess), toVec3(armory.playerPos or armory.pedPos))
        end

        for stashId, stash in pairs(station.stash or {}) do
            exports['vr-inventory']:RegisterStash(stashId, stash.label, stash.slots, stash.weight * 1000,
                stash.shared == false and true or nil, groupsFor(station.jobs, stash.min_grade), stash.pos)
        end
    end

    local patterns = {}
    for id in pairs(stashStations) do patterns[#patterns + 1] = '^' .. escapePattern(id) end
    if #patterns > 0 then
        pcall(function()
            exports['vr-inventory']:registerHook('openInventory', function(payload)
                local entry = type(payload) == 'table' and stashEntry(payload.inventoryId)
                if not entry then return end
                if not hasJob(payload.source, entry.station.jobs) then return false end
            end, { inventoryFilter = patterns })
        end)
    end
end)

local function canReadStash(src, stashId)
    local entry = stashStations[stashId]
    if not entry then return false end
    if not hasJob(src, entry.station.jobs) then return false end
    return getPlayerJobGrade(src) >= (entry.minGrade or 0)
end

lib.callback.register('vr-policejob:getItemCount', function(source, stash, item)
    if type(stash) ~= 'string' or type(item) ~= 'string' or #item > 64 then return 0 end
    if not canReadStash(source, stash) then
        Security.flag(source, ('getItemCount on %s'):format(stash:sub(1, 64)))
        return 0
    end
    return tonumber(exports['vr-inventory']:Search(stash, 'count', item)) or 0
end)

RegisterNetEvent('vr-policejob:server:takeArmoryItem', function(stationId, itemIndex)
    local src = source
    local station = type(stationId) == 'string' and Config.PoliceStations[stationId] or nil
    local armory = station and station.armory
    if not armory or type(armory.equipment) ~= 'table' then return end
    if not hasJob(src, station.jobs) then return end
    if not Security.cooldown('armory', src, Config.Security.armoryCooldown) then return end

    local dist = Security.distanceTo(src, armory.playerPos or armory.pedPos)
    if not dist or dist > Config.Security.armoryDistance then
        return Security.flag(src, 'armory request away from the armory')
    end

    local list = armory.equipment[getPlayerJobGrade(src)] or armory.equipment[1]
    itemIndex = Security.int(itemIndex, 1)
    local entry = type(list) == 'table' and itemIndex and list[itemIndex] or nil
    if type(entry) ~= 'table' or type(entry.item) ~= 'string' then
        return Security.flag(src, 'armory item not in the grade list')
    end

    local item = entry.item
    local label = entry.label or item
    local have = tonumber(exports['vr-inventory']:Search(src, 'count', item)) or 0
    local amount = (Security.int(entry.quantity, 1) or 1) - have
    if amount <= 0 then
        return notify(src, ('%s %s'):format(label, locale('already_have_item')))
    end

    local stashId = armory.require_storage and armory.storage and armory.storage.stashId or nil
    if stashId then
        local stock = tonumber(exports['vr-inventory']:Search(stashId, 'count', item)) or 0
        if stock < 1 then
            return notify(src, ('%s %s'):format(label, locale('no_item_in_storage')))
        end
        amount = math.min(amount, stock)
    end

    if not exports['vr-inventory']:CanCarryItem(src, item, amount) then
        return notify(src, locale('cannot_carry'), 'error')
    end

    if stashId then
        if not exports['vr-inventory']:RemoveItem(stashId, item, amount) then return end
        if not exports['vr-inventory']:AddItem(src, item, amount) then
            exports['vr-inventory']:AddItem(stashId, item, amount)
            return notify(src, locale('cannot_carry'), 'error')
        end
    elseif not exports['vr-inventory']:AddItem(src, item, amount) then
        return notify(src, locale('cannot_carry'), 'error')
    end
end)

local ALERTS = {
    panic = {
        message = 'panic_alert_message',
        codeName = 'panic',
        code = '10-99',
        icon = 'fas fa-skull',
        priority = 1,
        jobs = { 'leo', 'ems' },
        alert = { radius = 15.0, sprite = 161, color = 1, scale = 1.2, length = 2, flash = true },
    },
    backup = {
        message = 'backup_alert_message',
        codeName = 'officerbackup',
        code = '10-32',
        icon = 'fas fa-shield-halved',
        priority = 1,
        jobs = { 'leo' },
    },
}

local function copy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = copy(v) end
    return out
end

local function playerGender(src)
    local p = getPlayer(src)
    local ci = p and p.PlayerData.charinfo
    if type(ci) ~= 'table' then return nil end
    return tonumber(ci.gender) == 1 and 'Female' or 'Male'
end

function sendOfficerAlert(src, kind)
    local def = ALERTS[kind]
    if not def or not hasJob(src, Config.AccessToMenu) then return false end
    if not Security.cooldown('alert:' .. kind, src, Config.Security.alertCooldown) then
        notify(src, locale('alert_cooldown'), 'error')
        return false
    end

    local coords = Security.coords(src)
    if not coords then return false end

    if GetResourceState('vr-mdt') == 'started' then
        local data = {
            message = locale(def.message),
            codeName = def.codeName,
            code = def.code,
            icon = def.icon,
            priority = def.priority,
            gender = playerGender(src),
            alertTime = 10,
            jobs = copy(def.jobs),
            alert = copy(def.alert),
        }
        local ok, id = pcall(function() return exports['vr-mdt']:SendAlert(data, src) end)
        if ok and id then return true end
    end

    local blip = { name = locale('emergency_blip_label'), type = 161, scale = 1.2, color = 1, pos = vec3(coords.x, coords.y, coords.z) }
    for _, id in ipairs(getOnDutyPlayers(policeJobList())) do
        TriggerClientEvent('vr-policejob:client:createEmergencyBlip', id, blip)
    end
    return true
end

RegisterNetEvent('vr-policejob:server:panic', function()
    sendOfficerAlert(source, 'panic')
end)

local function inList(list, value)
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

RegisterNetEvent('vr-policejob:server:activateBlip', function(data)
    local src = source
    if type(data) ~= 'table' or not hasJob(src, Config.AccessToMenu) then return end

    local cfg = Config.InterdictArea
    local reason = Security.text(data.reason, cfg.maxLength)
    local radius = Security.int(tonumber(data.radius), 1)
    local blipType = Security.int(data.type, 1)
    local minutes = Security.int(data.time, 1, cfg.maxMinutes)
    if not reason or not radius or not inList(cfg.radii, radius) or not blipType or not inList(cfg.types, blipType) or not minutes then
        return notify(src, locale('invalid_input'), 'error')
    end
    if not Security.cooldown('interdict', src, Config.Security.interdictCooldown) then
        return notify(src, locale('action_cooldown'), 'error')
    end

    local coords = Security.coords(src)
    if not coords then return end

    local payload = {
        reason = reason,
        radius = radius + 0.0,
        type = blipType,
        position = vec3(coords.x, coords.y, coords.z),
        time = minutes * 60000,
    }
    for _, id in ipairs(getOnDutyPlayers(policeJobList(cfg.jobs))) do
        TriggerClientEvent('vr-policejob:client:activateBlip', id, payload)
    end
end)

local function cleanup(src)
    src = tonumber(src)
    if not src then return end
    releaseDragsBy(src)
    releaseDrag(src)
    clearCuffs(src)
    Security.clearSource(src)
end

AddEventHandler('playerDropped', function()
    cleanup(source)
end)

AddEventHandler('VRCore:Server:OnPlayerUnload', function(src)
    cleanup(src)
end)

AddEventHandler('VRCore:Server:SetDuty', function(src, onduty)
    if not onduty then releaseDragsBy(tonumber(src)) end
end)

AddEventHandler('VRCore:Server:OnJobUpdate', function(src, job)
    src = tonumber(src)
    if not src then return end
    job = normalizeJob(job)
    if type(job) ~= 'table' or job.onduty ~= true or not isPoliceJob(job, Config.Interactions.jobs) then
        releaseDragsBy(src)
    end
end)
