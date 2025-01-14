SetConvarReplicated('inventory:dropprops', 'true')
SetConvarReplicated('inventory:dropmodel', 'prop_paper_bag_small')

lib.callback.register('snowy_drops:callback:getInventoryItems', function(source, dropId)
    local items = {}
    local dropItems = exports.ox_inventory:GetInventoryItems(dropId, false)
    if dropItems then
        for _, item in pairs(dropItems) do
            items[item.name .. ':' .. item.slot] = true
        end
    end
    return items
end)

lib.callback.register('snowy_drops:callback:getDropItems', function(source, dropId)
    if not string.match(dropId, '^drop%-%d+$') then return end
    return exports.ox_inventory:GetInventory(dropId, false)
end)

local function handleAction(payload, isInsideDrop, dropId, isToDrop)
    local actionData = {
        dropId = dropId,
        isToDrop = isToDrop,
        isInsideDrop = isInsideDrop
    }
    if payload.action == 'move' then
        if isInsideDrop and payload.fromSlot.count > payload.count then
            actionData.oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
            actionData.newItem = { item = payload.fromSlot.name, slot = payload.toSlot }
            actionData.extra = true
            TriggerClientEvent('snowy_drops:client:updateDropId', -1, actionData)
            return
        end
        local lastItem = not isToDrop and (payload.fromSlot.count == 0 or (payload.fromInventory ~= payload.toInventory and (payload.fromSlot.count - payload?.count) == 0))
        local insideMove = isInsideDrop and payload.fromSlot.count == payload.count
        if lastItem or insideMove then
            actionData.oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
        end
        if type(payload.toSlot) == 'number' and isToDrop then
            actionData.newItem = { item = payload.fromSlot.name, slot = payload.toSlot }
        end
    elseif payload.action == 'swap' then
        if payload.toSlot.name ~= payload.fromSlot.name then
            actionData.oldItem = {
                { item = payload.fromSlot.name, slot = payload.fromSlot.slot },
                { item = payload.toSlot.name, slot = payload.toSlot.slot }
            }
            actionData.newItem = {
                { item = payload.fromSlot.name, slot = payload.toSlot.slot },
                { item = payload.toSlot.name, slot = payload.fromSlot.slot }
            }
        elseif isToDrop and (payload.fromSlot?.stack or payload.toSlot?.stack) then
            actionData.oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
            actionData.newItem = { item = payload.toSlot.name, slot = payload.toSlot.slot }
        end
    elseif payload.action == 'stack' then
        if isInsideDrop then
            if payload.fromSlot.count == 0 then
                actionData.oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
                TriggerClientEvent('snowy_drops:client:updateDropId', -1, actionData)
            end
            return
        elseif not isToDrop then
            if payload.fromSlot.count == 0 then
                actionData.oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
            end
            if type(payload.toSlot) == 'number' then
                actionData.newItem = { item = payload.fromSlot.name, slot = payload.toSlot }
            end
        end
    elseif payload.action == 'drop' then
        actionData.oldItem = { item = payload.fromSlot.name, slot = payload.fromSlot.slot }
        if type(payload.toSlot) == 'number' and isToDrop then
            actionData.newItem = { item = payload.fromSlot.name, slot = payload.toSlot }
        end
    end
    if actionData.oldItem or actionData.newItem then
        TriggerClientEvent('snowy_drops:client:updateDropId', -1, actionData)
    end
end

local hookId = exports.ox_inventory:registerHook('swapItems', function(payload)
    if not (payload.fromType == 'drop' or payload.toType == 'drop') then return true end
    local dropId = payload.fromType == 'drop' and payload.fromInventory or payload.toInventory
    local isToDrop = payload.toType == 'drop'
    local isInsideDrop = payload.fromType == 'drop' and payload.toType == 'drop' and payload.fromInventory == payload.toInventory
    handleAction(payload, isInsideDrop, dropId, isToDrop)
    return true
end, {
    inventoryFilter = {
        '^drop%-%d+$',
    }
})

lib.callback.register('snowy_drops:server:pickupItem', function(source, dropId, itemData)
    local inventory = exports.ox_inventory:GetInventory(dropId)
    if not inventory or inventory.open or inventory.type ~= 'drop' or #(GetEntityCoords(GetPlayerPed(source)) - vec3(inventory.coords.x, inventory.coords.y, inventory.coords.z)) > 2.0 then return 'busy' end
    local item = inventory.items[itemData.slot]
    if not item or item.name ~= itemData.name then return end
    local success = exports.ox_inventory:RemoveItem(dropId, item.name, item.count, item.metadata, item.slot)
    if success then
        exports.ox_inventory:AddItem(source, item.name, item.count, item.metadata)
        local newInv = exports.ox_inventory:GetInventory(source)
        if newInv and #newInv.items <= 0 then
            exports.ox_inventory:RemoveInventory(dropId)
        end
        TriggerClientEvent('snowy_drops:client:updateDropId', -1, {
            dropId = dropId,
            isToDrop = false,
            isInsideDrop = false,
            oldItem = { item = item.name, slot = item.slot }
        })
        return true
    end
    return false
end)