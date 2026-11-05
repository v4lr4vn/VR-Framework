fx_version 'cerulean'
game 'gta5'

vr_name 'vr-emotes'
lua54 'yes'

name 'vr-emotes'
author 'ValRavn (based on rpemotes by TayMcKenzieNZ and contributors, via WC Emotes V5 by White Custom)'
description 'Emotes, dances, walking styles and moods with a live preview and player-chosen quick keys'
version '1.0.0'
license 'GPL-3.0-or-later'

dependencies {
    '/onesync',
    'vr-lib',
    'vr-mysql',
}

shared_scripts {
    '@vr-lib/init.lua',
    'config.lua',
    'shared/lang.lua',
    'shared/animals.lua',
    'shared/animations.lua',
    'shared/catalog.lua',
}

client_scripts {
    '@vr-keybinds/import.lua',
    'client/utils.lua',
    'client/emote.lua',
    'client/shared.lua',
    'client/walk.lua',
    'client/preview.lua',
    'client/menu.lua',
    'client/crouch.lua',
    'client/pointing.lua',
    'client/extras.lua',
    'client/binoculars.lua',
    'client/newscam.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
}

data_file 'DLC_ITYP_REQUEST' 'stream/**/*.ytyp'
