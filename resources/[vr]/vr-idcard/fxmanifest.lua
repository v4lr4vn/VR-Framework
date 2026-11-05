fx_version 'cerulean'
game 'gta5'

vr_name 'vr-idcard'

name 'vr-idcard'
author 'ValRavn (based on um-idcard by uyuyorum)'
version '1.0.0'
description 'On-screen ID cards and licences for vr-core'

shared_scripts {
	'@vr-lib/init.lua',
}

vr_lib 'locale'

ui_page 'web/index.html'

files {
	'config.lua',
	'web/index.html',
	'web/assets/**',
	'web/dist/**',
	'locales/*.json',
}

client_scripts {
	'client/*.lua',
}

server_scripts {
	'@vr-mysql/lib/MySQL.lua',
	'bridge/**',
	'server/*.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
nui_callback_strict_mode 'true'

dependencies {
	'vr-lib',
	'vr-core',
	'vr-inventory',
}
