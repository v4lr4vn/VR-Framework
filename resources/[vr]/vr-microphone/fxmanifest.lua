fx_version 'cerulean'
game 'gta5'
lua54 'yes'

vr_name 'vr-microphone'
name 'vr-microphone'
author 'ValRavn'
description 'Microphone stands and a megaphone item that carry your voice further (needs vr-voice)'
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
