fx_version 'cerulean'
game 'gta5'

vr_name 'vr-ui'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-ui'
author 'ValRavn'
description 'ValRavn interface: notifications, prompts, menus, dialogs, progress, skill checks and radial in the Night Shift style'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    '@vr-keybinds/import.lua',
    'client/core.lua',
    'client/notify.lua',
    'client/textui.lua',
    'client/progress.lua',
    'client/context.lua',
    'client/menu.lua',
    'client/dialogs.lua',
    'client/skillcheck.lua',
    'client/radial.lua',
    'client/clipboard.lua',
    'client/radial_test.lua',
}

server_scripts {
    'server/notify.lua',
    'server/props.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
}

escrow_ignore {
    'config.lua',
}
