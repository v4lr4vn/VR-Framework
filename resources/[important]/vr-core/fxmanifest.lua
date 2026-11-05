fx_version 'cerulean'
game 'gta5'

vr_name 'vr-core'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-core'
author 'ValRavn'
description 'vr-core made by ValRavn for the ValRavn Framework'
version '1.0.0'
provide 'qb-core'

shared_scripts {
    'config.lua',
    'shared/locale.lua',
    'locale/en.lua',
    'shared/main.lua',
    'shared/functions.lua',
    'shared/items.lua',
    'shared/jobs.lua',
    'shared/vehicles.lua',
    'shared/gangs.lua',
    'shared/weapons.lua',
    'shared/locations.lua',
}

client_scripts {
    'client/functions.lua',
    'client/vehicle.lua',
    'client/events.lua',
    'client/drawtext.lua',
    'client/main.lua',
    'client/world.lua',
    'bridge/qb/client.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/database.lua',
    'server/functions.lua',
    'server/player.lua',
    'server/events.lua',
    'server/commands.lua',
    'server/loops.lua',
    'server/society.lua',
    'server/exports.lua',
    'server/world.lua',
    'server/integrity.lua',
    'bridge/qb/server.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependency 'vr-mysql'
