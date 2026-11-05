-- Owners, ranks, staff, duty, the business account and wages.

local function allPerms()
    local s = {}
    for _, p in ipairs(Config.Perms) do s[p.id] = true end
    return s
end

local function permSet(list)
    local s = {}
    for _, p in ipairs(list or {}) do s[p] = true end
    return s
end

local function permList(set)
    local out = {}
    for _, p in ipairs(Config.Perms) do
        if set[p.id] then out[#out + 1] = p.id end
    end
    return out
end

-- What a character is in a restaurant: owner, a ranked member, or nothing.
function Rest.role(b, cid)
    if b.owner ~= '' and b.owner == cid then
        return { owner = true, level = 100, perms = allPerms(), wage = b.ownerWage, label = 'Owner' }
    end
    local m = b.staff[cid]
    local r = m and b.ranks[m.rank]
    if not r then return nil end
    return { owner = false, level = r.level, perms = permSet(r.perms), wage = r.wage, label = r.label, rank = r }
end

-- The restaurant a player belongs to, and their role in it.
function Rest.membership(src)
    local who = Rest.info(src)
    if not who then return nil end
    local id = Rest.byCid[who.cid]
    local b = id and Rest.biz[id]
    if not b then return who end
    return who, b, Rest.role(b, who.cid)
end

local function dutyOff(cid)
    Rest.duty[cid] = nil
end

local function countStaff(b)
    local n = 0
    for _ in pairs(b.staff) do n = n + 1 end
    return n
end

local function countOn(b, rankId)
    local n = 0
    for _, m in pairs(b.staff) do
        if m.rank == rankId then n = n + 1 end
    end
    return n
end

local function rankCount(b)
    local n = 0
    for _ in pairs(b.ranks) do n = n + 1 end
    return n
end

local function sortedRanks(b)
    local out = {}
    for _, r in pairs(b.ranks) do out[#out + 1] = r end
    table.sort(out, function(a, c)
        if a.level ~= c.level then return a.level > c.level end
        return a.id < c.id
    end)
    return out
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------

function Rest.saveBusiness(b)
    MySQL.query('UPDATE vr_rest_businesses SET label = ?, x = ?, y = ?, z = ?, w = ?, owner = ?, owner_name = ?, max_wage = ?, owner_wage = ?, price = ?, licence_days = ?, licence_number = ?, licence_expires = ?, status = ?, closed_until = ?, closed_reason = ?, strikes = ?, last_strike = ?, last_inspected = ? WHERE id = ?', {
        b.label, b.x, b.y, b.z, b.w or 0.0, b.owner, b.ownerName or '', b.maxWage, b.ownerWage,
        b.price or 0, b.licenceDays or Config.Licence.defaultDays, b.licenceNumber or '', b.licenceExpires or 0,
        b.status or 'open', b.closedUntil or 0, b.closedReason or '', b.strikes or 0, b.lastStrike or 0, b.lastInspected or 0, b.id,
    })
end

local function saveRank(r)
    MySQL.query('UPDATE vr_rest_ranks SET level = ?, label = ?, wage = ?, perms = ? WHERE id = ?', { r.level, r.label, r.wage, Rest.permsToText(r.perms), r.id })
end

local function addRank(b, data)
    local id = MySQL.insert.await('INSERT INTO vr_rest_ranks (business, level, label, wage, perms) VALUES (?, ?, ?, ?, ?)', { b.id, data.level, data.label, data.wage, Rest.permsToText(data.perms) })
    if not id then return nil end
    local r = { id = id, level = data.level, label = data.label, wage = data.wage, perms = data.perms }
    b.ranks[id] = r
    return r
end
Rest.addRank = addRank

-- No rank may pay more than the owner, and the owner may not earn more than the admin limit.
function Rest.clampWages(b)
    if b.ownerWage > b.maxWage then b.ownerWage = b.maxWage end
    for _, r in pairs(b.ranks) do
        if r.wage > b.ownerWage then
            r.wage = b.ownerWage
            saveRank(r)
        end
    end
end

---------------------------------------------------------------------------
-- Wages
---------------------------------------------------------------------------

function Rest.payday()
    local paid, unpaid = 0, 0
    for _, b in pairs(Rest.biz) do
        local short = false
        local members = {}
        if b.owner ~= '' then members[#members + 1] = b.owner end
        for cid in pairs(b.staff) do members[#members + 1] = cid end
        for _, cid in ipairs(members) do
            local role = Rest.role(b, cid)
            if role and role.wage > 0 and Rest.duty[cid] == b.id then
                local src = Bridge.source(cid)
                if src then
                    if Rest.bank.remove(b, role.wage) then
                        if Bridge.addMoney(src, Config.Pay.account, role.wage, ('Wages: %s'):format(b.label)) then
                            paid = paid + 1
                            Rest.notify(src, ('Payday from %s: $%d'):format(b.label, role.wage), 'success')
                        else
                            Rest.bank.add(b, role.wage)
                        end
                    else
                        short = true
                        unpaid = unpaid + 1
                        Rest.notify(src, ('%s could not pay your wage this time'):format(b.label), 'error')
                    end
                end
            end
        end
        if short and b.owner ~= '' then
            local osrc = Bridge.source(b.owner)
            if osrc and Rest.duty[b.owner] ~= b.id then
                Rest.notify(osrc, ('%s ran out of money to pay wages. Put money in the business account'):format(b.label), 'error')
            end
        end
    end
    return paid, unpaid
end

Rest.nextPay = os.time() + math.max(1, Config.Pay.minutes) * 60

CreateThread(function()
    while true do
        Wait(math.max(1, Config.Pay.minutes) * 60 * 1000)
        Rest.nextPay = os.time() + math.max(1, Config.Pay.minutes) * 60
        if Rest.loaded then pcall(Rest.payday) end
    end
end)

-- What the next payday will cost: wages of everyone online and clocked in.
local function wagesDue(b)
    local total = 0
    local members = {}
    if b.owner ~= '' then members[#members + 1] = b.owner end
    for cid in pairs(b.staff) do members[#members + 1] = cid end
    for _, cid in ipairs(members) do
        local role = Rest.role(b, cid)
        if role and role.wage > 0 and Rest.duty[cid] == b.id and Bridge.source(cid) then total = total + role.wage end
    end
    return total
end

---------------------------------------------------------------------------
-- What the office screen shows
---------------------------------------------------------------------------

local function office(who, b, role)
    local out = {
        id = b.id, label = b.label,
        role = { label = role.label, owner = role.owner, wage = role.wage, level = role.level, perms = permList(role.perms) },
        duty = Rest.duty[who.cid] == b.id,
        maxWage = b.maxWage, ownerWage = b.ownerWage,
        payMinutes = Config.Pay.minutes,
        limits = { ranks = Config.Business.maxRanks, staff = Config.Business.maxStaff },
    }
    do
        local closed, reason = Rest.isClosed(b)
        local score = Rest.hygiene(b)
        local rate = Rest.ratingFor(score)
        out.compliance = {
            licence = Rest.licence(b), closed = closed, reason = reason, closedLeft = b.closedUntil > 0 and math.max(0, b.closedUntil - os.time()) or 0,
            hygiene = math.floor(score + 0.5), stars = rate.stars, rating = rate.label,
            strikes = b.strikes, maxStrikes = Config.Inspect.maxStrikes,
        }
    end
    out.payIn = math.max(0, (Rest.nextPay or os.time()) - os.time())
    if role.perms.money then
        out.balance = Rest.bank.balance(b)
        out.wagesDue = wagesDue(b)
    end
    if role.perms.staff or role.perms.ranks then
        out.ranks = {}
        for _, r in ipairs(sortedRanks(b)) do
            out.ranks[#out.ranks + 1] = {
                id = r.id, level = r.level, label = r.label, wage = r.wage, perms = r.perms,
                editable = r.level < role.level, members = countOn(b, r.id),
            }
        end
    end
    if role.perms.staff then
        out.staff = {}
        local list = {}
        for _, m in pairs(b.staff) do list[#list + 1] = m end
        table.sort(list, function(a, c) return (a.name or '') < (c.name or '') end)
        for _, m in ipairs(list) do
            local r = b.ranks[m.rank]
            out.staff[#out.staff + 1] = {
                cid = m.cid, name = m.name, rank = m.rank, rankLabel = r and r.label or '?',
                level = r and r.level or 0, wage = r and r.wage or 0,
                manageable = r ~= nil and r.level < role.level,
                online = Bridge.source(m.cid) ~= nil, duty = Rest.duty[m.cid] == b.id,
            }
        end
        out.owner = { name = b.ownerName ~= '' and b.ownerName or 'Nobody yet' }
    end
    return out
end

local function near(src, b)
    local d = Rest.distance(src, b.x, b.y, b.z)
    return d ~= nil and d <= Config.Business.reach + 2.0
end

local function officeContext(src, id)
    if not Rest.loaded then return nil, 'not_ready' end
    local who = Rest.info(src)
    if not who then return nil, 'no_player' end
    local b = Rest.biz[tonumber(id) or -1]
    if not b then return nil, 'not_found' end
    local role = Rest.role(b, who.cid)
    if not role then return nil, 'not_staff' end
    if not near(src, b) then return nil, 'too_far' end
    return who, b, role
end

lib.callback.register('vr-restaurant:office', function(src, id)
    local who, b, role = officeContext(src, id)
    if not who then return Rest.fail(b) end
    return { ok = true, data = office(who, b, role) }
end)

---------------------------------------------------------------------------
-- Validation of ranks
---------------------------------------------------------------------------

-- `existing` is the rank being edited, if any. Returns the cleaned fields or nil, error, extra.
local function cleanRank(b, role, data, existing)
    local out = {}
    if type(data) ~= 'table' then return nil, 'bad_request' end
    if data.label ~= nil or not existing then
        local label = Rest.text(data.label, 2, 24)
        if not label then return nil, 'bad_value' end
        for _, r in pairs(b.ranks) do
            if r ~= existing and r.label:lower() == label:lower() then return nil, 'name_taken' end
        end
        out.label = label
    end
    if data.level ~= nil or not existing then
        local level = Rest.int(data.level, 1, 99)
        if not level then return nil, 'bad_value' end
        if level >= role.level then return nil, 'level_too_high', { max = role.level - 1 } end
        out.level = level
    end
    if data.wage ~= nil or not existing then
        local wage = Rest.int(data.wage or 0, 0, 10000000)
        if not wage then return nil, 'bad_value' end
        if wage > b.ownerWage then return nil, 'wage_too_high', { max = b.ownerWage } end
        out.wage = wage
    end
    if data.perms ~= nil or not existing then
        local set, list = {}, {}
        local valid = allPerms()
        for _, p in ipairs(type(data.perms) == 'table' and data.perms or {}) do
            if type(p) ~= 'string' or not valid[p] then return nil, 'bad_value' end
            if not role.perms[p] then return nil, 'perm_not_yours' end
            set[p] = true
        end
        list = permList(set)
        out.perms = list
    end
    return out
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------

local ACT = {}
Rest.ACT = ACT
local inviting = {}

ACT.duty = function(who, b, role)
    if Rest.duty[who.cid] == b.id then
        dutyOff(who.cid)
        return { duty = false }
    end
    if Rest.isClosed(b) then return nil, 'closed' end
    Rest.duty[who.cid] = b.id
    return { duty = true }
end

ACT.wage = function(who, b, role, amount)
    if not role.owner then return nil, 'not_owner' end
    local wage = Rest.int(amount, 0, 10000000)
    if not wage then return nil, 'bad_value' end
    if wage > b.maxWage then return nil, 'wage_too_high', { max = b.maxWage } end
    b.ownerWage = wage
    Rest.clampWages(b)
    Rest.saveBusiness(b)
    return { wage = wage }
end

ACT.addrank = function(who, b, role, data)
    if not role.perms.ranks then return nil, 'no_permission' end
    if rankCount(b) >= Config.Business.maxRanks then return nil, 'too_many_ranks' end
    local clean, err, extra = cleanRank(b, role, data, nil)
    if not clean then return nil, err, extra end
    local r = addRank(b, clean)
    if not r then return nil, 'failed' end
    return { id = r.id }
end

ACT.editrank = function(who, b, role, id, data)
    if not role.perms.ranks then return nil, 'no_permission' end
    local r = b.ranks[tonumber(id) or -1]
    if not r then return nil, 'not_found' end
    if r.level >= role.level then return nil, 'too_senior' end
    local clean, err, extra = cleanRank(b, role, data, r)
    if not clean then return nil, err, extra end
    for k, v in pairs(clean) do r[k] = v end
    saveRank(r)
    return { id = r.id }
end

ACT.delrank = function(who, b, role, id)
    if not role.perms.ranks then return nil, 'no_permission' end
    local r = b.ranks[tonumber(id) or -1]
    if not r then return nil, 'not_found' end
    if r.level >= role.level then return nil, 'too_senior' end
    if countOn(b, r.id) > 0 then return nil, 'rank_in_use' end
    b.ranks[r.id] = nil
    MySQL.query('DELETE FROM vr_rest_ranks WHERE id = ?', { r.id })
    return { id = r.id }
end

ACT.nearby = function(who, b, role)
    if not role.perms.staff then return nil, 'no_permission' end
    local out = {}
    local me = Bridge.coords(who.src)
    if not me then return nil, 'too_far' end
    for _, src in ipairs(Bridge.sources()) do
        if src ~= who.src then
            local other = Rest.info(src)
            local at = Bridge.coords(src)
            if other and at and not Rest.byCid[other.cid] then
                local dx, dy, dz = at.x - me.x, at.y - me.y, at.z - me.z
                if dx * dx + dy * dy + dz * dz <= Config.Business.hireRange ^ 2 then
                    out[#out + 1] = { src = src, name = other.name }
                end
            end
        end
    end
    table.sort(out, function(a, c) return a.name < c.name end)
    return { players = out }
end

ACT.hire = function(who, b, role, target, rankId)
    if not role.perms.staff then return nil, 'no_permission' end
    target = tonumber(target)
    local rank = b.ranks[tonumber(rankId) or -1]
    if not target or not rank then return nil, 'bad_request' end
    if rank.level >= role.level then return nil, 'too_senior' end
    if countStaff(b) >= Config.Business.maxStaff then return nil, 'too_many_staff' end
    if target == who.src then return nil, 'bad_request' end
    local other = Rest.info(target)
    if not other then return nil, 'not_found' end
    if Rest.byCid[other.cid] then return nil, 'has_job' end
    local me, at = Bridge.coords(who.src), Bridge.coords(target)
    if not me or not at then return nil, 'too_far' end
    local dx, dy, dz = at.x - me.x, at.y - me.y, at.z - me.z
    if dx * dx + dy * dy + dz * dz > (Config.Business.hireRange + 2.0) ^ 2 then return nil, 'too_far' end
    if inviting[target] then return nil, 'busy' end

    inviting[target] = true
    local ok, answer = pcall(lib.callback.await, 'vr-restaurant:invite', target, {
        business = b.label, rank = rank.label, wage = rank.wage, by = who.name,
        seconds = Config.Business.inviteSeconds,
    })
    inviting[target] = nil
    if not ok or answer ~= true then return nil, 'declined' end

    -- Everything is checked again: a lot can change while somebody reads an offer.
    local still = Rest.info(target)
    if not still or still.cid ~= other.cid then return nil, 'not_found' end
    if Rest.byCid[still.cid] then return nil, 'has_job' end
    if not b.ranks[rank.id] or countStaff(b) >= Config.Business.maxStaff then return nil, 'failed' end
    local saved = MySQL.query.await('INSERT INTO vr_rest_staff (cid, business, name, rank_id) VALUES (?, ?, ?, ?)', { still.cid, b.id, still.name, rank.id })
    if not saved then return nil, 'failed' end
    b.staff[still.cid] = { cid = still.cid, name = still.name, rank = rank.id }
    Rest.byCid[still.cid] = b.id
    Rest.notify(target, ('You now work at %s as %s'):format(b.label, rank.label), 'success')
    return { name = still.name }
end

local function removeStaff(b, cid)
    b.staff[cid] = nil
    Rest.byCid[cid] = nil
    dutyOff(cid)
    MySQL.query('DELETE FROM vr_rest_staff WHERE cid = ?', { cid })
end
Rest.removeStaff = removeStaff

ACT.fire = function(who, b, role, cid)
    if not role.perms.staff then return nil, 'no_permission' end
    local m = b.staff[tostring(cid)]
    if not m then return nil, 'not_found' end
    local r = b.ranks[m.rank]
    if not r or r.level >= role.level then return nil, 'too_senior' end
    removeStaff(b, m.cid)
    local src = Bridge.source(m.cid)
    if src then Rest.notify(src, ('You no longer work at %s'):format(b.label), 'error') end
    return { name = m.name }
end

ACT.setrank = function(who, b, role, cid, rankId)
    if not role.perms.staff then return nil, 'no_permission' end
    local m = b.staff[tostring(cid)]
    local rank = b.ranks[tonumber(rankId) or -1]
    if not m or not rank then return nil, 'not_found' end
    local current = b.ranks[m.rank]
    if not current or current.level >= role.level or rank.level >= role.level then return nil, 'too_senior' end
    m.rank = rank.id
    MySQL.query('UPDATE vr_rest_staff SET rank_id = ? WHERE cid = ?', { rank.id, m.cid })
    local src = Bridge.source(m.cid)
    if src then Rest.notify(src, ('You are now %s at %s'):format(rank.label, b.label), 'success') end
    return { name = m.name }
end

ACT.quit = function(who, b, role)
    if role.owner then return nil, 'owner_cannot_quit' end
    removeStaff(b, who.cid)
    return { left = true }
end

ACT.deposit = function(who, b, role, amount)
    if not role.perms.money then return nil, 'no_permission' end
    local n = Rest.int(amount, 1, 100000000)
    if not n then return nil, 'bad_value' end
    if not Bridge.pay(who.src, n, ('Deposit: %s'):format(b.label)) then return nil, 'no_money' end
    if not Rest.bank.add(b, n) then
        Bridge.addMoney(who.src, 'bank', n, 'Deposit refund')
        return nil, 'failed'
    end
    return { balance = Rest.bank.balance(b) }
end

ACT.withdraw = function(who, b, role, amount)
    if not role.perms.money then return nil, 'no_permission' end
    local n = Rest.int(amount, 1, 100000000)
    if not n then return nil, 'bad_value' end
    if not Rest.bank.remove(b, n) then return nil, 'not_enough_in_account' end
    if not Bridge.addMoney(who.src, 'cash', n, ('Withdrawal: %s'):format(b.label)) then
        Rest.bank.add(b, n)
        return nil, 'failed'
    end
    return { balance = Rest.bank.balance(b) }
end

lib.callback.register('vr-restaurant:act', function(src, id, action, a, c)
    if Rest.throttle(src, 'act', Config.Business.minGapMs) then return Rest.fail('slow_down') end
    local who, b, role = officeContext(src, id)
    if not who then return Rest.fail(b) end
    local handler = type(action) == 'string' and ACT[action]
    if not handler then return Rest.fail('bad_request') end
    local data, err, extra = handler(who, b, role, a, c)
    if not data then return Rest.fail(err or 'failed', extra) end
    return { ok = true, data = data }
end)

local function leave(src)
    local who = Rest.info(src)
    if who then dutyOff(who.cid) end
end
AddEventHandler('playerDropped', function() leave(source) end)
AddEventHandler('VRCore:Server:OnPlayerUnload', function(src) leave(src) end)

-- For other scripts: does this player have this permission in a restaurant, and which one?
exports('HasPermission', function(src, perm, onDuty)
    local who, b, role = Rest.membership(src)
    if not b or not role or not role.perms[perm] then return false end
    if onDuty and Rest.duty[who.cid] ~= b.id then return false end
    return b.id
end)

exports('IsOnDuty', function(src)
    local who, b = Rest.membership(src)
    if not who or not b then return false end
    return Rest.duty[who.cid] == b.id and b.id or false
end)

exports('RunPayday', function() return Rest.payday() end)
