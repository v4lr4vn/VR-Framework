local MIC_MODEL = `v_ilev_fos_mic`
local MEGAPHONE_MODEL = `prop_megaphone_01`
local DICT, CLIP = 'amb@world_human_mobile_film_shocking@female@base', 'base'

local standing = nil      -- the stand whose box we are inside
local holding = false
local held = nil          -- megaphone prop entity
local props = {}          -- [stand] = entity

local function voice()
    if GetResourceState('vr-voice') ~= 'started' then return nil end
    return exports['vr-voice']
end

-- The widest range wins: stand, megaphone, or nothing (back to normal).
local function applyRange()
    local v = voice()
    if not v then return end
    local range = standing and standing.range or 0.0
    if holding and Config.MegaphoneRange > range then range = Config.MegaphoneRange end
    if range > 0.0 then v:overrideProximityRange(range, true) else v:clearProximityOverride() end
end

-- Stands -------------------------------------------------------------------------------------
local zones = {}
CreateThread(function()
    for _, stand in ipairs(Config.Stands) do
        zones[#zones + 1] = lib.zones.box({
            coords = stand.coords,
            size = stand.size,
            rotation = stand.heading or 0.0,
            debug = Config.Debug,
            onEnter = function() standing = stand applyRange() end,
            onExit = function() if standing == stand then standing = nil applyRange() end end,
        })
    end
end)

-- Stand props exist only while the player is within 150 m.
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local near = false
        for _, stand in ipairs(Config.Stands) do
            if stand.prop then
                if #(pos - stand.coords) <= 150.0 then
                    near = true
                    if not (props[stand] and DoesEntityExist(props[stand])) and lib.requestModel(MIC_MODEL, 5000) then
                        local e = CreateObject(MIC_MODEL, stand.coords.x, stand.coords.y, stand.coords.z - 1.0, false, false, false)
                        SetEntityHeading(e, stand.heading or 0.0)
                        FreezeEntityPosition(e, true)
                        SetModelAsNoLongerNeeded(MIC_MODEL)
                        props[stand] = e
                    end
                elseif props[stand] then
                    DeleteEntity(props[stand])
                    props[stand] = nil
                end
            end
        end
        Wait(near and 1000 or 2500)
    end
end)

-- Megaphone ----------------------------------------------------------------------------------
local function putAway()
    holding = false
    StopAnimTask(PlayerPedId(), DICT, CLIP, 1.0)
    if held and DoesEntityExist(held) then DeleteEntity(held) end
    held = nil
    applyRange()
end

local function pickUp()
    local ped = PlayerPedId()
    if not lib.requestAnimDict(DICT, 5000) or not lib.requestModel(MEGAPHONE_MODEL, 5000) then return end
    local at = GetEntityCoords(ped)
    held = CreateObject(MEGAPHONE_MODEL, at.x, at.y, at.z + 0.2, true, true, true)
    AttachEntityToEntity(held, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 80.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(MEGAPHONE_MODEL)
    TaskPlayAnim(ped, DICT, CLIP, 8.0, 1.0, -1, 49, 0, false, false, false)
    holding = true
    applyRange()

    CreateThread(function()
        local checks = 0
        while holding do
            Wait(1000)
            checks = checks + 1
            if holding and (IsEntityDead(PlayerPedId()) or not IsEntityPlayingAnim(PlayerPedId(), DICT, CLIP, 3)) then
                putAway()
            elseif holding and checks % 4 == 0 and not lib.callback.await('vr-microphone:hasMegaphone', false) then
                putAway()
            end
        end
    end)
end

RegisterNetEvent('vr-microphone:client:toggle', function()
    if GetInvokingResource() then return end
    if holding then putAway() else pickUp() end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, e in pairs(props) do if DoesEntityExist(e) then DeleteEntity(e) end end
    for _, z in ipairs(zones) do z:remove() end
    if held and DoesEntityExist(held) then DeleteEntity(held) end
    if standing or holding then
        local v = voice()
        if v then v:clearProximityOverride() end
    end
end)
