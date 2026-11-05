local VRCore    = VRCore
local Config    = VRCore.Config
local Shared    = VRCore.Shared
local Resources = Config.Resources

VRCore.PlayerData = {}
VRCore.Functions  = {}
local Functions = VRCore.Functions

local function toVec3(coords)
    if type(coords) == 'table' then return vec3(coords.x, coords.y, coords.z) end
    return coords
end

local function resourceUp(name)
    return name and GetResourceState(name) == 'started'
end

function Functions.CreateClientCallback(name, cb)
    VRCore.ClientCallbacks[name] = cb
end

local pending, nextId = {}, 0

function Functions.TriggerCallback(name, ...)
    local args = table.pack(...)
    local cb, first = nil, 1
    if Shared.IsFunction(args[1]) then cb, first = args[1], 2 end

    nextId = nextId + 1
    local id, p = nextId, promise.new()
    pending[id] = { p = p, cb = cb }
    TriggerServerEvent('VRCore:Server:TriggerCallback', name, id, table.unpack(args, first, args.n))

    SetTimeout(Config.CallbackTimeout, function()
        if not pending[id] then return end
        pending[id] = nil
        print(('^3[vr-core] server callback "%s" timed out^0'):format(name))
        p:resolve({ n = 0 })
    end)

    if not cb then
        local r = Citizen.Await(p)
        return table.unpack(r, 1, r.n)
    end
end

RegisterNetEvent('VRCore:Client:TriggerCallback', function(id, ...)
    local entry = pending[id]
    if not entry then return end
    pending[id] = nil
    entry.p:resolve(table.pack(...))
    if entry.cb then entry.cb(...) end
end)

RegisterNetEvent('VRCore:Client:TriggerClientCallback', function(name, id, ...)
    local handler = VRCore.ClientCallbacks[name]
    if not handler then return TriggerServerEvent('VRCore:Server:TriggerClientCallback', id) end
    handler(function(...) TriggerServerEvent('VRCore:Server:TriggerClientCallback', id, ...) end, ...)
end)

function Functions.GetPlayerData(cb)
    if not cb then return VRCore.PlayerData end
    cb(VRCore.PlayerData)
end

function Functions.GetCoords(entity)
    local c = GetEntityCoords(entity)
    return vector4(c.x, c.y, c.z, GetEntityHeading(entity))
end

function Functions.HasItem(items, amount)
    local inv = Resources.inventory
    if not resourceUp(inv) then return false end
    if inv ~= 'vr-inventory' then return exports[inv]:HasItem(items, amount) end
    amount = tonumber(amount) or 1
    local function count(name) return exports[inv]:Search('count', name) or 0 end
    if type(items) == 'string' then return count(items) >= amount end
    if type(items) ~= 'table' then return false end
    for k, v in pairs(items) do
        local name, need = k, tonumber(v) or amount
        if type(k) == 'number' then name, need = v, amount end
        if count(name) < need then return false end
    end
    return true
end

function Functions.GetGroups()
    return Shared.GetGroupsFromData(VRCore.PlayerData)
end

function Functions.HasGroup(filter)
    return Shared.MatchGroup(Shared.GetGroupsFromData(VRCore.PlayerData), filter)
end

function Functions.GetName()
    local charinfo = VRCore.PlayerData.charinfo
    return charinfo.firstname .. ' ' .. charinfo.lastname
end

function Functions.LookAtEntity(entity, timeout, speed)
    local caller = GetInvokingResource() or GetCurrentResourceName()
    if type(entity) ~= 'number' then return caller .. ' :^1  Entity must be a number' end
    if not DoesEntityExist(entity) then return caller .. ' :^1  Entity does not exist' end
    if type(speed) ~= 'number' then return caller .. ' :^1  Speed must be a number' end
    speed = math.min(speed, 5.0)
    timeout = math.min(tonumber(timeout) or 5000, 5000)

    local ped = PlayerPedId()
    local from, to = GetEntityCoords(ped), GetEntityCoords(entity)
    local target = GetHeadingFromVector_2d(to.x - from.x, to.y - from.y)
    local deadline = GetGameTimer() + timeout
    while GetGameTimer() < deadline do
        local current = GetEntityHeading(ped)
        local diff = target - current
        if math.abs(diff) < 2 then break end
        if diff < -180 then diff = diff + 360 elseif diff > 180 then diff = diff - 360 end
        local turn = speed + (2.5 - speed) * (1 - math.abs(diff) / 180)
        SetEntityHeading(ped, current + (diff > 0 and turn or -turn))
        Wait(0)
    end
    SetEntityHeading(ped, target)
end

function Functions.PlayAnim(animDict, animName, upperbodyOnly, duration)
    local caller = GetInvokingResource() or GetCurrentResourceName()
    if type(animDict) ~= 'string' or type(animName) ~= 'string' then return caller .. ' :^1  Wrong type for animDict or animName' end
    if not Functions.RequestAnimDict(animDict) then return caller .. ' :^1  Animation dictionary failed to load' end

    local flags = (duration or -1) == -1 and 49 or (upperbodyOnly and 16 or 0)
    TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, 8.0, duration or -1, flags, 0, true, true, true)
    Wait(10)
    local length = GetAnimDuration(animDict, animName)
    if length == 0 then return caller .. ' :^1  Animation does not exist' end
    local full = length * 1000
    Wait(duration and duration > 0 and math.min(duration, full) or full)
    RemoveAnimDict(animDict)
    return length
end

function Functions.IsWearingGloves()
    local ped = PlayerPedId()
    local arms = GetPedDrawableVariation(ped, 3)
    local bare = GetEntityModel(ped) == `mp_m_freemode_01` and Shared.MaleNoGloves or Shared.FemaleNoGloves
    return not bare[arms]
end

function Functions.Notify(text, texttype, length, icon)
    if GetResourceState('vr-ui') == 'started' then
        return exports['vr-ui']:Notify(text, texttype, length)
    end
    local message = { action = 'notify', type = texttype or 'primary', length = length or 5000, icon = icon }
    if type(text) == 'table' then
        message.text = text.text or ''
        message.caption = text.caption
    else
        message.text = text
    end
    SendNUIMessage(message)
end

function Functions.Progressbar(name, label, duration, useWhileDead, canCancel, disableControls, animation, prop, propTwo, onFinish, onCancel)
    local res = Resources.progressbar
    if not resourceUp(res) then return error(('%s must be started for VRCore.Functions.Progressbar'):format(tostring(res))) end
    exports[res]:Progress({
        name = name:lower(),
        duration = duration,
        label = label,
        useWhileDead = useWhileDead,
        canCancel = canCancel,
        controlDisables = disableControls,
        animation = animation,
        prop = prop,
        propTwo = propTwo,
    }, function(cancelled)
        if not cancelled then
            if onFinish then onFinish() end
        elseif onCancel then
            onCancel()
        end
    end)
end

function Functions.DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    DrawRect(0.0, 0.0125, 0.017 + #text / 370, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

function Functions.GetVehicles() return GetGamePool('CVehicle') end
function Functions.GetObjects() return GetGamePool('CObject') end
function Functions.GetPlayers() return GetActivePlayers() end

function Functions.GetPlayersFromCoords(coords, distance)
    coords = toVec3(coords) or GetEntityCoords(PlayerPedId())
    distance = distance or 5
    local found = {}
    for _, player in ipairs(GetActivePlayers()) do
        if #(GetEntityCoords(GetPlayerPed(player)) - coords) <= distance then found[#found + 1] = player end
    end
    return found
end

function Functions.GetClosestPlayer(coords)
    coords = toVec3(coords) or GetEntityCoords(PlayerPedId())
    local me = PlayerId()
    local best, bestDist = -1, -1
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= me then
            local dist = #(GetEntityCoords(GetPlayerPed(player)) - coords)
            if dist <= 5 and (bestDist == -1 or dist < bestDist) then best, bestDist = player, dist end
        end
    end
    return best, bestDist
end

function Functions.GetPeds(ignoreList)
    local ignore = {}
    for i = 1, #(ignoreList or {}) do ignore[ignoreList[i]] = true end
    local peds = {}
    for _, ped in ipairs(GetGamePool('CPed')) do
        if not ignore[ped] then peds[#peds + 1] = ped end
    end
    return peds
end

local function closest(pool, coords)
    local best, bestDist = -1, -1
    for i = 1, #pool do
        local dist = #(GetEntityCoords(pool[i]) - coords)
        if bestDist == -1 or dist < bestDist then best, bestDist = pool[i], dist end
    end
    return best, bestDist
end

function Functions.GetClosestPed(coords, ignoreList)
    return closest(Functions.GetPeds(ignoreList), toVec3(coords) or GetEntityCoords(PlayerPedId()))
end

function Functions.GetClosestVehicle(coords)
    return closest(GetGamePool('CVehicle'), toVec3(coords) or GetEntityCoords(PlayerPedId()))
end

function Functions.GetClosestObject(coords)
    return closest(GetGamePool('CObject'), toVec3(coords) or GetEntityCoords(PlayerPedId()))
end

function Functions.SpawnClear(coords, radius)
    coords = toVec3(coords) or GetEntityCoords(PlayerPedId())
    for _, vehicle in ipairs(GetGamePool('CVehicle')) do
        if #(GetEntityCoords(vehicle) - coords) <= radius then return false end
    end
    return true
end

local function streamIn(has, request, asset, timeout)
    if has(asset) then return true end
    request(asset)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not has(asset) and GetGameTimer() < deadline do Wait(0) end
    return has(asset)
end

function Functions.LoadModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if HasModelLoaded(hash) then return true, model end
    if not IsModelValid(hash) and not IsModelInCdimage(hash) then
        print(('[vr-core] Model does not exist: %s'):format(model))
        return false, hash
    end
    return streamIn(HasModelLoaded, RequestModel, hash, timeout), hash
end

function Functions.RequestAnimDict(animDict, timeout)
    if HasAnimDictLoaded(animDict) then return true, animDict end
    if not DoesAnimDictExist(animDict) then
        print(('[vr-core] Animation dictionary does not exist: %s'):format(animDict))
        return false, animDict
    end
    return streamIn(HasAnimDictLoaded, RequestAnimDict, animDict, timeout), animDict
end

function Functions.LoadAnimSet(animSet, timeout)
    return streamIn(HasAnimSetLoaded, RequestAnimSet, animSet, timeout), animSet
end

function Functions.LoadParticleDictionary(dictionary, timeout)
    return streamIn(HasNamedPtfxAssetLoaded, RequestNamedPtfxAsset, dictionary, timeout), dictionary
end

function Functions.StartParticleAtCoord(dict, ptName, looped, coords, rot, scale, alpha, color, duration)
    coords = toVec3(coords) or GetEntityCoords(PlayerPedId())
    Functions.LoadParticleDictionary(dict)
    UseParticleFxAssetNextCall(dict)
    SetPtfxAssetNextCall(dict)
    if not looped then
        SetParticleFxNonLoopedAlpha(alpha or 10.0)
        if color then SetParticleFxNonLoopedColour(color.r, color.g, color.b) end
        StartParticleFxNonLoopedAtCoord(ptName, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0)
        return
    end
    local handle = StartParticleFxLoopedAtCoord(ptName, coords.x, coords.y, coords.z, rot.x, rot.y, rot.z, scale or 1.0)
    if color then SetParticleFxLoopedColour(handle, color.r, color.g, color.b, false) end
    SetParticleFxLoopedAlpha(handle, alpha or 10.0)
    if duration then
        Wait(duration)
        StopParticleFxLooped(handle, false)
    end
    return handle
end

function Functions.StartParticleOnEntity(dict, ptName, looped, entity, bone, offset, rot, scale, alpha, color, evolution, duration)
    Functions.LoadParticleDictionary(dict)
    UseParticleFxAssetNextCall(dict)
    local boneId
    if bone then
        boneId = GetEntityType(entity) == 1 and GetPedBoneIndex(entity, bone) or GetEntityBoneIndexByName(entity, bone)
    end
    if not looped then
        SetParticleFxNonLoopedAlpha(alpha or 10.0)
        if color then SetParticleFxNonLoopedColour(color.r, color.g, color.b) end
        if bone then
            StartParticleFxNonLoopedOnPedBone(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneId, scale)
        else
            StartParticleFxNonLoopedOnEntity(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale)
        end
        return
    end
    local handle
    if bone then
        handle = StartParticleFxLoopedOnEntityBone(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, boneId, scale)
    else
        handle = StartParticleFxLoopedOnEntity(ptName, entity, offset.x, offset.y, offset.z, rot.x, rot.y, rot.z, scale)
    end
    if evolution then SetParticleFxLoopedEvolution(handle, evolution.name, evolution.amount, false) end
    if color then SetParticleFxLoopedColour(handle, color.r, color.g, color.b, false) end
    SetParticleFxLoopedAlpha(handle, alpha)
    if duration then
        Wait(duration)
        StopParticleFxLooped(handle, false)
    end
    return handle
end

function Functions.AttachProp(ped, model, boneId, x, y, z, xR, yR, zR, vertex)
    local hash = type(model) == 'string' and joaat(model) or model
    Functions.LoadModel(hash)
    local prop = CreateObject(hash, 1.0, 1.0, 1.0, true, true, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, boneId), x, y, z, xR, yR, zR, true, true, false, true, vertex and 0 or 2, true)
    SetModelAsNoLongerNeeded(hash)
    return prop
end

function Functions.GetClosestBone(entity, list)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local bone, coords, distance
    for _, element in pairs(list) do
        local boneCoords = GetWorldPositionOfEntityBone(entity, element.id or element)
        local dist = #(playerCoords - boneCoords)
        if not distance or dist < distance then bone, coords, distance = element, boneCoords, dist end
    end
    if not bone then
        bone = { id = GetEntityBoneIndexByName(entity, 'bodyshell'), type = 'remains', name = 'bodyshell' }
        coords = GetWorldPositionOfEntityBone(entity, bone.id)
        distance = #(coords - playerCoords)
    end
    return bone, coords, distance
end

function Functions.GetBoneDistance(entity, boneType, boneIndex)
    local bone = boneType == 1 and GetPedBoneIndex(entity, boneIndex) or GetEntityBoneIndexByName(entity, boneIndex)
    return #(GetWorldPositionOfEntityBone(entity, bone) - GetEntityCoords(PlayerPedId()))
end

function Functions.GetStreetNameAtCoords(coords)
    local main, cross = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return { main = GetStreetNameFromHashKey(main), cross = GetStreetNameFromHashKey(cross) }
end

function Functions.GetZoneAtCoords(coords)
    return GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
end

function Functions.GetCardinalDirection(entity)
    entity = (entity and DoesEntityExist(entity)) and entity or PlayerPedId()
    local h = GetEntityHeading(entity)
    if h >= 45 and h < 135 then return 'West' end
    if h >= 135 and h < 225 then return 'South' end
    if h >= 225 and h < 315 then return 'East' end
    return 'North'
end

function Functions.GetCurrentTime()
    local hour, min = GetClockHours(), GetClockMinutes()
    local h12 = hour % 12
    return {
        hour = hour,
        min = min,
        ampm = hour < 12 and 'AM' or 'PM',
        formattedHour = h12 == 0 and 12 or h12,
        formattedMin = ('%02d'):format(min),
    }
end

function Functions.GetGroundZCoord(coords)
    if not coords then return end
    local found, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z, false)
    if found then return vector3(coords.x, coords.y, groundZ) end
    return coords
end

function Functions.GetGroundHash(entity)
    local c = GetEntityCoords(entity)
    local handle = StartShapeTestCapsule(c.x, c.y, c.z + 4, c.x, c.y, c.z - 2.0, 1, 1, entity, 7)
    local retval, success, endCoords, surfaceNormal, materialHash, entityHit = GetShapeTestResultIncludingMaterial(handle)
    return materialHash, entityHit, surfaceNormal, endCoords, success, retval
end
