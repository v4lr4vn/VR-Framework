fx_version 'cerulean'
game 'gta5'

vr_name 'vr-recycle'
lua54 'yes'

name 'vr-recycle'
author 'ValRavn'
description 'Recycling: sorting line, dumpster diving, scrap searching, a materials trader, buyers and bottle banks. Places are set in game'
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
