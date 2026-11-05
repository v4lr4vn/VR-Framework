fx_version 'cerulean'
game 'gta5'

vr_name 'vr-keybinds'
lua54 'yes'

name 'vr-keybinds'
author 'ValRavn'
description 'Player-chosen key bindings for every ValRavn script. Nothing is bound until the player picks a key.'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    'config.lua',
    'shared/keys.lua',
}

client_scripts {
    '@vr-bridge/import.lua',
    'client/main.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'import.lua',
}
