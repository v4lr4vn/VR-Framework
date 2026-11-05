local TOP = 5

local function citizensFor(q, records)
    local people = People.search(q, TOP)
    local cids = {}
    for _, p in ipairs(people) do cids[#cids + 1] = p.cid end
    local profiles = records and Citizens and Citizens.profiles and Citizens.profiles(cids) or {}
    local out = {}
    for _, p in ipairs(people) do
        out[#out + 1] = { cid = p.cid, name = p.name, dob = p.dob, mugshot = profiles[p.cid] and profiles[p.cid].mugshot or nil }
    end
    return out
end

local function vehiclesFor(q)
    if not Vehicles or not Vehicles.byPlate then return {} end
    local like = U.like(q:upper())
    local found = Bridge.vehicles.platesLike and Bridge.vehicles.platesLike(q:upper(), TOP) or {}
    local plates, seen = {}, {}
    for _, plate in ipairs(found) do
        local p = V.plate(plate)
        if p and not seen[p] then
            seen[p] = true
            plates[#plates + 1] = p
        end
    end
    if #plates < TOP then
        local extra = Db.query('SELECT `plate` FROM `vr_mdt_vehicles` WHERE `plate` LIKE ? ORDER BY `plate` LIMIT ?', { like, TOP }) or {}
        for _, r in ipairs(extra) do
            if #plates >= TOP then break end
            if not seen[r.plate] then
                seen[r.plate] = true
                plates[#plates + 1] = r.plate
            end
        end
    end
    local list = Vehicles.byPlate(plates)
    table.sort(list, function(a, b) return a.plate < b.plate end)
    return list
end

local function weaponsFor(q)
    if not Weapons or not Weapons.searchSerial then return {} end
    return Weapons.searchSerial(q, TOP)
end

local function reportsFor(q)
    local list = Records.optional(Reports and Reports.search, q, TOP)
    local out = {}
    for i = 1, math.min(#list, TOP) do out[i] = list[i] end
    return out
end

Api.register('search.global', { 'records.view', 'patients.view' }, function(src, ctx, data)
    local q = V.str(data.q, 48)
    if not q then return false, 'bad_request' end
    local empty = { citizens = {}, vehicles = {}, weapons = {}, reports = {} }
    if #q < 2 then return true, empty end
    local records = Core.can(ctx, 'records.view')
    local out = { citizens = citizensFor(q, records), vehicles = {}, weapons = {}, reports = {} }
    if records then
        out.vehicles = vehiclesFor(q)
        out.weapons = weaponsFor(q)
        out.reports = reportsFor(q)
    end
    return true, out
end, { rate = 200 })
