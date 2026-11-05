fx_version 'cerulean'
game 'gta5'

vr_name 'vr-dealership'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-dealership'
author 'ValRavn'
description 'Vehicle dealerships for ValRavn: sales staff, self-service showroom, bank finance and test drives'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
    'vr-garages',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/main.lua',
    'client/showroom.lua',
    'client/preview.lua',
    'client/testdrive.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/dealers.lua',
    'server/sales.lua',
    'server/testdrive.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}
