fx_version 'cerulean'
game 'gta5'

vr_name 'vr-farming'
lua54 'yes'

name 'vr-farming'
author 'ValRavn'
description 'Fields, crops, watering and harvest. Fields and stores are placed in game by aiming'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/store.lua',
    'client/creator.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/main.lua',
    'server/growth.lua',
    'server/plants.lua',
    'server/store.lua',
    'server/admin.lua',
}

