fx_version 'cerulean'
game 'gta5'

vr_name 'vr-clothing'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

name 'vr-clothing'
author 'ValRavn (based on illenium-appearance by snakewiz & iLLeniumStudios)'
description 'Clothing, barbers, tattoos, surgeons, outfits and character creation for vr-core'
version '1.0.0'

dependencies {
    'vr-core',
    'vr-lib',
}

shared_scripts {
    '@vr-lib/init.lua',
    'shared/config.lua',
    'shared/theme.lua',
    'shared/blacklist.lua',
    'shared/peds.lua',
    'shared/tattoos.lua',
    'shared/framework/framework.lua',
    'locales/init.lua',
    'locales/languages/*.lua',
}

client_scripts {
    'client/compat.lua',
    'modules/required/client/**/*.lua',
    'game/constants.lua',
    'game/bridge.lua',
    'game/util.lua',
    'game/customization.lua',
    'game/nui.lua',
    'client/outfits.lua',
    'client/common.lua',
    'client/zones.lua',
    'client/framework/framework.lua',
    'client/framework/compat.lua',
    'client/framework/core.lua',
    'client/target/target.lua',
    'client/target/vrtarget.lua',
    'client/management/management.lua',
    'client/management/common.lua',
    'client/management/bossmenu.lua',
    'client/radial/radial.lua',
    'client/radial/vrui.lua',
    'client/stats.lua',
    'client/defaults.lua',
    'client/blips.lua',
    'client/props.lua',
    'client/client.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/database/database.lua',
    'server/database/schema.lua',
    'server/database/managementoutfits.lua',
    'server/database/playeroutfitcodes.lua',
    'server/database/playeroutfits.lua',
    'server/database/players.lua',
    'server/database/playerskins.lua',
    'server/framework/core.lua',
    'server/util.lua',
    'server/server.lua',
    'server/permissions.lua',
}

ui_page 'dist/index.html'

files {
    'dist/index.html',
    'dist/images/*.png',
    'dist/images/*.webp',
    'dist/assets/*.js',
    'dist/assets/*.css',
    'dist/nightshift.css',
    'dist/fonts/*.woff2',
    'modules/utility/shared/**/*.lua',
}
