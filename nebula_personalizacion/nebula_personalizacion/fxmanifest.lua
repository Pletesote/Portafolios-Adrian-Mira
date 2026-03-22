fx_version 'cerulean'
game 'gta5'

description 'Sistema para Tiendas de Personalizacion de Objetos'

shared_scripts {
    '@es_extended/imports.lua',
    '@ox_lib/init.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/main.lua'
}