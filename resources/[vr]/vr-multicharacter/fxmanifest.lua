fx_version 'cerulean'
game 'gta5'

vr_name 'vr-multicharacter'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-multicharacter'
author 'ValRavn'
description 'Character select, creation and spawn choice for vr-core (replaces vr-spawn)'
version '1.0.0'

-- vr-housing and other scripts still call exports['vr-spawn']:RegisterHouseProvider
provide 'vr-spawn'

shared_scripts {
    '@vr-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
    'spawn_client.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server.lua',
    'spawn_server.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/profanity.js',
    'web/map.jpg',
    'web/fonts/*.woff2',
}

dependencies {
    'vr-core',
}
