Minimap = { fix = nil }

local rect
local busy = false

local function hideBars()
    local scaleform = RequestScaleformMovie('minimap')
    local tries = 0
    while not HasScaleformMovieLoaded(scaleform) and tries < 100 do Wait(10); tries = tries + 1 end
    BeginScaleformMovieMethod(scaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
end

function Minimap.apply(r)
    if r then rect = r end
    if not rect or busy then return end
    busy = true
    CreateThread(function()
        local M = Config.Minimap
        RequestStreamedTextureDict('squaremap', false)
        local tries = 0
        while not HasStreamedTextureDictLoaded('squaremap') and tries < 100 do Wait(20); tries = tries + 1 end
        AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'squaremap', 'radarmasksm')
        AddReplaceTexture('platform:/textures/graphics', 'radarmask1g', 'squaremap', 'radarmasksm')

        local resX, resY = GetActiveScreenResolution()
        local aspect, ox = resX / resY, 0.0
        if M.ultrawideFix and aspect > 16 / 9 then ox = ((16 / 9 - aspect) / 3.6) - 0.008 end

        local margin = (1.0 - GetSafeZoneSize()) / 2.0
        local f = Minimap.fix or M.fix
        local x, w, h = rect.x + ox - margin + f.dx, rect.w * f.sx, rect.h * f.sy
        local by = -(1.0 - rect.y - rect.h) + margin + f.dy
        SetMinimapClipType(0)
        SetMinimapComponentPosition('minimap', 'L', 'B', x + M.map.dx, by + M.map.dy, w * M.map.sx, h * M.map.sy)
        SetMinimapComponentPosition('minimap_mask', 'L', 'B', x, by, w, h)
        SetMinimapComponentPosition('minimap_blur', 'L', 'B', x + M.blur.dx, by + M.blur.dy, w * M.blur.sx, h * M.blur.sy)
        SetBlipAlpha(GetNorthRadarBlip(), 0)
        SetRadarBigmapEnabled(true, false)
        Wait(50)
        SetRadarBigmapEnabled(false, false)
        SetRadarZoom(M.zoom)
        hideBars()
        busy = false
    end)
end

function Minimap.show(state)
    DisplayRadar(state == true)
end

CreateThread(function()
    DisplayRadar(false)
    while true do
        SetRadarZoom(Config.Minimap.zoom)
        Wait(1000)
    end
end)

RegisterCommand('hudmap', function(_, args)
    local M = Config.Minimap
    if args[1] == 'reset' then
        Minimap.fix = nil
    else
        local cur = Minimap.fix or M.fix
        Minimap.fix = {
            dx = tonumber(args[1]) or cur.dx, dy = tonumber(args[2]) or cur.dy,
            sx = tonumber(args[3]) or cur.sx, sy = tonumber(args[4]) or cur.sy,
        }
    end
    local f = Minimap.fix or M.fix
    Minimap.apply()
    print(('[vr-hud] minimap fix = { dx = %.4f, dy = %.4f, sx = %.3f, sy = %.3f }'):format(f.dx, f.dy, f.sx, f.sy))
end, false)
