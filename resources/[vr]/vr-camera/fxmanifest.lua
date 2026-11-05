fx_version 'cerulean'
game 'gta5'

vr_name 'vr-camera'
lua54 'yes'

name 'vr-camera'
author 'Project Sloth (ps-camera), vr-bridge port: ValRavn'
description 'Camera item that takes photos you can keep as items (stored in your own database)'
version '1.0.0'

dependencies {
    'vr-bridge',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    '@vr-bridge/import.lua',
    'config.lua',
}

client_scripts {
    'client/cl_main.lua',
}

server_scripts {
    '@vr-bridge/mysql.lua',
    'server/sv_main.lua',
}

ui_page 'client/nui/index.html'

files {
    'client/nui/index.html',
    'client/nui/app.js',
    'client/nui/main.css',
    'client/nui/vendor/*.css',
    'client/nui/vendor/*.js',
    'client/nui/vendor/fonts/*.woff2',
    'client/nui/vendor/webfonts/*.woff2',
}

data_file 'DLC_ITYP_REQUEST' 'stream/ps_camera.ytyp'
