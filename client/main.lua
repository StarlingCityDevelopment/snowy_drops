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
    local dims = {
        width = max.x - min.x,
        length = max.y - min.y,
        height = max.z - min.z
    }
    local itemWidth = dims.width + spacing
    
    local xOffset = (currentRow % itemsPerRow) * itemWidth
    local yOffset = math.floor(currentRow / itemsPerRow) * itemWidth
    
    currentRow = currentRow + 1
    
    local newCoords = vec3(
        point.coords.x + xOffset,
        point.coords.y + yOffset,
        point.coords.z
    )

    for _, dropModel in pairs(config.dropItems) do
        local found = GetClosestObjectOfType(
            newCoords.x, newCoords.y, newCoords.z,
            0.1,
            joaat(dropModel),
            false, false, false
        )

        if found and DoesEntityExist(found) then
            return getOffsetCoords(point, model)
        end
    end

    return newCoords
end

local function setupInteractions(point, entity, item)
    if config.useTarget then
        print('useTarget')
        exports.ox_target:addLocalEntity(entity, {
            {
                label = ('Pick up %s'):format(item),
                name = ('pickup_%s'):format(item),
                distance = 2.0,
                onSelect = function()
                    -- Find the item data in the inventory
                    local inventory = lib.callback.await('snowy_drops:callback:getDropItems', false, point.invId)
                    if not inventory then return end
                    for slot, slotData in pairs(inventory.items) do
                        if slotData.name == item then
                            local data = lib.callback.await('snowy_drops:server:pickupItem', false, point.invId, {
                                name = item,
                                slot = slot,
                                count = slotData.count
                            })
                            if data then
                               lib.notify({
                                title = 'Item Picked Up',
                                description = ('You picked up %s'):format(item),
                                type = 'success'
                               })
                               -- Remove item from the point's items list
                               point.items[item] = nil
                               DeleteEntity(entity)
                            else
                                lib.notify({
                                    title = 'Item doesn\'t exists',
                                    description = ('The item you are trying to pick up doesn\'t exists anymore'),
                                    type = 'error'
                                })
                                -- Remove item from the point's items list
                                point.items[item] = nil
                                DeleteEntity(entity)
                            end
                            break
                        end
                    end
                end
            }
        })
    elseif config.useInteract then
        exports.interact:AddLocalEntityInteraction({
            entity = entity,
            name = ('pickup_%s'):format(item),
            id = ('drop_%s_%s'):format(point.invId, item),
            distance = 8.0,
            interactDst = 2.0,
            options = {
                {
                    label = ('Pick up %s'):format(item),
                    action = function()
                        -- Find the item data in the inventory
                        local inventory = lib.callback.await('snowy_drops:callback:getDropItems', false, point.invId)
                        if not inventory then return end
                        
                        for slot, slotData in pairs(inventory.items) do
                            if slotData.name == item then
                                local data = lib.callback.await('snowy_drops:server:pickupItem', false, point.invId, {
                                    name = item,
                                    slot = slot,
                                    count = slotData.count
                                })
                                if data then
                                   lib.notify({
                                    title = 'Item Picked Up',
                                    description = ('You picked up %s'):format(item),
                                    type = 'success'
                                   })
                                   -- Remove item from the point's items list
                                   point.items[item] = nil
                                   DeleteEntity(entity)
                                else
                                    lib.notify({
                                        title = 'Item doesn\'t exists',
                                        description = ('The item you are trying to pick up doesn\'t exists anymore'),
                                        type = 'error'
                                    })
                                    -- Remove item from the point's items list
                                    point.items[item] = nil
                                    DeleteEntity(entity)
                                end
                                break
                            end
                        end
                    end
                }
            }
        })
    end
end

local function addDropObject(point, item)
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
        point.entitys[count] = { item = item, entity = entity }
        
        if config.useTarget or config.useInteract then
            setupInteractions(point, entity, item)
        end
    end
end

local function removeDropObject(point, item)
    if(type(point.entitys) ~= "table") then return end
    for _, data in pairs(point.entitys) do
        if data.item == item then
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
        for item, _ in pairs(point.items) do
            addDropObject(point, item)
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

RegisterNetEvent('snowy_drops:client:updateDropId', function(dropId, added, item)
    local point = drops[dropId]
    if point then
        if added then
            point.items[item] = true
            addDropObject(point, item)
        else
            point.items[item] = nil
            removeDropObject(point, item)
        end
    end
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