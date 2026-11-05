fx_version 'cerulean'
game 'gta5'

vr_name 'vr-pedscale'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vr-pedscale'
author 'ValRavn'
description 'Per-character height (ped scale) for vr-core, synced to everyone'
version '1.0.0'

dependency 'vr-core'

shared_script 'config.lua'
client_script 'client/client.lua'
server_script 'server/server.lua'
