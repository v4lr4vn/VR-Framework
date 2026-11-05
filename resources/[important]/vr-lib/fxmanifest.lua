fx_version 'cerulean'
game 'gta5'

vr_name 'vr-lib'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-lib'
author 'ValRavn (based on ox_lib by Overextended)'
description 'ValRavn shared library: callbacks, zones, points, streaming, locale, commands, keybinds and UI helpers'
version '1.0.0'
license 'LGPL-3.0-or-later'
provide 'ox_lib'

dependencies {
    '/onesync',
    'vr-ui',
}

files {
    'init.lua',
    'imports/**/client.lua',
    'imports/**/shared.lua',
}

shared_script 'resource/shared.lua'
client_script 'resource/client.lua'
server_scripts {
    'resource/server.lua',
    'resource/integrity.lua',
}
