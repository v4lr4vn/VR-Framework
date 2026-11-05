local cfg = Config.Jobs.garbage
local H = {}

local run = 0
local hashes = {}
local targetOn = false
local hidden = {}
local scannedAt = nil

for _, name in ipairs(cfg.bagModels) do hashes[#hashes + 1] = joaat(name) end

local hashSet = {}
for _, h in ipairs(hashes) do hashSet[h] = true end

local function alive(token)
    return run == token and Cj.session and Cj.session.job == 'garbage'
end

local function key(x, y)
    return ('%d:%d'):format(math.floor(x * 2), math.floor(y * 2))
end

local function hideBag(t, ent)
    local k = key(t.x, t.y)
    if hidden[k] then return end
    hidden[k] = t
    CreateModelHide(t.x, t.y, t.z, 0.8, t.model, true)
    if ent and DoesEntityExist(ent) then
        SetEntityVisible(ent, false, false)
        SetEntityCollision(ent, false, false)
    end
end

local function unhideAll()
    for _, t in pairs(hidden) do
        RemoveModelHide(t.x, t.y, t.z, 0.8, t.model, false)
    end
    hidden = {}
end

local function stopCentre()
    local d = Cj.session and Cj.session.data
    return d and d.stop or nil
end

local function inCircle(c)
    local s = stopCentre()
    if not s then return false end
    return #(vec2(c.x, c.y) - vec2(s.x, s.y)) <= cfg.stopRadius
end

local function pick(ent)
    if Cj.isCarrying() then return Cj.notify('Your hands are full', 'error') end
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local c = GetEntityCoords(ent)
    local model = GetEntityModel(ent)
    if hidden[key(c.x, c.y)] then return end
    local ped = Cj.ped()
    TaskTurnPedToFaceCoord(ped, c.x, c.y, c.z, 400)
    local ok, err = Cj.act('pickup', { x = c.x, y = c.y, z = c.z, model = model })
    if not ok then return Cj.fail(err) end
    hideBag({ x = c.x, y = c.y, z = c.z, model = model }, ent)
    Cj.carry(cfg.bagModel, 'bag', 'bag')
end

local function throw()
    local ped = Cj.ped()
    local ok, err = Cj.act('throw')
    if not ok then return Cj.fail(err) end
    local dict = lib.requestAnimDict('anim@heists@narcotics@trash')
    if dict then TaskPlayAnim(ped, 'anim@heists@narcotics@trash', 'throw_b', 8.0, -8.0, 1100, 48, 0, false, false, false) end
    Wait(800)
    Cj.drop()
end

local function countBags(centre)
    local n = 0
    for _, o in ipairs(GetGamePool('CObject')) do
        if hashSet[GetEntityModel(o)] then
            local c = GetEntityCoords(o)
            if #(vec2(c.x, c.y) - vec2(centre.x, centre.y)) <= cfg.stopRadius and not hidden[key(c.x, c.y)] and IsEntityVisible(o) then
                n = n + 1
            end
        end
    end
    return n
end

local function loop(token)
    CreateThread(function()
        while alive(token) do
            local d = Cj.session.data
            local sleep = 500
            if d.phase == 'collect' and d.stop then
                local here = Cj.here()
                local dist = #(vec2(here.x, here.y) - vec2(d.stop.x, d.stop.y))
                if dist < cfg.stopRadius + 80.0 then
                    sleep = 0
                    local z = d.stop.z
                    DrawMarker(1, d.stop.x, d.stop.y, z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, cfg.stopRadius * 2.0, cfg.stopRadius * 2.0, 3.0, 245, 166, 35, 45, false, false, 2, false, nil, nil, false)
                end
                local key_ = ('%d:%d'):format(d.idx, d.of)
                if not d.scanned and scannedAt ~= key_ and dist <= cfg.stopRadius - 2.0 then
                    scannedAt = key_
                    Wait(900)
                    if alive(token) and Cj.session.data.phase == 'collect' then
                        local ok, res = Cj.act('scan', { count = countBags(d.stop) })
                        if ok and res and res.need then
                            Cj.notify(('%d bags to collect here'):format(res.need), 'inform')
                        end
                    end
                end
            end
            Wait(sleep)
        end
    end)
end

local function hud(view)
    local d = view.data
    if d.phase == 'return' then
        Cj.hudSet('Garbage round', { { label = 'Round', value = 'Finished' }, { label = 'Bags', value = tostring(d.total) }, { label = 'Next', value = 'Return the truck to the depot', state = 'go' } })
        return
    end
    Cj.hudSet('Garbage round', {
        { label = 'Stop', value = ('%d / %d'):format(d.idx, d.of) },
        { label = 'Bags here', value = ('%d / %d'):format(d.thrown, d.need) },
        { label = 'Bags total', value = tostring(d.total) },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    }, math.floor(((d.idx - 1) + d.thrown / math.max(d.need, 1)) / d.of * 100))
end

local function attachTruck()
    CreateThread(function()
        local s = Cj.session
        local v = s and s.vehicles[1]
        if not v then return end
        local e = Cj.entity(v.netId)
        if not e or not Cj.session then return end
        Cj.target(e, {
            { name = 'vr-civjobs:throw', label = 'Throw bag in', icon = 'fa-solid fa-dumpster', distance = 5.0, canInteract = function() return Cj.isCarrying('bag') end, onSelect = throw },
        })
    end)
end

function H.start(view)
    run = run + 1
    scannedAt = nil
    attachTruck()
    if not targetOn then
        targetOn = true
        Bridge.target.addModel(hashes, {
            { name = 'vr-civjobs:bag', label = 'Pick up bag', icon = 'fa-solid fa-trash', distance = cfg.pickupRange, canInteract = function(ent)
                local s = Cj.session
                if not s or s.job ~= 'garbage' or s.data.phase ~= 'collect' or Cj.isCarrying() then return false end
                if s.data.collected >= s.data.need and s.data.scanned then return false end
                if not ent or ent == 0 then return false end
                local c = GetEntityCoords(ent)
                return inCircle(c) and not hidden[key(c.x, c.y)]
            end, onSelect = function(data) pick(data and data.entity) end },
        })
    end
    loop(run)
    H.sync(view)
end

function H.sync(view)
    local d = view.data
    hud(view)
    for _, t in ipairs(d.taken or {}) do hideBag(t) end
    if not d.carry and Cj.isCarrying('bag') then Cj.drop() end
    if d.phase == 'collect' and d.stop then
        Cj.blip('stop', d.stop, { sprite = 318, colour = 52, route = true, label = 'Garbage stop', radius = cfg.stopRadius })
    elseif d.phase == 'return' then
        Cj.unblip('stop')
        Cj.blip('depot', d.depot, { sprite = 318, colour = 2, route = true, label = 'Return the truck' })
        Cj.finishZone('finish', d.depot, 'Finish round', 12.0)
    end
end

function H.stop()
    run = run + 1
    scannedAt = nil
    if targetOn then
        targetOn = false
        pcall(function() Bridge.target.removeModel(hashes, 'vr-civjobs:bag') end)
    end
    unhideAll()
end

Cj.register('garbage', H)
