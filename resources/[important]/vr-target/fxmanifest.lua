fx_version 'cerulean'
game 'gta5'

vr_name 'vr-target'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

name 'vr-target'
author 'ValRavn (based on ox_target by Overextended)'
description 'ValRavn third-eye targeting with an aim-to-pick reticle in the Night Shift style'
version '1.0.0'
provide 'ox_target'
provide 'qb-target'
provide 'qtarget'
license 'GPL-3.0-or-later'

shared_scripts {
    '@vr-lib/init.lua',
    'config.lua',
}

client_scripts {
    '@vr-bridge/import.lua',
    'client/utils.lua',
    'client/api.lua',
    'client/main.lua',
    'client/defaults.lua',
    'client/compat.lua',
}

server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'locales/*.json',
}

dependencies {
    'vr-bridge',
    'vr-lib',
}

vr_lib 'locale'
