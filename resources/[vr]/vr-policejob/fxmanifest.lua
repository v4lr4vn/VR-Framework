fx_version 'cerulean'
use_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

vr_name 'vr-policejob'

name 'vr-policejob'
author 'Arius Scripts (vr-core port: ValRavn)'
description 'Police job for vr-core (port of Arius Scripts police job)'
version '1.0.0'

shared_scripts {
	'@vr-lib/init.lua',
	'config.lua',
}

client_scripts {
	'modules/utils/client.lua',
	'client.lua',

	'modules/compatibility/frameworks/vr/client.lua',

	'modules/job/menu/client/main.lua',
	'modules/job/menu/client/menus.lua',

	'modules/job/actions/client/clothing.lua',
	'modules/job/actions/client/armory.lua',
	'modules/job/actions/client/garage.lua',
	'modules/job/actions/client/interdict_area.lua',
	'modules/job/actions/client/stashes.lua',
	'modules/job/actions/client/cameras.lua',
	'modules/job/actions/client/bossmenu.lua',
	'modules/job/actions/client/duty.lua',

	'modules/job/interactions/client.lua',
	'modules/job/interactions/drag/client.lua',
	'modules/job/interactions/handcuffs/client.lua',
	'modules/job/interactions/fine/client.lua',
	'modules/job/interactions/escort/client.lua',
	'modules/job/interactions/props/client.lua',
	'modules/job/items/cuffs/client.lua',
}

server_scripts {
	'modules/utils/server.lua',
	'modules/compatibility/frameworks/vr/server.lua',
	'server.lua',
	'modules/job/menu/server.lua',
	'modules/job/interactions/handcuffs/server.lua',
	'modules/job/interactions/drag/server.lua',
	'modules/job/interactions/escort/server.lua',
	'modules/job/interactions/fine/server.lua',
}

files {
	'locales/*.json',
}

dependencies {
	'vr-core',
	'vr-lib',
	'vr-inventory',
	'vr-target',
}
