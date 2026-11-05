fx_version 'cerulean'
game 'common'

vr_name 'vr-mysql'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
node_version '22'

name 'vr-mysql'
author 'ValRavn (based on oxmysql by Overextended)'
version '1.0.0'
license 'LGPL-3.0-or-later'
description 'FXServer to MySQL communication via node-mysql2'

dependencies {
    '/server:12913',
}

server_script 'dist/build.js'

provide 'oxmysql'
provide 'mysql-async'
provide 'ghmattimysql'

convar_category 'VR-MySQL' {
	'Configuration',
	{
		{ 'Connection string', 'mysql_connection_string', 'CV_STRING', 'mysql://user:password@localhost/database' },
		{ 'Debug', 'mysql_debug', 'CV_BOOL', 'false' },
		{ 'Slow query warning (ms)', 'mysql_slow_query_warning', 'CV_INT', '200' },
	}
}
