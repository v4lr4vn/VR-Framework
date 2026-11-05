fx_version 'cerulean'
game 'gta5'

vr_name 'vr-admintools'
lua54 'yes'

name 'vr-admintools'
author 'ValRavn'
description 'Admin tab in the radial menu: one click opens each creator instead of typing its command. Only admins see it'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-ui',
}

shared_scripts {
    '@vr-bridge/import.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}
