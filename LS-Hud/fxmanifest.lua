fx_version 'cerulean'
game 'gta5'

author 'LSDev'
description 'LuaSpace Hud'
version '1.0.0'

client_scripts {
    'client/client.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua', 
    'server/server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'oulsen_satmap_postals.json',
    'assets/font.otf'
}

lua54 'yes'

dependency 'es_extended'
dependency 'esx_skin'
