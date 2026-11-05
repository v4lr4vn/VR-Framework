fx_version 'cerulean'
game 'gta5'

vr_name 'vr-djbooth'
lua54 'yes'

name 'vr-djbooth'
author 'ValRavn'
description 'Placeable speakers, linked sound systems, boomboxes and car stereos with a shared song queue'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/lang.lua',
}

client_scripts {
    '@vr-keybinds/import.lua',
    'client/main.lua',
    'client/audio.lua',
    'client/placement.lua',
    'client/vehicle.lua',
    'client/zones.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/places.lua',
    'server/boosters.lua',
    'server/playback.lua',
    'server/speakers.lua',
    'server/vehicles.lua',
    'server/zones.lua',
}

ui_page 'html/index.html'

escrow_ignore {
    'config.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/audio.js',
    'html/app.js',
    'html/fonts/*.woff2',
}
