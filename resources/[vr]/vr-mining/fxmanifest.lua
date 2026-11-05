fx_version 'cerulean'
game 'gta5'

vr_name 'vr-mining'
lua54 'yes'

name 'vr-mining'
author 'ValRavn'
description 'Mining: rock faces, stone cracking and washing, gold panning, smelting, gem cutting and buyers. Places are set in game'
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
    'client/admin.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/main.lua',
    'server/admin.lua',
}
