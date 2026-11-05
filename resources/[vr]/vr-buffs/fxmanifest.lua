fx_version 'cerulean'
game 'gta5'
lua54 'yes'

vr_name 'vr-buffs'
name 'vr-buffs'
author 'ValRavn'
description 'Timed buffs and enhancements: icons on the hud, health and armour over time, stress relief, run and swim speed'
version '1.0.0'

shared_scripts {
    '@vr-bridge/import.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_script 'server/main.lua'

dependencies {
    'vr-bridge',
}
