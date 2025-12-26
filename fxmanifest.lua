fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'aprts_shops'

ui_page 'web/index.html'

shared_scripts { '@ox_lib/init.lua', 'config.lua' }

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/bridge.lua', -- ZDE TO CHYBĚLO
    'server/main.lua'
}

client_scripts { 'client/main.lua' }

files {
    'web/index.html',
    'web/style.css',
    'web/script.js'
}

dependencies { 'ox_lib', 'ox_inventory', 'ox_target', 'qb-core' }