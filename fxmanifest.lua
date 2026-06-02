fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'jaiminator21'
description 'Sistema de amigos para Qbox (qbx_core): nombres sobre la cabeza, ox_target y exports para chat (/me, /do)'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/overhead.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_target',
    'oxmysql',
}
