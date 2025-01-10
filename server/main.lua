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
    if not (payload.fromType == "drop" or payload.toType == "drop") then return end

    local dropId, isToDrop, newItem, oldItem
    local isInsideDrop = payload.fromType == "drop" and payload.toType == "drop" and payload.fromInventory == payload.toInventory

    if payload.fromType == "drop" then
        dropId = payload.fromInventory
        isToDrop = false
    else
        dropId = payload.toInventory
        isToDrop = true
    end

    local actions = {
        move = function()
            if isInsideDrop and payload.fromSlot.count > payload.count then
                oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
                newItem = { item = payload.fromSlot.name, slot = payload.toSlot }
                TriggerClientEvent('snowy_drops:client:updateDropId', -1, dropId, true, newItem, oldItem, isInsideDrop, true)
                return true
            end

            oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
            newItem = { item = payload.fromSlot.name, slot = payload.toSlot or payload.fromSlot.slot }
        end,

        swap = function()
            newItem = { item = payload.toSlot.name, slot = payload.toSlot.slot }
            oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
        end,

        stack = function()
            if isInsideDrop then
                oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
                TriggerClientEvent('snowy_drops:client:updateDropId', -1, dropId, false, nil, oldItem, isInsideDrop)
                return true
            end

            newItem = { item = payload.fromSlot.name, slot = payload.toSlot or payload.fromSlot.slot }
            oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
        end,

        drop = function()
            newItem = { item = payload.fromSlot.name, slot = payload.toSlot or payload.fromSlot.slot }
            oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
        end
    }

    local shouldReturn = actions[payload.action]()
    if shouldReturn then return true end

    TriggerClientEvent('snowy_drops:client:updateDropId', -1, dropId, isToDrop, newItem, oldItem, isInsideDrop)
    return true
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
        local newInv = exports.ox_inventory:GetInventory(source)
        if newInv and #newInv.items <= 0 then
            exports.ox_inventory:RemoveInventory(dropId)
        end
        TriggerClientEvent('snowy_drops:client:updateDropId', -1, dropId, false, nil, { item = itemData.name, slot = itemData.slot }, false)
        return true
    end
    return false
end)