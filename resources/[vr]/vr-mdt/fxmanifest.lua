fx_version 'cerulean'
game 'gta5'

vr_name 'vr-mdt'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-mdt'
author 'ValRavn'
description 'Mobile data terminal and dispatch for police, EMS and the DOJ'
version '1.0.0'

dependencies {
    'vr-bridge',
}

shared_scripts {
    '@vr-bridge/import.lua',
    'config.lua',
    'config/*.lua',
    'shared/utils.lua',
    'shared/perms.lua',
    'shared/codes.lua',
    'shared/zones.lua',
}

client_scripts {
    '@vr-keybinds/import.lua',
    'client/init/main.lua',
    'client/modules/*.lua',
}

server_scripts {
    'server/init/db.lua',
    'server/init/core.lua',
    'server/modules/*.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/index.html',
    'web/dist/**/*',
    'sounds/*',
}

provides {
    'vr-dispatch',
    'ps-dispatch',
}

escrow_ignore {
    'config.lua',
}
