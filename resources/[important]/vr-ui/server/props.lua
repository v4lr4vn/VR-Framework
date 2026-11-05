local last = {}
local MAX = 2

local function num(v, lim)
    v = tonumber(v)
    if not v or v ~= v then return 0.0 end
    return math.max(-lim, math.min(lim, v)) + 0.0
end

local function clean(list)
    if type(list) ~= 'table' then return nil end
    local out = {}
    for i = 1, math.min(#list, MAX) do
        local p = list[i]
        if type(p) == 'table' then
            local model = p.model
            if type(model) == 'string' and #model <= 64 and model:match('^[%w_%-]+$') then
                model = model
            elseif type(model) == 'number' and model == math.floor(model) then
                model = math.floor(model)
            else
                model = nil
            end
            if model then
                local pos = type(p.pos) == 'table' and p.pos or {}
                local rot = type(p.rot) == 'table' and p.rot or {}
                out[#out + 1] = {
                    model = model,
                    bone = math.max(0, math.min(65535, math.floor(tonumber(p.bone) or 60309))),
                    pos = { x = num(pos[1] or pos.x, 5), y = num(pos[2] or pos.y, 5), z = num(pos[3] or pos.z, 5) },
                    rot = { x = num(rot[1] or rot.x, 360), y = num(rot[2] or rot.y, 360), z = num(rot[3] or rot.z, 360) },
                    rotOrder = math.max(0, math.min(5, math.floor(tonumber(p.rotOrder) or 0))),
                }
            end
        end
    end
    return #out > 0 and out or nil
end

RegisterNetEvent('vr-ui:server:props', function(list)
    local src = source
    local now = GetGameTimer()
    if last[src] and now - last[src] < 150 then return end
    last[src] = now
    Player(src).state:set('vrui:props', clean(list), true)
end)

AddEventHandler('playerDropped', function()
    last[source] = nil
end)
