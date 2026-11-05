fx_version 'cerulean'
name 'vr-loading'
games { 'gta5' }

vr_name 'vr-loading'
lua54 'yes'

author 'ValRavn'
description 'ValRavn loading screen: real progress, news, tips and a music player. Edit web/config.js.'
version '1.0.0'

loadscreen 'web/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'

client_script 'client.lua'
server_script 'server.lua'

files {
    'web/index.html',
    'web/style.css',
    'web/config.js',
    'web/app.js',
    'web/fonts/*.woff2',
    'web/backgrounds/*',
    'song/*',
}
