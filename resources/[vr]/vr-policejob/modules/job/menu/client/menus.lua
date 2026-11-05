local TriggerServerEvent = TriggerServerEvent

local function openMDT()
    if GetResourceState('vr-mdt') ~= 'started' then return end
    local ok, err = pcall(function() exports['vr-mdt']:OpenMDT() end)
    if not ok then utils.debug(('vr-mdt OpenMDT failed: %s'):format(err)) end
end

local function openDispatch()
    if GetResourceState('vr-mdt') ~= 'started' then return end
    local ok, err = pcall(function() exports['vr-mdt']:OpenDispatchMenu() end)
    if not ok then utils.debug(('vr-mdt OpenDispatchMenu failed: %s'):format(err)) end
end

local function onMainMenu(selected, scrollIndex, args)
    local action = args and args.action

    if action == 'adam' then
        openAdamMenu()
    elseif action == 'broadcast' then
        local input = lib.inputDialog(locale("broadcast_input_title"), {
            { type = 'input', label = locale("broadcast_input_reason"), description = locale("broadcast_input_reason_desc"), required = true, min = 5, max = Config.Broadcast.maxLength },
        })
        if not input then return end

        local reason = input[1]

        TriggerServerEvent("vr-policejob:server:broadcastMsg", { reason = reason })
    elseif action == 'interdict' then
        openDialogMenu()
    elseif action == 'meeting' then
        local jobGrade = getPlayerJobGrade()

        if jobGrade >= Config.MettingMenuGrade then
            local input = lib.inputDialog(locale("open_meeting_menu_label"), {
                { type = 'input',    label = locale("meeting_input_reason"),      description = locale("meeting_input_reason_desc"), required = true, max = Config.Meeting.maxLength },
                { type = 'number',   label = locale("meeting_input_radio"),       description = locale("meeting_input_radio_desc"),  required = true, icon = 'hashtag', min = 1, max = 999 },
                { type = 'checkbox', label = locale("meeting_input_confirmation") },
            })
            if not input then return end
            if not input[3] then return end

            local reason = input[1]
            local radio = input[2]

            TriggerServerEvent("vr-policejob:server:callMeeting", { reason = reason, radio = radio })
        end
    elseif action == 'panic' then
        TriggerServerEvent('vr-policejob:server:panic')
        utils.showNotification(locale('panic_sent'), 'warning')
    elseif action == 'mdt' then
        openMDT()
    elseif action == 'dispatch' then
        openDispatch()
    end
end

function registerPoliceMainMenu(options)
    lib.registerMenu({
        id = 'police_main_menu',
        title = locale("police_menu_title"),
        position = 'top-right',
        options = options,
    }, onMainMenu)
end

lib.registerMenu({
    id = 'police_meeting_menu',
    title = locale("police_meeting_menu_title"),
    position = 'top-right',
    options = {}
}, function(selected, scrollIndex, args)
    if selected == 1 then
        lib.showMenu("police_meeting_menu")
    elseif selected == 2 then
        joinRadio(player.frequencyToJoin)
    end
end)

lib.registerMenu({
    id = 'adam_menu',
    title = locale("adam_menu_title"),
    position = 'top-right',

    options = {},
    onCheck = function(selected, checked, args)
        if selected == 3 then
            player.receiveNotifications = checked
        end
    end,
    onClose = function(keyPressed)
        lib.showMenu("police_main_menu")
    end,
}, function(selected, scrollIndex, args)
    if selected == 1 then
        local input = lib.inputDialog(locale("input_set_adam_title"), {
            { type = 'number', label = locale("input_enter_adam_num"), description = locale("input_enter_adam_num_desc"), icon = 'hashtag', min = 0, max = 999 },
        })

        if not input then return end
        if not input[1] then return end

        player.adam = input[1]
        utils.showNotification(("%s %s"):format(locale("your_in_adam_x"), player.adam))
        openPoliceMenu()
    elseif selected == 2 then
        lib.showMenu('adam_status_menu')
    end
end)

local statusOptions = {}
for index, entry in ipairs(Config.StatusCodes) do
    statusOptions[#statusOptions + 1] = { label = entry.label, description = entry.description, args = { index = index }, icon = entry.icon }
end

lib.registerMenu({
    id = 'adam_status_menu',
    title = locale("adam_status_menu_title"),
    position = 'top-right',
    options = statusOptions,
    onClose = function(keyPressed)
        lib.showMenu("adam_menu")
    end,
}, function(selected, scrollIndex, args)
    if not player.adam then return utils.showNotification(locale("no_adam_set")) end
    local entry = args and Config.StatusCodes[args.index]
    if not entry then return end

    player.status = entry.code
    player.location = utils.getCurrentLocation()

    TriggerServerEvent("vr-policejob:server:sendStatusNotification", { adam = player.adam, status = args.index, location = player.location })

    utils.showNotification(locale("adam_status_changed"))
end)
