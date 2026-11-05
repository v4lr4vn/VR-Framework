fx_version 'cerulean'
game 'gta5'

vr_name 'vr-fence'
lua54 'yes'

name 'vr-fence'
author 'ValRavn'
description 'Money laundering and a pawn shop. Spots are placed in game by aiming'
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
    'client/creator.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/main.lua',
    'server/launder.lua',
    'server/pawn.lua',
    'server/admin.lua',
}
