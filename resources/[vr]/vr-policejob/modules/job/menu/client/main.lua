local GetEntityCoords = GetEntityCoords
local Wait = Wait
local RemoveBlip = RemoveBlip
local GetResourceState = GetResourceState
local PlaySoundFrontend = PlaySoundFrontend
local RegisterNetEvent = RegisterNetEvent
local GetGameTimer = GetGameTimer
local IsControlJustReleased = IsControlJustReleased

player.adam = nil
player.status = nil
player.location = nil
player.receiveNotifications = true
player.frequencyToJoin = 0

local function createEmergencyBlip(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or not data.pos or not hasJob(Config.Interactions.jobs) then return end

    local blip = utils.createBlip({
        pos = data.pos,
        type = tonumber(data.type) or 161,
        scale = tonumber(data.scale) or 1.2,
        color = tonumber(data.color) or 1,
        name = tostring(data.name or locale('emergency_blip_label')),
    })

    Wait(6 * 1000)
    RemoveBlip(blip)
end

RegisterNetEvent('vr-policejob:client:createEmergencyBlip', createEmergencyBlip)

function joinRadio(fz)
    fz = tonumber(fz)
    if not fz or GetResourceState('vr-voice') ~= 'started' then return end
    exports['vr-voice']:setVoiceProperty('radioEnabled', true)
    exports['vr-voice']:setVoiceProperty('micClicks', true)
    exports['vr-voice']:setRadioChannel(fz)
end

local function sendNotification(adam)
    if not player.receiveNotifications or not player.inDuty() then return end
    PlaySoundFrontend(-1, "Start_Squelch", "CB_RADIO_SFX", 1)

    local message = ("\n🚓 %s %s  \n🔢 %s %s  \n🗺️ %s %s"):format(locale("adam_notif_label"), adam.adam, locale("status_notif_label"), adam.status, locale("location_notif_label"), adam.location)

    lib.notify({
        title = locale("status_notif_title"),
        description = message,
        position = 'bottom-right',
        duration = 3000,
        style = {
            backgroundColor = '#1C1C1C',
            color = '#C1C2C5',
            borderRadius = '8px',
            ['.description'] = {
                fontSize = '16px',
                color = '#B0B3B8'
            },
        },
        icon = 'fas fa-badge-shield-altad',
        iconColor = '#FEBD69'
    })
end

local function mainMenuOptions()
    local options = {
        { label = locale("open_adam_menu_label"),  description = locale("open_adam_menu_description"), icon = "fas fa-car",          args = { action = 'adam' } },
        { label = locale("broadcast_alert_label"), description = locale("broadcast_alert_label_dsc"),  icon = "fas fa-bullhorn",     args = { action = 'broadcast' } },
        { label = locale("interdict_area_label"),                                                      icon = 'fa-tower-broadcast',  args = { action = 'interdict' } },
        { label = locale("call_metting_label"),                                                        icon = 'radio',               args = { action = 'meeting' } },
        { label = locale("panic_button_label"),    description = locale("panic_button_description"),   icon = 'fas fa-triangle-exclamation', args = { action = 'panic' } },
    }

    if GetResourceState('vr-mdt') == 'started' then
        options[#options + 1] = { label = locale("open_mdt_label"), icon = 'fas fa-tablet-screen-button', args = { action = 'mdt' } }
    end
    if GetResourceState('vr-mdt') == 'started' then
        options[#options + 1] = { label = locale("open_dispatch_label"), icon = 'fas fa-headset', args = { action = 'dispatch' } }
    end

    return options
end

function openPoliceMenu()
    if hasJob(Config.AccessToMenu) then
        if player.inDuty() == false then return utils.showNotification(locale("your_off_duty")) end
        registerPoliceMainMenu(mainMenuOptions())
        lib.showMenu("police_main_menu")
    end
end

local function validText(value, maxLen)
    return type(value) == 'string' and #value > 0 and #value <= maxLen * 4
end

RegisterNetEvent("vr-policejob:client:broadcastMsg", function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or not validText(data.reason, Config.Broadcast.maxLength) then return end

    lib.notify({
        title = locale("broadcast_notif_title"),
        description = data.reason,
        position = 'bottom-right',
        duration = 8000,
        style = {
            backgroundColor = '#1C1C1C',
            color = '#C1C2C5',
            borderRadius = '8px',
            ['.description'] = {
                fontSize = '16px',
                color = '#B0B3B8'
            },
        },
        icon = 'fas fa-badge-shield-altad',
        iconColor = '#FEBD69'
    })
end)

function openAdamMenu()
    lib.setMenuOptions('adam_menu', { label = locale("set_adam_label"), description = player.adam and ('Current adam %s'):format(player.adam) or locale("set_adam_label"), icon = "fas fa-user" }, 1)
    lib.setMenuOptions('adam_menu', { label = locale("set_adam_label_status"), description = player.status and ('Current Status %s'):format(player.status) or locale("set_adam_label_status"), icon = "fas fa-comment" }, 2)
    lib.setMenuOptions('adam_menu', { label = locale("adam_receive_notif_label"), description = locale("adam_receive_notif_dec"), icon = "fas fa-info", checked = player.receiveNotifications }, 3)

    lib.showMenu('adam_menu')
end

RegisterNetEvent("vr-policejob:client:sendStatusNotification", function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' then return end
    if hasJob(Config.AccessToMenu) then
        sendNotification({
            adam = tonumber(data.adam) or 'N/A',
            status = tostring(data.status),
            location = tostring(data.location)
        })
    end
end)

RegisterNetEvent("vr-policejob:client:callMeeting", function(data)
    if GetInvokingResource() then return end
    if type(data) ~= 'table' or not validText(data.reason, Config.Meeting.maxLength) or not tonumber(data.radio) then return end
    if hasJob(Config.AccessToMenu) then
        lib.setMenuOptions('police_meeting_menu', { label = string.len(data.reason) < 50 and ("%s %s"):format(locale("meeting_reason_label"), data.reason) or locale("read_meeting_reason_label"), description = data.reason, icon = 'info' }, 1)
        lib.setMenuOptions('police_meeting_menu', { label = ("%s %s"):format(locale("fz_meeting"), data.radio), description = ("%s %s"):format(locale("join_fz"), data.radio), icon = 'radio' }, 2)
        player.frequencyToJoin = tonumber(data.radio)

        lib.notify({
            title = locale("status_notif_title"),
            description = locale("open_called_meeting_menu"),
            position = 'top-center',
            duration = 5000,
        })

        local startTime = GetGameTimer()
        local timeout = 1 * 60000
        while true do
            if IsControlJustReleased(0, 303) then
                lib.showMenu("police_meeting_menu")
                break
            end

            if GetGameTimer() - startTime >= timeout then
                break
            end
            Wait(1)
        end
    end
end)

lib.addKeybind({
    name = 'open_police_menu',
    description = 'Open police menu',
    defaultKey = Config.OpenMenuKey,
    onReleased = function(self)
        openPoliceMenu()
    end
})
