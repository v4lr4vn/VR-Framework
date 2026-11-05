fx_version 'cerulean'
game 'gta5'

vr_name 'vr-vehiclekeys'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-vehiclekeys'
author 'ValRavn'
description 'Vehicle keys for ValRavn: lock, engine, shared keys, lockpicking, hotwiring, carjacking and a locksmith'
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
    'client/lock.lua',
    'client/engine.lua',
    'client/breakin.lua',
    'client/menu.lua',
    'client/quick.lua',
    'client/locksmith.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/store.lua',
    'server/api.lua',
    'server/events.lua',
    'server/exports.lua',
    'server/main.lua',
}
