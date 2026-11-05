local cfg = Config.Jobs.treasurehunter
local H = {}

local run = 0
local detector
local tank, mask
local chestProps = {}
local lastBeep = 0

local function alive(token)
    return run == token and Cj.session and Cj.session.job == 'treasurehunter'
end

local function attach(model, bone, pos, rot)
    local hash = lib.requestModel(model)
    if not hash then return nil end
    local ped = Cj.ped()
    local c = GetEntityCoords(ped)
    local o = CreateObject(hash, c.x, c.y, c.z + 0.3, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    AttachEntityToEntity(o, ped, GetPedBoneIndex(ped, bone), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    return o
end

local function drop(o)
    if o and DoesEntityExist(o) then DeleteEntity(o) end
end

local function show(got)
    local parts = {}
    for _, g in ipairs(got or {}) do parts[#parts + 1] = ('%dx %s'):format(g.count, g.label or g.item) end
    if #parts > 0 then Cj.notify('Found ' .. table.concat(parts, ', '), 'success') end
end

local function dig(spot)
    local ok, res = Cj.timed({
        label = 'Digging',
        seconds = cfg.detector.digSeconds,
        scenario = 'WORLD_HUMAN_GARDENER_PLANT',
        face = vec3(spot.x, spot.y, spot.z),
    }, 'dig', { id = spot.id })
    if ok then show(res.got) end
end

local function open(chest)
    local ok, res = Cj.timed({
        label = 'Opening the chest',
        seconds = cfg.dive.openSeconds,
        anim = { dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1 },
        face = vec3(chest.x, chest.y, chest.z),
    }, 'open', { id = chest.id })
    if ok then show(res.got) end
end

local function spots()
    local s = Cj.session
    if not s or s.job ~= 'treasurehunter' or s.data.mode ~= 'detector' then return {} end
    local out = {}
    for _, sp in ipairs(s.data.spots) do
        if not sp.dug then
            local z = Cj.ground(sp.x, sp.y, sp.z)
            out[#out + 1] = {
                coords = vec3(sp.x, sp.y, z),
                range = cfg.detector.digRange * 0.7,
                text = '[E] Dig here',
                lift = 0.2,
                color = { 255, 214, 90 },
                onUse = function() dig(sp) end,
            }
        end
    end
    return out
end

local function syncChests(view)
    local want = {}
    for _, c in ipairs(view.data.chests or {}) do
        if not c.opened then want[c.id] = c end
    end
    for id, rec in pairs(chestProps) do
        if not want[id] then
            Cj.removeProp(rec)
            chestProps[id] = nil
        end
    end
    for id, c in pairs(want) do
        if not chestProps[id] then
            local o = Cj.prop(cfg.dive.chestModel, c, {})
            if o then
                chestProps[id] = o
                Cj.target(o, {
                    { name = 'vr-civjobs:chest:' .. id, label = 'Open the chest', icon = 'fa-solid fa-treasure-chest', distance = 3.0, onSelect = function() open(c) end },
                })
            end
        end
    end
end

local function pingLoop(token)
    CreateThread(function()
        while alive(token) do
            local d = Cj.session.data
            if d.mode == 'detector' then
                local here = Cj.here()
                local best
                for _, sp in ipairs(d.spots) do
                    if not sp.dug then
                        local dist = #(here - vec3(sp.x, sp.y, here.z))
                        if not best or dist < best then best = dist end
                    end
                end
                local range = d.ping or cfg.detector.pingRange
                if best and best <= range then
                    local power = 1.0 - best / range
                    local interval = math.floor(1400 - power * 1200)
                    if GetGameTimer() - lastBeep >= interval then
                        lastBeep = GetGameTimer()
                        PlaySoundFrontend(-1, 'Beep_Red', 'DLC_HEIST_HACKING_SNAKE_SOUNDSET', true)
                    end
                    Cj.signal = math.floor(power * 100)
                else
                    Cj.signal = 0
                end
                Wait(100)
            else
                Wait(500)
            end
        end
        Cj.signal = nil
    end)
end

local function hud(view)
    local d = view.data
    if d.mode == 'detector' then
        Cj.hudSet('Metal detector', {
            { label = 'Finds', value = tostring(d.finds) },
            { label = 'Signal', value = (Cj.signal or 0) > 0 and ('%d%%'):format(Cj.signal) or 'Nothing nearby' },
            { label = 'Shift pay', value = ('$%d'):format(view.pool) },
        })
    else
        Cj.hudSet('Wreck diving', {
            { label = 'Chests', value = tostring(d.finds) },
            { label = 'Air', value = ('%d s tank'):format(d.tank) },
            { label = 'Next', value = 'Dive the marked wrecks' },
        })
    end
end

function H.start(view)
    run = run + 1
    chestProps = {}
    local d = view.data
    if d.mode == 'detector' then
        detector = attach('w_am_digiscanner', 28422, vec3(0.0, 0.0, 0.0), vec3(0.0, 0.0, 0.0))
        Cj.setSpots('treasure', spots)
        pingLoop(run)
    else
        for i, s in ipairs(d.sites) do
            Cj.blip('site' .. i, s, { sprite = 780, colour = 5, scale = 0.8, label = s.label, radius = s.r })
        end
        tank = attach('p_s_scuba_tank_s', 24818, vec3(-0.28, -0.24, 0.0), vec3(180.0, 90.0, 0.0))
        mask = attach('p_s_scuba_mask_s', 12844, vec3(0.0, 0.0, 0.0), vec3(180.0, 90.0, 0.0))
        SetEnableScuba(Cj.ped(), true)
        SetPedMaxTimeUnderwater(Cj.ped(), d.tank + 0.0)
    end
    H.sync(view)
end

function H.sync(view)
    hud(view)
    if view.data.mode == 'dive' then syncChests(view) end
    Cj.finishZone('finish', view.data.depot, 'Finish for the day', 40.0)
end

function H.stop()
    run = run + 1
    drop(detector) drop(tank) drop(mask)
    detector, tank, mask = nil, nil, nil
    chestProps = {}
    Cj.clearSpots('treasure')
    local ped = Cj.ped()
    SetEnableScuba(ped, false)
    SetPedMaxTimeUnderwater(ped, 10.0)
end

Cj.register('treasurehunter', H)
