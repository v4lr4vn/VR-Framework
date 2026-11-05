local U = Bridge.util
local OxLib
local function Ox()
    if OxLib then return OxLib end
    if type(_G.Ox) == 'table' then OxLib = _G.Ox return OxLib end
    local code = LoadResourceFile('ox_core', 'lib/init.lua')
    if code then
        local ok, res = pcall(load(code, '@@ox_core/lib/init.lua'))
        if ok and type(res) == 'table' then OxLib = res end
    end
    OxLib = OxLib or _G.Ox
    return OxLib
end

local C = {}
local statuses = {}

local function field(p, key)
    if p[key] ~= nil then return p[key] end
    if type(p.get) == 'function' then
        local ok, v = pcall(p.get, key)
        if ok then return v end
    end
end

local function pickJob(p)
    local groups = type(p.getGroups) == 'function' and p.getGroups() or {}
    local active = field(p, 'activeGroup')
    local best
    for name, grade in pairs(groups) do
        local info = GlobalState['group.' .. name]
        local job
        if type(info) == 'table' then job = info.type ~= 'gang' else job = U.jobType(name) ~= 'none' end
        if job and (not best or name == active) then best = { name = name, grade = math.max(0, (tonumber(grade) or 1) - 1), info = info } end
    end
    if not best and active and groups[active] then best = { name = active, grade = math.max(0, (tonumber(groups[active]) or 1) - 1) } end
    if not best then return { name = 'unemployed', label = 'Unemployed', type = 'none', grade = 0, onduty = false } end
    local info = type(best.info) == 'table' and best.info or {}
    return { name = best.name, label = info.label or best.name, type = U.jobType(best.name, info.type ~= 'job' and info.type or nil), grade = best.grade, onduty = active == nil or active == best.name }
end

local function player()
    local lib = Ox()
    local p = lib and lib.GetPlayer and lib.GetPlayer()
    if not p or not p.stateId then return nil end
    return p
end

function C.playerData()
    local p = player()
    if not p then return nil end
    local first, last = field(p, 'firstName'), field(p, 'lastName')
    return {
        cid = p.stateId,
        citizenid = p.stateId,
        firstname = first,
        lastname = last,
        name = U.fullName(first, last),
        gender = U.gender(field(p, 'gender')),
        job = pickJob(p),
        gang = nil,
        money = { cash = 0, bank = 0 },
        metadata = {},
    }
end

function C.loggedIn() return player() ~= nil end

function C.needs()
    local function full(v) return v and math.max(0, math.min(100, 100 - v)) or nil end
    return { hunger = full(statuses.hunger), thirst = full(statuses.thirst), stress = statuses.stress }
end

function C.listen(emit)
    local function refresh()
        local pd = C.playerData()
        if pd then emit('playerData', pd) end
        return pd
    end
    AddEventHandler('ox:playerLoaded', function() emit('playerLoaded') refresh() end)
    AddEventHandler('ox:playerLogout', function() emit('playerUnloaded') end)
    AddEventHandler('ox:setGroup', function()
        local pd = refresh()
        if pd then emit('jobChanged', pd.job) end
    end)
    AddEventHandler('ox:setActiveGroup', function()
        local pd = refresh()
        if pd then emit('dutyChanged', pd.job.onduty) end
    end)
    AddEventHandler('ox:statusTick', function(list)
        for name, value in pairs(type(list) == 'table' and list or {}) do statuses[name] = tonumber(value) end
        emit('needs', C.needs())
    end)
end

function C.notify(msg, kind, ms)
    TriggerEvent('ox_lib:notify', { description = msg, type = kind == 'primary' and 'inform' or kind, duration = ms })
end

return C
