local U = Bridge.util

return function(opts)
    local C = {}

    local function grade(g)
        return type(g) == 'table' and (tonumber(g.level) or tonumber(g.grade)) or tonumber(g) or 0
    end

    local function normJob(job)
        job = type(job) == 'table' and job or {}
        local g = job.grade
        return {
            name = job.name or 'unemployed',
            label = job.label or job.name,
            type = U.jobType(job.name, job.type),
            grade = grade(g),
            gradeName = type(g) == 'table' and g.name or nil,
            isboss = job.isboss == true or (type(g) == 'table' and g.isboss == true),
            onduty = job.onduty == true,
        }
    end
    C.normJob = normJob

    local function normGang(gang)
        if type(gang) ~= 'table' or not gang.name or gang.name == 'none' then return nil end
        local g = gang.grade
        return {
            name = gang.name,
            label = gang.label or gang.name,
            grade = grade(g),
            gradeName = type(g) == 'table' and g.name or nil,
            isboss = gang.isboss == true or (type(g) == 'table' and g.isboss == true),
        }
    end
    C.normGang = normGang

    local function normalize(pd)
        if type(pd) ~= 'table' or not pd.citizenid then return nil end
        local ci = pd.charinfo or {}
        local money = pd.money or {}
        return {
            cid = pd.citizenid,
            citizenid = pd.citizenid,
            firstname = ci.firstname,
            lastname = ci.lastname,
            name = U.fullName(ci.firstname, ci.lastname),
            gender = U.gender(ci.gender),
            phone = ci.phone and tostring(ci.phone) or nil,
            job = normJob(pd.job),
            gang = normGang(pd.gang),
            money = { cash = tonumber(money.cash) or 0, bank = tonumber(money.bank) or 0 },
            metadata = pd.metadata or {},
            items = pd.items,
        }
    end

    function C.playerData()
        return normalize(opts.playerData())
    end

    function C.loggedIn()
        if LocalPlayer.state.isLoggedIn ~= nil then return LocalPlayer.state.isLoggedIn == true end
        local pd = opts.playerData()
        return type(pd) == 'table' and pd.citizenid ~= nil
    end

    function C.needs()
        local pd = opts.playerData() or {}
        local md = pd.metadata or {}
        return { hunger = tonumber(md.hunger), thirst = tonumber(md.thirst), stress = tonumber(md.stress) }
    end

    function C.listen(emit)
        local E = opts.events
        RegisterNetEvent(E .. ':Client:OnPlayerLoaded', function()
            emit('playerLoaded')
            local pd = C.playerData()
            if pd then emit('playerData', pd) end
        end)
        RegisterNetEvent(E .. ':Client:OnPlayerUnload', function() emit('playerUnloaded') end)
        RegisterNetEvent(E .. ':Client:OnJobUpdate', function(job) emit('jobChanged', normJob(job)) end)
        RegisterNetEvent(E .. ':Client:OnGangUpdate', function(gang) emit('gangChanged', normGang(gang)) end)
        RegisterNetEvent(E .. ':Client:SetDuty', function(onduty) emit('dutyChanged', onduty == true) end)
        RegisterNetEvent(E .. ':Client:OnMoneyChange', function(account, amount, operation, reason)
            emit('moneyChanged', account, tonumber(amount) or 0, operation, reason)
        end)
        RegisterNetEvent(E .. ':Player:SetPlayerData', function(raw)
            local pd = normalize(raw)
            if pd then emit('playerData', pd) end
        end)
    end

    function C.notify(msg, kind, ms) opts.notify(msg, kind, ms) end
    C.textUI = opts.textUI

    return C
end
