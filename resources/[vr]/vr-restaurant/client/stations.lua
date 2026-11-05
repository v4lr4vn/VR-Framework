-- Crafting areas as players see them. Cleaning points work now. The other kinds are placed
-- ready for the kitchen update and show nothing yet.

Rn.stations = {}
local zones = {}

local function clear()
    for _, id in ipairs(zones) do pcall(function() Bridge.target.removeZone(id) end) end
    zones = {}
end

local function kindInfo(id)
    for _, k in ipairs(Config.Stations) do
        if k.id == id then return k end
    end
end

local cleaning = false

local function clean(s)
    if cleaning then return end
    cleaning = true
    CreateThread(function()
        local ok, res, extra = Rn.call('cleanBegin', s.id)
        if not ok then
            cleaning = false
            return Rn.fail(res, extra)
        end
        local done = lib.progressBar({
            duration = res.ms,
            label = 'Cleaning',
            useWhileDead = false,
            canCancel = true,
            disable = { move = true, car = true, combat = true },
            anim = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base' },
        })
        if not done then
            lib.callback.await('vr-restaurant:cleanCancel', false)
            cleaning = false
            return Rn.notify('You stopped cleaning', 'inform')
        end
        local fin, data, e = Rn.call('cleanFinish', s.id)
        cleaning = false
        if not fin then return Rn.fail(data, e) end
        Rn.notify('All clean here', 'success')
    end)
end

local function member(businessId)
    return Rn.mine ~= nil and Rn.mine == businessId
end

local function build()
    clear()
    for _, s in ipairs(Rn.stations) do
        local info = kindInfo(s.kind)
        local label = s.label ~= '' and s.label or (info and info.label) or s.kind
        local options
        if s.kind == 'clean' then
            options = {
                {
                    name = ('vr-restaurant:station:%d:clean'):format(s.id),
                    label = label,
                    icon = info.icon,
                    distance = s.radius + 1.5,
                    canInteract = function() return not cleaning and Rn.mine == s.business end,
                    onSelect = function() clean(s) end,
                },
            }
        elseif Rn.stationOptions then
            options = Rn.stationOptions(s, info, label)
        end
        if info and options and #options > 0 then
            zones[#zones + 1] = Bridge.target.addSphereZone({
                name = ('vr-restaurant:station:%d'):format(s.id),
                coords = vec3(s.x, s.y, s.z),
                radius = s.radius,
                options = options,
            })
        end
    end
end

-- Which business does this character work at? Used to show cleaning points to the right people.
function Rn.refreshMine()
    local res = lib.callback.await('vr-restaurant:mine', false)
    Rn.mine = type(res) == 'number' and res or nil
end

RegisterNetEvent('vr-restaurant:client:stations', function(list)
    Rn.stations = type(list) == 'table' and list or {}
    build()
end)

RegisterNetEvent('vr-restaurant:client:mine', function(id)
    Rn.mine = tonumber(id)
end)

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function()
    SetTimeout(2500, Rn.refreshMine)
end)
RegisterNetEvent('VRCore:Client:OnPlayerUnload', function()
    Rn.mine = nil
end)

CreateThread(function()
    Wait(2000)
    Rn.refreshMine()
    Rn.stations = lib.callback.await('vr-restaurant:stations', false) or {}
    build()
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then clear() end
end)
