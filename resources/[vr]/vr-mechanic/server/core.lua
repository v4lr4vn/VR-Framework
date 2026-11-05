Core = {}

local core = exports['vr-core']
local inv = exports['vr-inventory']
local shared

local function sharedData()
    if not shared then
        local obj = core:GetCoreObject()
        shared = obj and obj.Shared or { Jobs = {}, Gangs = {}, Vehicles = {} }
    end
    return shared
end

local byHash

AddEventHandler('VRCore:Server:UpdateObject', function() shared, byHash = nil, nil end)

local function nameOf(pd)
    local ci = type(pd) == 'table' and pd.charinfo or nil
    if type(ci) == 'table' and ci.firstname then
        return (('%s %s'):format(ci.firstname, ci.lastname or ''):gsub('%s+$', ''))
    end
    return type(pd) == 'table' and pd.name or 'Unknown'
end

function Core.player(src)
    src = tonumber(src)
    if not src then return nil end
    return core:GetPlayer(src)
end

function Core.info(src)
    local p = Core.player(src)
    local pd = p and p.PlayerData
    if not pd then return nil end
    local job = pd.job or {}
    local jg = job.grade or {}
    return {
        src = tonumber(src),
        cid = pd.citizenid,
        name = nameOf(pd),
        firstName = type(pd.charinfo) == 'table' and pd.charinfo.firstname or nameOf(pd),
        job = { name = job.name, label = job.label, grade = tonumber(jg.level) or 0, isboss = jg.isboss == true or job.isboss == true, onduty = job.onduty == true },
    }
end

function Core.isMechanic(info)
    return info ~= nil and MU.isMechanic(info.job)
end

function Core.money(src, kind)
    local p = Core.player(src)
    return p and p.Functions.GetMoney(kind) or 0
end

function Core.take(src, amount, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local p = Core.player(src)
    if not p or (p.Functions.GetMoney(kind) or 0) < amount then return false end
    return p.Functions.RemoveMoney(kind, amount, reason) == true
end

function Core.give(src, amount, kind, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    local p = Core.player(src)
    return p ~= nil and p.Functions.AddMoney(kind, amount, reason) == true
end

local fns
local function society()
    if not fns then fns = core:GetCoreObject().Functions end
    return fns
end

function Core.societyBalance(name) return society().GetSocietyMoney(name) or 0 end

function Core.addSociety(name, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return society().AddSocietyMoney(name, amount, reason) == true
end

function Core.removeSociety(name, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return true end
    return society().RemoveSocietyMoney(name, amount, reason) == true
end

function Core.vehicleLabel(model)
    local v = type(model) == 'string' and sharedData().Vehicles[model] or nil
    if v then return (('%s %s'):format(v.brand or '', v.name or model):gsub('^%s+', '')) end
    return model and tostring(model):upper() or 'Vehicle'
end

function Core.vehicleLabelByHash(hash)
    if not byHash then
        byHash = {}
        for model, v in pairs(sharedData().Vehicles or {}) do
            local h = tonumber(v.hash) or joaat(model)
            byHash[h] = Core.vehicleLabel(model)
            byHash[h & 0xFFFFFFFF] = byHash[h]
        end
    end
    hash = tonumber(hash)
    return hash and (byHash[hash] or byHash[hash & 0xFFFFFFFF]) or nil
end

function Core.notify(src, text, kind, title)
    if not src then return end
    TriggerClientEvent('vr-ui:notify', src, { title = title or 'Mechanic', description = text, type = kind or 'inform' })
end

function Core.coords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function Core.count(src, item)
    local ok, n = pcall(function() return inv:Search(src, 'count', item) end)
    return ok and tonumber(n) or 0
end

function Core.removeItem(src, item, count, metadata)
    local slot
    if metadata then
        local ok, list = pcall(function() return inv:Search(src, 'slots', item, metadata) end)
        local found = ok and type(list) == 'table' and list[1] or nil
        if not found then return false end
        slot = found.slot
    end
    local ok, done = pcall(function() return inv:RemoveItem(src, item, count or 1, nil, slot) end)
    return ok and done == true
end

function Core.canCarry(src, item, count)
    local ok, can = pcall(function() return inv:CanCarryItem(src, item, count or 1) end)
    return ok and can == true
end

function Core.addItem(src, item, count, metadata)
    if not Core.canCarry(src, item, count) then return false end
    local ok2, done = pcall(function() return inv:AddItem(src, item, count or 1, metadata) end)
    return ok2 and done == true
end

function Core.srcByCid(cid)
    if not cid then return nil end
    local ok, p = pcall(function() return core:GetPlayerByCitizenId(cid) end)
    return ok and p and p.PlayerData and tonumber(p.PlayerData.source) or nil
end
