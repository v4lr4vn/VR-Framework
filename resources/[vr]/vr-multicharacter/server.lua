local VRCore = exports['vr-core']:GetCoreObject({ 'Functions', 'Commands', 'Player' })
local starterItems = exports['vr-core']:GetShared('StarterItems') or {}
local Countries = json.decode(LoadResourceFile(GetCurrentResourceName(), 'countries.json') or '[]')
local preloaded = {}

local function licenseOf(src)
    return VRCore.Functions.GetIdentifier(src, 'license')
end

local function slotsFor(license)
    for _, v in ipairs(Config.PlayersNumberOfCharacters) do
        if v.license == license then return v.numberOfChars end
    end
    return Config.DefaultNumberOfCharacters
end

local function waitForPreload(src)
    local deadline = GetGameTimer() + 10000
    while not preloaded[src] and GetGameTimer() < deadline do Wait(10) end
    return preloaded[src]
end

local function cleanString(value, maxLength)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c<>]', ''):match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, maxLength)
end

-- years between an ISO birth date (YYYY-MM-DD) and today, or nil if it is not a real date
local function ageFrom(iso)
    if type(iso) ~= 'string' then return nil end
    local y, m, d = iso:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 or y < 1900 then return nil end
    local now = os.date('*t')
    local age = now.year - y
    if now.month < m or (now.month == m and now.day < d) then age = age - 1 end
    if age < 0 then return nil end
    return age
end

local function createFailed(src, message)
    TriggerClientEvent('vr-multicharacter:client:createFailed', src, message)
end

local function heightFrom(value)
    if GetResourceState('vr-pedscale') ~= 'started' then return nil end
    local limits = exports['vr-pedscale']:GetLimits()
    local cm = math.floor((tonumber(value) or limits.default) + 0.5)
    return math.max(limits.min, math.min(limits.max, cm))
end

local function giveStarterItems(src)
    if GetResourceState('vr-inventory') ~= 'started' then return end
    local player = exports['vr-core']:GetPlayer(src)
    if not player then return end

    local deadline = GetGameTimer() + 5000
    while not exports['vr-inventory']:GetInventory(src) and GetGameTimer() < deadline do Wait(100) end

    local idcard = GetResourceState('vr-idcard') == 'started'

    local pd, ci = player.PlayerData, player.PlayerData.charinfo
    for _, v in pairs(starterItems) do
        if idcard and exports['vr-idcard']:IsCard(v.item) then
            for _ = 1, v.amount or 1 do exports['vr-idcard']:CreateMetaLicense(src, v.item) end
        else
            local metadata
            if v.item == 'id_card' then
                metadata = {
                    citizenid = pd.citizenid, firstname = ci.firstname, lastname = ci.lastname,
                    birthdate = ci.birthdate, gender = ci.gender, nationality = ci.nationality,
                    description = ('%s %s | %s | %s'):format(ci.firstname, ci.lastname, ci.birthdate, pd.citizenid),
                }
            elseif v.item == 'driver_license' then
                metadata = {
                    firstname = ci.firstname, lastname = ci.lastname, birthdate = ci.birthdate, type = 'Class C Driver License',
                    description = ('%s %s | Class C'):format(ci.firstname, ci.lastname),
                }
            end
            local ok, err = exports['vr-inventory']:AddItem(src, v.item, v.amount, metadata)
            if not ok then print(('^3[vr-multicharacter] starter item %s not given: %s^0'):format(v.item, tostring(err))) end
        end
    end
end

VRCore.Commands.Add('logout', Lang:t('commands.logout_description'), {}, false, function(source)
    VRCore.Player.Logout(source)
    TriggerClientEvent('vr-multicharacter:client:chooseChar', source)
end, 'admin')

VRCore.Commands.Add('closeNUI', Lang:t('commands.closeNUI_description'), {}, false, function(source)
    TriggerClientEvent('vr-multicharacter:client:closeNUI', source)
end)

VRCore.Commands.Add('deletechar', Lang:t('commands.deletechar_description'), { { name = Lang:t('commands.citizenid'), help = Lang:t('commands.citizenid_help') } }, false, function(source, args)
    if not args[1] then
        return TriggerClientEvent('VRCore:Notify', source, Lang:t('notifications.forgot_citizenid'), 'error')
    end
    VRCore.Player.ForceDeleteCharacter(tostring(args[1]))
    TriggerClientEvent('VRCore:Notify', source, Lang:t('notifications.deleted_other_char', { citizenid = tostring(args[1]) }))
end, 'god')

AddEventHandler('VRCore:Server:PlayerLoaded', function(player)
    local src = player.PlayerData.source
    Wait(1000)
    preloaded[src] = true
end)

AddEventHandler('VRCore:Server:OnPlayerUnload', function(src)
    preloaded[src] = nil
end)

AddEventHandler('playerDropped', function()
    preloaded[source] = nil
end)

RegisterNetEvent('vr-multicharacter:server:disconnect', function()
    DropPlayer(source, Lang:t('misc.droppedplayer'))
end)

RegisterNetEvent('vr-multicharacter:server:loadUserData', function(cData)
    local src = source
    local citizenid = type(cData) == 'table' and cleanString(cData.citizenid, 50)
    if not citizenid or VRCore.Functions.GetPlayer(src) then return end
    if not VRCore.Player.Login(src, citizenid) then return end
    waitForPreload(src)
    print(('^2[vr-core]^7 %s (Citizen ID: %s) has successfully loaded!'):format(GetPlayerName(src), citizenid))
    VRCore.Commands.Refresh(src)
    TriggerEvent('vr-multicharacter:server:begin', src, false)
end)

RegisterNetEvent('vr-multicharacter:server:createCharacter', function(data)
    local src = source
    if type(data) ~= 'table' or VRCore.Functions.GetPlayer(src) then return end
    local license = licenseOf(src)

    local owned = MySQL.scalar.await('SELECT COUNT(*) FROM vr_players WHERE license = ?', { license }) or 0
    if owned >= slotsFor(license) then
        TriggerClientEvent('VRCore:Notify', src, Lang:t('notifications.slots_full'), 'error')
        return createFailed(src, Lang:t('notifications.slots_full'))
    end

    local firstname, lastname = cleanString(data.firstname, 50), cleanString(data.lastname, 50)
    if not firstname or not lastname then
        return createFailed(src, Lang:t('notifications.invalid_name'))
    end

    local minAge = tonumber(Config.MinAge) or 0
    if minAge > 0 then
        local age = ageFrom(cleanString(data.birthdate, 20))
        if not age then return createFailed(src, Lang:t('notifications.invalid_birthdate')) end
        if age < minAge then return createFailed(src, Lang:t('notifications.too_young', { age = minAge })) end
    end

    local newData = {
        cid = math.floor(tonumber(data.cid) or (owned + 1)),
        charinfo = {
            firstname = firstname,
            lastname = lastname,
            birthdate = cleanString(data.birthdate, 20) or '01-01-2000',
            nationality = cleanString(data.nationality, 50) or 'USA',
            gender = tonumber(data.gender) == 1 and 1 or 0,
            height = heightFrom(data.height),
        },
    }

    if not VRCore.Player.Login(src, false, newData) then
        return createFailed(src, Lang:t('notifications.create_failed'))
    end
    waitForPreload(src)
    print(('^2[vr-core]^7 %s has created a new character!'):format(GetPlayerName(src)))
    VRCore.Commands.Refresh(src)
    TriggerClientEvent('vr-multicharacter:client:closeNUI', src)
    giveStarterItems(src)
    local player = exports['vr-core']:GetPlayer(src)
    if player then
        TriggerEvent('vr-multicharacter:server:characterCreated', src, player.PlayerData.citizenid)
    end
    TriggerEvent('vr-multicharacter:server:begin', src, true)
end)

RegisterNetEvent('vr-multicharacter:server:deleteCharacter', function(citizenid)
    local src = source
    if not Config.EnableDeleteButton or type(citizenid) ~= 'string' then return end
    VRCore.Player.DeleteCharacter(src, citizenid)
    TriggerClientEvent('VRCore:Notify', src, Lang:t('notifications.char_deleted'), 'success')
end)

VRCore.Functions.CreateCallback('vr-multicharacter:server:GetNumberOfCharacters', function(source, cb)
    cb(slotsFor(licenseOf(source)), Countries)
end)

VRCore.Functions.CreateCallback('vr-multicharacter:server:setupCharacters', function(source, cb)
    local rows = MySQL.query.await('SELECT citizenid, cid, charinfo, money, job, UNIX_TIMESTAMP(last_updated) AS lastPlayed FROM vr_players WHERE license = ?', { licenseOf(source) }) or {}
    for i = 1, #rows do
        rows[i].charinfo = json.decode(rows[i].charinfo)
        rows[i].money = json.decode(rows[i].money)
        rows[i].job = json.decode(rows[i].job)
    end
    cb(rows)
end)

VRCore.Functions.CreateCallback('vr-multicharacter:server:getSkin', function(source, cb, citizenid)
    local row = MySQL.single.await([[
        SELECT s.model, s.skin FROM vr_clothing_skins s
        JOIN vr_players p ON p.citizenid = s.citizenid
        WHERE s.citizenid = ? AND p.license = ? AND s.active = 1 LIMIT 1]], { citizenid, licenseOf(source) })
    if row then
        cb(row.model, row.skin)
    else
        cb(nil)
    end
end)
