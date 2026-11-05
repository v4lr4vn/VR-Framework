fx_version 'cerulean'
game 'gta5'

vr_name 'vr-doorlock'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-doorlock'
author 'ValRavn'
description 'ValRavn door locks with an in-game editor in the Night Shift style'
version '1.0.0'

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/editor.lua',
    'client/lockpick.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'html/sounds/*',
    'icons/*.png',
    'locales/*.json',
}

dependencies {
    'vr-lib',
    'vr-bridge',
}

vr_lib 'locale'
