fx_version 'cerulean'
game 'gta5'

vr_name 'vr-wellness'
lua54 'yes'

name 'vr-wellness'
author 'ValRavn'
description 'Stress relief: yoga spots and smoking, for vr-core and vr-hud'
version '1.0.0'

dependencies { 'vr-core', 'vr-ui', 'vr-target', 'vr-inventory' }

shared_script 'config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'
