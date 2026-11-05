fx_version 'cerulean'
game 'gta5'

vr_name 'vr-hud'
lua54 'yes'

name 'vr-hud'
author 'ValRavn'
description 'Player and vehicle HUD for any framework through vr-bridge, in the vr-ui theme'
version '1.0.0'

dependencies {
    'vr-bridge',
}
shared_scripts {
    '@vr-bridge/import.lua',
    'config.lua',
}
client_scripts {
    '@vr-keybinds/import.lua',
    'client/postal.lua',
    'client/minimap.lua',
    'client/stress.lua',
    'client/main.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'data/postals.json',
}

