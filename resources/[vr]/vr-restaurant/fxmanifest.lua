fx_version 'cerulean'
game 'gta5'

vr_name 'vr-restaurant'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-restaurant'
author 'ValRavn'
description 'Food management: restaurants, staff and wages, licences, hygiene and inspections, plus everything vr-consumables did'
version '1.0.0'

-- This resource replaces vr-consumables. Scripts that call exports['vr-consumables'] keep working.
provide 'vr-consumables'

dependencies {
    'vr-bridge',
    'vr-lib',
    'vr-core',
    'vr-inventory',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
    'shared/emotes.lua',
    'shared/consumables.lua',
    'shared/normalize.lua',
    'shared/recipes.lua',
}

client_scripts {
    'client/effects.lua',
    'client/consume.lua',
    'client/main.lua',
    'client/boss.lua',
    'client/stations.lua',
    'client/hall.lua',
    'client/inspector.lua',
    'client/kitchen.lua',
    'client/creator.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/consume.lua',
    'server/main.lua',
    'server/business.lua',
    'server/compliance.lua',
    'server/stations.lua',
    'server/storage.lua',
    'server/kitchen.lua',
    'server/admin.lua',
    'server/jobs.lua',
}
