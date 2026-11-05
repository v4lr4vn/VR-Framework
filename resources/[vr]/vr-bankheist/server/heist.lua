Heist = { run = {}, ended = {}, drills = {}, tasks = {} }

local function fail(code) return { ok = false, error = code } end

local function freshSlot(el)
    return { done = false, left = (el.type == 'cash' or el.type == 'gold') and math.floor(el.grabs) or nil }
end

local function elementState(bank)
    local out = {}
    for _, el in ipairs(bank.elements) do out[el.id] = freshSlot(el) end
    return setmetatable(out, { __index = function(t, id)
        local el = BH.byId(bank, id)
        if not el then return nil end
        local slot = freshSlot(el)
        rawset(t, id, slot)
        return slot
    end })
end

local function cooldownLeft(bank)
    local ended = Heist.ended[bank.name]
    if not ended then return 0 end
    local left = ended + bank.cooldownMinutes * 60 - os.time()
    return left > 0 and left or 0
end

function Heist.status(bank)
    local run = Heist.run[bank.id]
    local out = { id = bank.id, state = 'idle', cd = 0, el = {} }
    if run then
        out.state = 'active'
        out.left = math.max(0, run.endsAt - os.time())
        for id, st in pairs(run.el) do
            out.el[tostring(id)] = { d = st.done, l = st.left }
        end
    else
        local cd = cooldownLeft(bank)
        if cd > 0 then
            out.state = 'cooldown'
            out.cd = cd
        end
    end
    return out
end

function Heist.push(bank, to)
    TriggerClientEvent('vr-bankheist:client:status', to or -1, bank.id, Heist.status(bank))
end

function Heist.pushAll(to)
    for _, bank in ipairs(Banks.all()) do Heist.push(bank, to) end
end

local RATIO = { forward = 1.0, reverse = -1.0 }

local function setDoors(el, locked)
    local ids = {}
    for _, name in ipairs(el.doors or {}) do
        local id = Core.doorId(name)
        if id then ids[#ids + 1] = id end
    end
    local ratio = RATIO[el.swing or 'forward']
    if locked then
        if ratio and #ids > 0 then TriggerClientEvent('vr-bankheist:client:swing', -1, ids, 0.0) end
        for _, name in ipairs(el.doors or {}) do Core.setDoor(name, true) end
    else
        for _, name in ipairs(el.doors or {}) do Core.setDoor(name, false) end
        if ratio and #ids > 0 then TriggerClientEvent('vr-bankheist:client:swing', -1, ids, ratio) end
    end
end

Heist.setDoors = setDoors

local function lockAll(bank)
    for _, el in ipairs(bank.elements) do
        if el.type == 'door' then setDoors(el, true) end
    end
end

Heist.lockAll = lockAll

function Heist.canStart(bank)
    if not bank.enabled then return false, 'disabled' end
    if cooldownLeft(bank) > 0 then return false, 'cooldown' end
    if bank.minPolice > 0 and Core.police() < bank.minPolice then return false, 'police' end
    return true
end

function Heist.alert(bank, run, src, why)
    if run.alerted or run.silenced then return false end
    run.alerted = true
    local title = ('%s in progress'):format(BH.kinds[bank.kind or 'bank'] or BH.kinds.bank)
    Core.alert(src or run.by, title, ('%s: %s'):format(bank.label, why or 'the alarm was triggered'), bank.center)
    if bank.blip then
        local lookup = {}
        for _, j in ipairs(Config.Police.jobs) do lookup[j] = true end
        for _, target in ipairs(Bridge.sources()) do
            local p = Bridge.player(target)
            if p and p.job and lookup[p.job.name] and (not Config.Police.onDutyOnly or p.job.onduty) then
                TriggerClientEvent('vr-bankheist:client:policeBlip', tonumber(target), bank.id, bank.center, bank.radius, 240)
            end
        end
    end
    TriggerEvent('vr-bankheist:alerted', bank.name)
    return true
end

local function openDoor(bank, run, el, force)
    local st = run.el[el.id]
    if not st then
        st = { done = false }
        run.el[el.id] = st
    end
    if st.done and not force then return end
    st.done = true
    local stamp = GetGameTimer()
    st.stamp = stamp
    setDoors(el, false)
    if (el.openSeconds or 0) > 0 then
        SetTimeout(el.openSeconds * 1000, function()
            if Heist.run[bank.id] ~= run or st.stamp ~= stamp then return end
            setDoors(el, true)
        end)
    end
end

function Heist.diagnose(bank)
    local lines = {}
    local run = Heist.run[bank.id]
    lines[#lines + 1] = ('%s: %s'):format(bank.name, run and 'heist running' or 'no heist running')
    local doorlock = Core.doors() ~= nil
    lines[#lines + 1] = ('vr-doorlock: %s'):format(doorlock and 'started' or 'NOT started')
    local count = 0
    for _, el in ipairs(bank.elements) do
        if el.type == 'door' then
            count = count + 1
            local st = run and run.el[el.id]
            lines[#lines + 1] = ('door step #%d: needs %s, opens %s, %d door(s), step %s'):format(el.id, el.needs and ('#' .. el.needs) or 'nothing', el.swing or 'forward', #(el.doors or {}), st and (st.done and 'done' or 'waiting') or 'idle')
            for _, name in ipairs(el.doors or {}) do
                local id = Core.doorId(name)
                local api = Core.doors()
                local door = api and id and api:getDoor(id)
                lines[#lines + 1] = ('  %s: %s'):format(name, id and ('doorlock id %d, %s'):format(id, door and (door.state == 1 and 'LOCKED' or 'unlocked') or '?') or 'NOT FOUND in vr-doorlock')
            end
        elseif el.type == 'hack' then
            local st = run and run.el[el.id]
            lines[#lines + 1] = ('hack #%d: needs %s, goal %s, %s'):format(el.id, el.needs and ('#' .. el.needs) or 'nothing', el.goal or 'vault', st and (st.done and 'done' or 'waiting') or 'idle')
        end
    end
    if count == 0 then lines[#lines + 1] = 'this bank has NO vault door step' end
    return lines
end

function Heist.finish(bank, reason)
    local run = Heist.run[bank.id]
    if not run then return false end
    Heist.run[bank.id] = nil
    Heist.ended[bank.name] = os.time()
    MySQL.query('INSERT INTO vr_bankheist_state (bank, ended, times) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE ended = VALUES(ended), times = times + 1', { bank.name, Heist.ended[bank.name] })
    Heist.push(bank)
    local cd = cooldownLeft(bank)
    if cd > 0 then
        SetTimeout(cd * 1000 + 500, function() Heist.push(bank) end)
    end
    SetTimeout(Config.RelockSeconds * 1000, function()
        if not Heist.run[bank.id] then lockAll(bank) end
    end)
    TriggerEvent('vr-bankheist:ended', bank.name, reason)
    return true
end

function Heist.reset(bank)
    Heist.run[bank.id] = nil
    Heist.ended[bank.name] = nil
    MySQL.query('DELETE FROM vr_bankheist_state WHERE bank = ?', { bank.name })
    lockAll(bank)
    Heist.push(bank)
end

local function lootGone(bank, run)
    local any = false
    for _, el in ipairs(bank.elements) do
        local st = run.el[el.id]
        if el.type == 'drill' or el.type == 'till' or el.type == 'case' then
            any = true
            if not st.done then return false end
        elseif el.type == 'cash' or el.type == 'gold' then
            any = true
            if (st.left or 0) > 0 then return false end
        end
    end
    return any
end

function Heist.begin(bank, src)
    local run = Heist.run[bank.id]
    if run then return run end
    local now = os.time()
    run = { state = 'active', startedAt = now, endsAt = now + bank.maxMinutes * 60, el = elementState(bank), silenced = false, alerted = false, by = src }
    Heist.run[bank.id] = run
    run.extra = 0
    local function arm(seconds)
        SetTimeout(seconds * 1000, function()
            if Heist.run[bank.id] ~= run then return end
            if run.extra > 0 then
                local more = run.extra
                run.extra = 0
                return arm(more)
            end
            Heist.alert(bank, run, src, 'the alarm was triggered')
        end)
    end
    if bank.alertSeconds <= 0 then
        Heist.alert(bank, run, src, 'the alarm was triggered')
    else
        arm(bank.alertSeconds)
    end
    SetTimeout(bank.maxMinutes * 60 * 1000, function()
        if Heist.run[bank.id] == run then Heist.finish(bank, 'timeout') end
    end)
    for _, el in ipairs(bank.elements) do
        if el.type == 'door' and not el.needs then openDoor(bank, run, el) end
    end
    Heist.push(bank)
    TriggerEvent('vr-bankheist:started', bank.name, src)
    return run
end

function Heist.complete(bank, run, el, src)
    local st = run.el[el.id]
    if el.type == 'hack' or el.type == 'drill' or el.type == 'till' or el.type == 'case' then
        st.done = true
    elseif el.type == 'cash' or el.type == 'gold' then
        st.done = (st.left or 0) <= 0
    end
    if el.type == 'hack' and el.goal == 'alarm' then
        if run.alerted then
            Core.notify(src, 'The alarm had already gone off', 'error')
        else
            run.silenced = true
            Core.notify(src, 'Alarm silenced. Police will not be told', 'success')
        end
    end
    for _, d in ipairs(bank.elements) do
        if d.type == 'door' and d.needs == el.id then openDoor(bank, run, d, true) end
    end
    Heist.push(bank)
    if lootGone(bank, run) then Heist.finish(bank, 'looted') end
end

function Heist.access(src, bankId, elId, kinds)
    local info = Core.info(src)
    if not info then return nil, 'no_player' end
    local bank = Banks.get(bankId)
    if not bank then return nil, 'bad_request' end
    local el = BH.byId(bank, math.floor(tonumber(elId) or -1))
    if not el or not kinds[el.type] then return nil, 'bad_request' end
    if not Core.near(src, el, (el.r or 2.0) + Config.Interact.extraRange) then return nil, 'too_far' end
    local run = Heist.run[bank.id]
    if not run then
        local ok, err = Heist.canStart(bank)
        if not ok then return nil, err end
    end
    if el.needs and (not run or not run.el[el.needs] or not run.el[el.needs].done) then return nil, 'locked' end
    return bank, el, run
end

local function lootRoll(src, el)
    local given = {}
    local cash = Core.between(el.cashMin, el.cashMax)
    if cash > 0 then
        local ok, err = Core.payout(src, cash)
        if not ok then return false, err or 'full' end
        given.cash = cash
    end
    if el.item and el.item ~= '' and math.random(100) <= (el.itemChance or 0) then
        local n = Core.between(el.itemMin, el.itemMax)
        if Core.give(src, el.item, n) then given.item = { name = el.item, count = n } end
    end
    return true, given
end

lib.callback.register('vr-bankheist:grab', function(src, bankId, elId)
    if Core.throttle(src, 'grab', Config.Grab.minGapMs) then return fail('slow_down') end
    local bank, el, run = Heist.access(src, bankId, elId, { cash = true, gold = true })
    if not bank then return fail(el) end
    local left = run and run.el[el.id].left or el.grabs
    if (left or 0) <= 0 then return fail('empty') end
    local amount
    if el.type == 'cash' then
        amount = Core.between(el.cashMin, el.cashMax)
        local ok, err = Core.payout(src, amount)
        if not ok then return fail(err or 'full') end
    else
        amount = Core.between(el.barsMin, el.barsMax)
        local ok, err = Core.give(src, Config.Items.gold, amount)
        if not ok then return fail(err or 'full') end
    end
    run = Heist.begin(bank, src)
    local st = run.el[el.id]
    st.left = math.max(0, (st.left or 0) - 1)
    Heist.complete(bank, run, el, src)
    return { ok = true, data = { amount = amount, left = st.left, kind = el.type } }
end)

local function drillSession(src, bankId, elId)
    local s = Heist.drills[src]
    if not s or s.bank ~= bankId or s.el ~= elId then return nil end
    if GetGameTimer() - s.at > 15 * 60 * 1000 then
        Heist.drills[src] = nil
        return nil
    end
    return s
end

lib.callback.register('vr-bankheist:drill:begin', function(src, bankId, elId)
    if Core.throttle(src, 'drillbegin', 800) then return fail('slow_down') end
    local bank, el, run = Heist.access(src, bankId, elId, { drill = true })
    if not bank then return fail(el) end
    if run and run.el[el.id].done then return fail('empty') end
    if Core.count(src, Config.Items.drill) < 1 then return fail('need_drill') end
    Heist.drills[src] = { bank = bank.id, el = el.id, at = GetGameTimer(), seconds = el.seconds }
    Heist.begin(bank, src)
    return { ok = true, data = { seconds = el.seconds, difficulty = el.difficulty } }
end)

lib.callback.register('vr-bankheist:drill:jam', function(src, bankId, elId)
    if Core.throttle(src, 'drilljam', 600) then return fail('slow_down') end
    local s = drillSession(src, bankId, math.floor(tonumber(elId) or -1))
    if not s then return fail('bad_request') end
    local broken = false
    if math.random(100) <= Config.Drill.breakChanceOnJam and Core.take(src, Config.Items.drill, 1) then
        broken = true
        Heist.drills[src] = nil
    end
    return { ok = true, data = { broken = broken } }
end)

lib.callback.register('vr-bankheist:drill:cancel', function(src, bankId, elId)
    local s = drillSession(src, bankId, math.floor(tonumber(elId) or -1))
    if s then Heist.drills[src] = nil end
    return { ok = true }
end)

lib.callback.register('vr-bankheist:drill:finish', function(src, bankId, elId)
    if Core.throttle(src, 'drillfinish', 800) then return fail('slow_down') end
    elId = math.floor(tonumber(elId) or -1)
    local s = drillSession(src, bankId, elId)
    if not s then return fail('bad_request') end
    local bank, el, run = Heist.access(src, bankId, elId, { drill = true })
    if not bank then return fail(el) end
    if not run then return fail('over') end
    local st = run.el[el.id]
    if st.done then return fail('empty') end
    if GetGameTimer() - s.at < s.seconds * 1000 * Config.Drill.minFraction then return fail('too_fast') end
    if Core.count(src, Config.Items.drill) < 1 then return fail('need_drill') end
    local ok, given = lootRoll(src, el)
    if not ok then return fail(given) end
    Heist.drills[src] = nil
    Heist.complete(bank, run, el, src)
    return { ok = true, data = given }
end)

AddEventHandler('playerDropped', function()
    Heist.drills[source] = nil
end)

local function timedSession(src, kind, bankId, elId)
    local s = Heist.tasks[src]
    if not s or s.kind ~= kind or s.bank ~= bankId or s.el ~= elId then return nil end
    if GetGameTimer() - s.at > 5 * 60 * 1000 then
        Heist.tasks[src] = nil
        return nil
    end
    return s
end

local function caseLoot(src, el)
    local given = {}
    local item = el.item
    if item and item ~= '' then
        local n = Core.between(el.itemMin, el.itemMax)
        local ok, err = Core.give(src, item, n)
        if not ok then return false, err or 'full' end
        given.item = { name = item, count = n }
    end
    local rare = el.rareItem
    if rare and rare ~= '' and math.random(100) <= (el.rareChance or 0) then
        if Core.give(src, rare, 1) then given.rare = { name = rare, count = 1 } end
    end
    local cash = Core.between(el.cashMin, el.cashMax)
    if cash > 0 and Core.payout(src, cash) then given.cash = cash end
    return true, given
end

lib.callback.register('vr-bankheist:till:begin', function(src, bankId, elId)
    if Core.throttle(src, 'tillbegin', 800) then return fail('slow_down') end
    elId = math.floor(tonumber(elId) or -1)
    local bank, el, run = Heist.access(src, bankId, elId, { till = true })
    if not bank then return fail(el) end
    if run and run.el[el.id].done then return fail('empty') end
    if el.tool and el.tool ~= '' and Core.count(src, el.tool) < 1 then return fail('need_tool') end
    Heist.tasks[src] = { kind = 'till', bank = bank.id, el = el.id, at = GetGameTimer(), seconds = el.seconds }
    Heist.begin(bank, src)
    return { ok = true, data = { seconds = el.seconds } }
end)

lib.callback.register('vr-bankheist:till:finish', function(src, bankId, elId)
    if Core.throttle(src, 'tillfinish', 800) then return fail('slow_down') end
    elId = math.floor(tonumber(elId) or -1)
    local s = timedSession(src, 'till', bankId, elId)
    if not s then return fail('bad_request') end
    local bank, el, run = Heist.access(src, bankId, elId, { till = true })
    if not bank then return fail(el) end
    if not run then return fail('over') end
    local st = run.el[el.id]
    if st.done then return fail('empty') end
    if GetGameTimer() - s.at < s.seconds * 1000 * Config.Till.minFraction then return fail('too_fast') end
    if el.tool and el.tool ~= '' and Core.count(src, el.tool) < 1 then return fail('need_tool') end
    local ok, given = lootRoll(src, el)
    if not ok then return fail(given) end
    Heist.tasks[src] = nil
    Heist.complete(bank, run, el, src)
    return { ok = true, data = given }
end)

lib.callback.register('vr-bankheist:till:cancel', function(src, bankId, elId)
    local s = timedSession(src, 'till', bankId, math.floor(tonumber(elId) or -1))
    if s then Heist.tasks[src] = nil end
    return { ok = true }
end)

lib.callback.register('vr-bankheist:case:begin', function(src, bankId, elId)
    if Core.throttle(src, 'casebegin', 800) then return fail('slow_down') end
    elId = math.floor(tonumber(elId) or -1)
    local bank, el, run = Heist.access(src, bankId, elId, { case = true })
    if not bank then return fail(el) end
    if run and run.el[el.id].done then return fail('empty') end
    Heist.tasks[src] = { kind = 'case', bank = bank.id, el = el.id, at = GetGameTimer(), seconds = Config.Case.minSeconds }
    Heist.begin(bank, src)
    return { ok = true, data = { anim = el.anim or 'necklace' } }
end)

lib.callback.register('vr-bankheist:case:finish', function(src, bankId, elId)
    if Core.throttle(src, 'casefinish', 800) then return fail('slow_down') end
    elId = math.floor(tonumber(elId) or -1)
    local s = timedSession(src, 'case', bankId, elId)
    if not s then return fail('bad_request') end
    local bank, el, run = Heist.access(src, bankId, elId, { case = true })
    if not bank then return fail(el) end
    if not run then return fail('over') end
    local st = run.el[el.id]
    if st.done then return fail('empty') end
    if GetGameTimer() - s.at < s.seconds * 1000 then return fail('too_fast') end
    local ok, given = caseLoot(src, el)
    if not ok then return fail(given) end
    Heist.tasks[src] = nil
    Heist.complete(bank, run, el, src)
    return { ok = true, data = given }
end)

lib.callback.register('vr-bankheist:case:cancel', function(src, bankId, elId)
    local s = timedSession(src, 'case', bankId, math.floor(tonumber(elId) or -1))
    if s then Heist.tasks[src] = nil end
    return { ok = true }
end)

AddEventHandler('playerDropped', function()
    Heist.tasks[source] = nil
end)

lib.callback.register('vr-bankheist:status', function()
    local out = {}
    for _, bank in ipairs(Banks.all()) do out[#out + 1] = Heist.status(bank) end
    return out
end)

Bridge.on('playerLoaded', function(src)
    if Banks.loaded then Heist.pushAll(src) end
end)

Db.onReady(function()
    if Config.ClearCooldownsOnStart then
        MySQL.query.await('DELETE FROM vr_bankheist_state')
    end
    local rows = MySQL.query.await('SELECT bank, ended FROM vr_bankheist_state') or {}
    for _, r in ipairs(rows) do Heist.ended[r.bank] = tonumber(r.ended) or 0 end
    local waited = 0
    while not Banks.loaded and waited < 30000 do
        Wait(200)
        waited = waited + 200
    end
    local deadline = GetGameTimer() + 25000
    while Core.doors() == nil and GetGameTimer() < deadline do Wait(500) end
    Wait(2000)
    for _, bank in ipairs(Banks.all()) do
        lockAll(bank)
        local cd = cooldownLeft(bank)
        if cd > 0 then SetTimeout(cd * 1000 + 500, function() Heist.push(bank) end) end
    end
    Heist.pushAll()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, bank in ipairs(Banks.all()) do lockAll(bank) end
end)

exports('GetBanks', function() return Banks.publicList() end)
exports('IsActive', function(name)
    local bank = Banks.find(name)
    return bank ~= nil and Heist.run[bank.id] ~= nil
end)
exports('Reset', function(name)
    local bank = Banks.find(name)
    if not bank then return false end
    Heist.reset(bank)
    return true
end)
