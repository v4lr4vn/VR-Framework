fx_version 'cerulean'
game 'gta5'
lua54 'yes'

vr_name 'vr-fuel'
name 'vr-fuel'
author 'ValRavn'
description 'Fuel for every vehicle: consumption, pumps, petrol cans and siphoning'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
    'vr-target',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/refuel.lua',
}

server_script 'server/main.lua'

