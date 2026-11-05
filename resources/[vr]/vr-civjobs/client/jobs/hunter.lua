local cfg = Config.Jobs.hunter
local H = {}

local run = 0
local animals = {}
local gaveNative = false
local skinning = false

local function alive(token)
    return run == token and Cj.session and Cj.session.job == 'hunter'
end

local function zonesOf()
    return Cj.session and Cj.session.data.zones or {}
end

local function inside(x, y)
    for _, z in ipairs(zonesOf()) do
        if #(vec2(x, y) - vec2(z.x, z.y)) <= z.r then return true end
    end
    return false
end

local function weights()
    local list = {}
    for kind, w in pairs(cfg.spawnWeights) do list[#list + 1] = { kind = kind, w = w } end
    local total = 0
    for _, e in ipairs(list) do total = total + e.w end
    local roll = math.random() * total
    for _, e in ipairs(list) do
        roll = roll - e.w
        if roll <= 0 then return e.kind end
    end
    return list[1].kind
end

local function forget(rec)
    for i, a in ipairs(animals) do
        if a == rec then table.remove(animals, i) break end
    end
    if rec.ped and DoesEntityExist(rec.ped) then
        Cj.untarget(rec.ped)
        DeleteEntity(rec.ped)
    end
end

local function skin(rec)
    if skinning then return end
    if not rec.ped or not DoesEntityExist(rec.ped) or not IsEntityDead(rec.ped) then return end
    skinning = true
    local c = GetEntityCoords(rec.ped)
    local ok, res = Cj.timed({
        label = 'Skinning the ' .. cfg.animals[rec.kind].label:lower(),
        seconds = cfg.knifeSeconds,
        scenario = 'CODE_HUMAN_MEDIC_KNEEL',
        face = c,
        guard = function() return DoesEntityExist(rec.ped) end,
    }, 'skin', { kind = rec.kind, x = c.x, y = c.y, z = c.z })
    skinning = false
    if ok then
        local parts = {}
        for _, g in ipairs(res.got or {}) do parts[#parts + 1] = ('%dx %s'):format(g.count, Bridge.inventory.label and Bridge.inventory.label(g.item) or g.item) end
        if #parts > 0 then Cj.notify('Got ' .. table.concat(parts, ', '), 'success') end
        forget(rec)
    end
end

local function spawnOne()
    local here = Cj.here()
    for _ = 1, 8 do
        local a = math.random() * math.pi * 2
        local r = 55.0 + math.random() * 60.0
        local x, y = here.x + math.cos(a) * r, here.y + math.sin(a) * r
        if inside(x, y) then
            local ok, gz = GetGroundZFor_3dCoord(x, y, here.z + 80.0, false)
            if ok and gz then
                local kind = weights()
                local hash = lib.requestModel(cfg.animals[kind].model)
                if hash then
                    local ped = CreatePed(28, hash, x, y, gz, math.random(0, 359) + 0.0, false, false)
                    SetModelAsNoLongerNeeded(hash)
                    if ped and ped ~= 0 then
                        SetPedFleeAttributes(ped, 0, false)
                        SetPedKeepTask(ped, true)
                        TaskWanderInArea(ped, x, y, gz, 25.0, 6.0, 6.0)
                        local rec = { ped = ped, kind = kind, born = GetGameTimer() }
                        animals[#animals + 1] = rec
                        Cj.target(ped, {
                            { name = 'vr-civjobs:skin:' .. ped, label = 'Skin the animal', icon = 'fa-solid fa-knife', distance = cfg.skinRange,
                                canInteract = function(ent) return not skinning and DoesEntityExist(ent) and IsEntityDead(ent) end,
                                onSelect = function() skin(rec) end },
                        })
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function loop(token)
    CreateThread(function()
        while alive(token) do
            local here = Cj.here()
            local near = false
            for _, z in ipairs(zonesOf()) do
                if #(vec2(here.x, here.y) - vec2(z.x, z.y)) <= z.r + 80.0 then near = true break end
            end
            for i = #animals, 1, -1 do
                local rec = animals[i]
                if not rec.ped or not DoesEntityExist(rec.ped) then
                    table.remove(animals, i)
                else
                    local d = #(GetEntityCoords(rec.ped) - here)
                    local age = GetGameTimer() - rec.born
                    if d > 220.0 or (IsEntityDead(rec.ped) and age > 300000) or age > cfg.animalRespawnSeconds * 4000 and not IsEntityDead(rec.ped) and d > 120.0 then
                        forget(rec)
                    end
                end
            end
            if near and #animals < cfg.animalCount then
                spawnOne()
                Wait(1500)
            else
                Wait(near and 4000 or 8000)
            end
        end
        for i = #animals, 1, -1 do forget(animals[i]) end
    end)
end

local function hud(view)
    local d = view.data
    local lines = {}
    for _, n in ipairs(d.needs) do
        lines[#lines + 1] = { label = n.label, value = ('%d / %d'):format(n.have, n.need), state = n.have >= n.need and 'go' or nil }
    end
    lines[#lines + 1] = { label = 'Next', value = d.ready and 'Take it back to the lodge' or 'Hunt and skin the game', state = d.ready and 'go' or nil }
    Cj.hudSet(d.contract, lines)
end

function H.start(view)
    run = run + 1
    animals = {}
    skinning = false
    local d = view.data
    for i, z in ipairs(d.zones) do
        Cj.blip('zone' .. i, z, { sprite = 141, colour = 2, scale = 0.7, label = z.label, radius = z.r })
    end
    local w = d.weapon
    if w and not w.item then
        local hash = joaat(w.name)
        if not HasPedGotWeapon(Cj.ped(), hash, false) then
            GiveWeaponToPed(Cj.ped(), hash, w.ammo, false, true)
            gaveNative = true
        end
    end
    loop(run)
    H.sync(view)
end

function H.sync(view)
    hud(view)
    if view.data.ready then
        Cj.blip('lodge', view.data.depot, { sprite = 442, colour = 2, route = true, label = 'Hunting lodge' })
        Cj.finishZone('finish', view.data.depot, 'Hand in the contract', 40.0)
    end
end

function H.stop()
    run = run + 1
    if gaveNative then
        gaveNative = false
        RemoveWeaponFromPed(Cj.ped(), joaat(cfg.weapon.name))
    end
    for i = #animals, 1, -1 do forget(animals[i]) end
    animals = {}
end

Cj.register('hunter', H)
