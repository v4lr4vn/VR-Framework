fx_version 'cerulean'
game 'gta5'

vr_name 'vr-cityhall'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-cityhall'
author 'ValRavn'
description 'City Hall for ValRavn: replace a lost ID or licence, the Job Centre and business licences'
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

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

client_scripts {
    'client/main.lua',
    'client/desk.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/documents.lua',
    'server/jobcentre.lua',
    'server/business.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
}
