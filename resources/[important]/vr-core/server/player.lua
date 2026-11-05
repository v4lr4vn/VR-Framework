local VRCore    = VRCore
local Config    = VRCore.Config
local Shared    = VRCore.Shared
local Functions = VRCore.Functions
local Resources = Config.Resources
local resourceName = GetCurrentResourceName()

VRCore.Player = {}

local Players   = VRCore.Players
local ByCid     = VRCore.PlayersByCitizenId
local ByLicense = VRCore.PlayersByLicense

local legacyInventory = Resources.inventory and not IsSlotInventory

local noMinus = {}
for _, moneytype in ipairs(Config.Money.DontAllowMinus) do noMinus[moneytype] = true end

local varargMethods = {
    'GetPlayerData', 'UpdateClient', 'SetJob', 'SetGang', 'Notify', 'HasItem',
    'SetJobDuty', 'SetPlayerData', 'SetMetaData', 'GetMetaData',
    'AddRep', 'RemoveRep', 'GetRep', 'AddMoney', 'RemoveMoney', 'SetMoney', 'GetMoney',
    'AddMethod', 'AddField',
}
local noargMethods = { 'GetName', 'Save', 'Logout' }

local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) == 'table' and type(rawget(value, '__cfx_functionReference')) == 'string' then return true end
    local mt = getmetatable(value)
    return mt ~= nil and type(mt.__call) == 'function'
end

local function buildMethodTable(player)
    local t = {}
    for _, name in ipairs(varargMethods) do
        local fn = player[name]
        t[name] = function(...) return fn(player, ...) end
    end
    for _, name in ipairs(noargMethods) do
        local fn = player[name]
        t[name] = function() return fn(player) end
    end
    t.UpdatePlayerData = t.UpdateClient
    if VRCore.Player.ExtendMethods then VRCore.Player.ExtendMethods(player, t) end
    return t
end

local Player = {}
Player.__index = Player

function Player.new(PlayerData, Offline)
    local self = setmetatable({}, Player)
    self.PlayerData = PlayerData
    self.Offline = Offline or false
    self.Functions = buildMethodTable(self)
    return self
end

function Player:GetPlayerData()
    return self.PlayerData
end

function Player:UpdateClient(key, val, sub)
    if self.Offline then return end
    local src = self.PlayerData.source
    if not key then
        CoreEmit('Player:SetPlayerData', self.PlayerData)
        CoreEmit('Server:OnPlayerUpdated', src, 'all', self.PlayerData)
        CoreEmit('Server:OnJobUpdate', src, self.PlayerData.job)
        CoreEmit('Server:OnGangUpdate', src, self.PlayerData.gang)
        TriggerClientEvent('VRCore:Client:OnPlayerUpdated', src, 'all', self.PlayerData)
        return
    end
    CoreEmit('Server:OnPlayerUpdated', src, key, val, sub)
    if key == 'job' then
        CoreEmit('Server:OnJobUpdate', src, val)
    elseif key == 'gang' then
        CoreEmit('Server:OnGangUpdate', src, val)
    end
    TriggerClientEvent('VRCore:Client:OnPlayerUpdated', src, key, val, sub)
end

local function gradeKey(grade)
    return tostring(math.floor(tonumber(grade) or 0))
end

function Player:SetJob(job, grade)
    if type(job) ~= 'string' then return false end
    job = job:lower()
    local info = Shared.Jobs[job]
    if not info then return false end
    local key = gradeKey(grade)
    local g = info.grades[key]
    self.PlayerData.job = {
        name = job,
        label = info.label,
        onduty = info.defaultDuty,
        type = info.type or 'none',
        isboss = g and g.isboss or false,
        grade = {
            name = g and g.name or 'No Grades',
            level = g and tonumber(key) or 0,
            payment = g and g.payment or 30,
            isboss = g and g.isboss or false,
        },
    }
    self:UpdateClient('job', self.PlayerData.job)
    return true
end

function Player:SetGang(gang, grade)
    if type(gang) ~= 'string' then return false end
    gang = gang:lower()
    local info = Shared.Gangs[gang]
    if not info then return false end
    local key = gradeKey(grade)
    local g = info.grades[key]
    self.PlayerData.gang = {
        name = gang,
        label = info.label,
        isboss = g and g.isboss or false,
        grade = {
            name = g and g.name or 'No Grades',
            level = g and tonumber(key) or 0,
            isboss = g and g.isboss or false,
        },
    }
    self:UpdateClient('gang', self.PlayerData.gang)
    return true
end

function Player:Notify(text, notifyType, length)
    if self.Offline then return end
    TriggerClientEvent('VRCore:Notify', self.PlayerData.source, text, notifyType, length)
end

function Player:HasItem(items, amount)
    return Functions.HasItem(self.PlayerData.source, items, amount)
end

function Player:GetName()
    local charinfo = self.PlayerData.charinfo
    return charinfo.firstname .. ' ' .. charinfo.lastname
end

function Player:SetJobDuty(onDuty)
    self.PlayerData.job.onduty = not not onDuty
    self:UpdateClient('job', self.PlayerData.job)
end

function Player:SetPlayerData(key, val)
    if type(key) ~= 'string' then return end
    self.PlayerData[key] = val
    self:UpdateClient(key, val)
end

function Player:SetMetaData(meta, val)
    if type(meta) ~= 'string' then return end
    if meta == 'hunger' or meta == 'thirst' then
        val = math.min(100, math.max(0, tonumber(val) or 0))
    end
    self.PlayerData.metadata[meta] = val
    self:UpdateClient('metadata', val, meta)
end

function Player:GetMetaData(meta)
    if type(meta) ~= 'string' then return end
    return self.PlayerData.metadata[meta]
end

local function repTable(self)
    local md = self.PlayerData.metadata
    md.rep = md.rep or {}
    return md.rep
end

function Player:AddRep(rep, amount)
    amount = tonumber(amount)
    if not rep or not amount then return end
    local reps = repTable(self)
    reps[rep] = (reps[rep] or 0) + amount
    self:UpdateClient('metadata', reps, 'rep')
end

function Player:RemoveRep(rep, amount)
    amount = tonumber(amount)
    if not rep or not amount then return end
    local reps = repTable(self)
    reps[rep] = math.max(0, (reps[rep] or 0) - amount)
    self:UpdateClient('metadata', reps, 'rep')
end

function Player:GetRep(rep)
    if not rep then return end
    return repTable(self)[rep] or 0
end

local function moneyArgs(self, moneytype, amount)
    if type(moneytype) ~= 'string' then return end
    moneytype = moneytype:lower()
    amount = tonumber(amount)
    if not amount or amount < 0 or amount ~= amount or amount == math.huge then return end
    if self.PlayerData.money[moneytype] == nil then return end
    return moneytype, amount
end

local function moneyChanged(self, moneytype, amount, operation, reason, logColor, tagEveryone)
    if self.Offline then return end
    local pd = self.PlayerData
    TriggerClientEvent('VRCore:Client:OnMoneyChange', pd.source, moneytype, amount, operation, reason, pd.money)
    CoreEmit('Server:OnMoneyChange', pd.source, moneytype, amount, operation, reason)
    CoreEmit('Server:OnPlayerUpdated', pd.source, 'money', pd.money)
    CoreLog('playermoney', operation == 'add' and 'AddMoney' or operation == 'remove' and 'RemoveMoney' or 'SetMoney', logColor, tagEveryone,
        '**%s** (citizenid: %s | id: %s) $%s (%s) %s, new %s balance: %s reason: %s',
        pd.name, pd.citizenid, pd.source, amount, moneytype, operation == 'add' and 'added' or operation == 'remove' and 'removed' or 'set',
        moneytype, pd.money[moneytype], reason)
end

function Player:AddMoney(moneytype, amount, reason)
    local mt, amt = moneyArgs(self, moneytype, amount)
    if not mt then return false end
    local money = self.PlayerData.money
    money[mt] = money[mt] + amt
    moneyChanged(self, mt, amt, 'add', reason or 'unknown', 'lightgreen', amt > 100000)
    return true
end

function Player:RemoveMoney(moneytype, amount, reason)
    local mt, amt = moneyArgs(self, moneytype, amount)
    if not mt then return false end
    local money = self.PlayerData.money
    local after = money[mt] - amt
    if (noMinus[mt] and after < 0) or after < Config.Money.MinusLimit then return false end
    money[mt] = after
    moneyChanged(self, mt, amt, 'remove', reason or 'unknown', 'red', amt > 100000)
    return true
end

function Player:SetMoney(moneytype, amount, reason)
    local mt, amt = moneyArgs(self, moneytype, amount)
    if not mt then return false end
    self.PlayerData.money[mt] = amt
    moneyChanged(self, mt, amt, 'set', reason or 'unknown', 'green', false)
    return true
end

function Player:GetMoney(moneytype)
    if type(moneytype) ~= 'string' then return false end
    return self.PlayerData.money[moneytype:lower()]
end

function Player:Save()
    if self.Offline then
        VRCore.Player.SaveOffline(self.PlayerData)
    else
        VRCore.Player.Save(self.PlayerData.source)
    end
end

function Player:Logout()
    if self.Offline then return end
    VRCore.Player.Logout(self.PlayerData.source)
end

function Player:AddMethod(methodName, handler)
    if type(methodName) ~= 'string' or not isCallable(handler) then return false end
    self[methodName] = handler
    self.Functions[methodName] = handler
    return true
end

function Player:AddField(fieldName, data)
    if type(fieldName) ~= 'string' or isCallable(data) then return false end
    self[fieldName] = data
    return true
end

local function decode(value)
    if type(value) ~= 'string' or value == '' then return nil end
    return json.decode(value)
end

local function decodePlayerFields(pd)
    pd.money    = decode(pd.money)
    pd.job      = decode(pd.job)
    pd.gang     = decode(pd.gang)
    pd.position = decode(pd.position)
    pd.metadata = decode(pd.metadata)
    pd.charinfo = decode(pd.charinfo)
end

local function applyDefaults(data, defaults)
    for key, value in pairs(defaults) do
        local t = type(value)
        if t == 'function' then
            if data[key] == nil then data[key] = value() end
        elseif t == 'table' then
            if type(data[key]) ~= 'table' then data[key] = {} end
            applyDefaults(data[key], value)
        elseif data[key] == nil then
            data[key] = value
        end
    end
end

local function validateGroup(group, list, withPayment)
    if not group or group.name == nil or not group.grade or group.grade.level == nil then return nil end
    local info = list[group.name]
    local g = info and info.grades[tostring(group.grade.level)]
    if not g then return nil end
    group.label = info.label
    group.grade.name = g.name
    if withPayment then group.grade.payment = g.payment end
    group.grade.isboss = g.isboss or false
    group.isboss = g.isboss or false
    return group
end

local SELECT_BY_CID     = 'SELECT * FROM vr_players WHERE citizenid = ? LIMIT 1'
local SELECT_BY_LICENSE = 'SELECT * FROM vr_players WHERE license = ? LIMIT 1'

function VRCore.Player.Login(source, citizenid, newData)
    if not source or source == '' then
        VRCore.ShowError(resourceName, 'VRCore.Player.Login - no source given')
        return false
    end
    if not citizenid then
        VRCore.Player.CheckPlayerData(source, newData)
        return true
    end
    local license = Functions.GetIdentifier(source, 'license')
    local pd = MySQL.single.await(SELECT_BY_CID, { citizenid })
    if not pd or pd.license ~= license then
        DropPlayer(source, Lang:t('info.exploit_dropped'))
        CoreLog('anticheat', 'Anti-Cheat', 'white', false, '%s Has Been Dropped For Character Joining Exploit', GetPlayerName(source))
        return false
    end
    decodePlayerFields(pd)
    VRCore.Player.CheckPlayerData(source, pd)
    return true
end

local function forget(src)
    local player = Players[src]
    if not player then return end
    local pd = player.PlayerData
    if ByCid[pd.citizenid] == player then ByCid[pd.citizenid] = nil end
    if pd.license and ByLicense[pd.license] == player then ByLicense[pd.license] = nil end
    if pd.license then VRCore.Player_Buckets[pd.license] = nil end
    Players[src] = nil
end
VRCore.Player.Forget = forget

function VRCore.Player.Logout(source)
    local player = Players[source]
    if not player then return end
    player:Save()
    TriggerClientEvent('VRCore:Client:OnPlayerUnload', source)
    CoreEmit('Server:OnPlayerUnload', source)
    forget(source)
end

function VRCore.Player.GetOfflinePlayer(citizenid)
    if not citizenid then return nil end
    local pd = MySQL.single.await(SELECT_BY_CID, { citizenid })
    if not pd then return nil end
    decodePlayerFields(pd)
    return VRCore.Player.CheckPlayerData(nil, pd)
end

function VRCore.Player.GetPlayerByLicense(license)
    if not license then return nil end
    return ByLicense[license] or VRCore.Player.GetOfflinePlayerByLicense(license)
end

function VRCore.Player.GetOfflinePlayerByLicense(license)
    if not license then return nil end
    local pd = MySQL.single.await(SELECT_BY_LICENSE, { license })
    if not pd then return nil end
    decodePlayerFields(pd)
    return VRCore.Player.CheckPlayerData(nil, pd)
end

function VRCore.Player.CheckPlayerData(source, PlayerData)
    PlayerData = PlayerData or {}
    local offline = not source

    if source then
        PlayerData.source  = source
        PlayerData.license = PlayerData.license or Functions.GetIdentifier(source, 'license')
        PlayerData.name    = GetPlayerName(source)
    end

    PlayerData.job  = validateGroup(PlayerData.job, Shared.Jobs, true)
    PlayerData.gang = validateGroup(PlayerData.gang, Shared.Gangs, false)

    applyDefaults(PlayerData, Config.Player.PlayerDefaults)

    for moneytype, start in pairs(Config.Money.MoneyTypes) do
        if PlayerData.money[moneytype] == nil then PlayerData.money[moneytype] = start end
    end

    if Shared.ForceJobDefaultDutyAtLogin then
        local info = Shared.Jobs[PlayerData.job.name]
        if info then PlayerData.job.onduty = info.defaultDuty end
    end

    if not offline and legacyInventory and ResourceUp(Resources.inventory) then
        PlayerData.items = exports[Resources.inventory]:LoadInventory(PlayerData.source, PlayerData.citizenid)
    end

    return VRCore.Player.CreatePlayer(PlayerData, offline)
end

function VRCore.Player.CreatePlayer(PlayerData, Offline)
    local player = Player.new(PlayerData, Offline)
    if Offline then return player end
    Players[PlayerData.source] = player
    ByCid[PlayerData.citizenid] = player
    if PlayerData.license then ByLicense[PlayerData.license] = player end
    VRCore.Player.Save(PlayerData.source)
    CoreEmit('Server:PlayerLoaded', player)
    player:UpdateClient()
    return player
end

local function forEachPlayer(ids, fn)
    if type(ids) == 'number' then
        if ids == -1 then
            for _, p in pairs(Players) do fn(p) end
        elseif Players[ids] then
            fn(Players[ids])
        end
    elseif type(ids) == 'table' then
        for i = 1, #ids do forEachPlayer(ids[i], fn) end
    end
end

function Functions.AddPlayerMethod(ids, methodName, handler)
    forEachPlayer(ids, function(p) p:AddMethod(methodName, handler) end)
end

function Functions.AddPlayerField(ids, fieldName, data)
    forEachPlayer(ids, function(p) p:AddField(fieldName, data) end)
end

local SAVE_QUERY = [[
INSERT INTO vr_players (citizenid, cid, license, name, money, charinfo, job, gang, position, metadata)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON DUPLICATE KEY UPDATE cid = ?, name = ?, money = ?, charinfo = ?, job = ?, gang = ?, position = ?, metadata = ?]]

local function writePlayer(pd, position)
    local cid      = tonumber(pd.cid) or 1
    local name     = pd.name or ''
    local money    = json.encode(pd.money)
    local charinfo = json.encode(pd.charinfo)
    local job      = json.encode(pd.job)
    local gang     = json.encode(pd.gang)
    local pos      = json.encode(position)
    local metadata = json.encode(pd.metadata)
    MySQL.prepare(SAVE_QUERY, {
        pd.citizenid, cid, pd.license, name, money, charinfo, job, gang, pos, metadata,
        cid, name, money, charinfo, job, gang, pos, metadata,
    })
end

function VRCore.Player.Save(source)
    local player = Players[source]
    if not player then
        if Config.Debug then VRCore.ShowError(resourceName, ('Save - no player loaded for %s'):format(tostring(source))) end
        return
    end
    local pd = player.PlayerData
    local ped = GetPlayerPed(source)
    local position = ped ~= 0 and GetEntityCoords(ped) or pd.position
    writePlayer(pd, position)
    if legacyInventory and ResourceUp(Resources.inventory) then exports[Resources.inventory]:SaveInventory(source) end
    if Config.Debug then VRCore.ShowSuccess(resourceName, pd.name .. ' saved') end
end

function VRCore.Player.SaveOffline(pd)
    if not pd then return end
    writePlayer(pd, pd.position)
    if legacyInventory and ResourceUp(Resources.inventory) then exports[Resources.inventory]:SaveInventory(pd, true) end
    if Config.Debug then VRCore.ShowSuccess(resourceName, tostring(pd.name) .. ' saved (offline)') end
end

local characterTables = {}
for _, entry in ipairs(Config.CharacterTables) do
    if type(entry) == 'table' then
        characterTables[entry[1]] = entry[2] or 'citizenid'
    else
        characterTables[entry] = 'citizenid'
    end
end

function Functions.RegisterCharacterTable(tableName, column)
    column = column or 'citizenid'
    if type(tableName) ~= 'string' or not tableName:match('^[%w_]+$') then return false end
    if type(column) ~= 'string' or not column:match('^[%w_]+$') then return false end
    characterTables[tableName] = column
    return true
end

local function deleteCharacterRows(citizenid, onDone)
    local names = {}
    for name in pairs(characterTables) do names[#names + 1] = name end
    local existing = CoreDB.ExistingTables(names)
    local queries = {}
    for i = 1, #names do
        local name = names[i]
        if existing[name] then
            queries[#queries + 1] = { query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(name, characterTables[name]), values = { citizenid } }
        end
    end
    MySQL.transaction(queries, onDone)
end

function VRCore.Player.DeleteCharacter(source, citizenid)
    local license = Functions.GetIdentifier(source, 'license')
    local owner = MySQL.scalar.await('SELECT license FROM vr_players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not owner or owner ~= license then
        DropPlayer(source, Lang:t('info.exploit_dropped'))
        CoreLog('anticheat', 'Anti-Cheat', 'white', true, '%s Has Been Dropped For Character Deletion Exploit', GetPlayerName(source))
        return
    end
    deleteCharacterRows(citizenid, function(ok)
        if ok then
            CoreEmit('Server:OnCharacterDeleted', citizenid)
            CoreLog('joinleave', 'Character Deleted', 'red', false, '**%s** %s deleted **%s**..', GetPlayerName(source), license, citizenid)
        end
    end)
end

function VRCore.Player.ForceDeleteCharacter(citizenid)
    local exists = MySQL.scalar.await('SELECT 1 FROM vr_players WHERE citizenid = ? LIMIT 1', { citizenid })
    if not exists then return end
    local online = ByCid[citizenid]
    if online then
        local src = online.PlayerData.source
        forget(src)
        DropPlayer(src, 'An admin deleted the character which you are currently using')
    end
    deleteCharacterRows(citizenid, function(ok)
        if ok then
            CoreEmit('Server:OnCharacterDeleted', citizenid)
            CoreLog('joinleave', 'Character Force Deleted', 'red', false, 'Character **%s** got deleted', citizenid)
        end
    end)
end

local function createUniqueId(generator, query)
    for _ = 1, 100 do
        local value = generator()
        if tonumber(MySQL.scalar.await(query, { value })) == 0 then return value end
    end
    VRCore.ShowError(resourceName, 'createUniqueId: gave up after 100 collisions')
end

local RandomStr, RandomInt = Shared.RandomStr, Shared.RandomInt

function VRCore.Player.CreateCitizenId()
    return createUniqueId(
        function() return (RandomStr(3) .. RandomInt(5)):upper() end,
        'SELECT EXISTS(SELECT 1 FROM vr_players WHERE citizenid = ?)')
end

function Functions.CreateAccountNumber()
    return createUniqueId(
        function() return ('US0%dVRCore%d%d%d'):format(math.random(1, 9), math.random(1111, 9999), math.random(1111, 9999), math.random(11, 99)) end,
        'SELECT EXISTS(SELECT 1 FROM vr_players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.account")) = ?)')
end

function Functions.CreatePhoneNumber()
    return createUniqueId(
        function() return math.random(100, 999) .. math.random(1000000, 9999999) end,
        'SELECT EXISTS(SELECT 1 FROM vr_players WHERE JSON_UNQUOTE(JSON_EXTRACT(charinfo, "$.phone")) = ?)')
end

function VRCore.Player.CreateFingerId()
    return createUniqueId(
        function() return RandomStr(2) .. RandomInt(3) .. RandomStr(1) .. RandomInt(2) .. RandomStr(3) .. RandomInt(4) end,
        'SELECT EXISTS(SELECT 1 FROM vr_players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.fingerprint")) = ?)')
end

function VRCore.Player.CreateWalletId()
    return createUniqueId(
        function() return 'VR-' .. math.random(11111111, 99999999) end,
        'SELECT EXISTS(SELECT 1 FROM vr_players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.walletid")) = ?)')
end

function VRCore.Player.CreateSerialNumber()
    return createUniqueId(
        function() return math.random(11111111, 99999999) end,
        'SELECT EXISTS(SELECT 1 FROM vr_players WHERE JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.phonedata.SerialNumber")) = ?)')
end

local function buildInterface(player)
    if not player then return nil end
    local iface, methods = {}, {}
    for name, handler in pairs(player.Functions) do
        if isCallable(handler) then
            iface[name] = handler
            methods[name] = handler
        end
    end
    for name, data in pairs(player) do
        if name ~= 'PlayerData' and name ~= 'Functions' and name ~= 'Offline' and not isCallable(data) then
            iface[name] = data
        end
    end
    iface.PlayerData = player.PlayerData
    iface.Functions = methods
    return iface
end

CoreExport('GetPlayer', function(source) return buildInterface(Players[tonumber(source)]) end)
CoreExport('GetPlayerByCitizenId', function(citizenid) return buildInterface(ByCid[citizenid]) end)
CoreExport('GetOfflinePlayerByCitizenId', function(citizenid) return buildInterface(VRCore.Player.GetOfflinePlayer(citizenid)) end)
CoreExport('GetPlayerByLicense', function(license) return buildInterface(VRCore.Player.GetPlayerByLicense(license)) end)
CoreExport('GetOfflinePlayerByLicense', function(license) return buildInterface(VRCore.Player.GetOfflinePlayerByLicense(license)) end)
CoreExport('AddPlayerMethod', Functions.AddPlayerMethod)
CoreExport('AddPlayerField', Functions.AddPlayerField)
