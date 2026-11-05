local cfg = Config.Jobs.windowcleaner
local H = {}

local function clean(i, w)
    local ok = Cj.timed({
        label = 'Cleaning the window',
        seconds = cfg.cleanSeconds,
        scenario = 'WORLD_HUMAN_MAID_CLEAN',
        face = vec3(w.x, w.y, w.z),
    }, 'clean', { i = i })
    if ok then PlaySoundFrontend(-1, 'PURCHASE', 'HUD_LIQUOR_STORE_SOUNDSET', true) end
end

local function spots()
    local s = Cj.session
    if not s or s.job ~= 'windowcleaner' or s.data.phase ~= 'clean' then return {} end
    local out = {}
    for i, w in ipairs(s.data.windows) do
        if not w.done then
            out[#out + 1] = {
                coords = vec3(w.x, w.y, w.z),
                range = cfg.cleanRange - 0.4,
                text = '[E] Clean window',
                color = { 90, 200, 255 },
                lift = 0.0,
                onUse = function() clean(i, w) end,
            }
        end
    end
    return out
end

local function hud(view)
    local d = view.data
    Cj.hudSet(d.label, {
        { label = 'Windows', value = ('%d / %d'):format(d.cleaned, d.total) },
        { label = 'Next', value = d.phase == 'clean' and 'Clean every window' or 'Take the van back to the depot', state = d.phase == 'clean' and nil or 'go' },
        { label = 'Shift pay', value = ('$%d'):format(view.pool) },
    }, math.floor(d.cleaned / math.max(d.total, 1) * 100))
end

function H.start(view)
    local first = view.data.windows[1]
    if first then Cj.blip('site', first, { sprite = 177, colour = 7, route = true, label = view.data.label }) end
    Cj.setSpots('windows', spots)
    H.sync(view)
end

function H.sync(view)
    hud(view)
    if view.data.phase == 'return' then
        Cj.unblip('site')
        Cj.blip('depot', view.data.depot, { sprite = 177, colour = 2, route = true, label = 'Return the van' })
        Cj.finishZone('finish', view.data.depot, 'Finish shift', 14.0)
    end
end

function H.stop()
    Cj.clearSpots('windows')
end

Cj.register('windowcleaner', H)
