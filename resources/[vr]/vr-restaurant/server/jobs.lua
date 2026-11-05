-- Every restaurant is a real job in the framework (rest_<id>), so it shows up in the job menu, can be
-- seen by other scripts, and clocking in/out follows the job menu's duty button.
--
-- The restaurant stays the source of truth. A check runs every few seconds and after any change
-- (hire, fire, rank edit, owner change, new or removed restaurant) and brings the framework job list and
-- each character's job menu into line with it, so no single change has to remember to do this.

local cfg = Config.Jobs or {}
local MULTIJOB = 'vr-multijob'

local defined = {}      -- job name -> encoded definition last sent to the framework
local applied = {}      -- citizen id -> 'job:grade' last put in the job menu
local syncing = {}      -- citizen ids whose duty is being changed by us, so we ignore the echo
local unsupported = false
local pending = false

function Rest.jobName(id) return (cfg.prefix or 'rest_') .. tostring(id) end

function Rest.jobBusiness(name)
    if type(name) ~= 'string' then return nil end
    local prefix = cfg.prefix or 'rest_'
    if name:sub(1, #prefix) ~= prefix then return nil end
    local id = tonumber(name:sub(#prefix + 1))
    return id and Rest.biz[id] or nil, id
end

local function isRestaurantJob(name)
    local prefix = cfg.prefix or 'rest_'
    return type(name) == 'string' and name:sub(1, #prefix) == prefix and tonumber(name:sub(#prefix + 1)) ~= nil
end

-- Ranks from the lowest to the highest, then the owner on top.
local function ladder(b)
    local list = {}
    for _, r in pairs(b.ranks) do list[#list + 1] = r end
    table.sort(list, function(a, c)
        if a.level ~= c.level then return a.level < c.level end
        return a.id < c.id
    end)
    local index = {}
    for i, r in ipairs(list) do index[r.id] = i - 1 end
    return list, index, #list
end

function Rest.jobDef(b)
    local list, index, top = ladder(b)
    local grades = {}
    for i, r in ipairs(list) do
        grades[i - 1] = { name = r.label, payment = 0, display = r.wage }
    end
    grades[top] = { name = cfg.ownerGrade or 'Owner', payment = 0, isboss = true, display = b.ownerWage }
    return {
        label = b.label, type = 'restaurant', defaultDuty = false, offDutyPay = false,
        whitelisted = cfg.whitelisted ~= false, source = 'vr-restaurant', icon = cfg.icon,
        description = ('Work at %s. Wages are paid by the business while you are clocked in'):format(b.label),
        grades = grades,
    }, index, top
end

-- Which job and grade each character should have.
local function wanted()
    local out = {}
    for id, b in pairs(Rest.biz) do
        if b.status ~= 'revoked' then
            local _, index, top = Rest.jobDef(b)
            local name = Rest.jobName(id)
            if b.owner ~= '' then out[b.owner] = { job = name, grade = top, business = id } end
            for cid, m in pairs(b.staff) do
                if index[m.rank] ~= nil then out[cid] = { job = name, grade = index[m.rank], business = id } end
            end
        end
    end
    return out
end

local function multijob(name, ...)
    if GetResourceState(MULTIJOB) ~= 'started' then return nil end
    local args = { ... }
    local ok, res = pcall(function() return exports[MULTIJOB][name](exports[MULTIJOB], table.unpack(args)) end)
    if not ok then return nil end
    return res
end

local function defineAll()
    local retry = false
    local seen = {}
    for id, b in pairs(Rest.biz) do
        local name = Rest.jobName(id)
        seen[name] = true
        local def = Rest.jobDef(b)
        local encoded = json.encode(def)
        if defined[name] ~= encoded then
            if Bridge.defineJob(name, def) then defined[name] = encoded else retry = true end
        end
    end
    return seen, retry
end

local function removeStale(seen)
    for name in pairs(defined) do
        if not seen[name] then
            if Bridge.removeJobDef(name) then defined[name] = nil end
        end
    end
end

-- Puts one online person right: their job-menu entry, and no leftover restaurant jobs.
local function tidyPerson(src, cid, want)
    local ok, p = pcall(Bridge.player, src)
    if not ok or not p then return false end
    local retry = false
    local held = multijob('GetJobs', cid) or {}
    for job in pairs(held) do
        if isRestaurantJob(job) and (not want or want.job ~= job) then
            multijob('RemoveJob', cid, job)
        end
    end
    local current = p.job and p.job.name
    if isRestaurantJob(current) and (not want or want.job ~= current) then
        multijob('RemoveJob', cid, current)
        local after = Bridge.player(src)
        if after and after.job and after.job.name == current then Bridge.setJob(src, 'unemployed', 0) end
    end
    return retry
end

local function syncMembers()
    local want = wanted()
    local retry = false
    for cid, w in pairs(want) do
        local key = ('%s:%d'):format(w.job, w.grade)
        if applied[cid] ~= key then
            local before = applied[cid]
            local done
            if before and before:match('^[^:]+') == w.job then
                done = multijob('UpdateJobRank', cid, w.job, w.grade)
            else
                done = multijob('AddJob', cid, w.job, w.grade)
            end
            if done then
                applied[cid] = key
                local src = Bridge.source(cid)
                local p = src and Bridge.player(src)
                -- Somebody with no other job starts out working here; everybody else switches in the job menu.
                if p and p.job and (p.job.name == 'unemployed' or p.job.name == nil) then
                    Bridge.setJob(src, w.job, w.grade)
                end
            else
                retry = true
            end
        end
    end
    -- Anyone who is no longer in a restaurant.
    for cid, key in pairs(applied) do
        if not want[cid] then
            local job = key:match('^[^:]+')
            multijob('RemoveJob', cid, job)
            applied[cid] = nil
        end
    end
    -- Online characters are checked directly, which also covers anything left over from before a restart.
    for _, src in ipairs(Bridge.sources()) do
        local cid = Bridge.cid(src)
        if cid then tidyPerson(src, cid, want[cid]) end
    end
    return retry
end

function Rest.syncJobs()
    if unsupported or cfg.enabled == false or not Rest.loaded then return end
    local seen, retryDefine = defineAll()
    local retryMembers = syncMembers()
    removeStale(seen)
    if retryDefine or retryMembers then Rest.syncSoon(6) end
end

function Rest.syncSoon(seconds)
    if pending then return end
    pending = true
    SetTimeout((tonumber(seconds) or 1) * 1000, function()
        pending = false
        local ok, err = pcall(Rest.syncJobs)
        if not ok then print(('^1[vr-restaurant] job sync failed: %s^0'):format(tostring(err))) end
    end)
end

---------------------------------------------------------------------------
-- Clocking in and out follows the framework's duty, and the other way round
---------------------------------------------------------------------------

local raw = Rest.duty
Rest.duty = setmetatable({}, {
    __index = raw,
    __newindex = function(_, cid, value)
        local old = raw[cid]
        raw[cid] = value
        if old == value or syncing[cid] or cfg.enabled == false then return end
        local ok, err = pcall(function()
            local src = Bridge.source(cid)
            if not src then return end
            local p = Bridge.player(src)
            if not p or not p.job then return end
            syncing[cid] = true
            if value then
                local b = Rest.biz[value]
                if b then
                    local _, index, top = Rest.jobDef(b)
                    local role = Rest.role(b, cid)
                    local m = b.staff[cid]
                    local grade = (role and role.owner) and top or (m and index[m.rank])
                    local name = Rest.jobName(b.id)
                    if grade ~= nil and p.job.name ~= name then Bridge.setJob(src, name, grade) end
                    if grade ~= nil then Bridge.setDuty(src, true) end
                end
            else
                local was = old and Rest.biz[old]
                if was and p.job.name == Rest.jobName(was.id) and p.job.onduty then Bridge.setDuty(src, false) end
            end
            syncing[cid] = nil
        end)
        syncing[cid] = nil
        if not ok then print(('^1[vr-restaurant] duty sync failed: %s^0'):format(tostring(err))) end
    end,
})

-- The job menu's duty button.
Bridge.on('dutyChanged', function(src, onduty)
    src = tonumber(src)
    local who = src and Rest.info(src)
    if not who or syncing[who.cid] or cfg.enabled == false then return end
    local p = Bridge.player(src)
    local b = p and p.job and Rest.jobBusiness(p.job.name)
    if not b then return end
    if onduty then
        if Rest.duty[who.cid] == b.id then return end
        local role = Rest.role(b, who.cid)
        local refuse
        if not role then refuse = 'You do not work here'
        elseif Rest.isClosed(b) then refuse = 'This restaurant is closed, so nobody can clock in' end
        if refuse then
            syncing[who.cid] = true
            Bridge.setDuty(src, false)
            syncing[who.cid] = nil
            Rest.notify(src, refuse, 'error')
            return
        end
        syncing[who.cid] = true
        Rest.duty[who.cid] = b.id
        syncing[who.cid] = nil
    elseif Rest.duty[who.cid] == b.id then
        syncing[who.cid] = true
        Rest.duty[who.cid] = nil
        syncing[who.cid] = nil
    end
end)

-- Switching to another job while clocked in ends the shift.
Bridge.on('jobChanged', function(src, job)
    src = tonumber(src)
    local who = src and Rest.info(src)
    if not who or cfg.enabled == false then return end
    local at = Rest.duty[who.cid]
    if at and (type(job) ~= 'table' or job.name ~= Rest.jobName(at)) then
        syncing[who.cid] = true
        Rest.duty[who.cid] = nil
        syncing[who.cid] = nil
    end
    if type(job) == 'table' and isRestaurantJob(job.name) then Rest.syncSoon(2) end
end)

Bridge.on('playerLoaded', function() Rest.syncSoon(3) end)

---------------------------------------------------------------------------
-- Start up, and keep checking
---------------------------------------------------------------------------

Rest.onReady(function()
    if cfg.enabled == false then return end
    if not Bridge.canDefineJobs() then
        unsupported = true
        print('^3[vr-restaurant] This framework cannot create jobs while running, so restaurants are not added to the job menu.^0')
        return
    end
    Rest.syncJobs()
    while true do
        Wait((cfg.syncSeconds or 15) * 1000)
        local ok, err = pcall(Rest.syncJobs)
        if not ok then print(('^1[vr-restaurant] job sync failed: %s^0'):format(tostring(err))) end
    end
end)

-- The framework or the job menu restarted: send everything again.
AddEventHandler('onResourceStart', function(resource)
    if resource == 'vr-core' or resource == MULTIJOB or resource == 'vr-bridge' then
        defined, applied = {}, {}
        Rest.syncSoon(4)
    end
end)

-- Any change to who belongs where also changes jobs.
local index = Rest.index
function Rest.index(...)
    local r = index(...)
    Rest.syncSoon(1)
    return r
end

-- The office actions that change ranks, wages or who works here.
for _, name in ipairs({ 'wage', 'addrank', 'editrank', 'delrank', 'hire', 'fire', 'setrank', 'quit' }) do
    local fn = Rest.ACT and Rest.ACT[name]
    if type(fn) == 'function' then
        Rest.ACT[name] = function(...)
            local a, b, c = fn(...)
            if a then Rest.syncSoon(1) end
            return a, b, c
        end
    end
end

exports('GetJobName', function(id) return Rest.jobName(tonumber(id) or 0) end)
