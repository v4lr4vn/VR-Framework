fx_version 'cerulean'
game 'gta5'
lua54 'yes'

vr_name 'vr-signrobbery'
name 'vr-signrobbery'
author 'ValRavn'
description 'Steal road signs, carry them around and scrap them for materials'
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

client_script 'client/main.lua'
server_script 'server/main.lua'
