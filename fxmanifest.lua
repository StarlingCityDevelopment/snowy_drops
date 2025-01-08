--[[ FX Information ]]--
fx_version   'cerulean'
use_experimental_fxv2_oal 'yes'
lua54        'yes'
game         'gta5'

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
    'config/client.lua'
}
