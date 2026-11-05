fx_version 'cerulean'
game 'gta5'

vr_name 'vr-mechanic'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-mechanic'
author 'ValRavn'
description 'Mechanic job for ValRavn: part wear and breakdowns, repairs with parts, performance upgrades and cosmetic tuning'
version '1.0.0'

dependencies {
    'vr-core',
    'vr-lib',
    'vr-mysql',
    'vr-target',
    'vr-inventory',
}

shared_scripts {
    '@vr-lib/init.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/fitting.lua',
}

client_scripts {
    'client/main.lua',
    'client/camera.lua',
    'client/anim.lua',
    'client/workshops.lua',
    'client/wear.lua',
    'client/effects.lua',
    'client/repair.lua',
    'client/tuning.lua',
    'client/design.lua',
    'client/orders.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/core.lua',
    'server/db.lua',
    'server/workshops.lua',
    'server/cars.lua',
    'server/wear.lua',
    'server/work.lua',
    'server/tuning.lua',
    'server/orders.lua',
    'server/bills.lua',
    'server/shop.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}
