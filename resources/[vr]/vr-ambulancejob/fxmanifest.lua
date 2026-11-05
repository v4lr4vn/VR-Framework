fx_version 'cerulean'
use_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

vr_name 'vr-ambulancejob'

name 'vr-ambulancejob'
version '1.0.0'
author 'Arius Scripts (vr-core port: ValRavn)'
description 'Advanced ambulance job with integrated death system (vr-core port of the Arius Scripts ambulance job)'

shared_script '@vr-lib/init.lua'

vr_libs {
	'locale',
}

client_scripts {
	"modules/utils/client/utils.lua",

	"client.lua",

	"modules/compatibility/frameworks/vr/client.lua",
	"modules/compatibility/target/vr_target.lua",

	"modules/injuries/client.lua",
	"modules/death/client.lua",
	"modules/stretcher/client.lua",
	"modules/paramedic/client.lua",

	"modules/job/client/main.lua",
	"modules/job/client/garage.lua",
	"modules/job/client/medical_bag.lua",
	"modules/job/client/stashes.lua",
	"modules/job/client/shops.lua",
	"modules/job/client/clothing.lua",
	"modules/job/client/bossmenu.lua",

	"modules/utils/client/coords_debug.lua",
}

server_scripts {
	"modules/compatibility/frameworks/vr/server.lua",
	"server.lua",
	"modules/commands/server.lua",
	"modules/compatibility/txadmin/server.lua",
}

files {
	'locales/*.json',
	"data/*.lua",
	'config.lua',
}

dependencies {
	'vr-core',
	'vr-lib',
	'vr-inventory',
	'vr-target',
}
