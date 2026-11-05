fx_version 'cerulean'
game 'gta5'

vr_name 'vr-multijob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-multijob'
author 'ValRavn'
description 'Job menu for ValRavn: hold several jobs, switch between them, go on or off duty and leave a job'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/store.lua',
    'server/jobs.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
}
