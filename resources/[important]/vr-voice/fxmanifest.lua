fx_version 'cerulean'
game 'gta5'

vr_name 'vr-voice'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-voice'
author 'ValRavn'
description 'VOIP on FiveM\'s built-in mumble'
version '1.0.0'

dependencies {
    '/onesync',
    'vr-bridge',
}

shared_script 'shared.lua'

client_scripts {
    '@vr-keybinds/import.lua',
    'client/settings.lua',
    'client/nui.lua',
    'client/proximity.lua',
    'client/init.lua',
    'client/main.lua',
    'client/submix.lua',
    'client/radio.lua',
    'client/listen.lua',
    'client/call.lua',
    'client/commands.lua',
    'client/events.lua',
}

server_scripts {
    '@vr-bridge/import.lua',
    'server/main.lua',
    'server/radio.lua',
    'server/listen.lua',
    'server/call.lua',
    'server/mute.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
    'ui/style.css',
    'ui/app.js',
    'ui/mic_click_on.ogg',
    'ui/mic_click_off.ogg',
}

provides {
    'mumble-voip',
    'tokovoip',
    'toko-voip',
    'tokovoip_script',
}

convar_category 'VR-Voice' {
    'VR-Voice Configuration Options',
    {
        { 'Use native audio',                      '$voice_useNativeAudio',       'CV_BOOL',   'false' },
        { 'Use 2D audio',                          '$voice_use2dAudio',           'CV_BOOL',   'false' },
        { 'Use sending range only',                '$voice_useSendingRangeOnly',  'CV_BOOL',   'false' },
        { 'Enable UI',                             '$voice_enableUi',             'CV_INT',    '1' },
        { 'Enable F11 proximity key',              '$voice_enableProximityCycle', 'CV_INT',    '1' },
        { 'Proximity cycle key',                   '$voice_defaultCycle',         'CV_STRING', 'F11' },
        { 'Voice radio volume',                    '$voice_defaultRadioVolume',   'CV_INT',    '30' },
        { 'Voice call volume',                     '$voice_defaultCallVolume',    'CV_INT',    '60' },
        { 'Enable radios',                         '$voice_enableRadios',         'CV_INT',    '1' },
        { 'Enable calls',                          '$voice_enableCalls',          'CV_INT',    '1' },
        { 'Enable submix',                         '$voice_enableSubmix',         'CV_INT',    '1' },
        { 'Enable radio animation',                '$voice_enableRadioAnim',      'CV_INT',    '1' },
        { 'Radio key',                             '$voice_defaultRadio',         'CV_STRING', 'LMENU' },
        { 'Proximity refresh rate (ms)',           '$voice_refreshRate',          'CV_INT',    '200' },
        { 'Allow players to set audio intent',     '$voice_allowSetIntent',       'CV_INT',    '1' },
        { 'External mumble server address',        '$voice_externalAddress',      'CV_STRING', '' },
        { 'External mumble server port',           '$voice_externalPort',         'CV_INT',    '0' },
        { 'Voice debug mode',                      '$voice_debugMode',            'CV_INT',    '0' },
        { 'Disable players being allowed to join', '$voice_externalDisallowJoin', 'CV_INT',    '0' },
        { 'Hide server endpoints in logs',         '$voice_hideEndpoints',        'CV_INT',    '1' },
        { 'pma-voice compatibility bridge',        '$voice_pmaBridge',            'CV_INT',    '0' },
        { 'Jobs that can listen to several radio channels', '$voice_multiListenTypes', 'CV_STRING', 'dispatch' },
    }
}
