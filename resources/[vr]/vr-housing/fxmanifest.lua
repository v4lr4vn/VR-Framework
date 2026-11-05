fx_version 'cerulean'
game 'gta5'

vr_name 'vr-housing'
lua54 'yes'

name 'vr-housing'
author 'ValRavn (based on ps-housing by Xirvin & Project Sloth)'
description 'Houses, apartments, furniture and storage for vr-core (ported from ps-housing by Xirvin & Project Sloth)'
version '1.0.0'

provide 'ps-housing'

ui_page 'html/index.html'

dependencies {
    'vr-core',
    'vr-lib',
    'vr-target',
    'vr-inventory',
    'fivem-freecam',
}

shared_scripts {
    '@vr-lib/init.lua',
    'shared/config.lua',
    'shared/framework.lua',
}

client_scripts {
    'client/shell.lua',
    'client/apartment.lua',
    'client/cl_property.lua',
    'client/client.lua',
    'client/modeler.lua',
}

server_scripts {
    '@vr-mysql/lib/MySQL.lua',
    'server/sv_property.lua',
    'server/server.lua',
}

files {
    'html/**',
    'stream/**.ytyp',
}

data_file 'DLC_ITYP_REQUEST' 'x64c:/levels/gta5/interiors/int_props/int_corporate.rpf/int_corporate.ytyp'
data_file 'DLC_ITYP_REQUEST' 'x64c:/levels/gta5/interiors/int_props/int_industrial.rpf/int_industrial.ytyp'
data_file 'DLC_ITYP_REQUEST' 'x64c:/levels/gta5/interiors/int_props/int_lev_des.rpf/int_lev_des.ytyp'
data_file 'DLC_ITYP_REQUEST' 'x64c:/levels/gta5/interiors/int_props/int_residential.rpf/int_residential.ytyp'
data_file 'DLC_ITYP_REQUEST' 'x64c:/levels/gta5/interiors/int_props/int_retail.rpf/int_retail.ytyp'
data_file 'DLC_ITYP_REQUEST' 'x64c:/levels/gta5/interiors/int_props/int_services.rpf/int_services.ytyp'

data_file 'DLC_ITYP_REQUEST' 'stream/**.ytyp'

this_is_a_map 'yes'
