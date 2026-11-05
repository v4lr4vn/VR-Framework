local cfg = Config.Jobs.newspaper
local H = {}

local boxes = {}

local function clearBoxes()
    for _, o in pairs(boxes) do Cj.removeProp(o) end
    boxes = {}
end

local function throw(i, stop)
    local ped = Cj.ped()
    if GetVehiclePedIsIn(ped, false) == 0 then
        local dict = lib.requestAnimDict('weapons@projectile@')
        if dict then TaskPlayAnim(ped, 'weapons@projectile@', 'throw_m_fb_stand', 8.0, -8.0, 700, 48, 0, false, false, false) end
    end
    local ok, err = Cj.act('throw', { i = i })
    if not ok then return Cj.fail(err) end
    PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end

local function spots()
    local s = Cj.session
    if not s or s.job ~= 'newspaper' or s.data.phase ~= 'deliver' then return {} end
    local out = {}
    for i, st in ipairs(s.data.stops) do
        if not st.done then
            out[#out + 1] = {
                coords = vec3(st.x, st.y, st.z),
                range = cfg.throwRange * 0.5,
                text = '[E] Throw the paper',
                lift = 1.2,
                onUse = function() throw(i, st) end,
            }
        end
    end
    return out
end

local function sync(view)
    local d = view.data
    for i, st in ipairs(d.stops) do
        if st.done then
            if boxes[i] then Cj.removeProp(boxes[i]) boxes[i] = nil end
        elseif not boxes[i] then
            boxes[i] = Cj.prop(cfg.mailboxModel, st, { ground = true, placeOnGround = true })
        end
    end
    Cj.hudSet(d.route, {
        { label = 'Papers', value = ('%d / %d'):format(d.count, d.total) },
        { label = 'Next', value = d.phase == 'deliver' and 'Ride to the glowing mailboxes' or 'Take the bike back to the depot', state = d.phase == 'deliver' and nil or 'go' },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    }, math.floor(d.count / math.max(d.total, 1) * 100))
    if d.phase == 'deliver' then
        local n
        for i, st in ipairs(d.stops) do
            if not st.done then n = st break end
        end
        if n then Cj.blip('next', n, { sprite = 280, colour = 5, route = true, label = 'Next mailbox' }) end
    else
        Cj.unblip('next')
        Cj.blip('depot', d.depot, { sprite = 280, colour = 2, route = true, label = 'Return the bike' })
        Cj.finishZone('finish', d.depot, 'Finish round', cfg.vehicle.returnRadius)
    end
end

function H.start(view)
    boxes = {}
    Cj.setSpots('paper', spots)
    sync(view)
end

function H.sync(view)
    sync(view)
end

function H.stop()
    Cj.clearSpots('paper')
    boxes = {}
end

Cj.register('newspaper', H)
