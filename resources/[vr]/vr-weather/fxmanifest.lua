fx_version 'cerulean'
game 'gta5'

vr_name 'vr-weather'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-weather'
author 'ValRavn'
description 'Synced weather, time and seasons with a configurable day length'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/time.lua',
    'shared/weather.lua',
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@vr-bridge/import.lua',
    'server/main.lua',
    'server/admin.lua',
    'server/exports.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

provides {
    'qb-weathersync',
    'vr-weathersync',
}

dependency 'vr-bridge'
