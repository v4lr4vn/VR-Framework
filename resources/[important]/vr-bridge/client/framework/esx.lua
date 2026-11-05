local U = Bridge.util
local cfg = BridgeConfig.esx or {}
local ESX
local function esx()
    if not ESX then ESX = exports['es_extended']:getSharedObject() end
    return ESX
end

local C = {}
local needs = {}

local function normJob(job)
    job = type(job) == 'table' and job or {}
    local onduty = job.onDuty
    return {
        name = job.name or 'unemployed',
        label = job.label or job.name,
        type = U.jobType(job.name),
        grade = tonumber(job.grade) or 0,
        gradeName = job.grade_label or job.grade_name,
        isboss = (cfg.bossGrades or {})[job.grade_name] == true,
        onduty = onduty ~= false,
    }
end
C.normJob = normJob

local function accounts(pd)
    local out = { cash = 0, bank = 0 }
    for _, acc in pairs(pd.accounts or {}) do
        if acc.name == 'money' then out.cash = tonumber(acc.money) or 0
        elseif acc.name == 'bank' then out.bank = tonumber(acc.money) or 0
        elseif acc.name then out[acc.name] = tonumber(acc.money) or 0 end
    end
    return out
end

function C.playerData()
    local pd = esx().GetPlayerData() or {}
    if not pd.identifier then return nil end
    local first, last = pd.firstName, pd.lastName
    if not first and type(pd.name) == 'string' then first, last = pd.name:match('^(%S+)%s*(.*)$') end
    return {
        cid = pd.identifier,
        citizenid = pd.identifier,
        firstname = first,
        lastname = last,
        name = U.fullName(first, last),
        gender = U.gender(pd.sex),
        job = normJob(pd.job),
        gang = nil,
        money = accounts(pd),
        metadata = pd.metadata or {},
    }
end

function C.loggedIn()
    if esx().IsPlayerLoaded then return esx().IsPlayerLoaded() == true end
    local pd = esx().GetPlayerData() or {}
    return pd.identifier ~= nil
end

function C.needs()
    return { hunger = needs.hunger, thirst = needs.thirst, stress = needs.stress }
end

function C.listen(emit)
    local lastDuty
    RegisterNetEvent('esx:playerLoaded', function(x)
        lastDuty = x and x.job and x.job.onDuty
        emit('playerLoaded')
        local pd = C.playerData()
        if pd then emit('playerData', pd) end
    end)
    RegisterNetEvent('esx:onPlayerLogout', function() emit('playerUnloaded') end)
    RegisterNetEvent('esx:setJob', function(job)
        emit('jobChanged', normJob(job))
        if job and job.onDuty ~= lastDuty then
            lastDuty = job.onDuty
            emit('dutyChanged', job.onDuty ~= false)
        end
    end)
    AddEventHandler('esx:setPlayerData', function(key)
        if key == 'inventory' or key == 'loadout' then return end
        local pd = C.playerData()
        if pd then emit('playerData', pd) end
    end)
    AddEventHandler('esx_status:onTick', function(list)
        local map = cfg.needs or { hunger = 'hunger', thirst = 'thirst' }
        for _, st in ipairs(list or {}) do
            for key, name in pairs(map) do
                if st.name == name then needs[key] = tonumber(st.percent) or ((tonumber(st.val) or 0) / 10000) end
            end
            if st.name == 'stress' then needs.stress = tonumber(st.percent) or ((tonumber(st.val) or 0) / 10000) end
        end
        emit('needs', C.needs())
    end)
end

function C.notify(msg, kind, ms) esx().ShowNotification(msg, kind == 'primary' and 'info' or kind, ms) end

C.textUI = {
    show = function(text) if esx().TextUI then esx().TextUI(text) end end,
    hide = function() if esx().HideUI then esx().HideUI() end end,
}

return C
