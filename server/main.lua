lib.callback.register('snowy_drops:callback:getInventoryItems', function(source, dropId)
    local items = {}
    local dropItems = exports.ox_inventory:GetInventoryItems(dropId, false)
    if dropItems then
        for _, item in pairs(dropItems) do
            items[item.name .. ":" .. item.slot] = true
        end
    end
    return items
end)
lib.callback.register('snowy_drops:callback:getDropItems', function(source, dropId)
    if not string.match(dropId, '^drop%-%d+$') then return end
    return exports.ox_inventory:GetInventory(dropId, false)
end)
local hookId = exports.ox_inventory:registerHook('swapItems', function(payload)
    if payload.fromType ~= payload.toType then
        local dropId = type(payload.fromInventory) == 'string' and payload.fromInventory or payload.toInventory
        TriggerClientEvent('snowy_drops:client:updateDropId', -1, dropId, (payload.toType == 'drop'), payload.fromSlot.name, payload.fromSlot.slot)
        return true
    end
end, {
    inventoryFilter = {
        '^drop%-%d+$',
    }
})

lib.callback.register('snowy_drops:server:pickupItem', function(source, dropId, itemData)
    local inventory = exports.ox_inventory:GetInventory(dropId)
    if not inventory or inventory.open or inventory.type ~= 'drop' or #(GetEntityCoords(GetPlayerPed(source)) - vec3(inventory.coords.x, inventory.coords.y, inventory.coords.z)) > 2.0 then return "no" end
    local item = inventory.items[itemData.slot]
    if not item or item.name ~= itemData.name then return  end
    
    local success = exports.ox_inventory:RemoveItem(dropId, itemData.name, itemData.count, item.metadata, itemData.slot)

    
    if success then
        exports.ox_inventory:AddItem(source, itemData.name, itemData.count, item.metadata)
        TriggerClientEvent('snowy_drops:client:updateDropId', -1, dropId, false, itemData.name, itemData.slot)
        return true
    end
    return false
end)