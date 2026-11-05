local U = InvUtil

Utils = {}

function Utils.PlayAnim(wait, dict, name, blendIn, blendOut, duration, flag, rate, lockX, lockY, lockZ)
    lib.requestAnimDict(dict)
    TaskPlayAnim(cache.ped, dict, name, blendIn, blendOut, duration, flag, rate, lockX, lockY, lockZ)
    RemoveAnimDict(dict)
    if wait > 0 then Wait(wait) end
end

function Utils.PlayAnimAdvanced(wait, dict, name, posX, posY, posZ, rotX, rotY, rotZ, blendIn, blendOut, duration, flag, time)
    lib.requestAnimDict(dict)
    TaskPlayAnimAdvanced(cache.ped, dict, name, posX, posY, posZ, rotX, rotY, rotZ, blendIn, blendOut, duration, flag, time, 0, 0)
    RemoveAnimDict(dict)
    if wait > 0 then Wait(wait) end
end

function Utils.Raycast(flag, destination, size)
    local ped = cache.ped
    local origin = GetEntityCoords(ped)
    destination = destination or GetOffsetFromEntityInWorldCoords(ped, 0.0, 2.2, -0.25)
    local handle = StartShapeTestCapsule(origin.x, origin.y, origin.z + 0.5, destination.x, destination.y, destination.z, size or 2.2, flag or 30, ped, 4)
    local started = GetGameTimer()
    while true do
        Wait(0)
        local result, _, _, _, entityHit = GetShapeTestResult(handle)
        if result ~= 1 then
            if entityHit and entityHit ~= 0 then
                local kind = GetEntityType(entityHit)
                if kind ~= 0 then return entityHit, kind end
            end
            return false
        end
        if GetGameTimer() - started > 1000 then return false end
    end
end

function Utils.GetClosestPlayer()
    local players = GetActivePlayers()
    local coords = GetEntityCoords(cache.ped)
    local best, bestId, bestPed
    for i = 1, #players do
        local player = players[i]
        if player ~= cache.playerId then
            local ped = GetPlayerPed(player)
            local distance = #(coords - GetEntityCoords(ped))
            if distance < (best or 2) then
                best, bestId, bestPed = distance, player, ped
            end
        end
    end
    return bestId, bestPed
end

function Utils.Notify(data)
    if type(data) ~= 'table' then return end
    data.description = data.description or data.text
    data.text = nil
    lib.notify(data)
end

U.netEvent('notify', Utils.Notify)
exports('notify', Utils.Notify)

local notifySuppressed = false

local function setNotifySuppressed(value) notifySuppressed = value == true end

U.netEvent('suppressItemNotifications', setNotifySuppressed)
exports('suppressItemNotifications', setNotifySuppressed)

function Utils.ItemNotify(data)
    if notifySuppressed or not client.itemnotify then return end
    if type(data) ~= 'table' or type(data[1]) ~= 'table' then return end
    SendNUIMessage({ action = 'itemNotify', data = data })
end

U.netEvent('itemNotify', Utils.ItemNotify)

function Utils.DeleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        SetEntityAsMissionEntity(entity, false, true)
        DeleteEntity(entity)
    end
end

local rewardTypes = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3) | (1 << 7) | (1 << 10)
local wheelOverride = false

function Utils.WeaponWheel(state, override)
    if not override and wheelOverride and state == false then return end
    if client.disableweapons then state = true end
    if state == nil then state = WeaponWheelEnabled end
    if override then wheelOverride = state or false end

    WeaponWheelEnabled = state
    SetWeaponsNoAutoswap(not state)
    SetWeaponsNoAutoreload(not state)

    if client.suppresspickups then
        if state then
            Citizen.InvokeNative(0x762DB2D380B48D04, rewardTypes)
        else
            Citizen.InvokeNative(0xF92099527DB8E2A7, rewardTypes, true)
        end
    end
end

exports('weaponWheel', function(state) Utils.WeaponWheel(state, true) end)

function Utils.CreateBlip(settings, coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, settings.id)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, settings.scale or 0.8)
    SetBlipColour(blip, settings.colour or 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName(settings.name)
    EndTextCommandSetBlipName(blip)
    return blip
end

function Utils.CreateBoxZone(data, options)
    if data.length then
        local height = math.abs(data.maxZ - data.minZ)
        local z = data.loc.z + math.abs(data.minZ - data.maxZ) / 2
        data.coords = vec3(data.loc.x, data.loc.y, z)
        data.size = vec3(data.width, data.length, height)
        data.rotation = data.heading
        data.loc, data.heading, data.length, data.width, data.maxZ, data.minZ = nil, nil, nil, nil, nil, nil
    end

    if not data.options and options then
        local distance = data.distance or 2.0
        for _, v in pairs(options) do
            if not v.distance then v.distance = distance end
        end
        data.options = options
    end

    return Bridge.target.addBoxZone(data)
end

local promptPoint

function Utils.nearbyMarker(point)
    local m = point.marker
    DrawMarker(m.type, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, m.scale[1], m.scale[2], m.scale[3], m.colour[1], m.colour[2], m.colour[3], 222, false, false, 0, true, false, false, false)

    if point.isClosest and point.currentDistance < 1.2 then
        if promptPoint ~= point then
            promptPoint = point
            lib.showTextUI(point.prompt.message, point.prompt.options)
        end

        if IsControlJustReleased(0, 38) then
            CreateThread(function()
                if point.inv == 'policeevidence' then
                    client.openInventory('policeevidence')
                elseif point.inv == 'crafting' then
                    client.openInventory('crafting', { id = point.benchid, index = point.index })
                else
                    client.openInventory(point.inv or 'drop', { id = point.invId, type = point.type })
                end
            end)
        end
    elseif promptPoint == point then
        promptPoint = nil
        lib.hideTextUI()
    end
end

function Utils.clearPrompt(point)
    if promptPoint and (not point or promptPoint == point) then
        promptPoint = nil
        lib.hideTextUI()
    end
end

function Utils.prompt(label)
    return ('**%s**  \n%s'):format(label, locale('interact_prompt', '[E]'))
end

function Utils.blurIn()
    if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    TriggerScreenblurFadeIn(100)
end

function Utils.blurOut()
    if IsScreenblurFadeRunning() then DisableScreenblurFade() end
    TriggerScreenblurFadeOut(250)
end

local function defaultPlayerName(serverId)
    local playerId = GetPlayerFromServerId(serverId)
    return ('[%d] %s'):format(serverId, GetPlayerName(playerId) or '?')
end

local getPlayerName = defaultPlayerName

exports('setGetPlayerNameMethod', function(fn)
    getPlayerName = InvUtil.callable(fn) and fn or defaultPlayerName
end)

function Utils.getPlayerName(serverId) return getPlayerName(serverId) end
