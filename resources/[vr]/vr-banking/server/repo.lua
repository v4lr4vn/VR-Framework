Repo = {}

local K = Config.Collections
local S = K.stage or {}
local T = K.tracker or {}
local staged = {}
local extraSpots = {}
local entities = {}
local sentTo = {}
local last = {}

local function now() return os.time() end
local function plateKey(p) return Loans.plateKey(p) end

local function garagesUp()
    return GetResourceState('vr-garages') == 'started'
end

local function garageRow(plate)
    if not garagesUp() then return nil end
    local ok, row = pcall(function() return exports['vr-garages']:GetVehicle(plate) end)
    return ok and type(row) == 'table' and row or nil
end

local function worldMap(wanted, all)
    local map = {}
    local function put(p, veh)
        if not p or (wanted and not wanted[p]) then return end
        if all then
            map[p] = map[p] or {}
            map[p][#map[p] + 1] = veh
        elseif not map[p] then
            map[p] = veh
        end
    end
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) then
            local a, b = Loans.platesOf(veh)
            put(a, veh)
            put(b, veh)
        end
    end
    return map
end

local function entityFor(plate)
    local e = entities[plate]
    if e and DoesEntityExist(e) and Loans.vehicleHasPlate(e, plate) then return e end
    entities[plate] = nil
    local veh = worldMap({ [plate] = true })[plate]
    if veh then entities[plate] = veh end
    return veh
end

Repo.entityFor = entityFor

local function vehicleName(model, plate)
    return model and Core.vehicleName(model) or plate
end

function Repo.isStaged(plate)
    plate = plateKey(plate)
    return plate ~= nil and staged[plate] ~= nil and staged[plate].x ~= nil
end

function Repo.isFlagged(plate)
    plate = plateKey(plate)
    if not plate or Collections.isHeld(plate) then return false end
    return Collections.collateral()[plate] ~= nil
end

function Repo.spots()
    local out = {}
    for _, s in ipairs(Config.RepoSpots or {}) do
        out[#out + 1] = { x = s.x + 0.0, y = s.y + 0.0, z = s.z + 0.0, w = (s.w or 0.0) + 0.0, config = true }
    end
    for _, s in ipairs(extraSpots) do out[#out + 1] = s end
    return out
end

local function clearAt(spot, ignore)
    local r = S.spotClearance or 3.5
    local p = vec3(spot.x, spot.y, spot.z)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and #(GetEntityCoords(veh) - p) < r then return false end
    end
    for plate, st in pairs(staged) do
        if plate ~= ignore and st.x and #(vec3(st.x, st.y, st.z) - p) < r then return false end
    end
    return true
end

local function pickSpot(ignore)
    local list = Repo.spots()
    for i = #list, 2, -1 do
        local j = math.random(1, i)
        list[i], list[j] = list[j], list[i]
    end
    for _, s in ipairs(list) do
        if clearAt(s, ignore) then return s end
    end
    return nil
end

local function record(st)
    MySQL.query([[INSERT INTO vr_bank_staged (plate, case_id, citizenid, model, x, y, z, h, staged_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE case_id = VALUES(case_id), citizenid = VALUES(citizenid), model = VALUES(model), x = VALUES(x), y = VALUES(y), z = VALUES(z), h = VALUES(h), staged_at = VALUES(staged_at)]],
        { st.plate, st.caseId, st.cid, st.model, st.x, st.y, st.z, st.h, st.at })
end

local function tellCollectors(text)
    for _, src in ipairs(Collections.collectorSources()) do Core.notify(src, text, 'inform', 'Collections') end
end

local function report(plate, how, st)
    if last[plate] == how then return end
    last[plate] = how
    if how == 'parked' and st then
        print(('[vr-banking] repo car %s parked on the street at %.1f, %.1f, %.1f'):format(plate, st.x, st.y, st.z))
    elseif how == 'out' then
        print(('[vr-banking] repo car %s is out in the city, tracker on'):format(plate))
    else
        print(('^3[vr-banking] repo car %s not parked: %s^0'):format(plate, tostring(how)))
    end
end

function Repo.stage(c, plate, model, quiet)
    local ok, how, st = Repo.tryStage(c, plate, model, quiet)
    local key = plateKey(plate)
    if key then report(key, how, st) end
    return ok, how, st
end

function Repo.tryStage(c, plate, model, quiet)
    plate = plateKey(plate)
    if not c or c.status ~= 'open' or not plate then return false, 'no_case' end
    if Collections.isHeld(plate) then return false, 'held' end
    local name = vehicleName(model, plate)
    if entityFor(plate) then
        local st = staged[plate] or { plate = plate, at = now() }
        st.caseId, st.cid, st.model = c.id, c.cid, model
        staged[plate] = st
        record(st)
        if not quiet then
            Collections.noteCase(c.id, ('Tracker on for %s (%s). It is out in the city.'):format(name, plate))
            tellCollectors(('Tracker live on %s (%s) for case #%d'):format(name, plate, c.id))
        end
        return true, 'out'
    end
    if not S.enabled then return false, 'disabled' end
    local row = garageRow(plate)
    if not row then return false, 'no_vehicle' end
    if tonumber(row.state) == 2 then
        if not quiet then Collections.noteCase(c.id, ('%s (%s) is in the police impound. It stays there until the debt is cleared.'):format(name, plate)) end
        return false, 'impounded'
    end
    local prev = staged[plate]
    local spot = prev and prev.x and clearAt(prev, plate) and { x = prev.x, y = prev.y, z = prev.z, w = prev.h } or pickSpot(plate)
    if not spot then
        if not quiet then Collections.noteCase(c.id, ('No free street spot for %s (%s). Add more with /repospot.'):format(name, plate)) end
        return false, 'no_spot'
    end
    local ok, done, netId = pcall(function() return exports['vr-garages']:ParkVehicle(plate, { x = spot.x, y = spot.y, z = spot.z, w = spot.w }) end)
    if not ok then return false, 'spawn_failed: ' .. tostring(done) end
    if not done then return false, netId or 'spawn_failed' end
    local st = { plate = plate, caseId = c.id, cid = c.cid, model = model, x = spot.x, y = spot.y, z = spot.z, h = spot.w, at = now() }
    staged[plate] = st
    record(st)
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 then entities[plate] = ent end
    if not quiet then
        Collections.noteCase(c.id, ('The bank parked %s (%s) on the street. Tracker on.'):format(name, plate))
        tellCollectors(('Tracker live on %s (%s) for case #%d. It is parked on the street.'):format(name, plate, c.id))
        local debtor = Core.sourceOf(c.cid)
        if debtor then
            Core.notify(debtor, ('The bank switched on the tracker in your %s (%s) and moved it out of your garage. Clear your debt at a bank branch before it is repossessed.'):format(name, plate), 'error')
        end
    end
    return true, 'parked', st
end

function Repo.onCaseOpened(c)
    if not c.plate then return end
    Wait(1000)
    Repo.stage(c, c.plate, c.model, false)
end

function Repo.unstage(plate)
    plate = plateKey(plate)
    local st = plate and staged[plate]
    if plate then last[plate] = nil end
    if not st then return nil end
    staged[plate] = nil
    entities[plate] = nil
    MySQL.query('DELETE FROM vr_bank_staged WHERE plate = ?', { plate })
    return st
end

function Repo.caseClosed(c)
    for plate, st in pairs(staged) do
        if st.caseId == c.id then
            Repo.unstage(plate)
            local debtor = Core.sourceOf(c.cid)
            local veh = entityFor(plate)
            if debtor and veh then
                local pos = GetEntityCoords(veh)
                TriggerClientEvent('vr-banking:client:carReleased', debtor, { plate = plate, name = vehicleName(st.model, plate), x = pos.x, y = pos.y, z = pos.z })
            end
        end
    end
end

local function dedupe(open)
    for plate, list in pairs(worldMap(open, true)) do
        if #list > 1 then
            local keep
            for _, veh in ipairs(list) do
                if GetPedInVehicleSeat(veh, -1) ~= 0 then keep = veh break end
            end
            if not keep then
                for _, veh in ipairs(list) do
                    if veh == entities[plate] then keep = veh break end
                end
            end
            keep = keep or list[1]
            local removed = 0
            for _, veh in ipairs(list) do
                if veh ~= keep and GetPedInVehicleSeat(veh, -1) == 0 then
                    DeleteEntity(veh)
                    removed = removed + 1
                end
            end
            entities[plate] = keep
            if removed > 0 then print(('[vr-banking] removed %d duplicate repo car(s) for %s'):format(removed, plate)) end
        end
    end
end

function Repo.ensure()
    for plate, st in pairs(staged) do
        local c = Collections.get(st.caseId)
        if not c or c.status ~= 'open' or Collections.isHeld(plate) then Repo.unstage(plate) end
    end
    local open = Collections.collateral()
    if next(open) then dedupe(open) end
    for plate, c in pairs(open) do
        local st = staged[plate]
        if not entityFor(plate) then
            Repo.stage(c, plate, c.model, st ~= nil and st.x ~= nil)
        elseif not st then
            Repo.stage(c, plate, c.model, false)
        end
    end
end

local function trackerList()
    local open = Collections.collateral()
    local out = {}
    if not next(open) then return out end
    local map = worldMap(open)
    for plate, c in pairs(open) do
        local veh = map[plate]
        if veh then
            entities[plate] = veh
            local pos = GetEntityCoords(veh)
            out[#out + 1] = {
                plate = plate, caseId = c.id, name = vehicleName(c.model, plate), owner = c.name,
                x = pos.x, y = pos.y, z = pos.z, claimedBy = Collections.claimedBy(c),
            }
        end
    end
    return out
end

function Repo.tick()
    if T.enabled == false then return end
    local collectors = Collections.collectors()
    local now_ = {}
    local list = #collectors > 0 and trackerList() or {}
    for _, info in ipairs(collectors) do
        now_[info.src] = true
        local mine = {}
        for _, e in ipairs(list) do
            mine[#mine + 1] = { plate = e.plate, caseId = e.caseId, name = e.name, owner = e.owner, x = e.x, y = e.y, z = e.z, other = e.claimedBy ~= nil and e.claimedBy ~= info.cid }
        end
        TriggerClientEvent('vr-banking:client:trackers', info.src, mine)
    end
    for src in pairs(sentTo) do
        if not now_[src] and GetPlayerName(src) then TriggerClientEvent('vr-banking:client:trackers', src, {}) end
    end
    sentTo = now_
end

function Repo.addSpot(pos, heading, by)
    heading = (tonumber(heading) or 0.0) + 0.0
    local id = MySQL.insert.await('INSERT INTO vr_bank_repo_spots (x, y, z, h, added_by, created) VALUES (?, ?, ?, ?, ?, ?)', { pos.x, pos.y, pos.z, heading, by, now() })
    if not id then return nil end
    extraSpots[#extraSpots + 1] = { id = id, x = pos.x, y = pos.y, z = pos.z, w = heading }
    return id
end

function Repo.removeSpotNear(pos, radius)
    local best, bestD
    for i, s in ipairs(extraSpots) do
        local d = #(vec3(s.x, s.y, s.z) - pos)
        if d <= (radius or 6.0) and (not bestD or d < bestD) then best, bestD = i, d end
    end
    if not best then return false end
    local s = table.remove(extraSpots, best)
    MySQL.query('DELETE FROM vr_bank_repo_spots WHERE id = ?', { s.id })
    return true
end

function Repo.status(plate)
    plate = plateKey(plate)
    local veh = plate and entityFor(plate)
    local st = plate and staged[plate]
    local row = plate and garageRow(plate)
    local pos = veh and GetEntityCoords(veh)
    return {
        plate = plate, onStreet = veh ~= nil, x = pos and pos.x, y = pos and pos.y, z = pos and pos.z,
        staged = st ~= nil and st.x ~= nil, garageState = row and tonumber(row.state), last = plate and last[plate],
    }
end

function Repo.list()
    local out = {}
    for _, st in pairs(staged) do out[#out + 1] = st end
    return out
end

function Repo.load()
    for _, r in ipairs(MySQL.query.await('SELECT * FROM vr_bank_staged') or {}) do
        local plate = plateKey(r.plate)
        if plate then
            staged[plate] = { plate = plate, caseId = tonumber(r.case_id), cid = r.citizenid, model = r.model, x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), h = tonumber(r.h), at = tonumber(r.staged_at) or now() }
        end
    end
    for _, r in ipairs(MySQL.query.await('SELECT * FROM vr_bank_repo_spots ORDER BY id') or {}) do
        extraSpots[#extraSpots + 1] = { id = tonumber(r.id), x = tonumber(r.x), y = tonumber(r.y), z = tonumber(r.z), w = tonumber(r.h) or 0.0 }
    end
end
