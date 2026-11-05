fx_version 'cerulean'
game 'gta5'

vr_name 'vr-prison'
lua54 'yes'

name 'vr-prison'
author 'ValRavn'
description 'Life inside the prison: cells, outfits, work and workout stations, the canteen. Sentences come from vr-mdt'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
    'vr-mdt',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/admin.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/main.lua',
    'server/admin.lua',
}
