Zones = {}

local function normalisePoints(points)
    local out = {}
    for i = 1, #(points or {}) do
        local p = points[i]
        local x, y = DJ.num(p.x or p[1]), DJ.num(p.y or p[2])
        if not x or not y then return nil end
        out[#out + 1] = { x = x, y = y }
    end
    if #out < 3 then return nil end
    return out
end

function LoadZones()
    Zones = {}
    for i, z in ipairs(Config.Businesses or {}) do
        local points = normalisePoints(z.points)
        local id = type(z.id) == 'string' and z.id:match('^[%w_%-]+$')
        if points and type(z.job) == 'string' and id then
            local key = 'c' .. id
            if Zones[key] then print(('^3[vr-djbooth] Config.Businesses: id "%s" is used twice^0'):format(id)) end
            Zones[key] = {
                key = key, label = z.label or z.job, job = z.job, max = tonumber(z.max) or Config.Limits.perBusiness,
                minZ = DJ.num(z.minZ) or -500.0, maxZ = DJ.num(z.maxZ) or 2000.0, points = points,
            }
        else
            print(('^3[vr-djbooth] Config.Businesses[%d] needs an id (letters, numbers, _ or -), a job and at least 3 points^0'):format(i))
        end
    end
    for _, row in ipairs(MySQL.query.await('SELECT * FROM `vr_djbooth_zones`') or {}) do
        local ok, decoded = pcall(json.decode, row.points or '')
        local points = ok and normalisePoints(decoded)
        if points then
            local key = 'z' .. row.id
            Zones[key] = {
                key = key, dbId = row.id, label = row.label, job = row.job, max = tonumber(row.max_speakers) or Config.Limits.perBusiness,
                minZ = tonumber(row.min_z), maxZ = tonumber(row.max_z), points = points,
            }
        end
    end
end

function ZonesPayload()
    local list = {}
    for _, z in pairs(Zones) do
        list[#list + 1] = { key = z.key, label = z.label, job = z.job, max = z.max, minZ = z.minZ, maxZ = z.maxZ, points = z.points, editable = z.dbId ~= nil }
    end
    return list
end

function PushZones() TriggerClientEvent('vr-djbooth:client:zones', -1, ZonesPayload()) end

local function zoneOf(place)
    local key = type(place) == 'string' and place:match('^biz:(.+)$')
    return key and Zones[key]
end

function PlaceJob(place)
    local z = zoneOf(place)
    return z and z.job or nil
end

function PlaceLabel(place)
    local z = zoneOf(place)
    if z then return z.label end
    if type(place) == 'string' and place:match('^home:') then return 'Home' end
    return 'Unknown'
end

function PlaceMax(place)
    local z = zoneOf(place)
    if z then return z.max or Config.Limits.perBusiness end
    return Config.Limits.perHome
end

function CountInPlace(place)
    local n = 0
    for _, sp in pairs(Speakers) do
        if sp.place == place then n = n + 1 end
    end
    return n
end

local function currentProperty(Player)
    local inside = Player.metadata and Player.metadata.inside
    local pid = inside and inside.property_id
    if pid == nil then return nil end
    return tostring(pid)
end

local function housing(fn, ...)
    if GetResourceState('vr-housing') ~= 'started' then return false end
    local args = table.pack(...)
    local ok, result = pcall(function() return exports['vr-housing'][fn](exports['vr-housing'], table.unpack(args, 1, args.n)) end)
    return ok and result == true
end

function HomeAccess(src, propertyId) return housing('IsOwner', src, propertyId) end

function HomeInside(src, propertyId) return housing('IsInside', src, propertyId) end

local function onDutyFor(Player, job)
    local j = Player.job
    return j and j.name == job and j.onduty == true
end

function ResolvePlace(src, pos, bucket)
    local Player = GetPlayer(src)
    if not Player then return nil, 'not_loaded' end

    local pid = currentProperty(Player)
    if pid and HomeInside(src, pid) then
        if bucket ~= 0 and bucket ~= tonumber(pid) then return nil, 'not_here' end
        if HomeAccess(src, pid) then return 'home:' .. pid, 'Home', Config.Limits.perHome end
        return nil, 'not_your_home'
    end

    if bucket ~= 0 then return nil, 'not_here' end

    local otherJob = false
    for _, z in pairs(Zones) do
        if DJ.inZone(z, pos.x, pos.y, pos.z) then
            if z.job == Player.job.name then
                if not onDutyFor(Player, z.job) then return nil, 'off_duty' end
                return 'biz:' .. z.key, z.label, z.max or Config.Limits.perBusiness
            end
            otherJob = true
        end
    end
    return nil, otherJob and 'not_your_business' or 'not_here'
end

function CanUsePlace(src, place)
    if IsAdmin(src) then return true end
    local Player = GetPlayer(src)
    if not Player then return false, 'not_loaded' end
    local zone = zoneOf(place)
    if zone then
        if onDutyFor(Player, zone.job) then return true end
        return false, Player.job.name == zone.job and 'off_duty' or 'not_your_business'
    end
    local pid = type(place) == 'string' and place:match('^home:(.+)$')
    if pid then
        if HomeAccess(src, pid) then return true end
        return false, 'not_your_home'
    end
    return false, 'not_allowed'
end

function CanControl(src, sys)
    if not sys then return false, 'gone' end
    if sys.kind == 'vehicle' then
        return IsInVehicleSeat(src, sys), 'not_in_vehicle'
    end
    if DistanceTo(src, sys) > Config.Limits.controlDistance then return false, 'too_far' end
    if sys.kind == 'boombox' then
        if Config.Boombox.anyoneCanControl then return true end
        local Player = GetPlayer(src)
        if Player and Player.cid == sys.ownerCid then return true end
        return false, 'not_yours'
    end
    return CanUsePlace(src, sys.place)
end

function LinkCandidates(sys)
    local out = {}
    if sys.kind ~= 'speakers' then return out end
    local range = LinkRange(sys.place)
    local members = {}
    for id in pairs(sys.speakers) do members[#members + 1] = Speakers[id] end
    for id, sp in pairs(Speakers) do
        if sp.place == sys.place and sp.system ~= sys.id and (sp.bucket or 0) == (sys.bucket or 0) then
            for _, m in ipairs(members) do
                if m and DJ.dist(sp, m) <= range then
                    out[id] = sp
                    break
                end
            end
        end
    end
    return out
end
