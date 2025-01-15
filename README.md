# snowy_drops
 
## How to set up?
1. Download as Zip or clone the repository
2. Install it on your server
3. Run `ensure snowy_drops` in your server console
4. Its done!

## How to add more props?
1. Go into the `snowy_drops` folder
2. Go into the `config/client.lua` file
3. Add your props as this (insdie the dropItems table):
```lua
item_name = "spawn_code",
```
4. Save the file
5. Restart the script
6. Its done!

## My customdrop model is different then configured?
This is because we changed the dropmodel convar so that we can correctly remove the model spawned by ox_inventory, if you are using this resource please always set a [dropmodel](https://overextended.dev/ox_inventory/Functions/Server#customdrop) on custom drops.

## Dependencies
- (ox_inventory)[https://github.com/overextended/ox_inventory] v2.43.5 or higher
- (ox_lib)[https://github.com/overextended/ox_lib] v3.27.0 or higher
- (ox_target)[https://github.com/overextended/ox_target] if enabled in config
- (interact)[https://github.com/darktrovx/interact] if enabled in config

# Credits
- Special Credits to [@0Programmer](https://github.com/0Programmer) for the spawning part!
- Me for adding the Interact / Target support.