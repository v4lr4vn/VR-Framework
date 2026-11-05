fx_version 'cerulean'
game 'gta5'

vr_name 'vr-notepad'
lua54 'yes'

name 'vr-notepad'
author 'ValRavn'
description 'Write a note and leave it on the ground as a piece of paper for others to read or tear up'
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

client_scripts { 'client/main.lua' }
server_scripts { 'server/main.lua' }
