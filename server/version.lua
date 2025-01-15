lib.versionCheck('SSnowly/snowy_drops')
if not lib.checkDependency('ox_lib', '3.27.0', true) then
    error('ox_lib version 3.27.0 or higher is required')
elseif not lib.checkDependency('ox_inventory', '2.43.5', true) then
    error('ox_inventory version 2.43.5 or higher is required')
elseif GetConvarInt('onesync_enableInfinity', 0) ~= 1 then
    error('OneSync Infinity is not enabled. You can do so in txAdmin settings or add +set onesync on to your server startup command line')
end