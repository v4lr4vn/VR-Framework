Settings = { externalAddress = '', externalPort = 0 }

local function refresh()
    Settings.useNativeAudio           = GetConvar('voice_useNativeAudio', 'false') == 'true'
    Settings.enableUi                 = GetConvarInt('voice_enableUi', 1) == 1
    Settings.enableSubmix             = GetConvarInt('voice_enableSubmix', 1) == 1
    Settings.enableRadios             = GetConvarInt('voice_enableRadios', 1) == 1
    Settings.enableCalls              = GetConvarInt('voice_enableCalls', 1) == 1
    Settings.enableRadioAnim          = GetConvarInt('voice_enableRadioAnim', 1) == 1
    Settings.disableVehicleRadioAnim  = GetConvarInt('voice_disableVehicleRadioAnim', 0) == 1
    Settings.disableRadioWhenShooting = GetConvarBool('voice_disableRadioWhenShooting', false)
    Settings.disableCameraListener    = GetConvarInt('voice_disableAutomaticListenerOnCamera', 0) == 1
    Settings.enableProximityCycle     = GetConvarInt('voice_enableProximityCycle', 1) == 1
    Settings.syncPlayerNames          = GetConvarInt('voice_syncPlayerNames', 0) == 1
    Settings.allowSetIntent           = GetConvarInt('voice_allowSetIntent', 1) == 1
    Settings.hideEndpoints            = GetConvarInt('voice_hideEndpoints', 1) == 1
    Settings.refreshRate              = math.max(50, GetConvarInt('voice_refreshRate', 200))
    voiceDebugLevel                   = GetConvarInt('voice_debugMode', 0)

    local address, port = GetConvar('voice_externalAddress', ''), GetConvarInt('voice_externalPort', 0)
    if address ~= Settings.externalAddress or port ~= Settings.externalPort then
        Settings.externalAddress, Settings.externalPort = address, port
        MumbleSetServerAddress(address, port)
    end
end

refresh()
CreateThread(function()
    while true do
        Wait(1000)
        refresh()
    end
end)
