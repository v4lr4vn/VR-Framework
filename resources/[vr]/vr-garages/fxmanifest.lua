fx_version 'cerulean'
game 'gta5'

vr_name 'vr-garages'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-garages'
author 'ValRavn'
description 'Garages for ValRavn: public lots, job and gang garages, house garages and the impound'
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
    'client/zones.lua',
    'client/vehicles.lua',
    'client/impound.lua',
    'client/builder.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/garages.lua',
    'server/vehicles.lua',
    'server/spawn.lua',
    'server/jobvehicles.lua',
    'server/api.lua',
    'server/builder.lua',
    'server/exports.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

provide 'qb-garages'
