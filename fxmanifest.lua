--[[ FX Information ]]--
fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

author 'Snowy and 0Programmer (CrossSet)'
description 'Drop items on the ground'
version '1.1.0'

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
    'config/items.lua'
}
