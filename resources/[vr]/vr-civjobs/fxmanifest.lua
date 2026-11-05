fx_version 'cerulean'
game 'gta5'

vr_name 'vr-civjobs'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

name 'vr-civjobs'
author 'ValRavn'
description 'Civilian Jobs Mega Pack for ValRavn: garbage, lumberjack, scrapyard, window cleaning, builder, trucker, taxi, bus, newspaper, hunter, fishing and treasure hunting'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
    'config/garbage.lua',
    'config/lumberjack.lua',
    'config/scrapyard.lua',
    'config/windowcleaner.lua',
    'config/builder.lua',
    'config/trucker.lua',
    'config/taxi.lua',
    'config/busdriver.lua',
    'config/newspaper.lua',
    'config/hunter.lua',
    'config/fisherman.lua',
    'config/treasurehunter.lua',
    'shared/utils.lua',
    'shared/setup.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/**/*',
}

client_scripts {
    'client/lib.lua',
    'client/main.lua',
    'client/setup.lua',
    'client/jobs/garbage.lua',
    'client/jobs/lumberjack.lua',
    'client/jobs/scrapyard.lua',
    'client/jobs/windowcleaner.lua',
    'client/jobs/builder.lua',
    'client/jobs/trucker.lua',
    'client/jobs/taxi.lua',
    'client/jobs/busdriver.lua',
    'client/jobs/newspaper.lua',
    'client/jobs/hunter.lua',
    'client/jobs/fisherman.lua',
    'client/jobs/treasurehunter.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/core.lua',
    'server/db.lua',
    'server/setup.lua',
    'server/progress.lua',
    'server/session.lua',
    'server/jobs/garbage.lua',
    'server/jobs/lumberjack.lua',
    'server/jobs/scrapyard.lua',
    'server/jobs/windowcleaner.lua',
    'server/jobs/builder.lua',
    'server/jobs/trucker.lua',
    'server/jobs/taxi.lua',
    'server/jobs/busdriver.lua',
    'server/jobs/newspaper.lua',
    'server/jobs/hunter.lua',
    'server/jobs/fisherman.lua',
    'server/jobs/treasurehunter.lua',
    'server/api.lua',
    'server/exports.lua',
    'server/main.lua',
}
