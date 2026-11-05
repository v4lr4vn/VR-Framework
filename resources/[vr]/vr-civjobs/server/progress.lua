Progress = {}

local rows = {}
local owner = {}
local dirty = {}

local function today()
    return math.floor(os.time() / 86400)
end

local function fresh()
    return { xp = 0, done = 0, earned = 0, data = {} }
end

local function load(cid)
    if rows[cid] then return rows[cid] end
    Db.await()
    local list = MySQL.query.await('SELECT job, xp, done, earned, data FROM vr_civjobs_progress WHERE cid = ?', { cid }) or {}
    if rows[cid] then return rows[cid] end
    local mine = {}
    for i = 1, #list do
        local r = list[i]
        local ok, data = pcall(json.decode, r.data or '{}')
        mine[r.job] = {
            xp = tonumber(r.xp) or 0,
            done = tonumber(r.done) or 0,
            earned = tonumber(r.earned) or 0,
            data = (ok and type(data) == 'table') and data or {},
        }
    end
    rows[cid] = mine
    return mine
end

function Progress.bind(src, cid)
    owner[src] = cid
end

function Progress.get(cid, job)
    local mine = load(cid)
    mine[job] = mine[job] or fresh()
    return mine[job]
end

function Progress.level(cid, job)
    local row = Progress.get(cid, job)
    return (Civ.levelOf(row.xp))
end

function Progress.touch(cid, job)
    dirty[cid] = dirty[cid] or {}
    dirty[cid][job] = true
end

function Progress.addXp(cid, job, xp)
    xp = math.floor(tonumber(xp) or 0)
    local row = Progress.get(cid, job)
    local before = Civ.levelOf(row.xp)
    if xp > 0 then row.xp = row.xp + xp end
    local after = Civ.levelOf(row.xp)
    Progress.touch(cid, job)
    return before, after
end

function Progress.record(cid, job, earned, done)
    local row = Progress.get(cid, job)
    row.earned = row.earned + math.max(0, math.floor(tonumber(earned) or 0))
    row.done = row.done + (tonumber(done) or 0)
    Progress.touch(cid, job)
end

function Progress.setXp(cid, job, xp)
    local row = Progress.get(cid, job)
    row.xp = math.max(0, math.floor(tonumber(xp) or 0))
    Progress.touch(cid, job)
end

function Progress.reset(cid, job)
    local mine = load(cid)
    mine[job] = fresh()
    Progress.touch(cid, job)
end

function Progress.dailyDone(cid, job, id)
    local row = Progress.get(cid, job)
    return row.data.daily and row.data.daily[id] == today() or false
end

function Progress.markDaily(cid, job, id)
    local row = Progress.get(cid, job)
    row.data.daily = row.data.daily or {}
    row.data.daily[id] = today()
    Progress.touch(cid, job)
end

local function save(cid)
    local list = dirty[cid]
    if not list then return end
    dirty[cid] = nil
    local mine = rows[cid]
    if not mine then return end
    for job in pairs(list) do
        local r = mine[job]
        if r then
            MySQL.query.await(
                'INSERT INTO vr_civjobs_progress (cid, job, xp, done, earned, data) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE xp = VALUES(xp), done = VALUES(done), earned = VALUES(earned), data = VALUES(data)',
                { cid, job, r.xp, r.done, r.earned, json.encode(r.data or {}) }
            )
        end
    end
end

function Progress.flush(cid)
    if cid then return save(cid) end
    local ids = {}
    for id in pairs(dirty) do ids[#ids + 1] = id end
    for i = 1, #ids do save(ids[i]) end
end

function Progress.wipe(cid)
    rows[cid] = nil
    dirty[cid] = nil
    Db.await()
    MySQL.query.await('DELETE FROM vr_civjobs_progress WHERE cid = ?', { cid })
end

AddEventHandler('playerDropped', function()
    local src = source
    local cid = owner[src]
    owner[src] = nil
    if not cid then return end
    CreateThread(function()
        save(cid)
        for _, other in pairs(owner) do
            if other == cid then return end
        end
        rows[cid] = nil
    end)
end)

CreateThread(function()
    while true do
        Wait(120000)
        Progress.flush()
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Progress.flush() end
end)
