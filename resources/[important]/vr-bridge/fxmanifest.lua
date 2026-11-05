fx_version 'cerulean'
game 'gta5'

vr_name 'vr-bridge'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-bridge'
author 'ValRavn'
description 'One API for vr-core, Qbox, QBCore, ESX and ox_core scripts: players, money, jobs, items, targets, society, vehicles and voice'
version '1.0.0'

server_scripts {
    'server/service.lua',
    'integrity.lua',
}

client_script 'client/service.lua'

files {
    'import.lua',
    'config.lua',
    'shared/*.lua',
    'client/*.lua',
    'client/**/*.lua',
}

escrow_ignore {
    'config.lua',
}
