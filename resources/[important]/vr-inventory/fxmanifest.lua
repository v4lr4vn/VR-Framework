fx_version 'cerulean'
game 'gta5'

vr_name 'vr-inventory'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-inventory'
author 'ValRavn (based on ox_inventory by Overextended)'
description 'ValRavn slot inventory in the Night Shift style'
version '1.0.0'
license 'GPL-3.0-or-later'
provide 'ox_inventory'
provide 'qb-inventory'

dependencies {
    '/server:6116',
    '/onesync',
    'vr-bridge',
    'vr-lib',
    'vr-ui',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/items.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/items.lua',
    'server/hooks.lua',
    'server/db.lua',
    'server/inventory.lua',
    'server/actions.lua',
    'server/shops.lua',
    'server/crafting.lua',
    'server/framework/bridge.lua',
    'server/main.lua',
    'shared/compat.lua',
}

client_scripts {
    'client/utils.lua',
    'client/items.lua',
    'client/weapon.lua',
    'client/inventory.lua',
    'client/shops.lua',
    'client/crafting.lua',
    'client/framework/bridge.lua',
    'client/main.lua',
    'shared/compat.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'html/licenses/*',
    'web/images/*.png',
    'web/images/*.webp',
    'locales/*.json',
    'data/*.lua',
}

vr_lib 'locale'
