local U = Bridge.util
local db = Bridge.db
local store = Bridge.metaStore
local F = { name = 'ox' }
local OxLib

local function Ox()
    if OxLib then return OxLib end
    U.waitFor('ox_core', 30000)
    if type(_G.Ox) == 'table' then OxLib = _G.Ox return OxLib end
    local code = LoadResourceFile('ox_core', 'lib/init.lua')
    if code then
        local fn = load(code, '@@ox_core/lib/init.lua')
        local ok, res = pcall(fn)
        if ok and type(res) == 'table' then OxLib = res end
    end
    OxLib = OxLib or _G.Ox
    if not OxLib then error('[vr-bridge] could not load @ox_core/lib/init.lua') end
    return OxLib
end
F.core = Ox

local function field(p, key)
    if type(p) ~= 'table' then return nil end
    if p[key] ~= nil then return p[key] end
    if type(p.get) == 'function' then
        local ok, v = pcall(p.get, key)
        if ok then return v end
    end
    return nil
end

local groupsCache, groupsAt
function F.jobs()
    local now = GetGameTimer()
    if groupsCache and now - groupsAt < 5000 then return groupsCache end
    local out = {}
    local groups = db.query('SELECT `name`, `label`, `type` FROM `ox_groups`') or {}
    local grades = db.query('SELECT `group`, `grade`, `label`, `accountRole` FROM `ox_group_grades`') or {}
    for _, g in ipairs(groups) do
        out[g.name] = { name = g.name, label = g.label or g.name, type = U.jobType(g.name, g.type ~= 'job' and g.type or nil), kind = g.type, grades = {} }
    end
    local top = {}
    for _, gr in ipairs(grades) do
        local info = out[gr.group]
        local level = tonumber(gr.grade)
        level = level and level - 1
        if info and level then
            info.grades[level] = { name = gr.label or tostring(level), isboss = gr.accountRole == 'owner' or gr.accountRole == 'manager', payment = 0 }
            if not top[gr.group] or level > top[gr.group] then top[gr.group] = level end
        end
    end
    for name, level in pairs(top) do
        local g = out[name].grades[level]
        if g then g.isboss = true end
    end
    groupsCache, groupsAt = out, now
    return out
end

local function pickGroup(groups, active)
    local jobs = F.jobs()
    local best
    for name, grade in pairs(groups or {}) do
        local info = jobs[name]
        local job
        if info then job = info.kind ~= 'gang' else job = U.jobType(name) ~= 'none' end
        if job and (not best or name == active) then best = { name = name, grade = math.max(0, (tonumber(grade) or 1) - 1) } end
    end
    if not best and active and groups and groups[active] then best = { name = active, grade = math.max(0, (tonumber(groups[active]) or 1) - 1) } end
    return best
end

local function normJob(group, active)
    if not group then
        return { name = 'unemployed', label = 'Unemployed', type = 'none', grade = 0, gradeName = 'Unemployed', isboss = false, onduty = false }
    end
    local info = F.jobs()[group.name]
    local g = info and info.grades[group.grade]
    return {
        name = group.name,
        label = info and info.label or group.name,
        type = info and info.type or U.jobType(group.name),
        grade = group.grade,
        gradeName = g and g.name or tostring(group.grade),
        isboss = g and g.isboss == true or false,
        onduty = active == nil or active == group.name,
    }
end
F.normJob = normJob

local function fromPlayer(p)
    if not p then return nil end
    local groups = type(p.getGroups) == 'function' and p.getGroups() or {}
    local active = field(p, 'activeGroup')
    local account = type(p.getAccount) == 'function' and p.getAccount() or nil
    local bank = account and tonumber(field(account, 'balance')) or 0
    local cash = 0
    local inv = Bridge.inventoryName == 'ox' and Bridge.inventoryResource or 'ox_inventory'
    if U.started(inv) then
        local ok, n = pcall(function() return exports[inv]:Search(p.source, 'count', 'money') end)
        cash = ok and tonumber(n) or 0
    end
    local first, last = field(p, 'firstName'), field(p, 'lastName')
    return {
        source = tonumber(p.source),
        cid = p.stateId,
        firstname = first,
        lastname = last,
        name = U.fullName(first, last),
        dob = U.dob(field(p, 'dateOfBirth')),
        gender = U.gender(field(p, 'gender')),
        phone = field(p, 'phoneNumber'),
        job = normJob(pickGroup(groups, active), active),
        money = { cash = cash, bank = bank },
        metadata = store.all(p.stateId),
        online = true,
        charId = p.charId,
    }
end

function F.raw(src) return src and Ox().GetPlayer(tonumber(src)) or nil end

local function oxFilter(filter)
    if type(filter) ~= 'table' or filter[1] ~= nil then return filter end
    local out = {}
    for name, grade in pairs(filter) do
        if type(grade) == 'table' then
            local list = {}
            for i, g in ipairs(grade) do list[i] = (tonumber(g) or 0) + 1 end
            out[name] = list
        else
            out[name] = (tonumber(grade) or 0) + 1
        end
    end
    return out
end

function F.hasGroup(src, filter)
    local p = F.raw(src)
    if not p or not p.getGroup then return false end
    local name, grade = p.getGroup(oxFilter(filter))
    if name then return name, math.max(0, (tonumber(grade) or 1) - 1) end
    return false
end
function F.rawByCid(cid)
    if type(cid) ~= 'string' then return nil end
    for _, p in pairs(Ox().GetPlayers() or {}) do
        if p.stateId == cid then return p end
    end
    return nil
end

function F.player(src) return fromPlayer(F.raw(src)) end
function F.playerByCid(cid) return fromPlayer(F.rawByCid(cid)) end

function F.sources()
    local out = {}
    for _, p in pairs(Ox().GetPlayers() or {}) do out[#out + 1] = tonumber(p.source) end
    return out
end

function F.setMeta(src, key, value)
    local p = F.raw(src)
    if not p then return false end
    store.set(p.stateId, key, value)
    if type(p.set) == 'function' then pcall(p.set, key, value, true) end
    return true
end

local function currentJobGroup(p)
    local groups = type(p.getGroups) == 'function' and p.getGroups() or {}
    return pickGroup(groups, field(p, 'activeGroup'))
end

function F.setJob(src, job, grade)
    local p = F.raw(src)
    if not p then return false end
    local current = currentJobGroup(p)
    if current and current.name ~= job then p.setGroup(current.name, 0) end
    if job == 'unemployed' then return true end
    return p.setGroup(job, (tonumber(grade) or 0) + 1) ~= false
end

function F.setDuty(src, onduty)
    local p = F.raw(src)
    if not p or type(p.setActiveGroup) ~= 'function' then return false end
    local current = currentJobGroup(p)
    if onduty and current then return p.setActiveGroup(current.name) ~= false end
    return p.setActiveGroup() ~= false
end

function F.addMoney(src, account, amount, reason)
    if account == 'cash' then
        local inv = Bridge.inventoryName == 'ox' and Bridge.inventoryResource or 'ox_inventory'
        return U.started(inv) and exports[inv]:AddItem(src, 'money', amount) ~= false
    end
    local p = F.raw(src)
    local acc = p and p.getAccount()
    if not acc then return false end
    local res = acc.addBalance({ amount = amount, message = reason })
    return type(res) ~= 'table' or res.success ~= false
end

function F.removeMoney(src, account, amount, reason)
    if account == 'cash' then
        local inv = Bridge.inventoryName == 'ox' and Bridge.inventoryResource or 'ox_inventory'
        return U.started(inv) and exports[inv]:RemoveItem(src, 'money', amount) ~= false
    end
    local p = F.raw(src)
    local acc = p and p.getAccount()
    if not acc then return false end
    local res = acc.removeBalance({ amount = amount, message = reason, overdraw = false })
    return type(res) ~= 'table' or res.success ~= false
end

function F.save(src)
    local p = F.raw(src)
    if p and type(p.save) == 'function' then pcall(p.save) end
end

function F.notify(src, msg, kind, ms)
    TriggerClientEvent('ox_lib:notify', src, { description = msg, type = kind == 'primary' and 'inform' or kind, duration = ms })
end

function F.isAdmin(src)
    return IsPlayerAceAllowed(src, 'group.admin') or IsPlayerAceAllowed(src, 'command')
end

local function invRes()
    return Bridge.inventoryName == 'ox' and Bridge.inventoryResource or 'ox_inventory'
end

function F.money(src, account)
    if account == 'cash' or account == 'money' then
        local inv = invRes()
        if not U.started(inv) then return 0 end
        local ok, n = pcall(function() return exports[inv]:Search(src, 'count', 'money') end)
        return ok and tonumber(n) or 0
    end
    local p = F.raw(src)
    local acc = p and type(p.getAccount) == 'function' and p.getAccount() or nil
    return acc and tonumber(field(acc, 'balance')) or 0
end

function F.setMoney(src, account, amount, reason)
    local have = F.money(src, account)
    if amount > have then return F.addMoney(src, account, amount - have, reason) end
    if amount < have then return F.removeMoney(src, account, have - amount, reason) end
    return true
end

function F.getMeta(src, key)
    local p = F.raw(src)
    if not p then return nil end
    if key == nil then return store.all(p.stateId) end
    local v = store.get(p.stateId, key)
    if v == nil then v = field(p, key) end
    return v
end

function F.groups(src)
    local p = F.raw(src)
    local out = {}
    if not p or type(p.getGroups) ~= 'function' then return out end
    for name, grade in pairs(p.getGroups() or {}) do out[name] = math.max(0, (tonumber(grade) or 1) - 1) end
    return out
end

function F.license(src)
    return GetPlayerIdentifierByType(tostring(src), 'license')
end

function F.gangs()
    local out = {}
    for name, info in pairs(F.jobs()) do
        if info.type == 'gang' then out[name] = { name = name, label = info.label, grades = info.grades } end
    end
    return out
end

function F.setGang(src, gang, grade)
    local p = F.raw(src)
    if not p then return false end
    for name in pairs(F.gangs()) do
        if name ~= gang and p.getGroup(name) then p.setGroup(name, 0) end
    end
    if not gang or gang == 'none' then return true end
    return p.setGroup(gang, (tonumber(grade) or 0) + 1) ~= false
end

function F.useItem(name, fn)
    AddEventHandler('__vrb_use:' .. name, function(src, item) fn(src, item) end)
    exports('use_' .. name, function(event, item, inventory, slot)
        if event ~= 'usedItem' then return end
        local id = type(inventory) == 'table' and inventory.id or inventory
        fn(tonumber(id), { name = item and item.name or name, slot = slot, metadata = type(inventory) == 'table' and inventory.items and inventory.items[slot] and inventory.items[slot].metadata or nil })
    end)
    if U.started('vr-bridge') then pcall(function() exports['vr-bridge']:registerUsable(name) end) end
    return true
end

function F.usable(name)
    local ok, known = pcall(function() return exports['vr-bridge']:isUsable(name) end)
    if ok and known then
        return function(source, item) TriggerEvent('__vrb_use:' .. name, source, item) end
    end
    return nil
end

function F.itemDefs()
    local inv = invRes()
    if not U.started(inv) then return {} end
    local ok, list = pcall(function() return exports[inv]:Items() end)
    return ok and list or {}
end

local vehicleCache
function F.vehicleList()
    if vehicleCache then return vehicleCache end
    local ok, all = pcall(function() return Ox().GetVehicleData() end)
    vehicleCache = {}
    for model, v in pairs(ok and type(all) == 'table' and all or {}) do
        vehicleCache[model] = { model = model, name = v.name or model, brand = v.make or '', price = tonumber(v.price) or 0, category = v.class, type = v.type, hash = GetHashKey(model) }
    end
    return vehicleCache
end

F.societyApi = {
    balance = function(name)
        local ok, acc = pcall(Ox().GetGroupAccount, name)
        if not ok or not acc then return nil end
        return tonumber(field(acc, 'balance')) or 0
    end,
    add = function(name, amount, reason)
        local ok, acc = pcall(Ox().GetGroupAccount, name)
        if not ok or not acc then return false end
        local res = acc.addBalance({ amount = amount, message = reason })
        return type(res) ~= 'table' or res.success ~= false
    end,
    remove = function(name, amount, reason)
        local ok, acc = pcall(Ox().GetGroupAccount, name)
        if not ok or not acc then return false end
        local res = acc.removeBalance({ amount = amount, message = reason, overdraw = false })
        return type(res) ~= 'table' or res.success ~= false
    end,
}

function F.status(src)
    local st = Player(src).state
    return { dead = st.isDead == true or st.dead == true, cuffed = st.isHandcuffed == true or st.handcuffed == true }
end

function F.listen(emit)
    AddEventHandler('ox:playerLoaded', function(src) emit('playerLoaded', tonumber(src)) end)
    AddEventHandler('ox:playerLogout', function(src) emit('playerUnloaded', tonumber(src)) end)
    AddEventHandler('ox:setGroup', function(src)
        local p = F.player(src)
        if p then emit('jobChanged', tonumber(src), p.job) end
    end)
    AddEventHandler('ox:setGroup', function(src, name)
        if F.gangs()[name] then
            local g = F.groups(src)[name]
            emit('gangChanged', tonumber(src), g and { name = name, label = F.jobs()[name].label, grade = g, isboss = false } or nil)
        end
    end)
    AddEventHandler('ox:setActiveGroup', function(src)
        local p = F.player(src)
        if p then emit('dutyChanged', tonumber(src), p.job.onduty) end
    end)
end

local chars = {}
F.chars = chars

local COLS = 'c.`charId`, c.`stateId`, c.`firstName`, c.`lastName`, c.`gender`, c.`dateOfBirth`, c.`phoneNumber`'

local function groupsOf(charIds)
    local out = {}
    if #charIds == 0 then return out end
    local rows = db.query(('SELECT `charId`, `name`, `grade`, `isActive` FROM `character_groups` WHERE `charId` IN (%s)'):format(U.placeholders(#charIds)), charIds) or {}
    for _, r in ipairs(rows) do
        local e = out[r.charId] or { groups = {}, active = nil }
        e.groups[r.name] = tonumber(r.grade)
        if tonumber(r.isActive) == 1 then e.active = r.name end
        out[r.charId] = e
    end
    return out
end

local function fromRows(rows)
    local ids = {}
    for i, r in ipairs(rows) do ids[i] = r.charId end
    local g = groupsOf(ids)
    local out = {}
    for _, r in ipairs(rows) do
        local e = g[r.charId] or { groups = {} }
        out[#out + 1] = {
            cid = r.stateId,
            firstname = r.firstName,
            lastname = r.lastName,
            name = U.fullName(r.firstName, r.lastName),
            dob = U.dob(r.dateOfBirth),
            gender = U.gender(r.gender),
            phone = r.phoneNumber,
            job = normJob(pickGroup(e.groups, e.active), e.active),
            money = { cash = 0, bank = 0 },
            metadata = store.all(r.stateId),
            online = false,
            charId = r.charId,
        }
    end
    return out
end

function chars.search(q, limit)
    limit = math.max(1, math.min(tonumber(limit) or 20, 100))
    local first, last = q:match('^(%S+)%s+(.+)$')
    local rows
    if first then
        rows = db.query(('SELECT %s FROM `characters` c WHERE (LOWER(c.`firstName`) LIKE LOWER(?) AND LOWER(c.`lastName`) LIKE LOWER(?)) OR c.`stateId` = ? LIMIT ?'):format(COLS), { U.like(first), U.like(last), q:upper(), limit })
    else
        local like = U.like(q)
        rows = db.query(('SELECT %s FROM `characters` c WHERE LOWER(c.`firstName`) LIKE LOWER(?) OR LOWER(c.`lastName`) LIKE LOWER(?) OR c.`stateId` LIKE ? OR c.`phoneNumber` LIKE ? LIMIT ?'):format(COLS), { like, like, like, like, limit })
    end
    return fromRows(rows or {})
end

function chars.get(cid)
    local live = F.playerByCid(cid)
    if live then return live end
    local row = db.single(('SELECT %s FROM `characters` c WHERE c.`stateId` = ? LIMIT 1'):format(COLS), { cid })
    return row and fromRows({ row })[1] or nil
end

function chars.exists(cid)
    if F.rawByCid(cid) then return true end
    return db.scalar('SELECT 1 FROM `characters` WHERE `stateId` = ? LIMIT 1', { cid }) ~= nil
end

function chars.many(cids)
    local out, missing = {}, {}
    for _, cid in ipairs(cids) do
        local live = F.playerByCid(cid)
        if live then out[cid] = live else missing[#missing + 1] = cid end
    end
    if #missing > 0 then
        local rows = db.query(('SELECT %s FROM `characters` c WHERE c.`stateId` IN (%s)'):format(COLS, U.placeholders(#missing)), missing) or {}
        for _, p in ipairs(fromRows(rows)) do out[p.cid] = p end
    end
    return out
end

function chars.byJobs(names, q, limit)
    if #names == 0 then return {} end
    local params = {}
    for i, n in ipairs(names) do params[i] = n end
    local where = ('c.`charId` IN (SELECT `charId` FROM `character_groups` WHERE `name` IN (%s))'):format(U.placeholders(#names))
    if type(q) == 'string' and q ~= '' then
        local like = U.like(q)
        where = where .. ' AND (LOWER(c.`firstName`) LIKE LOWER(?) OR LOWER(c.`lastName`) LIKE LOWER(?))'
        params[#params + 1] = like
        params[#params + 1] = like
    end
    params[#params + 1] = math.max(1, math.min(tonumber(limit) or 500, 2000))
    local rows = db.query(('SELECT %s FROM `characters` c WHERE %s LIMIT ?'):format(COLS, where), params) or {}
    local out = {}
    for _, p in ipairs(fromRows(rows)) do out[#out + 1] = F.playerByCid(p.cid) or p end
    return out
end

function chars.findByMeta(key, value) return store.find(key, value) end

local function charIdOf(cid)
    local p = F.rawByCid(cid)
    if p then return p.charId end
    return db.scalar('SELECT `charId` FROM `characters` WHERE `stateId` = ? LIMIT 1', { cid })
end

function chars.setJob(cid, job, grade, onduty)
    local p = F.rawByCid(cid)
    if p then
        F.setJob(p.source, job, grade)
        if onduty ~= nil then F.setDuty(p.source, onduty) end
        return true
    end
    local charId = charIdOf(cid)
    if not charId then return false end
    local jobs = F.jobs()
    local names = {}
    for name, info in pairs(jobs) do if info.type ~= 'none' then names[#names + 1] = name end end
    if #names > 0 then
        db.update(('DELETE FROM `character_groups` WHERE `charId` = ? AND `name` IN (%s)'):format(U.placeholders(#names)), { charId, table.unpack(names) })
    end
    if job == 'unemployed' then return true end
    return db.insert('INSERT INTO `character_groups` (`charId`, `name`, `grade`, `isActive`) VALUES (?, ?, ?, ?)', { charId, job, (tonumber(grade) or 0) + 1, onduty and 1 or 0 }) ~= nil
end

function chars.setMeta(cid, key, value)
    local p = F.rawByCid(cid)
    if p then return F.setMeta(p.source, key, value) end
    return store.set(cid, key, value)
end

function chars.removeBank(cid, amount, partial, reason)
    local charId = charIdOf(cid)
    if not charId then return 0 end
    local ok, acc = pcall(Ox().GetCharacterAccount, charId)
    if not ok or not acc then return 0 end
    local bank = U.int(field(acc, 'balance'), 0)
    local take = math.min(bank, amount)
    if take < amount and not partial then take = 0 end
    if take <= 0 then return 0 end
    local res = acc.removeBalance({ amount = take, message = reason, overdraw = false })
    if type(res) == 'table' and res.success == false then return 0 end
    return take
end

function chars.bank(cid)
    local charId = charIdOf(cid)
    if not charId then return 0 end
    local ok, acc = pcall(Ox().GetCharacterAccount, charId)
    return ok and acc and U.int(field(acc, 'balance'), 0) or 0
end

function chars.addBank(cid, amount, reason)
    amount = U.int(amount, 0)
    if amount <= 0 then return false end
    local charId = charIdOf(cid)
    if not charId then return false end
    local ok, acc = pcall(Ox().GetCharacterAccount, charId)
    if not ok or not acc then return false end
    local res = acc.addBalance({ amount = amount, message = reason })
    return type(res) ~= 'table' or res.success ~= false
end

function chars.license(cid)
    local p = F.rawByCid(cid)
    if p then return GetPlayerIdentifierByType(tostring(p.source), 'license') end
    return db.scalar('SELECT u.`license2` FROM `characters` c JOIN `users` u ON u.`userId` = c.`userId` WHERE c.`stateId` = ? LIMIT 1', { cid })
end

local licences = {}
F.licences = licences

function licences.get(cid)
    local charId = charIdOf(cid)
    local out = {}
    if not charId then return out end
    for _, r in ipairs(db.query('SELECT `name` FROM `character_licenses` WHERE `charId` = ?', { charId }) or {}) do
        out[r.name] = true
    end
    return out
end

function licences.set(cid, name, value)
    local p = F.rawByCid(cid)
    if p then
        if value then return p.addLicense(name) ~= false end
        return p.removeLicense(name) ~= false
    end
    local charId = charIdOf(cid)
    if not charId then return false end
    if value then
        return db.insert('INSERT IGNORE INTO `character_licenses` (`charId`, `name`, `data`) VALUES (?, ?, ?)', { charId, name, json.encode({ issued = os.time() }) }) ~= nil
    end
    return db.update('DELETE FROM `character_licenses` WHERE `charId` = ? AND `name` = ?', { charId, name }) ~= nil
end

local vehicles = {}
F.vehicles = vehicles

local function vrows(rows)
    local out = {}
    for _, r in ipairs(rows or {}) do
        out[#out + 1] = { plate = r.plate, model = r.model, ownerCid = r.stateId, garage = nil, state = tonumber(r.stored) and 1 or (r.stored and r.stored ~= '' and 1 or 0) }
    end
    return out
end

local VSEL = 'SELECT v.`plate`, v.`model`, v.`stored`, c.`stateId` FROM `vehicles` v LEFT JOIN `characters` c ON c.`charId` = v.`owner`'

function vehicles.label(model) return model end
function vehicles.modelsMatching() return {} end

function vehicles.search(q, limit)
    local like = U.like(q)
    return vrows(db.query(VSEL .. ' WHERE v.`plate` LIKE ? OR v.`model` LIKE ? ORDER BY v.`plate` LIMIT ?', { like, like, math.max(1, math.min(tonumber(limit) or 30, 100)) }))
end

function vehicles.byPlates(plates)
    if #plates == 0 then return {} end
    return vrows(db.query(VSEL .. (' WHERE v.`plate` IN (%s)'):format(U.placeholders(#plates)), plates))
end

function vehicles.byPlate(plate)
    return vrows(db.query(VSEL .. ' WHERE v.`plate` = ? LIMIT 1', { plate }))[1]
end

function vehicles.ofOwner(cid, limit)
    return vrows(db.query(VSEL .. ' WHERE c.`stateId` = ? LIMIT ?', { cid, math.max(1, math.min(tonumber(limit) or 50, 200)) }))
end

function vehicles.platesLike(q, limit)
    local out = {}
    for _, r in ipairs(db.query('SELECT `plate` FROM `vehicles` WHERE `plate` LIKE ? ORDER BY `plate` LIMIT ?', { U.like(q), limit or 10 }) or {}) do out[#out + 1] = r.plate end
    return out
end

return F
