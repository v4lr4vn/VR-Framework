-- Spawning: where a character appears once they are logged in.
-- Brand new characters go to Config.FirstSpawn. Returning ones get the map (or go straight to
-- their last location when Config.ShowSpawnMenu is off and they own no house).
local cam
local choosing = false
local entered = false
local needsSkin = false
local options = {}
local chosen = {}

local function toVec4(c)
    if not c or type(c.x) ~= 'number' or type(c.y) ~= 'number' or type(c.z) ~= 'number' then return nil end
    local w = (type(c) == 'vector4' and c.w) or (type(c) == 'table' and (c.w or c.h or c.heading)) or 0.0
    return vector4(c.x + 0.0, c.y + 0.0, c.z + 0.0, w + 0.0)
end

local function areaName(c)
    local street, zone = '', ''
    local s1 = GetStreetNameAtCoord(c.x, c.y, c.z)
    if s1 and s1 ~= 0 then street = GetStreetNameFromHashKey(s1) or '' end
    local label = GetLabelText(GetNameOfZone(c.x, c.y, c.z))
    if label and label ~= 'NULL' then zone = label end
    return street, zone
end

local function destroyCam()
    if cam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(cam, true)
        cam = nil
    end
    ClearFocus()
end

-- The menu is an opaque map, so this camera is never seen. It is here to make the game
-- stream the area around the highlighted spot so the spawn itself is quick.
local function pointCamAt(coords)
    local camZ = coords.z + Config.CameraHeight
    if not cam then
        cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', coords.x, coords.y, camZ, -85.0, 0.0, 0.0, 70.0, false, 0)
        SetCamActive(cam, true)
        RenderScriptCams(true, false, 0, true, true)
    else
        SetCamCoord(cam, coords.x, coords.y, camZ)
    end
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
end

local function placePed(coords, snap)
    local ped = PlayerPedId()
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, coords.w)
    local deadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(0) end
    local z = coords.z
    if snap then
        local found, gz = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)
        if found then z = gz + 0.1 end
    end
    NetworkResurrectLocalPlayer(coords.x, coords.y, z, coords.w, true, true, false)
    ped = PlayerPedId()
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(PlayerId())
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true)
    TriggerEvent('playerSpawned', { x = coords.x, y = coords.y, z = z, heading = coords.w })
end

local function closeMenu()
    choosing = false
    SetNuiFocus(false, false)
end

AddEventHandler('vr-spawn:client:entered', function() entered = true end)

local function spawnAt(coords, houseId, enterEvent, snap)
    if choosing then closeMenu() end
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(0) end
    SendNUIMessage({ action = 'close' })
    destroyCam()
    placePed(coords, snap)

    TriggerServerEvent('VRCore:Server:OnPlayerLoaded')
    TriggerServerEvent('vr-multicharacter:server:spawned')
    if GetResourceState('spawnmanager') == 'started' then exports.spawnmanager:setAutoSpawn(false) end

    if houseId ~= nil and enterEvent then
        entered = false
        TriggerEvent(enterEvent, houseId)
        local deadline = GetGameTimer() + 15000
        while not entered and GetGameTimer() < deadline do Wait(50) end
    end

    Wait(500)
    if not IsScreenFadedIn() and not IsScreenFadingIn() then DoScreenFadeIn(500) end

    if needsSkin then
        needsSkin = false
        TriggerEvent('qb-clothes:client:CreateFirstCharacter')
    end
end

-- the character the player just picked, so the map can show who is spawning
AddEventHandler('vr-multicharacter:client:chosen', function(cData)
    chosen = {}
    if type(cData) ~= 'table' then return end
    local ci = cData.charinfo or {}
    local first, last = tostring(ci.firstname or ''), tostring(ci.lastname or '')
    chosen.name = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')
    chosen.initials = ((first:sub(1, 1)) .. (last:sub(1, 1))):upper()
    chosen.citizenid = cData.citizenid
    chosen.lastPlayed = cData.lastPlayed
end)

AddEventHandler('vr-multicharacter:client:spawnReset', function()
    if choosing then closeMenu() end
    destroyCam()
    options = {}
end)

RegisterNetEvent('vr-spawn:client:firstSpawn', function(coords)
    spawnAt(toVec4(coords) or toVec4(Config.FirstSpawn))
    TriggerEvent('qb-clothes:client:CreateFirstCharacter')
end)
RegisterNetEvent('vr-multicharacter:client:firstSpawn', function(coords)
    TriggerEvent('vr-spawn:client:firstSpawn', coords)
end)

RegisterNetEvent('vr-multicharacter:client:spawnChoose', function(data)
    needsSkin = data.needsSkin == true
    local last = toVec4(data.last)
    local lastHouse, lastEvent = data.lastHouse, data.lastEvent
    if not last or (last.x == 0.0 and last.y == 0.0) then
        last, lastHouse, lastEvent = toVec4(Config.FirstSpawn), nil, nil
    end
    local houses = data.houses or {}
    local jobSpawn = data.job and Config.JobSpawns and Config.JobSpawns[data.job]

    if #houses == 0 and not Config.ShowSpawnMenu then
        return spawnAt(last, lastHouse, lastEvent)
    end

    options = {}
    local list = {}

    local street, zone = areaName(last)
    local lastArea = (street ~= '' and zone ~= '') and (street .. ', ' .. zone) or (street ~= '' and street or zone)
    options.last = { coords = last, houseId = lastHouse, event = lastEvent }
    list[#list + 1] = {
        id = 'last', kind = 'last', group = 'CONTINUE', label = 'Last location',
        sub = zone ~= '' and zone or street, area = lastArea, x = last.x, y = last.y,
        lastPlayed = chosen.lastPlayed, inside = lastHouse ~= nil,
    }

    for i = 1, #houses do
        local h = houses[i]
        local coords = toVec4(h.coords)
        if coords then
            local id = 'house' .. i
            options[id] = { coords = coords, houseId = h.id, event = h.event }
            local _, hz = areaName(coords)
            list[#list + 1] = {
                id = id, kind = 'home', group = 'YOURS', label = tostring(h.label or ('House ' .. i)),
                sub = hz, x = coords.x, y = coords.y, inside = h.event ~= nil,
            }
        end
    end

    local jc = jobSpawn and toVec4(jobSpawn.coords)
    if jc then
        options.work = { coords = jc, snap = true }
        local ws, wz = areaName(jc)
        list[#list + 1] = {
            id = 'work', kind = 'work', group = 'YOURS', label = 'Work',
            sub = tostring(jobSpawn.label or ''), area = (ws ~= '' and wz ~= '') and (ws .. ', ' .. wz) or (ws ~= '' and ws or wz),
            x = jc.x, y = jc.y,
        }
    end

    for i = 1, #(Config.PublicSpawns or {}) do
        local p = Config.PublicSpawns[i]
        local pc = toVec4(p.coords)
        if pc then
            local id = 'city' .. i
            options[id] = { coords = pc, snap = true }
            local ps, pz = areaName(pc)
            list[#list + 1] = {
                id = id, kind = 'city', group = 'THE CITY', label = tostring(p.label or ('Spot ' .. i)),
                area = (ps ~= '' and pz ~= '') and (ps .. ', ' .. pz) or (ps ~= '' and ps or pz),
                x = pc.x, y = pc.y,
            }
        end
    end

    choosing = true
    pointCamAt(last)
    DoScreenFadeIn(300)
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'spawn',
        options = list,
        selected = 'last',
        map = Config.Map,
        canChange = true,
        char = { name = chosen.name, initials = chosen.initials, citizenid = chosen.citizenid },
    })
end)

RegisterNUICallback('spawnPreview', function(data, cb)
    cb('ok')
    local option = options[data and data.id]
    if choosing and option then pointCamAt(option.coords) end
end)

RegisterNUICallback('spawnConfirm', function(data, cb)
    cb('ok')
    local option = options[data and data.id]
    if not choosing or not option then return end
    spawnAt(option.coords, option.houseId, option.event, option.snap)
end)

RegisterNUICallback('backToSelect', function(_, cb)
    cb('ok')
    if not choosing then return end
    TriggerServerEvent('vr-multicharacter:server:backToSelect')
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if choosing then closeMenu() end
    destroyCam()
end)
