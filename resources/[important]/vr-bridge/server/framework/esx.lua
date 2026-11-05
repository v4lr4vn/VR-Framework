local U = Bridge.util
local db = Bridge.db
local cfg = BridgeConfig.esx or {}
local F = { name = 'esx' }
local ESX

local function esx()
    if ESX then return ESX end
    U.waitFor('es_extended', 30000)
    ESX = exports['es_extended']:getSharedObject()
    return ESX
end
F.core = esx

local function xp(src) return src and esx().GetPlayerFromId(tonumber(src)) or nil end
local function xpByCid(cid) return type(cid) == 'string' and esx().GetPlayerFromIdentifier(cid) or nil end
F.raw, F.rawByCid = xp, xpByCid

local hasMetaColumn
local function metaColumn()
    if hasMetaColumn == nil then hasMetaColumn = db.columnExists('users', 'metadata') end
    return hasMetaColumn
end

local hasPhoneColumn
local function phoneColumn()
    if hasPhoneColumn == nil then hasPhoneColumn = db.columnExists('users', 'phone_number') end
    return hasPhoneColumn
end

local jobsCache, jobsAt
function F.jobs()
    local now = GetGameTimer()
    if jobsCache and now - jobsAt < 5000 then return jobsCache end
    local raw = esx().GetJobs and esx().GetJobs() or esx().Jobs or {}
    local out = {}
    for name, info in pairs(raw) do
        local grades = {}
        for key, g in pairs(type(info.grades) == 'table' and info.grades or {}) do
            local level = tonumber(g.grade) or tonumber(key)
            if level then
                grades[level] = { name = g.label or g.name or tostring(level), isboss = (cfg.bossGrades or {})[g.name] == true, payment = tonumber(g.salary) or 0, key = g.name }
            end
        end
        out[name] = { name = name, label = info.label or name, type = U.jobType(name, info.type), grades = grades }
    end
    jobsCache, jobsAt = out, now
    return out
end

local function normJob(job)
    job = type(job) == 'table' and job or {}
    local name = job.name or 'unemployed'
    local level = tonumber(job.grade) or 0
    local info = F.jobs()[name]
    local g = info and info.grades[level]
    local onduty = job.onDuty
    if onduty == nil then onduty = job.onduty end
    return {
        name = name,
        label = job.label or (info and info.label) or name,
        type = U.jobType(name, info and info.type),
        grade = level,
        gradeName = job.grade_label or (g and g.name) or job.grade_name or tostring(level),
        isboss = (cfg.bossGrades or {})[job.grade_name] == true or (g and g.isboss) == true,
        onduty = onduty ~= false,
    }
end
F.normJob = normJob

local store = Bridge.metaStore

local function metaOf(x)
    if type(x.getMeta) == 'function' then
        local ok, md = pcall(x.getMeta)
        if ok and type(md) == 'table' then return md end
    end
    return store.all(x.identifier)
end

local function fromX(x)
    if not x then return nil end
    local get = type(x.get) == 'function' and x.get or function() return nil end
    local first, last = get('firstName') or get('firstname'), get('lastName') or get('lastname')
    if not first and type(x.getName) == 'function' then
        first, last = tostring(x.getName()):match('^(%S+)%s*(.*)$')
    end
    local bank = 0
    if type(x.getAccount) == 'function' then
        local acc = x.getAccount('bank')
        bank = acc and tonumber(acc.money) or 0
    end
    return {
        source = tonumber(x.source),
        cid = x.identifier,
        firstname = first,
        lastname = last,
        name = U.fullName(first, last),
        dob = U.dob(get('dateofbirth')),
        gender = U.gender(get('sex')),
        phone = get('phoneNumber') or get('phone_number'),
        nationality = nil,
        job = normJob(x.job),
        money = { cash = type(x.getMoney) == 'function' and tonumber(x.getMoney()) or 0, bank = bank },
        metadata = metaOf(x),
        online = true,
    }
end

local function fromRow(r)
    local accounts = U.decode(r.accounts, {})
    local metadata = r.metadata and U.decode(r.metadata, {}) or store.all(r.identifier)
    return {
        cid = r.identifier,
        firstname = r.firstname,
        lastname = r.lastname,
        name = U.fullName(r.firstname, r.lastname),
        dob = U.dob(r.dateofbirth),
        gender = U.gender(r.sex),
        phone = r.phone_number,
        job = normJob({ name = r.job, grade = r.job_grade }),
        money = { cash = tonumber(accounts.money) or 0, bank = tonumber(accounts.bank) or 0 },
        metadata = metadata,
        online = false,
    }
end

function F.player(src) return fromX(xp(src)) end
function F.playerByCid(cid) return fromX(xpByCid(cid)) end

function F.sources()
    local out = {}
    if esx().GetExtendedPlayers then
        for _, x in pairs(esx().GetExtendedPlayers()) do out[#out + 1] = tonumber(x.source) end
    else
        for _, s in ipairs(esx().GetPlayers()) do out[#out + 1] = tonumber(s) end
    end
    return out
end

function F.setMeta(src, key, value)
    local x = xp(src)
    if not x then return false end
    if type(x.setMeta) == 'function' then
        if value == nil and type(x.clearMeta) == 'function' then x.clearMeta(key) else x.setMeta(key, value) end
    else
        store.set(x.identifier, key, value)
    end
    return true
end

function F.setJob(src, job, grade)
    local x = xp(src)
    if not x then return false end
    local onduty = x.job and x.job.onDuty
    x.setJob(job, grade, onduty)
    return true
end

function F.setDuty(src, onduty)
    local x = xp(src)
    if not x or not x.job then return false end
    if x.job.onDuty == nil then return false end
    x.setJob(x.job.name, x.job.grade, onduty == true)
    return true
end

local function accountName(account) return account == 'cash' and 'money' or account end

function F.addMoney(src, account, amount, reason)
    local x = xp(src)
    if not x then return false end
    x.addAccountMoney(accountName(account), amount, reason)
    return true
end

function F.removeMoney(src, account, amount, reason)
    local x = xp(src)
    if not x then return false end
    local acc = x.getAccount(accountName(account))
    if not acc or (tonumber(acc.money) or 0) < amount then return false end
    x.removeAccountMoney(accountName(account), amount, reason)
    return true
end

function F.save(src)
    local x = xp(src)
    if x and esx().SavePlayer then pcall(esx().SavePlayer, x) end
end

function F.notify(src, msg, kind, ms)
    TriggerClientEvent('esx:showNotification', src, msg, kind == 'primary' and 'info' or kind, ms)
end

function F.isAdmin(src)
    local x = xp(src)
    local group = x and type(x.getGroup) == 'function' and x.getGroup() or nil
    return group == 'admin' or group == 'superadmin' or IsPlayerAceAllowed(src, 'command')
end

function F.money(src, account)
    local x = xp(src)
    if not x then return 0 end
    local acc = x.getAccount(accountName(account))
    return acc and tonumber(acc.money) or 0
end

function F.setMoney(src, account, amount, reason)
    local x = xp(src)
    if not x then return false end
    x.setAccountMoney(accountName(account), amount, reason)
    return true
end

function F.setGang() return false end

function F.getMeta(src, key)
    local x = xp(src)
    if not x then return nil end
    local md = metaOf(x)
    if key == nil then return md end
    return md[key]
end

function F.groups(src)
    local x = xp(src)
    local out = {}
    if x and x.job and x.job.name then out[x.job.name] = tonumber(x.job.grade) or 0 end
    return out
end

function F.license(src)
    return GetPlayerIdentifierByType(tostring(src), 'license')
end

function F.gangs() return {} end

function F.useItem(name, fn)
    esx().RegisterUsableItem(name, function(source, item, data)
        fn(source, type(data) == 'table' and data or { name = item })
    end)
    return true
end

function F.usable(name)
    local list = esx().GetUsableItems and esx().GetUsableItems() or nil
    if type(list) == 'table' and list[name] then
        return function(source, item) esx().UseItem(source, name, item) end
    end
    return nil
end

function F.itemDefs()
    return esx().Items or (esx().GetItems and esx().GetItems()) or {}
end

local vehicleCache
function F.vehicleList()
    if vehicleCache then return vehicleCache end
    vehicleCache = {}
    if db.tableExists('vehicles') then
        for _, r in ipairs(db.query('SELECT * FROM `vehicles`') or {}) do
            if type(r.model) == 'string' then
                vehicleCache[r.model] = { model = r.model, name = r.name or r.model, brand = '', price = tonumber(r.price) or 0, category = r.category, hash = GetHashKey(r.model) }
            end
        end
    end
    return vehicleCache
end

F.societyApi = {
    balance = function(name)
        local acc
        TriggerEvent('esx_addonaccount:getSharedAccount', (cfg.society or 'society_%s'):format(name), function(a) acc = a end)
        return acc and tonumber(acc.money) or nil
    end,
    add = function(name, amount)
        local done = false
        TriggerEvent('esx_addonaccount:getSharedAccount', (cfg.society or 'society_%s'):format(name), function(acc)
            if acc then
                acc.addMoney(amount)
                done = true
            end
        end)
        return done
    end,
    remove = function(name, amount)
        local done = false
        TriggerEvent('esx_addonaccount:getSharedAccount', (cfg.society or 'society_%s'):format(name), function(acc)
            if acc and (tonumber(acc.money) or 0) >= amount then
                acc.removeMoney(amount)
                done = true
            end
        end)
        return done
    end,
    ready = function()
        if U.started('esx_addonaccount') then return true end
        local seen = false
        TriggerEvent('esx_addonaccount:getSharedAccount', (cfg.society or 'society_%s'):format('police'), function() seen = true end)
        return seen
    end,
}

function F.status(src)
    local st = Player(src).state
    return { dead = st.dead == true or st.isDead == true, cuffed = st.isHandcuffed == true or st.handcuffed == true }
end

function F.listen(emit)
    local duty = {}
    AddEventHandler('esx:playerLoaded', function(src, x)
        src = tonumber(src)
        duty[src] = x and x.job and x.job.onDuty
        emit('playerLoaded', src)
    end)
    AddEventHandler('esx:playerDropped', function(src) duty[tonumber(src)] = nil emit('playerUnloaded', tonumber(src)) end)
    AddEventHandler('esx:playerLogout', function(src) duty[tonumber(src)] = nil emit('playerUnloaded', tonumber(src)) end)
    for _, op in ipairs({ 'add', 'remove', 'set' }) do
        AddEventHandler(('esx:%sAccountMoney'):format(op), function(src, account, amount, reason)
            emit('moneyChanged', tonumber(src), account == 'money' and 'cash' or account, tonumber(amount) or 0, op, reason)
        end)
    end
    AddEventHandler('esx:setJob', function(src, job, last)
        src = tonumber(src)
        local n = normJob(job)
        if not last or last.name ~= job.name or tonumber(last.grade) ~= tonumber(job.grade) then emit('jobChanged', src, n) end
        if duty[src] ~= job.onDuty then
            duty[src] = job.onDuty
            emit('dutyChanged', src, n.onduty)
        end
    end)
end

local chars = {}
F.chars = chars

local function cols()
    local c = '`identifier`, `firstname`, `lastname`, `dateofbirth`, `sex`, `job`, `job_grade`, `accounts`'
    if metaColumn() then c = c .. ', `metadata`' end
    if phoneColumn() then c = c .. ', `phone_number`' end
    return c
end

function chars.search(q, limit)
    limit = math.max(1, math.min(tonumber(limit) or 20, 100))
    local first, last = q:match('^(%S+)%s+(.+)$')
    local rows
    if first then
        rows = db.query(('SELECT %s FROM `users` WHERE (LOWER(`firstname`) LIKE LOWER(?) AND LOWER(`lastname`) LIKE LOWER(?)) OR `identifier` = ? LIMIT ?'):format(cols()), { U.like(first), U.like(last), q, limit })
    else
        local like = U.like(q)
        local phone = phoneColumn() and ' OR `phone_number` LIKE ?' or ''
        local params = { like, like, q }
        if phone ~= '' then params[#params + 1] = like end
        params[#params + 1] = limit
        rows = db.query(('SELECT %s FROM `users` WHERE LOWER(`firstname`) LIKE LOWER(?) OR LOWER(`lastname`) LIKE LOWER(?) OR `identifier` = ?%s LIMIT ?'):format(cols(), phone), params)
    end
    local out = {}
    for _, r in ipairs(rows or {}) do out[#out + 1] = fromRow(r) end
    return out
end

function chars.get(cid)
    local live = F.playerByCid(cid)
    if live then return live end
    local row = db.single(('SELECT %s FROM `users` WHERE `identifier` = ? LIMIT 1'):format(cols()), { cid })
    return row and fromRow(row) or nil
end

function chars.exists(cid)
    if xpByCid(cid) then return true end
    return db.scalar('SELECT 1 FROM `users` WHERE `identifier` = ? LIMIT 1', { cid }) ~= nil
end

function chars.many(cids)
    local out, missing = {}, {}
    for _, cid in ipairs(cids) do
        local live = F.playerByCid(cid)
        if live then out[cid] = live else missing[#missing + 1] = cid end
    end
    if #missing > 0 then
        local rows = db.query(('SELECT %s FROM `users` WHERE `identifier` IN (%s)'):format(cols(), U.placeholders(#missing)), missing) or {}
        for _, r in ipairs(rows) do out[r.identifier] = fromRow(r) end
    end
    return out
end

function chars.byJobs(names, q, limit)
    if #names == 0 then return {} end
    local params = {}
    for i, n in ipairs(names) do params[i] = n end
    local where = ('`job` IN (%s)'):format(U.placeholders(#names))
    if type(q) == 'string' and q ~= '' then
        local like = U.like(q)
        where = where .. ' AND (LOWER(`firstname`) LIKE LOWER(?) OR LOWER(`lastname`) LIKE LOWER(?))'
        params[#params + 1] = like
        params[#params + 1] = like
    end
    params[#params + 1] = math.max(1, math.min(tonumber(limit) or 500, 2000))
    local rows = db.query(('SELECT %s FROM `users` WHERE %s LIMIT ?'):format(cols(), where), params) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = F.playerByCid(r.identifier) or fromRow(r) end
    return out
end

function chars.findByMeta(key, value, jobNames)
    if metaColumn() then
        local params = { value }
        local where = ('LOWER(JSON_UNQUOTE(JSON_EXTRACT(`metadata`, \'$.%s\'))) = LOWER(?)'):format(key:gsub('[^%w_]', ''))
        if jobNames and #jobNames > 0 then
            where = where .. (' AND `job` IN (%s)'):format(U.placeholders(#jobNames))
            for _, n in ipairs(jobNames) do params[#params + 1] = n end
        end
        local rows = db.query(('SELECT `identifier` FROM `users` WHERE %s LIMIT 20'):format(where), params) or {}
        local out = {}
        for _, r in ipairs(rows) do out[#out + 1] = r.identifier end
        return out
    end
    return store.find(key, value)
end

function chars.setJob(cid, job, grade, onduty)
    local x = xpByCid(cid)
    if x then
        x.setJob(job, grade, onduty)
        return true
    end
    return db.update('UPDATE `users` SET `job` = ?, `job_grade` = ? WHERE `identifier` = ?', { job, grade, cid }) ~= nil
end

function chars.setMeta(cid, key, value)
    local x = xpByCid(cid)
    if x then return F.setMeta(x.source, key, value) end
    if not metaColumn() then return store.set(cid, key, value) end
    local path = '$.' .. key:gsub('[^%w_]', '')
    if value == nil then
        return db.update('UPDATE `users` SET `metadata` = JSON_REMOVE(COALESCE(NULLIF(`metadata`, \'\'), \'{}\'), ?) WHERE `identifier` = ?', { path, cid }) ~= nil
    end
    return db.update('UPDATE `users` SET `metadata` = JSON_SET(COALESCE(NULLIF(`metadata`, \'\'), \'{}\'), ?, JSON_EXTRACT(?, \'$\')) WHERE `identifier` = ?', { path, json.encode(value), cid }) ~= nil
end

function chars.removeBank(cid, amount, partial, reason)
    local x = xpByCid(cid)
    if x then
        local acc = x.getAccount('bank')
        local bank = acc and U.int(acc.money, 0) or 0
        local take = math.min(bank, amount)
        if take < amount and not partial then take = 0 end
        if take <= 0 then return 0 end
        x.removeAccountMoney('bank', take, reason)
        return take
    end
    local row = db.single('SELECT `accounts` FROM `users` WHERE `identifier` = ? LIMIT 1', { cid })
    local accounts = row and U.decode(row.accounts, nil)
    if type(accounts) ~= 'table' then return 0 end
    local bank = U.int(accounts.bank, 0)
    local take = math.min(bank, amount)
    if take < amount and not partial then take = 0 end
    if take <= 0 then return 0 end
    accounts.bank = bank - take
    local n = db.update('UPDATE `users` SET `accounts` = ? WHERE `identifier` = ? AND `accounts` = ?', { json.encode(accounts), cid, row.accounts })
    if not n or n < 1 then return 0 end
    return take
end

function chars.bank(cid)
    local x = xpByCid(cid)
    if x then
        local acc = x.getAccount('bank')
        return acc and U.int(acc.money, 0) or 0
    end
    local row = db.single('SELECT `accounts` FROM `users` WHERE `identifier` = ? LIMIT 1', { cid })
    local accounts = row and U.decode(row.accounts, nil)
    return type(accounts) == 'table' and U.int(accounts.bank, 0) or 0
end

function chars.addBank(cid, amount, reason)
    amount = U.int(amount, 0)
    if amount <= 0 then return false end
    local x = xpByCid(cid)
    if x then
        x.addAccountMoney('bank', amount, reason)
        return true
    end
    for _ = 1, 3 do
        local row = db.single('SELECT `accounts` FROM `users` WHERE `identifier` = ? LIMIT 1', { cid })
        local accounts = row and U.decode(row.accounts, nil)
        if type(accounts) ~= 'table' then return false end
        accounts.bank = U.int(accounts.bank, 0) + amount
        local n = db.update('UPDATE `users` SET `accounts` = ? WHERE `identifier` = ? AND `accounts` = ?', { json.encode(accounts), cid, row.accounts })
        if n and n > 0 then return true end
    end
    return false
end

function chars.license(cid)
    local x = xpByCid(cid)
    if x then return GetPlayerIdentifierByType(tostring(x.source), 'license') end
    local own = type(cid) == 'string' and cid:match(':(%x+)$')
    return own and ('license:' .. own) or nil
end

local licences = {}
F.licences = licences

local function licenceMap() return cfg.licences or {} end

function licences.get(cid)
    local out = {}
    local rows = db.query('SELECT `type` FROM `user_licenses` WHERE `owner` = ?', { cid }) or {}
    for _, r in ipairs(rows) do
        local name = licenceMap()[r.type] or r.type
        out[name] = true
    end
    return out
end

function licences.set(cid, name, value)
    local types = {}
    for esxType, mapped in pairs(licenceMap()) do
        if mapped == name then types[#types + 1] = esxType end
    end
    if #types == 0 then types = { name } end
    table.sort(types)
    if value then
        local have = db.scalar(('SELECT COUNT(*) FROM `user_licenses` WHERE `owner` = ? AND `type` IN (%s)'):format(U.placeholders(#types)), { cid, table.unpack(types) })
        if tonumber(have) and tonumber(have) > 0 then return true end
        return db.insert('INSERT INTO `user_licenses` (`type`, `owner`) VALUES (?, ?)', { types[1], cid }) ~= nil
    end
    return db.update(('DELETE FROM `user_licenses` WHERE `owner` = ? AND `type` IN (%s)'):format(U.placeholders(#types)), { cid, table.unpack(types) }) ~= nil
end

local vehicles = {}
F.vehicles = vehicles
local modelNames

local function models()
    if modelNames then return modelNames end
    modelNames = {}
    if db.tableExists('vehicles') then
        for _, r in ipairs(db.query('SELECT `model`, `name` FROM `vehicles`') or {}) do
            if type(r.model) == 'string' then
                modelNames[GetHashKey(r.model)] = { model = r.model, name = r.name }
            end
        end
    end
    return modelNames
end

local function vrow(r)
    local props = U.decode(r.vehicle, {})
    local hash = tonumber(props.model)
    local known = hash and models()[hash]
    local stored = tonumber(r.stored)
    return {
        plate = r.plate,
        model = known and known.model or (hash and tostring(hash)) or nil,
        ownerCid = r.owner,
        garage = r.parking,
        state = r.pound and r.pound ~= '' and 2 or (stored == 1 and 1 or 0),
    }
end

local vcolsChecked
local function vcols()
    if vcolsChecked then return vcolsChecked end
    vcolsChecked = '`plate`, `vehicle`, `owner`, `stored`'
    if db.columnExists('owned_vehicles', 'parking') then vcolsChecked = vcolsChecked .. ', `parking`' end
    if db.columnExists('owned_vehicles', 'pound') then vcolsChecked = vcolsChecked .. ', `pound`' end
    return vcolsChecked
end

function vehicles.label(model)
    for _, v in pairs(models()) do
        if v.model == model then return v.name end
    end
    return nil
end

function vehicles.modelsMatching(q, limit)
    local out, needle = {}, tostring(q):lower()
    for hash, v in pairs(models()) do
        if (v.model .. ' ' .. (v.name or '')):lower():find(needle, 1, true) then
            out[#out + 1] = hash
            if #out >= (limit or 50) then break end
        end
    end
    return out
end

function vehicles.search(q, limit)
    limit = math.max(1, math.min(tonumber(limit) or 30, 100))
    local params = { U.like(q) }
    local where = '`plate` LIKE ?'
    local hashes = vehicles.modelsMatching(q, 50)
    if #hashes > 0 then
        where = where .. (" OR JSON_EXTRACT(`vehicle`, '$.model') IN (%s)"):format(U.placeholders(#hashes))
        for _, h in ipairs(hashes) do params[#params + 1] = h end
    end
    params[#params + 1] = limit
    local rows = db.query(('SELECT %s FROM `owned_vehicles` WHERE %s ORDER BY `plate` LIMIT ?'):format(vcols(), where), params) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = vrow(r) end
    return out
end

function vehicles.byPlates(plates)
    if #plates == 0 then return {} end
    local rows = db.query(('SELECT %s FROM `owned_vehicles` WHERE `plate` IN (%s)'):format(vcols(), U.placeholders(#plates)), plates) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = vrow(r) end
    return out
end

function vehicles.byPlate(plate)
    local r = db.single(('SELECT %s FROM `owned_vehicles` WHERE `plate` = ? LIMIT 1'):format(vcols()), { plate })
    return r and vrow(r) or nil
end

function vehicles.ofOwner(cid, limit)
    local rows = db.query(('SELECT %s FROM `owned_vehicles` WHERE `owner` = ? LIMIT ?'):format(vcols()), { cid, math.max(1, math.min(tonumber(limit) or 50, 200)) }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = vrow(r) end
    return out
end

function vehicles.platesLike(q, limit)
    local rows = db.query('SELECT `plate` FROM `owned_vehicles` WHERE `plate` LIKE ? ORDER BY `plate` LIMIT ?', { U.like(q), limit or 10 }) or {}
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = r.plate end
    return out
end

return F
