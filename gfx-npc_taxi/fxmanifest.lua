fx_version 'cerulean'
lua54 'yes'
author 'Grafix'
version '1.0.0'
description 'NPC Taxi Service using payphones'

client_script {
    'client/*.lua',
    'client/classes/*.lua',
}
server_script {
    'server/*.lua',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

