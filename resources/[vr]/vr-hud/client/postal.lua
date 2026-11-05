-- Postal data format from nearest-postal by BlockBa5her (MIT), see data/NEAREST-POSTAL-LICENSE.txt.
Postal = { nearest = nil }

local postals = {}
local route

local function notify(msg, kind)
    Bridge.notify(msg, kind or 'primary')
end

local function clearRoute(arrived)
    if not route then return end
    RemoveBlip(route.blip)
    TriggerEvent(arrived and 'nearest-postal:arrivedAtPostal' or 'nearest-postal:removedPostalBlip', route.code)
    route = nil
end

CreateThread(function()
    local raw = LoadResourceFile(GetCurrentResourceName(), 'data/postals.json')
    local ok, data = pcall(json.decode, raw or '[]')
    if ok and type(data) == 'table' then
        for i, p in ipairs(data) do postals[i] = { x = p.x + 0.0, y = p.y + 0.0, code = tostring(p.code) } end
    end
    local clearSq = Config.Postal.blip.clearDistance ^ 2
    while true do
        local c = GetEntityCoords(PlayerPedId())
        local best, bestD
        for i = 1, #postals do
            local p = postals[i]
            local dx, dy = c.x - p.x, c.y - p.y
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then best, bestD = p, d end
        end
        if best then Postal.nearest = { code = best.code, dist = math.sqrt(bestD) } end
        if route then
            local dx, dy = c.x - route.x, c.y - route.y
            if dx * dx + dy * dy < clearSq then
                notify(Config.Postal.text.arrived, 'success')
                clearRoute(true)
            end
        end
        Wait(Config.Postal.interval)
    end
end)

RegisterCommand('postal', function(_, args)
    if not args[1] then
        if route then
            clearRoute(false)
            notify(Config.Postal.text.cleared)
        end
        return
    end
    local want = args[1]:upper()
    for i = 1, #postals do
        local p = postals[i]
        if p.code:upper() == want then
            clearRoute(false)
            local blip = AddBlipForCoord(p.x, p.y, 0.0)
            local b = Config.Postal.blip
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.color)
            SetBlipRoute(blip, true)
            SetBlipRouteColour(blip, b.color)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('Postal %s'):format(p.code))
            EndTextCommandSetBlipName(blip)
            route = { blip = blip, x = p.x, y = p.y, code = p.code }
            notify(Config.Postal.text.routing:format(p.code))
            return
        end
    end
    notify(Config.Postal.text.missing, 'error')
end, false)

TriggerEvent('chat:addSuggestion', '/postal', 'Set the GPS to a postal code', { { name = 'code', help = 'Leave empty to remove the route' } })

exports('getPostal', function() return Postal.nearest and Postal.nearest.code or nil end)
exports('getDistance', function() return Postal.nearest and Postal.nearest.dist or nil end)
exports('getNearest', function() return Postal.nearest end)
