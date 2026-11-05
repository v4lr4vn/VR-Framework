local U = Bridge.util
Bridge.include('server/db.lua')
Bridge.include('server/meta.lua')

local fwName = Bridge.framework
if fwName == 'none' then
    print(('^1[vr-bridge] %s: no supported framework found (vr-core, qbx_core, qb-core, es_extended, ox_core)^0'):format(Bridge.resource))
end
local F = fwName ~= 'none' and Bridge.include(('server/framework/%s.lua'):format(fwName)) or {}
Bridge.fw = F

local invName = Bridge.inventoryName
if invName == 'core' then invName = 'qb' end
local ok, I = pcall(Bridge.include, ('server/inventory/%s.lua'):format(invName))
if not ok then
    print(('^3[vr-bridge] inventory %s not supported, items are disabled^0'):format(tostring(Bridge.inventoryName)))
    I = Bridge.include('server/inventory/none.lua')
end
Bridge.inventory = I

Bridge.include('server/society.lua')

local gone = {}

local function emit(name, src, ...)
    if name == 'playerLoaded' then
        if not src then return end
        gone[src] = nil
    elseif name == 'playerUnloaded' then
        if not src or gone[src] then return end
        gone[src] = true
    end
    Bridge.emit(name, src, ...)
end

if F.listen then F.listen(emit) end

AddEventHandler('playerDropped', function()
    local src = tonumber(source)
    if src and not gone[src] then emit('playerUnloaded', src) end
end)

AddEventHandler('vr-bridge:societyChanged', function(name, amount, operation, reason, balance)
    Bridge.emit('societyChanged', name, amount, operation, reason, balance)
end)

local function safe(fn, ...)
    if not fn then return nil end
    local done, a, b, c = pcall(fn, ...)
    if not done then
        print(('^1[vr-bridge] %s: %s^0'):format(Bridge.resource, tostring(a)))
        return nil
    end
    return a, b, c
end

function Bridge.player(src)
    if not F.player or not src then return nil end
    return safe(F.player, src)
end

function Bridge.cid(src)
    local p = Bridge.player(src)
    return p and p.cid or nil
end

function Bridge.name(src)
    local p = Bridge.player(src)
    return p and p.name or nil
end

function Bridge.loggedIn(src)
    return Bridge.player(src) ~= nil
end

local function matchGroup(filter, name, grade)
    if not name then return false end
    local kind = type(filter)
    if kind == 'string' then return filter == name end
    if kind ~= 'table' then return false end
    if filter[1] ~= nil then
        for i = 1, #filter do
            if filter[i] == name then return true end
        end
        return false
    end
    local need = filter[name]
    if type(need) == 'table' then
        for _, g in ipairs(need) do if tonumber(g) == tonumber(grade) then return true end end
        return false
    end
    return need ~= nil and (tonumber(grade) or 0) >= (tonumber(need) or 0)
end
Bridge.matchGroup = matchGroup

function Bridge.hasGroup(src, filter)
    if F.hasGroup then
        local done, name, grade = pcall(F.hasGroup, src, filter)
        if done and name then return name, grade end
        if done then return false end
    end
    local p = Bridge.player(src)
    if not p then return false end
    if p.job and matchGroup(filter, p.job.name, p.job.grade) then return p.job.name, p.job.grade end
    if p.gang and matchGroup(filter, p.gang.name, p.gang.grade) then return p.gang.name, p.gang.grade end
    return false
end

function Bridge.hasJob(src, filter, onduty)
    local p = Bridge.player(src)
    if not p or not p.job then return false end
    if onduty and not p.job.onduty then return false end
    if matchGroup(filter, p.job.name, p.job.grade) then return p.job.name, p.job.grade end
    return false
end

function Bridge.groups(src)
    if F.groups then
        local out = safe(F.groups, src)
        if type(out) == 'table' then return out end
    end
    local out = {}
    local p = Bridge.player(src)
    if p and p.job then out[p.job.name] = p.job.grade end
    if p and p.gang then out[p.gang.name] = p.gang.grade end
    return out
end

function Bridge.playerByCid(cid)
    if not F.playerByCid or type(cid) ~= 'string' then return nil end
    return safe(F.playerByCid, cid)
end

function Bridge.source(cid)
    local p = Bridge.playerByCid(cid)
    return p and p.source or nil
end

function Bridge.license(src)
    if F.license then return safe(F.license, src) end
    return GetPlayerIdentifierByType(tostring(src), 'license')
end

function Bridge.sources() return F.sources and safe(F.sources) or {} end

function Bridge.players()
    local out = {}
    for _, src in ipairs(Bridge.sources()) do
        local p = Bridge.player(src)
        if p then out[#out + 1] = p end
    end
    return out
end

function Bridge.jobs() return F.jobs and safe(F.jobs) or {} end
function Bridge.gangs() return F.gangs and safe(F.gangs) or {} end

function Bridge.job(name)
    return Bridge.jobs()[name]
end

function Bridge.gang(name)
    return Bridge.gangs()[name]
end

function Bridge.isJob(name) return type(name) == 'string' and Bridge.jobs()[name] ~= nil end
function Bridge.isGang(name) return type(name) == 'string' and Bridge.gangs()[name] ~= nil end

function Bridge.groupLabel(name, kind)
    local list = kind == 'gang' and Bridge.gangs() or Bridge.jobs()
    local g = list[name] or (kind == nil and Bridge.gangs()[name]) or nil
    return g and g.label or name
end

function Bridge.jobsOfType(jobType)
    local out = {}
    for name, info in pairs(Bridge.jobs()) do
        if info.type == jobType then out[#out + 1] = name end
    end
    table.sort(out)
    return out
end

function Bridge.grade(job, level)
    local info = Bridge.jobs()[job] or Bridge.gangs()[job]
    return info and info.grades[tonumber(level)] or nil
end

function Bridge.grades(job)
    local info = Bridge.jobs()[job] or Bridge.gangs()[job]
    local out = {}
    for level, g in pairs(info and info.grades or {}) do
        out[#out + 1] = { level = level, name = g.name, isboss = g.isboss == true }
    end
    table.sort(out, function(a, b) return a.level < b.level end)
    return out
end

-- Create, change or remove a job while the server runs. Works on vr-core and QBCore. False elsewhere.
function Bridge.defineJob(name, def) return F.defineJob and safe(F.defineJob, name, def) == true or false end
function Bridge.removeJobDef(name) return F.removeJobDef and safe(F.removeJobDef, name) == true or false end
function Bridge.canDefineJobs() return F.defineJob ~= nil and (F.name == 'vr' or F.name == 'qb') end

function Bridge.setJob(src, job, grade) return F.setJob and safe(F.setJob, src, job, tonumber(grade) or 0) == true or false end
function Bridge.setGang(src, gang, grade) return F.setGang and safe(F.setGang, src, gang, tonumber(grade) or 0) == true or false end
function Bridge.setMeta(src, key, value) return F.setMeta and safe(F.setMeta, src, key, value) == true or false end
function Bridge.setDuty(src, onduty) return F.setDuty and safe(F.setDuty, src, onduty) == true or false end

function Bridge.getMeta(src, key)
    if F.getMeta then return safe(F.getMeta, src, key) end
    local p = Bridge.player(src)
    local md = p and p.metadata or {}
    if key == nil then return md end
    return md[key]
end

local function account(name)
    if name == 'money' then return 'cash' end
    return name or 'cash'
end

function Bridge.money(src, acc)
    acc = account(acc)
    if F.money then return U.int(safe(F.money, src, acc), 0) end
    local p = Bridge.player(src)
    return p and U.int(p.money[acc], 0) or 0
end

function Bridge.addMoney(src, acc, amount, reason)
    amount = U.int(amount, 0)
    if amount <= 0 then return amount == 0 end
    return F.addMoney and safe(F.addMoney, src, account(acc), amount, reason) == true or false
end

function Bridge.removeMoney(src, acc, amount, reason)
    amount = U.int(amount, 0)
    if amount <= 0 then return amount == 0 end
    acc = account(acc)
    if Bridge.money(src, acc) < amount then return false end
    return F.removeMoney and safe(F.removeMoney, src, acc, amount, reason) == true or false
end

function Bridge.setMoney(src, acc, amount, reason)
    amount = U.int(amount, 0)
    if amount < 0 then return false end
    return F.setMoney and safe(F.setMoney, src, account(acc), amount, reason) == true or false
end

function Bridge.pay(src, amount, reason, method)
    amount = U.int(amount, 0)
    if amount <= 0 then return true, 'free' end
    local order = method == 'cash' and { 'cash' } or method == 'bank' and { 'bank' } or { 'bank', 'cash' }
    for _, acc in ipairs(order) do
        if Bridge.money(src, acc) >= amount and Bridge.removeMoney(src, acc, amount, reason) then return true, acc end
    end
    return false
end

function Bridge.save(src) if F.save then safe(F.save, src) end end
function Bridge.isAdmin(src)
    if F.isAdmin and safe(F.isAdmin, src) == true then return true end
    return IsPlayerAceAllowed(tostring(src), 'command') == true
end
function Bridge.status(src) return F.status and safe(F.status, src) or { dead = false, cuffed = false } end

function Bridge.adminGroups()
    local list = BridgeConfig.adminGroups or {}
    return list[Bridge.framework] or list.none or { 'group.admin' }
end

function Bridge.notify(src, msg, kind, ms, title)
    if not src then return end
    if type(msg) == 'table' then
        title, kind, ms, msg = msg.title, msg.type or kind, msg.duration or ms, msg.description or msg.message
    end
    local mode = GetConvar('vr_bridge:notify', BridgeConfig.notify or 'auto')
    if (mode == 'auto' or mode == 'vr-ui') and U.started('vr-ui') then
        return TriggerClientEvent('vr-ui:notify', src, { title = title, description = msg, type = kind, duration = ms })
    end
    if (mode == 'auto' or mode == 'ox_lib') and U.started('ox_lib') then
        return TriggerClientEvent('ox_lib:notify', src, { title = title, description = msg, type = kind == 'primary' and 'inform' or kind, duration = ms })
    end
    if F.notify then return safe(F.notify, src, msg, kind, ms) end
    TriggerClientEvent('chat:addMessage', src, { args = { title or 'Notice', tostring(msg) } })
end

function Bridge.addSocietyMoney(name, amount, reason)
    return Bridge.society.add(name, amount, reason)
end

function Bridge.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Bridge.useItem(name, fn)
    if type(name) ~= 'string' or not U.callable(fn) then return false end
    if not F.useItem then return false end
    return safe(F.useItem, name, function(src, item, ...)
        local data = type(item) == 'table' and item or { name = name }
        data.name = data.name or name
        data.metadata = data.metadata or data.info or {}
        data.count = data.count or data.amount
        local done, err = pcall(fn, tonumber(src), data, ...)
        if not done then print(('^1[vr-bridge] use %s failed: %s^0'):format(name, tostring(err))) end
    end) == true
end

function Bridge.usable(name)
    if not F.usable then return nil end
    return safe(F.usable, name)
end

function Bridge.items() return I.itemDefs() end
function Bridge.item(name) return I.item(name) end

local vehicleCache, vehicleAt = nil, 0

function Bridge.vehicleList()
    local now = GetGameTimer()
    if vehicleCache and now - vehicleAt < 30000 then return vehicleCache end
    local raw = F.vehicleList and safe(F.vehicleList) or {}
    local out = {}
    for model, v in pairs(raw or {}) do
        if type(v) == 'table' then
            local key = type(model) == 'string' and model or v.model
            if key then
                out[key] = {
                    model = key,
                    name = v.name or key,
                    brand = v.brand or v.make or '',
                    price = tonumber(v.price) or 0,
                    category = v.category or v.class,
                    type = v.type or 'automobile',
                    hash = tonumber(v.hash) or GetHashKey(key),
                    shop = v.shop,
                }
            end
        end
    end
    vehicleCache, vehicleAt = out, now
    return out
end

function Bridge.vehicleData(model)
    if type(model) ~= 'string' then return nil end
    return Bridge.vehicleList()[model]
end

function Bridge.vehicleLabel(model)
    local v = Bridge.vehicleData(model)
    if v then return U.trim(('%s %s'):format(v.brand or '', v.name or model)) end
    return model and tostring(model):upper() or 'Vehicle'
end

Bridge.chars = F.chars or {}
Bridge.vehicles = F.vehicles or {}
Bridge.licences = F.licences or {}

function Bridge.chars.name(cid)
    local p = Bridge.chars.get and Bridge.chars.get(cid)
    return p and p.name or nil
end

if not Bridge.chars.bank then
    function Bridge.chars.bank(cid)
        local p = Bridge.chars.get and Bridge.chars.get(cid)
        return p and U.int(p.money and p.money.bank, 0) or 0
    end
end

if not Bridge.chars.addBank then
    function Bridge.chars.addBank(cid, amount, reason)
        local src = Bridge.source(cid)
        return src ~= nil and Bridge.addMoney(src, 'bank', amount, reason)
    end
end

function Bridge.chars.takeBank(cid, amount, reason)
    amount = U.int(amount, 0)
    if amount <= 0 then return amount == 0 end
    if not Bridge.chars.removeBank then return false end
    return Bridge.chars.removeBank(cid, amount, false, reason) == amount
end

if not Bridge.chars.license then
    function Bridge.chars.license(cid)
        local src = Bridge.source(cid)
        return src and Bridge.license(src) or nil
    end
end

function Bridge.meta(cid, key)
    local p = Bridge.chars.get and Bridge.chars.get(cid)
    return p and p.metadata and p.metadata[key] or nil
end

function Bridge.exportAs(name, fn, aliases)
    exports(name, fn)
    for _, res in ipairs(aliases or {}) do
        AddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
    end
end

Bridge.include('server/vehicle.lua')
Bridge.include('server/voice.lua')

return true
