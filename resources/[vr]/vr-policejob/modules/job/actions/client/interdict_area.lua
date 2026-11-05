local TriggerServerEvent = TriggerServerEvent
local RegisterNetEvent = RegisterNetEvent
local AddBlipForRadius = AddBlipForRadius
local SetBlipColour = SetBlipColour
local SetBlipAlpha = SetBlipAlpha
local Wait = Wait
local RemoveBlip = RemoveBlip

function openDialogMenu()
    local input = lib.inputDialog(locale('restrict_area_dialog_title'), {
        {
            type = 'input',
            label = locale('restrict_area_message_title'),
            description = locale('restrict_area_message_description'),
            required = true,
            max = Config.InterdictArea.maxLength,
        },
        {
            type = 'select',
            label = locale('restrict_area_radius_title'),
            description = locale('restrict_area_radius_description'),
            icon = 'hashtag',
            required = true,
            options = {
                { value = '100.00', label = '100' },
                { value = '200.00', label = '200' },
                { value = '300.00', label = '300' },
                { value = '400.00', label = '400' },
            }
        },
        {
            type = 'select',
            label = locale('restrict_area_type_title'),
            description = locale('restrict_area_type_description'),
            icon = 'hashtag',
            required = true,
            options = {
                { value = 1, label = locale('restrict_area_type_1') },
                { value = 2, label = locale('restrict_area_type_2') },
                { value = 3, label = locale('restrict_area_type_3') },
            }
        },
        {
            type = 'number',
            label = locale('restrict_area_time_title'),
            description = locale('restrict_area_time_description'),
            required = true,
            min = 1,
            max = Config.InterdictArea.maxMinutes,
        },
        { type = 'checkbox', label = 'Confirm', required = true },
    })

    if not input then return end

    local reason = input[1]
    local radius = input[2]
    local type = input[3]
    local time = input[4]
    local confirm = input[5]

    if not confirm then return end

    TriggerServerEvent('vr-policejob:server:activateBlip', {
        reason = reason,
        radius = radius,
        type = type,
        time = time,
    })
end

RegisterNetEvent('vr-policejob:client:activateBlip', function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or not data.position or not tonumber(data.radius) or not tonumber(data.time) then return end

    local blip = AddBlipForRadius(data.position.x, data.position.y, data.position.z, tonumber(data.radius) + 0.0)

    SetBlipColour(blip, tonumber(data.type) or 1)
    SetBlipAlpha(blip, 128)
    utils.showNotification(tostring(data.reason))

    Wait(math.min(tonumber(data.time), Config.InterdictArea.maxMinutes * 60000))
    RemoveBlip(blip)
end)
