Docs = {}

local cooldown = {}

local function find(item)
    for _, d in ipairs(Config.Documents.items) do
        if d.item == item then return d end
    end
    return nil
end

local function left(cid, item)
    local t = cooldown[cid .. ':' .. item]
    if not t then return 0 end
    local n = t - os.time()
    return n > 0 and n or 0
end

function Docs.list(info)
    local cfg = Config.Documents
    local out = {}
    if not cfg.enabled then return out end
    local held = Core.licences(info.cid)
    for _, d in ipairs(cfg.items) do
        local carrying = Core.countItem(info.src, d.item) > 0
        local entitled = d.licence == nil or held[d.licence] == true
        out[#out + 1] = {
            item = d.item,
            label = d.label,
            description = d.description,
            icon = d.icon,
            fee = d.fee,
            carrying = carrying,
            entitled = entitled,
            wait = left(info.cid, d.item),
            blocked = cfg.refuseIfCarrying and carrying or false,
        }
    end
    return out
end

local function issue(info, item)
    if GetResourceState('vr-idcard') == 'started' then
        local ok, res = pcall(function() return exports['vr-idcard']:CreateMetaLicense(info.src, item) end)
        if ok and res ~= false then return true end
    end
    local meta = {
        holder = info.name,
        citizenid = info.cid,
        issued = os.date('%Y-%m-%d'),
        description = ('%s | %s'):format(info.name, info.cid),
    }
    return Bridge.inventory.add(info.src, item, 1, meta) == true
end

function Docs.replace(info, item)
    local cfg = Config.Documents
    if not cfg.enabled then return false, 'disabled' end
    local d = type(item) == 'string' and find(item) or nil
    if not d then return false, 'bad_request' end
    if d.licence and Core.licences(info.cid)[d.licence] ~= true then return false, 'not_entitled' end
    if cfg.refuseIfCarrying and Core.countItem(info.src, d.item) > 0 then return false, 'carrying' end
    if left(info.cid, d.item) > 0 then return false, 'cooldown', { wait = left(info.cid, d.item) } end
    local okCarry, can = pcall(Bridge.inventory.canCarry, info.src, d.item, 1)
    if okCarry and can == false then return false, 'no_room' end
    if not Core.charge(info.src, d.fee, ('City Hall: replacement %s'):format(d.label)) then return false, 'no_money' end
    if not issue(info, d.item) then
        Core.refund(info.src, d.fee, ('City Hall: refund %s'):format(d.label))
        return false, 'failed'
    end
    cooldown[info.cid .. ':' .. d.item] = os.time() + (tonumber(cfg.cooldownMinutes) or 0) * 60
    return true, nil, { item = d.item, label = d.label, fee = d.fee }
end
