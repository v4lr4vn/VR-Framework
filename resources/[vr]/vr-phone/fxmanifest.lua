fx_version 'cerulean'
game 'gta5'

vr_name 'vr-phone'
shared_script 'guard.lua'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-phone'
author 'ValRavn'
description 'Foldable smartphone for roleplay servers. The host that other vr- scripts add apps to.'
version '0.9.0'

dependencies {
    '/onesync',
    'vr-lib',
    'vr-mysql',
    'vr-bridge',
}

shared_scripts {
    '@vr-lib/init.lua',
    'config/phone.lua',
    'config/apps.lua',
    'config/signal.lua',
    'config/prop.lua',
    'shared/util.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    '@vr-bridge/import.lua',
    'server/db.lua',
    'server/modules/session.lua',
    'server/modules/apps.lua',
    'server/modules/identity.lua',
    'server/modules/security.lua',
    'server/modules/settings.lua',
    'server/modules/signal.lua',
    'server/modules/battery.lua',
    'server/modules/status.lua',
    'server/modules/notifications.lua',
    'server/modules/contacts.lua',
    'server/modules/voicemail.lua',
    'server/modules/messages.lua',
    'server/modules/voice.lua',
    'server/modules/media.lua',
    'server/modules/share.lua',
    'server/modules/notes.lua',
    'server/modules/planner.lua',
    'server/modules/mail.lua',
    'server/modules/wallet.lua',
    'server/modules/places.lua',
    'server/modules/health.lua',
    'server/modules/charging.lua',
    'server/modules/music.lua',
    'server/modules/veil.lua',
    'server/modules/hearth.lua',
    'server/modules/calls.lua',
    'server/modules/badges.lua',
    'server/main.lua',
    'server/comms.lua',
    'server/comms_apps.lua',
    'server/comms_music.lua',
    'server/comms_store.lua',
    'server/comms_social.lua',
    'server/exports.lua',
}

client_scripts {
    '@vr-bridge/import.lua',
    'client/state.lua',
    'client/modules/prop.lua',
    'client/modules/camera.lua',
    'client/modules/clock.lua',
    'client/modules/due.lua',
    'client/modules/world.lua',
    'client/modules/music.lua',
    'client/modules/charging.lua',
    'client/modules/nui.lua',
    'client/modules/notifications.lua',
    'client/modules/calls.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/assets/*',
    'html/tiles/**/*',
    'html/player.html',
    'html/sdk.js',
    'locales/*.json',
}
