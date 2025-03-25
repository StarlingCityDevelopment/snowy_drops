--[[ FX Information ]]--
fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

author 'Snowy and 0Programmer aka CrossSet'
description 'Visual items for ox_inventory drop stashes'
version '1.2.2'

ox_lib 'locale'

--[[ Manifest ]]--
shared_scripts {
    '@ox_lib/init.lua'
}
server_scripts {
    'server/*.lua'
}
client_scripts {
    'client/*.lua'
}
files {
    'config/client.lua',
    'config/items.lua',
    'config/rotations.lua',
    'locales/*.json',
}