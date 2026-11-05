fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
game 'gta5'

vr_name 'vr-realtor'
lua54 'yes'

name 'vr-realtor'
author 'ValRavn (based on ps-realtor by Xirvin & Project Sloth)'
description 'Real estate tablet for vr-housing (ported from ps-realtor by Xirvin & Project Sloth)'
version '1.0.0'

ui_page 'html/index.html'

dependencies {
    'vr-core',
    'vr-housing',
    'vr-lib',
    'fivem-freecam',
}

shared_scripts {
    '@vr-lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/server.lua',
}

client_scripts {
    'client/client.lua',
    'client/createProperty.lua',
    'client/sync.lua',
    'client/zoneCreator.lua',
}

files {
    'html/**',
}
