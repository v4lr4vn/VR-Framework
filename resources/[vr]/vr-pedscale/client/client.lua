-- Based on um-ped-scale by uyuyorum

local targets = {}
local preview
local lastSet = {}

local sqrt = math.sqrt

local function scaled(v, s)
    local m = sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if m == 0 then return v end
    s = s / m
    return vector3(v.x * s, v.y * s, v.z * s)
end

local function scaleFor(ped, cm)
    local base = Config.ModelHeights[GetEntityModel(ped)] or Config.OtherModelHeight
    return cm / base
end

local function apply(ped, cm)
    if not DoesEntityExist(ped) then return end
    if IsPedInAnyVehicle(ped, false) then lastSet[ped] = nil return end

    local scale = scaleFor(ped, cm)
    if scale > 0.99 and scale < 1.01 then return end

    local forward, right, up, pos = GetEntityMatrix(ped)

    local trueZ = pos.z
    local last = lastSet[ped]
    if last and math.abs(pos.z - last.z) < 0.0005 then trueZ = last.trueZ end
    local z = trueZ - (1.0 - scale) * Config.HipHeight

    local f, r, u = scaled(forward, scale), scaled(right, scale), scaled(up, scale)
    SetEntityMatrix(ped, f.x, f.y, f.z, r.x, r.y, r.z, u.x, u.y, u.z, pos.x, pos.y, z)
    lastSet[ped] = { z = z, trueZ = trueZ }
end

CreateThread(function()
    while true do
        local list, keep = {}, {}
        local myCoords = GetEntityCoords(PlayerPedId())
        for _, ply in ipairs(GetActivePlayers()) do
            local cm = tonumber(Player(GetPlayerServerId(ply)).state.vrHeight)
            if cm then
                local ped = GetPlayerPed(ply)
                if ped ~= 0 and #(GetEntityCoords(ped) - myCoords) <= Config.SyncDistance then
                    list[#list + 1] = { ped = ped, cm = cm }
                    keep[ped] = true
                end
            end
        end
        if preview then keep[preview.ped] = true end
        for ped in pairs(lastSet) do
            if not keep[ped] then lastSet[ped] = nil end
        end
        targets = list
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        local n = #targets
        if n == 0 and not preview then
            Wait(250)
        else
            for i = 1, n do
                local t = targets[i]
                apply(t.ped, t.cm)
            end
            if preview then apply(preview.ped, preview.cm) end
            Wait(0)
        end
    end
end)

exports('SetPreview', function(ped, cm)
    if not ped or ped == 0 or not cm then preview = nil return end
    preview = { ped = ped, cm = Config.ClampHeight(cm) }
end)

exports('ClearPreview', function() preview = nil end)
exports('FormatHeight', Config.FormatHeight)
exports('GetLimits', function()
    return { min = Config.MinHeight, max = Config.MaxHeight, default = Config.DefaultHeight }
end)
