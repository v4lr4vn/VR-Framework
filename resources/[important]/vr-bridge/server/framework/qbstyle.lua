local U = Bridge.util
local db = Bridge.db

return function(opts)
    local F = { name = opts.name }
    local playersTable = opts.table
    local events = opts.events

    local function core() return opts.core() end

    local function invoke(player, method, ...)
        if not player then return nil end
        local fns = player.Functions
        if type(fns) == 'table' and U.callable(fns[method]) then return fns[method](...) end
        if U.callable(player[method]) then return player[method](player, ...) end
        return nil
    end
    F.invoke = invoke

    local jobsCache, jobsAt = nil, 0

    function F.jobs()
        local now = GetGameTimer()
        if jobsCache and now - jobsAt < 5000 then return jobsCache end
        local raw = opts.jobs() or {}
        local out = {}
        for name, info in pairs(raw) do
            local grades = {}
            for key, g in pairs(type(info.grades) == 'table' and info.grades or {}) do
                local level = tonumber(key) or tonumber(g.grade) or tonumber(g.level)
                if level then
                    grades[level] = { name = g.name or g.label or tostring(level), isboss = g.isboss == true, payment = tonumber(g.payment), display = tonumber(g.display) }
                end
            end
            out[name] = {
                name = name, label = info.label or name, type = U.jobType(name, info.type), grades = grades, defaultDuty = info.defaultDuty,
                -- Optional extras a script can put on a job it creates: shown in the job menu.
                whitelisted = info.whitelisted == true, description = type(info.description) == 'string' and info.description or nil,
                icon = type(info.icon) == 'string' and info.icon or nil, source = type(info.source) == 'string' and info.source or nil,
            }
        end
        jobsCache, jobsAt = out, now
        return out
    end

    local function normJob(job)
        job = type(job) == 'table' and job or {}
        local g = job.grade
        local level = type(g) == 'table' and tonumber(g.level) or tonumber(g) or 0
        local name = job.name or 'unemployed'
        local info = F.jobs()[name]
        local gradeInfo = info and info.grades[level]
        return {
            name = name,
            label = job.label or (info and info.label) or name,
            type = U.jobType(name, job.type or (info and info.type)),
            grade = level,
            gradeName = type(g) == 'table' and g.name or (gradeInfo and gradeInfo.name) or tostring(level),
            isboss = job.isboss == true or (type(g) == 'table' and g.isboss == true) or (gradeInfo and gradeInfo.isboss) == true,
            onduty = job.onduty == true,
        }
    end
    F.normJob = normJob

    local function normalize(pd, online)
        if type(pd) ~= 'table' then return nil end
        local ci = U.decode(pd.charinfo, {})
        local money = U.decode(pd.money, {})
        return {
            source = online and tonumber(pd.source) or nil,
            cid = pd.citizenid,
            firstname = ci.firstname,
            lastname = ci.lastname,
            name = U.fullName(ci.firstname, ci.lastname),
            dob = U.dob(ci.birthdate),
            gender = U.gender(ci.gender),
            phone = ci.phone and tostring(ci.phone) or nil,
            nationality = ci.nationality,
            job = normJob(U.decode(pd.job, {})),
            gang = (function()
                local g = U.decode(pd.gang, {})
                if type(g) ~= 'table' or not g.name or g.name == 'none' then return nil end
                local grade = type(g.grade) == 'table' and tonumber(g.grade.level) or tonumber(g.grade) or 0
                return { name = g.name, label = g.label or g.name, grade = grade, isboss = g.isboss == true or (type(g.grade) == 'table' and g.grade.isboss == true) }
            end)(),
            money = { cash = tonumber(money.cash) or 0, bank = tonumber(money.bank) or 0 },
            metadata = U.decode(pd.metadata, {}),
            online = online == true,
        }
    end

    function F.raw(src) return opts.getPlayer(tonumber(src)) end
    function F.rawByCid(cid) return opts.getPlayerByCid(cid) end

    function F.player(src)
        local p = opts.getPlayer(tonumber(src))
        return p and normalize(p.PlayerData, true) or nil
    end

    function F.playerByCid(cid)
        if type(cid) ~= 'string' then return nil end
        local p = opts.getPlayerByCid(cid)
        return p and normalize(p.PlayerData, true) or nil
    end

    function F.sources() return opts.sources() end

    function F.setMeta(src, key, value)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        invoke(p, 'SetMetaData', key, value)
        return true
    end

    -- Jobs made while the server runs (for example one per restaurant). `def` has label, type, defaultDuty,
    -- offDutyPay, whitelisted, description, icon, source and grades = { [0] = { name, payment, isboss, display } }.
    function F.defineJob(name, def)
        if type(name) ~= 'string' or name == '' or type(def) ~= 'table' then return false end
        local fns = core().Functions
        local grades = {}
        for level, g in pairs(type(def.grades) == 'table' and def.grades or {}) do
            grades[tostring(tonumber(level) or level)] = g
        end
        local data = {}
        for k, v in pairs(def) do data[k] = v end
        data.grades = grades
        local exists = core().Shared.Jobs[name] ~= nil
        local fn = exists and fns.UpdateJob or fns.AddJob
        if not U.callable(fn) then return false end
        local done = fn(name, data)
        jobsCache = nil
        return done ~= false
    end

    function F.removeJobDef(name)
        if type(name) ~= 'string' or name == '' then return false end
        local fns = core().Functions
        if core().Shared.Jobs[name] == nil then return true end
        if not U.callable(fns.RemoveJob) then return false end
        local done = fns.RemoveJob(name)
        jobsCache = nil
        return done ~= false
    end

    function F.setJob(src, job, grade)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        return invoke(p, 'SetJob', job, grade) ~= false
    end

    function F.setDuty(src, onduty)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        invoke(p, 'SetJobDuty', onduty == true)
        if opts.afterDuty then opts.afterDuty(tonumber(src), onduty == true) end
        return true
    end

    function F.addMoney(src, account, amount, reason)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        return invoke(p, 'AddMoney', account, amount, reason) ~= false
    end

    function F.removeMoney(src, account, amount, reason)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        return invoke(p, 'RemoveMoney', account, amount, reason) ~= false
    end

    function F.save(src)
        local p = opts.getPlayer(tonumber(src))
        if p then invoke(p, 'Save') end
    end

    F.notify = opts.notify
    F.isAdmin = opts.isAdmin
    F.society = opts.society

    function F.status(src)
        local p = opts.getPlayer(tonumber(src))
        local md = p and p.PlayerData and p.PlayerData.metadata or {}
        local st = Player(src).state
        return {
            dead = md.isdead == true or md.inlaststand == true or st.dead == true or st.isDead == true,
            cuffed = md.ishandcuffed == true or st.isHandcuffed == true,
        }
    end

    function F.listen(emit)
        AddEventHandler(events .. ':Server:PlayerLoaded', function(player)
            local src = type(player) == 'table' and player.PlayerData and tonumber(player.PlayerData.source)
            if src then emit('playerLoaded', src) end
        end)
        AddEventHandler(events .. ':Server:OnPlayerUnload', function(src)
            emit('playerUnloaded', tonumber(src))
        end)
        AddEventHandler(events .. ':Server:OnJobUpdate', function(src, job)
            emit('jobChanged', tonumber(src), normJob(job))
        end)
        AddEventHandler(events .. ':Server:SetDuty', function(src, onduty)
            emit('dutyChanged', tonumber(src), onduty == true)
        end)
        AddEventHandler(events .. ':Server:OnGangUpdate', function(src, gang)
            local g = type(gang) == 'table' and gang or {}
            local grade = type(g.grade) == 'table' and tonumber(g.grade.level) or tonumber(g.grade) or 0
            emit('gangChanged', tonumber(src), g.name and g.name ~= 'none' and { name = g.name, label = g.label or g.name, grade = grade, isboss = g.isboss == true or (type(g.grade) == 'table' and g.grade.isboss == true) } or nil)
        end)
        AddEventHandler(events .. ':Server:OnMoneyChange', function(src, account, amount, operation, reason)
            emit('moneyChanged', tonumber(src), account, tonumber(amount) or 0, operation, reason)
        end)
        if opts.societyEvent then
            AddEventHandler(opts.societyEvent, function(name, amount, operation, reason, balance)
                emit('societyChanged', name, tonumber(amount) or 0, operation, reason, tonumber(balance))
            end)
        end
    end

    function F.money(src, account)
        local p = opts.getPlayer(tonumber(src))
        local money = p and p.PlayerData and p.PlayerData.money
        return type(money) == 'table' and tonumber(money[account]) or 0
    end

    function F.setMoney(src, account, amount, reason)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        return invoke(p, 'SetMoney', account, amount, reason) ~= false
    end

    function F.setGang(src, gang, grade)
        local p = opts.getPlayer(tonumber(src))
        if not p then return false end
        return invoke(p, 'SetGang', gang, grade) ~= false
    end

    function F.getMeta(src, key)
        local p = opts.getPlayer(tonumber(src))
        local md = p and p.PlayerData and p.PlayerData.metadata
        if type(md) ~= 'table' then return nil end
        if key == nil then return md end
        return md[key]
    end

    function F.groups(src)
        local p = opts.getPlayer(tonumber(src))
        local pd = p and p.PlayerData
        local out = {}
        if not pd then return out end
        local job, gang = pd.job, pd.gang
        if type(job) == 'table' and job.name then
            out[job.name] = type(job.grade) == 'table' and tonumber(job.grade.level) or tonumber(job.grade) or 0
        end
        if type(gang) == 'table' and gang.name and gang.name ~= 'none' then
            out[gang.name] = type(gang.grade) == 'table' and tonumber(gang.grade.level) or tonumber(gang.grade) or 0
        end
        return out
    end

    function F.license(src)
        local p = opts.getPlayer(tonumber(src))
        local lic = p and p.PlayerData and p.PlayerData.license
        return lic or GetPlayerIdentifierByType(tostring(src), 'license')
    end

    local gangsCache, gangsAt = nil, 0

    function F.gangs()
        local now = GetGameTimer()
        if gangsCache and now - gangsAt < 5000 then return gangsCache end
        local raw = opts.gangs and opts.gangs() or {}
        local out = {}
        for name, info in pairs(raw) do
            if name ~= 'none' then
                local grades = {}
                for key, g in pairs(type(info.grades) == 'table' and info.grades or {}) do
                    local level = tonumber(key) or tonumber(g.grade) or tonumber(g.level)
                    if level then grades[level] = { name = g.name or g.label or tostring(level), isboss = g.isboss == true } end
                end
                out[name] = { name = name, label = info.label or name, grades = grades }
            end
        end
        gangsCache, gangsAt = out, now
        return out
    end

    function F.useItem(name, fn)
        if opts.useItem then return opts.useItem(name, fn) end
        local c = core()
        local create = c and c.Functions and c.Functions.CreateUseableItem
        if U.callable(create) then create(name, fn) return true end
        return false
    end

    function F.usable(name)
        local found
        if opts.canUseItem then
            found = opts.canUseItem(name)
        else
            local c = core()
            local can = c and c.Functions and c.Functions.CanUseItem
            if U.callable(can) then found = can(name) end
        end
        if type(found) == 'table' and U.callable(found.func) then return found.func end
        if U.callable(found) then return found end
        return nil
    end

    function F.itemDefs()
        if opts.items then return opts.items() or {} end
        local c = core()
        return c and c.Shared and c.Shared.Items or {}
    end

    function F.vehicleList()
        return opts.vehicleList and opts.vehicleList() or {}
    end

    local chars = {}
    F.chars = chars

    local COLS = '`citizenid`, `charinfo`, `job`, `metadata`, `money`'

    local function jsonLike(col, path)
        return ('LOWER(JSON_UNQUOTE(JSON_EXTRACT(`%s`, \'%s\')))'):format(col, path)
    end

    function chars.search(q, limit)
        limit = math.max(1, math.min(tonumber(limit) or 20, 100))
        local first, last = q:match('^(%S+)%s+(.+)$')
        local rows
        if first then
            rows = db.query(('SELECT %s FROM `%s` WHERE (%s LIKE LOWER(?) AND %s LIKE LOWER(?)) OR `citizenid` = ? LIMIT ?'):format(
                COLS, playersTable, jsonLike('charinfo', '$.firstname'), jsonLike('charinfo', '$.lastname')), { U.like(first), U.like(last), q:upper(), limit })
        else
            local like = U.like(q)
            rows = db.query(('SELECT %s FROM `%s` WHERE %s LIKE LOWER(?) OR %s LIKE LOWER(?) OR `citizenid` LIKE ? OR %s LIKE LOWER(?) LIMIT ?'):format(
                COLS, playersTable, jsonLike('charinfo', '$.firstname'), jsonLike('charinfo', '$.lastname'), jsonLike('charinfo', '$.phone')), { like, like, like, like, limit })
        end
        local out = {}
        for _, r in ipairs(rows or {}) do out[#out + 1] = normalize(r, false) end
        return out
    end

    function chars.get(cid)
        local live = F.playerByCid(cid)
        if live then return live end
        local row = db.single(('SELECT %s FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(COLS, playersTable), { cid })
        return row and normalize(row, false) or nil
    end

    function chars.exists(cid)
        if opts.getPlayerByCid(cid) then return true end
        return db.scalar(('SELECT 1 FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(playersTable), { cid }) ~= nil
    end

    function chars.many(cids)
        local out = {}
        if #cids == 0 then return out end
        local missing = {}
        for _, cid in ipairs(cids) do
            local live = F.playerByCid(cid)
            if live then out[cid] = live else missing[#missing + 1] = cid end
        end
        if #missing > 0 then
            local rows = db.query(('SELECT %s FROM `%s` WHERE `citizenid` IN (%s)'):format(COLS, playersTable, U.placeholders(#missing)), missing) or {}
            for _, r in ipairs(rows) do out[r.citizenid] = normalize(r, false) end
        end
        return out
    end

    function chars.byJobs(names, q, limit)
        if #names == 0 then return {} end
        local params = {}
        for i, n in ipairs(names) do params[i] = n end
        local where = ("JSON_UNQUOTE(JSON_EXTRACT(`job`, '$.name')) IN (%s)"):format(U.placeholders(#names))
        if type(q) == 'string' and q ~= '' then
            local like = U.like(q)
            where = where .. (' AND (%s LIKE LOWER(?) OR %s LIKE LOWER(?) OR %s LIKE LOWER(?))'):format(jsonLike('charinfo', '$.firstname'), jsonLike('charinfo', '$.lastname'), jsonLike('metadata', '$.callsign'))
            params[#params + 1] = like
            params[#params + 1] = like
            params[#params + 1] = like
        end
        params[#params + 1] = math.max(1, math.min(tonumber(limit) or 500, 2000))
        local rows = db.query(('SELECT %s FROM `%s` WHERE %s LIMIT ?'):format(COLS, playersTable, where), params) or {}
        local out = {}
        for _, r in ipairs(rows) do
            local live = F.playerByCid(r.citizenid)
            out[#out + 1] = live or normalize(r, false)
        end
        return out
    end

    function chars.findByMeta(key, value, jobNames)
        local params = { value }
        local where = ('LOWER(JSON_UNQUOTE(JSON_EXTRACT(`metadata`, \'$.%s\'))) = LOWER(?)'):format(key:gsub('[^%w_]', ''))
        if jobNames and #jobNames > 0 then
            where = where .. (" AND JSON_UNQUOTE(JSON_EXTRACT(`job`, '$.name')) IN (%s)"):format(U.placeholders(#jobNames))
            for _, n in ipairs(jobNames) do params[#params + 1] = n end
        end
        local rows = db.query(('SELECT `citizenid` FROM `%s` WHERE %s LIMIT 20'):format(playersTable, where), params) or {}
        local out = {}
        for _, r in ipairs(rows) do out[#out + 1] = r.citizenid end
        return out
    end

    local function jobJson(job, grade, onduty)
        local info = F.jobs()[job] or { label = job, type = 'none', grades = {} }
        local g = info.grades[grade] or { name = 'No Grades', isboss = false }
        local payment = g.payment or 30
        return json.encode({
            name = job, label = info.label, payment = payment, type = info.type, onduty = (onduty == nil and info.defaultDuty == true) or onduty == true,
            isboss = g.isboss == true, grade = { name = g.name, level = grade, isboss = g.isboss == true, payment = payment },
        })
    end

    function chars.setJob(cid, job, grade, onduty)
        local p = opts.getPlayerByCid(cid)
        if p then
            if invoke(p, 'SetJob', job, grade) == false then return false end
            if onduty ~= nil then
                local fresh = opts.getPlayerByCid(cid) or p
                local current = fresh.PlayerData.job and fresh.PlayerData.job.onduty == true
                if current ~= (onduty == true) then invoke(fresh, 'SetJobDuty', onduty == true) end
            end
            invoke(opts.getPlayerByCid(cid) or p, 'Save')
            return true
        end
        return db.update(('UPDATE `%s` SET `job` = ? WHERE `citizenid` = ?'):format(playersTable), { jobJson(job, grade, onduty), cid }) ~= nil
    end

    function chars.setMeta(cid, key, value)
        local p = opts.getPlayerByCid(cid)
        if p then
            invoke(p, 'SetMetaData', key, value)
            return true
        end
        local path = '$.' .. key:gsub('[^%w_]', '')
        if value == nil then
            return db.update(('UPDATE `%s` SET `metadata` = JSON_REMOVE(COALESCE(NULLIF(`metadata`, \'\'), \'{}\'), ?) WHERE `citizenid` = ?'):format(playersTable), { path, cid }) ~= nil
        end
        return db.update(('UPDATE `%s` SET `metadata` = JSON_SET(COALESCE(NULLIF(`metadata`, \'\'), \'{}\'), ?, JSON_EXTRACT(?, \'$\')) WHERE `citizenid` = ?'):format(playersTable), { path, json.encode(value), cid }) ~= nil
    end

    function chars.removeBank(cid, amount, partial, reason)
        local p = opts.getPlayerByCid(cid)
        if p then
            local bank = U.int(p.PlayerData.money and p.PlayerData.money.bank, 0)
            local take = math.min(bank, amount)
            if take < amount and not partial then take = 0 end
            if take <= 0 then return 0 end
            return invoke(p, 'RemoveMoney', 'bank', take, reason) == false and 0 or take
        end
        local row = db.single(('SELECT `money` FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(playersTable), { cid })
        local money = row and U.decode(row.money, nil)
        if type(money) ~= 'table' then return 0 end
        local bank = U.int(money.bank, 0)
        local take = math.min(bank, amount)
        if take < amount and not partial then take = 0 end
        if take <= 0 then return 0 end
        money.bank = bank - take
        local n = db.update(('UPDATE `%s` SET `money` = ? WHERE `citizenid` = ? AND `money` = ?'):format(playersTable), { json.encode(money), cid, row.money })
        if not n or n < 1 then return 0 end
        return take
    end

    function chars.bank(cid)
        local p = opts.getPlayerByCid(cid)
        if p then return U.int(p.PlayerData.money and p.PlayerData.money.bank, 0) end
        local row = db.single(('SELECT `money` FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(playersTable), { cid })
        local money = row and U.decode(row.money, nil)
        return type(money) == 'table' and U.int(money.bank, 0) or 0
    end

    function chars.addBank(cid, amount, reason)
        amount = U.int(amount, 0)
        if amount <= 0 then return false end
        local p = opts.getPlayerByCid(cid)
        if p then return invoke(p, 'AddMoney', 'bank', amount, reason) ~= false end
        for _ = 1, 3 do
            local row = db.single(('SELECT `money` FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(playersTable), { cid })
            local money = row and U.decode(row.money, nil)
            if type(money) ~= 'table' then return false end
            money.bank = U.int(money.bank, 0) + amount
            local n = db.update(('UPDATE `%s` SET `money` = ? WHERE `citizenid` = ? AND `money` = ?'):format(playersTable), { json.encode(money), cid, row.money })
            if n and n > 0 then return true end
        end
        return false
    end

    function chars.license(cid)
        local p = opts.getPlayerByCid(cid)
        if p and p.PlayerData.license then return p.PlayerData.license end
        return db.scalar(('SELECT `license` FROM `%s` WHERE `citizenid` = ? LIMIT 1'):format(playersTable), { cid })
    end

    local licences = {}
    F.licences = licences

    function licences.get(cid)
        local person = chars.get(cid)
        local held = person and type(person.metadata.licences) == 'table' and person.metadata.licences or {}
        local out = {}
        for k, v in pairs(held) do out[k] = v == true end
        return out
    end

    function licences.set(cid, name, value)
        local current = licences.get(cid)
        current[name] = value == true
        return chars.setMeta(cid, 'licences', current)
    end

    local vehicles = {}
    F.vehicles = vehicles
    local vtable = opts.vehicleTable or 'player_vehicles'

    local function vrow(r)
        return { plate = r.plate, model = r.vehicle, ownerCid = r.citizenid, garage = r.garage, state = tonumber(r.state) }
    end

    function vehicles.label(model)
        local list = opts.vehicleList and opts.vehicleList() or {}
        local v = type(model) == 'string' and list[model] or nil
        if v then return U.trim(('%s %s'):format(v.brand or '', v.name or model)) end
        return nil
    end

    function vehicles.modelsMatching(q, limit)
        local out = {}
        local needle = tostring(q):lower()
        for model, v in pairs(opts.vehicleList and opts.vehicleList() or {}) do
            local hay = ('%s %s %s'):format(model, v.brand or '', v.name or ''):lower()
            if hay:find(needle, 1, true) then
                out[#out + 1] = model
                if #out >= (limit or 50) then break end
            end
        end
        return out
    end

    function vehicles.search(q, limit)
        limit = math.max(1, math.min(tonumber(limit) or 30, 100))
        local like = U.like(q)
        local models = vehicles.modelsMatching(q, 50)
        local rows
        if #models > 0 then
            local params = { like }
            for _, m in ipairs(models) do params[#params + 1] = m end
            params[#params + 1] = limit
            rows = db.query(('SELECT `plate`, `vehicle`, `citizenid`, `garage`, `state` FROM `%s` WHERE `plate` LIKE ? OR `vehicle` IN (%s) ORDER BY `plate` LIMIT ?'):format(vtable, U.placeholders(#models)), params)
        else
            rows = db.query(('SELECT `plate`, `vehicle`, `citizenid`, `garage`, `state` FROM `%s` WHERE `plate` LIKE ? OR `vehicle` LIKE ? ORDER BY `plate` LIMIT ?'):format(vtable), { like, like, limit })
        end
        local out = {}
        for _, r in ipairs(rows or {}) do out[#out + 1] = vrow(r) end
        return out
    end

    function vehicles.byPlates(plates)
        if #plates == 0 then return {} end
        local rows = db.query(('SELECT `plate`, `vehicle`, `citizenid`, `garage`, `state` FROM `%s` WHERE `plate` IN (%s)'):format(vtable, U.placeholders(#plates)), plates) or {}
        local out = {}
        for _, r in ipairs(rows) do out[#out + 1] = vrow(r) end
        return out
    end

    function vehicles.byPlate(plate)
        local r = db.single(('SELECT `plate`, `vehicle`, `citizenid`, `garage`, `state` FROM `%s` WHERE `plate` = ? LIMIT 1'):format(vtable), { plate })
        return r and vrow(r) or nil
    end

    function vehicles.ofOwner(cid, limit)
        local rows = db.query(('SELECT `plate`, `vehicle`, `citizenid`, `garage`, `state` FROM `%s` WHERE `citizenid` = ? LIMIT ?'):format(vtable), { cid, math.max(1, math.min(tonumber(limit) or 50, 200)) }) or {}
        local out = {}
        for _, r in ipairs(rows) do out[#out + 1] = vrow(r) end
        return out
    end

    function vehicles.platesLike(q, limit)
        local rows = db.query(('SELECT `plate` FROM `%s` WHERE `plate` LIKE ? ORDER BY `plate` LIMIT ?'):format(vtable), { U.like(q), limit or 10 }) or {}
        local out = {}
        for _, r in ipairs(rows) do out[#out + 1] = r.plate end
        return out
    end

    return F
end
