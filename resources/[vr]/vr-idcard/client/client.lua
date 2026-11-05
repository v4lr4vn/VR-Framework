local config = require('config')
local openID = false
local closeAt
local animDict, anim = 'paper_1_rcm_alt1-9', 'player_one_dual-9'

local CLOSE_KEY = config.settings.closeControl or 177

function CloseCard()
    if not openID then return end
    openID, closeAt = false, nil
    SendNUIMessage({ type = 'close' })
end

local function closeButton()
    local sf = RequestScaleformMovie('instructional_buttons')
    local timeout = GetGameTimer() + 2000
    while not HasScaleformMovieLoaded(sf) do
        if GetGameTimer() > timeout then return nil end
        Wait(0)
    end
    BeginScaleformMovieMethod(sf, 'CLEAR_ALL') EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'SET_DATA_SLOT')
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(0, CLOSE_KEY, true))
    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay('Close card')
    EndTextCommandScaleformString()
    EndScaleformMovieMethod()
    BeginScaleformMovieMethod(sf, 'DRAW_INSTRUCTIONAL_BUTTONS') EndScaleformMovieMethod()
    return sf
end

local watching = false
local function watchCard()
    if watching then return end
    watching = true
    CreateThread(function()
        local sf = closeButton()
        while openID do
            if sf then DrawScaleformMovieFullscreen(sf, 255, 255, 255, 255, 0) end
            if IsControlJustPressed(0, CLOSE_KEY) or IsDisabledControlJustPressed(0, CLOSE_KEY)
                or (closeAt and GetGameTimer() >= closeAt) then
                CloseCard()
            end
            Wait(0)
        end
        if sf then SetScaleformMovieAsNoLongerNeeded(sf) end
        watching = false
    end)
end

local function getCardProp(cardtype)
    if not cardtype then return warn('No Card Type') end

    local license = config.licenses[cardtype]
    if not license then return warn('Invalid Card Type: ' .. tostring(cardtype)) end

    local prop = license.prop
    if not prop then return warn('Card Type: ' .. cardtype .. ' No Prop') end

    return prop
end

local function startAnim(prop)
    lib.requestModel(prop)
    local playerCoords = GetEntityCoords(cache.ped)
    local createProp = CreateObject(prop, playerCoords.x, playerCoords.y, playerCoords.z + 0.2, true, true, true)

    AttachEntityToEntity(createProp, cache.ped, GetPedBoneIndex(cache.ped, 57005), 0.1000, 0.0200, -0.0300, -90.000,
        170.000, 78.999, true, true, false, true, 1, true)

    lib.requestAnimDict(animDict)
    TaskPlayAnim(cache.ped, animDict, anim, 3.0, -1, -1, 50, -1, false, false, false)
    SetModelAsNoLongerNeeded(prop)

    SetTimeout(3000, function()
        DeleteEntity(createProp)
        StopAnimTask(cache.ped, animDict, anim, 1.0)
        RemoveAnimDict(animDict)
    end)
end

RegisterNetEvent('vr-idcard:client:sendData', function(metadata)
    if GetInvokingResource() or type(metadata) ~= 'table' then return end
    if not getCardProp(metadata.cardtype) then return end

    openID = true
    local auto = config.settings.autoClose
    closeAt = auto and auto.status and GetGameTimer() + (auto.time or 8000) or nil
    SendNUIMessage({ type = 'playerData', playerData = metadata })
    watchCard()
end)

RegisterNetEvent('vr-idcard:client:animStart', function(metadata)
    if GetInvokingResource() then return end

    local prop = getCardProp(metadata.cardtype)
    if not prop then return end

    startAnim(prop)
end)

RegisterNetEvent('VRCore:Client:OnPlayerUnload', CloseCard)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then CloseCard() end
end)
