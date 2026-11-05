fx_version 'cerulean'
game 'gta5'

vr_name 'vr-banking'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-banking'
author 'ValRavn'
description 'Banking for ValRavn: accounts, cards and ATMs, savings, loans, credit scores and debt collection'
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
    'client/branches.lua',
    'client/atm.lua',
    'client/collections.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/sha256.lua',
    'server/core.lua',
    'server/db.lua',
    'server/accounts.lua',
    'server/credit.lua',
    'server/cards.lua',
    'server/loans.lua',
    'server/collections.lua',
    'server/savings.lua',
    'server/repo.lua',
    'server/external.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
    'server/admin.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}
