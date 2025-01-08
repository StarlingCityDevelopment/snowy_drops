local config = require 'config.client'
local drops = {}
local dropmodel = joaat(GetConvar('inventory:dropmodel', 'prop_med_bag_01b'))
local currentInstance
local lastPosition = vec3(0, 0, 0)
local currentRow = 0
local itemsPerRow = 3
local spacing = 0.3

local function getOffsetCoords(point, model)
    if #(point.coords - lastPosition) > 0.1 then
        lastPosition = point.coords
        currentRow = 0
    end

    local min, max = GetModelDimensions(model)
    local radius = 0.5  -- Base radius for the circle
    local maxAttempts = 20  -- Maximum attempts to find a valid position
    
    -- Generate random angle and distance within a circle
    for attempt = 1, maxAttempts do
        local angle = math.random() * 2 * math.pi
        local distance = math.sqrt(math.random()) * radius  -- Square root for more uniform distribution
        
        -- Add some controlled randomness to make it look more natural
        local jitter = math.random() * 0.1 - 0.05
        
        local newCoords = vec3(
            point.coords.x + math.cos(angle) * distance + jitter,
            point.coords.y + math.sin(angle) * distance + jitter,
            point.coords.z
        )

        -- Check if position is clear
        local isPositionClear = true
        for _, dropModel in pairs(config.dropItems) do
            local found = GetClosestObjectOfType(
                newCoords.x, newCoords.y, newCoords.z,
                0.2,  -- Slightly increased detection radius
                joaat(dropModel),
                false, false, false
            )

            if found and DoesEntityExist(found) then
                isPositionClear = false
                break
            end
        end

        if isPositionClear then
            return newCoords
        end
    end

    -- Fallback: If no position found, return slightly offset coordinates
    return vec3(
        point.coords.x + math.random() * 0.3 - 0.15,
        point.coords.y + math.random() * 0.3 - 0.15,
        point.coords.z
    )
end

local function setupInteractions(point, entity, item, slot)
    if config.useTarget then
        print('useTarget')
        exports.ox_target:addLocalEntity(entity, {
            {
                label = ('Pick up %s'):format(item),
                name = ('pickup_%s_%s'):format(item, slot),
                distance = 2.0,
                onSelect = function()
                    -- Find the item data in the inventory
                    local inventory = lib.callback.await('snowy_drops:callback:getDropItems', false, point.invId)
                    if not inventory then return end
                    local slotData = inventory.items[slot]
                    if slotData and slotData.name == item then
                        local data = lib.callback.await('snowy_drops:server:pickupItem', false, point.invId, {
                            name = item,
                            slot = slot,
                            count = slotData.count
                        })
                        if data == "no" then return end
                        if data then
                           lib.notify({
                            title = 'Item Picked Up',
                            description = ('You picked up %s'):format(item),
                            type = 'success'
                           })
                           -- Remove item from the point's items list
                        else
                            lib.notify({
                                title = 'Item doesn\'t exists',
                                description = ('The item you are trying to pick up doesn\'t exists anymore'),
                                type = 'error'
                            })
                            -- Remove item from the point's items list
                        end
                    end
                end
            }
        })
    elseif config.useInteract then
        exports.interact:AddLocalEntityInteraction({
            entity = entity,
            name = ('pickup_%s_%s'):format(item, slot),
            id = ('drop_%s_%s_%s'):format(point.invId, item, slot),
            distance = 8.0,
            interactDst = 3.0,
            options = {
                {
                    label = ('Pick up %s'):format(item),
                    action = function()
                        -- Find the item data in the inventory
                        local inventory = lib.callback.await('snowy_drops:callback:getDropItems', false, point.invId)
                        if not inventory then return end
                        
                        local slotData = inventory.items[slot]
                        if slotData and slotData.name == item then
                            local data = lib.callback.await('snowy_drops:server:pickupItem', false, point.invId, {
                                name = item,
                                slot = slot,
                                count = slotData.count
                            })
                            if data == "no" then return end
                            if data then
                               lib.notify({
                                title = 'Item Picked Up',
                                description = ('You picked up %s'):format(item),
                                type = 'success'
                               })
                               -- Remove item from the point's items list
                            else
                                lib.notify({
                                    title = 'Item doesn\'t exists',
                                    description = ('The item you are trying to pick up doesn\'t exists anymore'),
                                    type = 'error'
                                })
                                -- Remove item from the point's items list
                            end
                        end
                    end
                }
            }
        })
    end
end

local function addDropObject(point, item, slot)
    if(type(point.entitys) ~= "table") then point.entitys = {} end
    local model = config.dropItems[item]
    if model then
        local count = #point.entitys + 1
        if not IsModelValid(model) and not IsModelInCdimage(model) then
            model = dropmodel
        end
        lib.requestModel(model)
        local coords = getOffsetCoords(point, model)
        local entity = CreateObject(model, coords.x, coords.y, coords.z, false, true, true)
        SetModelAsNoLongerNeeded(model)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        SetEntityCollision(entity, true, true)
        point.entitys[count] = { item = item, slot = slot, entity = entity }
        
        if config.useTarget or config.useInteract then
            setupInteractions(point, entity, item, slot)
        end
    end
end

local function removeDropObject(point, item, slot)
    if(type(point.entitys) ~= "table") then return end
    for _, data in pairs(point.entitys) do
        if data.item == item and data.slot == slot then
            if DoesEntityExist(data.entity) then
                SetEntityAsMissionEntity(data.entity, false, true)
                DeleteEntity(data.entity)
                break
            end
        end
    end
end

local function removeObjects(point)
    if(type(point.entitys) ~= "table") then return end
    for _, data in pairs(point.entitys) do
        if DoesEntityExist(data.entity) then
            SetEntityAsMissionEntity(data.entity, false, true)
            DeleteEntity(data.entity)
        end
    end
    point.entitys = nil
end

local function onEnterDrop(point)
    if not point.instance or point.instance == currentInstance and not point.entitys then
        CreateThread(function()
            local oxProp = GetClosestObjectOfType(point.coords.x, point.coords.y, point.coords.z, 25.0, dropmodel, false, false, false)
            Wait(250)
            if DoesEntityExist(oxProp) then
                SetEntityAsMissionEntity(oxProp, false, true)
                DeleteEntity(oxProp)
            end
        end)
        print(json.encode(point.items))
        for itemSlot, _ in pairs(point.items) do
            local item, slot = itemSlot:match("(.+):(%d+)")
            addDropObject(point, item, tonumber(slot))
        end
    end
end

local function onExitDrop(point)
    local entitys = point.entitys
    if entitys then
        removeObjects(point)
    end
end

local function createDrop(dropId, data)
    if data?.model then return end -- ignore custom drops
    local items = lib.callback.await('snowy_drops:callback:getInventoryItems', false, dropId)
    local point = lib.points.new({
        coords = data.coords,
        distance = 30,
        invId = dropId,
        instance = data.instance,
        items = items
    })
    point.onEnter = onEnterDrop
    point.onExit = onExitDrop
    point.entitys = {}
    drops[dropId] = point
end

AddStateBagChangeHandler('instance', stateId, function(_, _, value)
    currentInstance = value
    if drops then
        for dropId, point in pairs(drops) do
            if point.instance then
                if point.instance ~= value then
                    if point.entitys then
                        removeObjects(point)
                    end
                    point:remove()
                else
                    createDrop(dropId, point)
                end
            end
        end
    end
end)

RegisterNetEvent('snowy_drops:client:updateDropId', function(dropId, isToDrop, newItem, oldItem, isInsideDrop, isSplit2Props)
    local point = drops[dropId]
    if not point then return end
    
    lastPosition = vec3(0, 0, 0)
    print(isInsideDrop, isSplit2Props)
    if isInsideDrop then
        if isSplit2Props then
            print('splitting props')
            local oldItemKey = ('%s:%s'):format(oldItem.item, oldItem.slot)
            if point.items[oldItemKey] then
                point.items[oldItemKey] = nil
                removeDropObject(point, oldItem.item, oldItem.slot)
            end
            local newItemKey = ('%s:%s'):format(newItem.item, newItem.slot)
            point.items[newItemKey] = true
            addDropObject(point, newItem.item, newItem.slot)
            
            local splitItemKey = ('%s:%s'):format(oldItem.item, oldItem.slot)
            point.items[splitItemKey] = true
            addDropObject(point, oldItem.item, oldItem.slot)

            return true
        else
            local oldItemKey = ('%s:%s'):format(oldItem.item, oldItem.slot)
            if point.items[oldItemKey] then
                point.items[oldItemKey] = nil
                removeDropObject(point, oldItem.item, oldItem.slot)
            end
        end
    elseif isToDrop then
        
        if point.entitys then
            local oldItemKey = ('%s:%s'):format(oldItem.item, oldItem.slot)
            point.items[oldItemKey] = nil
            removeDropObject(point, oldItem.item, oldItem.slot)
        end

        local newItemKey = ('%s:%s'):format(newItem.item, newItem.slot)
        point.items[newItemKey] = true
        
        if point.currentDistance and point.currentDistance <= point.distance then
            addDropObject(point, newItem.item, newItem.slot)
        end
    else
        if point.items then
            local oldItemKey = ('%s:%s'):format(oldItem.item, oldItem.slot)
            point.items[oldItemKey] = nil
            removeDropObject(point, oldItem.item, oldItem.slot)
            
            if not next(point.items) then
                if not lib.callback.await('snowy_drops:server:doesDropExist', false, dropId) then
                    if point.entitys then removeObjects(point) end
                    point:remove()
                    drops[dropId] = nil
                end
            end
        end
    end
    print(json.encode(point.items))
end)

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data, owner, slot)
    if not drops[dropId] then
        createDrop(dropId, data)
    end
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
    local point = drops[dropId]
    if point then
        drops[dropId] = nil
        point:remove()
        if point.entitys then removeObjects(point) end
    end
end)


RegisterNetEvent('snowy_drops:client:closeInv', function()
    exports.ox_inventory:closeInventory()
end)
