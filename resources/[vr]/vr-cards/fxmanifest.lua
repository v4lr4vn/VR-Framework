fx_version 'cerulean'
game 'gta5'

vr_name 'vr-cards'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-cards'
author 'ValRavn'
description 'ValRavn trading cards: booster packs, foils, binders and grading'
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
}

client_scripts {
    'client/main.lua',
    'client/shop.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'cards.lua',
    'server/core.lua',
    'server/db.lua',
    'server/catalog.lua',
    'server/copies.lua',
    'server/packs.lua',
    'server/binders.lua',
    'server/shop.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
    'images/*',
}
