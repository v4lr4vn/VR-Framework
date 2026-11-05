fx_version 'cerulean'
game 'gta5'

vr_name 'vr-adminmenu'
lua54 'yes'

name 'vr-adminmenu'
author 'Project Sloth & OK1ez (vr-core port)'
version '1.0.0'
description 'Admin menu for vr-core (port of the Project Sloth admin menu)'

ui_page 'html/index.html'

shared_scripts {
    '@vr-lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/utils.lua',
    'client/data.lua',
    'client/chat.lua',
    'client/inventory.lua',
    'client/misc.lua',
    'client/noclip.lua',
    'client/players.lua',
    'client/spectate.lua',
    'client/teleport.lua',
    'client/toggle_laser.lua',
    'client/troll.lua',
    'client/vehicles.lua',
    'client/world.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/main.lua',
    'server/utils.lua',
    'server/chat.lua',
    'server/inventory.lua',
    'server/misc.lua',
    'server/players.lua',
    'server/regcommands.lua',
    'server/resources.lua',
    'server/spectate.lua',
    'server/teleport.lua',
    'server/trolls.lua',
    'server/vehicle.lua',
    'server/world.lua',
}

files {
    'html/**',
    'data/ped.lua',
    'data/object.lua',
    'data/locations.lua',
    'locales/*.json',
}

vr_lib 'locale'

dependencies {
    'vr-core',
    'vr-mysql',
    'vr-lib',
    'vr-inventory',
}
