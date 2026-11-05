fx_version 'cerulean'
game 'gta5'

vr_name 'vr-bankheist'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

name 'vr-bankheist'
author 'ValRavn'
description 'Bank heists built in game: hack terminals, drill lock boxes, grab cash and gold, vault doors through vr-doorlock'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
    'shared/schema.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

client_scripts {
    'client/main.lua',
    'client/actions.lua',
    'client/drill.lua',
    'client/hack.lua',
    'client/creator.lua',
    'client/check.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/banks.lua',
    'server/heist.lua',
    'server/hack.lua',
    'server/creator.lua',
}
