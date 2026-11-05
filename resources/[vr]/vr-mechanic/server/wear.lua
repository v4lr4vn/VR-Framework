Wear = {}

local last = {}

function Wear.report(src, netId, status, distance)
    if not Config.Wear.enabled or type(status) ~= 'table' then return false end
    local veh = Cars.entity(netId)
    if not veh then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    local now = GetGameTimer()
    local l = last[veh]
    local driver = GetPedInVehicleSeat(veh, -1)
    if driver ~= ped then
        local grace = (Config.Wear.reportSeconds + 6) * 1000
        if driver ~= 0 or not l or l.src ~= src or now - l.at > grace then return false end
    end
    local elapsed = l and (now - l.at) / 1000 or Config.Wear.reportSeconds
    if elapsed < 1.0 then return false end
    last[veh] = { at = now, src = src }
    local cap = Config.Wear.maxSpeed * math.min(elapsed, Config.Wear.reportSeconds * 3) * 1.15
    distance = tonumber(distance) or 0
    if distance ~= distance then distance = 0 end
    distance = math.max(0, math.min(distance, cap))
    local cur = Cars.status(veh)
    local new = {}
    for part in pairs(Config.Parts) do
        local v = tonumber(status[part])
        if v and v == v then new[part] = math.max(0, math.min(cur[part], v)) else new[part] = cur[part] end
    end
    Cars.setStatus(veh, new, distance)
    return true
end

function Wear.forget(veh)
    last[veh] = nil
end
