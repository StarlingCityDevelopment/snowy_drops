local config = require 'config.client'
local items = require 'config.items'
local rotations = require 'config.rotations'
local cachedDrops = {}
local currentInstance = LocalPlayer.state.instance or 0

local function getOffsetCoords(point, model)
    local radius = config.propRadius
    local maxAttempts = 20
    local detectionRadius = config.propRadius + 0.2
    for attempt = 1, maxAttempts do
        local angle = math.random() * 2 * math.pi
        local distance = math.sqrt(math.random()) * radius
        local jitter = vec3(math.random() * 0.1 - 0.05, math.random() * 0.1 - 0.05, 0)
        local newCoords = point.coords + vec3(math.cos(angle) * distance, math.sin(angle) * distance, 0) + jitter
        local found = IsAnyObjectNearPoint(newCoords.x, newCoords.y, newCoords.z, detectionRadius)
        if not found or not DoesEntityExist(found) then
            return newCoords
        end
    end
    return point.coords + vec3(math.random() * 0.3 - 0.15, math.random() * 0.3 - 0.15, 0)
end

local function doInteractionAction(point, item, slot)
    local inventory = lib.callback.await('snowy_drops:callback:getDropItems', false, point.invId)
    if not inventory then return end
    local slotData = inventory.items[slot]
    if slotData and slotData.name == item then
        local data = lib.callback.await('snowy_drops:server:pickupItem', false, point.invId, {
            name = item,
            slot = slot
        })
        if data == 'busy' then
            return lib.notify({ description = locale('error.inv_busy'), type = 'error' })
        end
        if data then
            lib.playAnim(cache.ped, 'random@domestic', 'pickup_low')
            lib.notify({ description = locale('success.picked_up', exports.ox_inventory:Items(item)?.label or item), type = 'success' })
        else
            lib.notify({ description = locale('error.not_exist'), type = 'error' })
        end
    end
end

local function setupInteractions(point, entity, item, slot)
    if config.useTarget then
        exports.ox_target:addLocalEntity(entity, {
            {
                label = locale('general.target_label', exports.ox_inventory:Items(item)?.label or item),
                name = ('snowydrops_%s:%s'):format(item, slot),
                icon = 'fas fa-hand-lizard',
                distance = 2.0,
                onSelect = function()
                    doInteractionAction(point, item, slot)
                end
            }
        })
    elseif config.useInteract then
        exports.interact:AddLocalEntityInteraction({
            entity = entity,
            id = ('snowydrops_%s:%s'):format(item, slot),
            distance = 8.0,
            interactDst = 3.0,
            options = {
                {
                    label = locale('general.interact_label', exports.ox_inventory:Items(item)?.label or item),
                    action = function()
                        doInteractionAction(point, item, slot)
                    end
                }
            }
        })
    end
end

local function addDropObject(point, item, slot, plcd)
    if point.currentDistance and point.currentDistance > point.distance then return end
    if(type(point.entitys) ~= 'table') then point.entitys = {} end
    local model = items[string.lower(item)] or config.defaultModel
    if model then
        local key = ('%s:%s'):format(item, slot)
        if point.entitys[key] then return end
        if not IsModelValid(model) and not IsModelInCdimage(model) then
            model = config.defaultModel
        end
        lib.requestModel(model)
        local coords = getOffsetCoords(point, model)
        local entity = CreateObject(model, coords.x, coords.y, coords.z, false, true, true)
        SetModelAsNoLongerNeeded(model)
        PlaceObjectOnGroundProperly(entity)
        FreezeEntityPosition(entity, true)
        SetEntityCollision(entity, true, false)
        local itemRotation = rotations[string.lower(item)]
        if string.match(string.lower(item), '^weapon_') then itemRotation = rotations['weapon_'] or nil end
        if itemRotation then
            SetEntityRotation(entity, itemRotation?.pitch or 0.0, itemRotation?.roll or 0.0, itemRotation?.yaw or 0.0, 2, false)
            SetEntityCoords(entity, coords.x, coords.y, coords.z + itemRotation?.heightOffset or -0.95)
        end
        point.entitys[key] = { item = item, slot = slot, entity = entity }
        if config.useTarget or config.useInteract then
            setupInteractions(point, entity, item, slot)
        end
    end
end

local function removeDropObject(point, item, slot)
    if(type(point.entitys) ~= 'table') then return end
    for id, data in pairs(point.entitys) do
        if data.item == item and data.slot == slot then
            if DoesEntityExist(data.entity) then
                if config.useTarget then
                    exports.ox_target:removeLocalEntity(data.entity, ('snowydrops_%s'):format(id))
                elseif config.useInteract then
                    exports.interact:RemoveLocalEntityInteraction(data.entity, ('snowydrops_%s'):format(id))
                end
                SetEntityAsMissionEntity(data.entity, false, true)
                DeleteEntity(data.entity)
                point.entitys[id] = nil
                break
            end
        end
    end
end

local function removeObjects(point)
    if(type(point.entitys) ~= 'table') then return end
    for id, data in pairs(point.entitys) do
        if DoesEntityExist(data.entity) then
            if config.useTarget then
                exports.ox_target:removeLocalEntity(data.entity, ('snowydrops_%s'):format(id))
            elseif config.useInteract then
                exports.interact:RemoveLocalEntityInteraction(data.entity, ('snowydrops_%s'):format(id))
            end
            SetEntityAsMissionEntity(data.entity, false, true)
            DeleteEntity(data.entity)
        end
    end
    point.entitys = {}
end

local function onEnterDrop(point)
    if not point.instance or point.instance == currentInstance and not point.entitys then
        CreateThread(function()
            local startTime = GetGameTimer()
            local oxProp = nil
            repeat
                Wait(500)
                oxProp = GetClosestObjectOfType(point.coords.x, point.coords.y, point.coords.z, 25.0, joaat('prop_paper_bag_small'), false, false, false)
                if oxProp ~= 0 and DoesEntityExist(oxProp) then break end
            until (GetGameTimer() - startTime) >= 6000
            if DoesEntityExist(oxProp) then
                SetEntityAsMissionEntity(oxProp, false, true)
                DeleteEntity(oxProp)
            end
        end)
        for itemSlot, _ in pairs(point.items) do
            local item, slot = itemSlot:match('(.+):(%d+)')
            addDropObject(point, item, tonumber(slot), 0)
        end
        CreateThread(function()
            while point.entitys and point.currentDistance and point.currentDistance <= point.distance do
                local collisionNeeded = not cache.vehicle
                for id, data in pairs(point.entitys) do
                    if point.currentDistance > point.distance then break end
                    if id and data.entity then
                        SetEntityCollision(data.entity, collisionNeeded, false)
                    end
                end
                Wait(1000)
            end
        end)
    end
end

local function onExitDrop(point)
    local entitys = point.entitys
    if entitys then
        removeObjects(point)
    end
end

local function createDrop(dropId, data)
    if data?.model then return end -- Ignore custom drops from ox_inventory
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
    cachedDrops[dropId] = point
end

AddStateBagChangeHandler('instance', ('player:%s'):format(cache.serverId), function(_, _, value)
    currentInstance = value
    if cachedDrops then
        for dropId, point in pairs(cachedDrops) do
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

local function getItemKey(item)
    return ('%s:%s'):format(item.item, item.slot)
end

RegisterNetEvent('snowy_drops:client:updateDropId', function(actionData)
    local dropId = actionData.dropId
    local point = cachedDrops[dropId]
    if not point then return end
    local oldItem = actionData.oldItem
    local newItem = actionData.newItem
    local isInsideDrop = actionData.isInsideDrop
    local isToDrop = actionData.isToDrop
    local extraDrop = actionData.extra
    if isInsideDrop then
        if table.type(oldItem) == 'array' and table.type(newItem) == 'array' then
            for _, oItem in pairs(oldItem) do
                local oldItemKey = getItemKey(oItem)
                if point.items[oldItemKey] then
                    point.items[oldItemKey] = nil
                    removeDropObject(point, oItem.item, oItem.slot)
                end
            end
            for _, nItem in pairs(newItem) do
                local newItemKey = getItemKey(nItem)
                point.items[newItemKey] = true
                addDropObject(point, nItem.item, nItem.slot, 1)
            end
        else
            local oldItemKey = getItemKey(oldItem)
            if point.items[oldItemKey] then
                point.items[oldItemKey] = nil
                removeDropObject(point, oldItem.item, oldItem.slot)
            end
            if extraDrop then
                local newItemKey = getItemKey(newItem)
                point.items[newItemKey] = true
                addDropObject(point, newItem.item, newItem.slot, 2)
                point.items[oldItemKey] = true
                addDropObject(point, oldItem.item, oldItem.slot, 3)
            elseif newItem then
                local newItemKey = getItemKey(newItem)
                point.items[newItemKey] = true
                addDropObject(point, newItem.item, newItem.slot, 4)
            end
        end
    elseif isToDrop then
        if oldItem then
            local oldItemKey = getItemKey(oldItem)
            if point.entitys then
                point.items[oldItemKey] = nil
                removeDropObject(point, oldItem.item, oldItem.slot)
            end
        end
        if newItem then
            local newItemKey = getItemKey(newItem)
            if not point.items[newItemKey] then
                point.items[newItemKey] = true
                addDropObject(point, newItem.item, newItem.slot, 5)
            end
        end
    else
        if point.items then
            local oldItemKey = getItemKey(oldItem)
            point.items[oldItemKey] = nil
            removeDropObject(point, oldItem.item, oldItem.slot)
            if not next(point.items) then
                if point.entitys then removeObjects(point) end
                point:remove()
                cachedDrops[dropId] = nil
                exports.ox_inventory:closeInventory()
            end
        end
    end
end)

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data, owner, slot)
    if not cachedDrops[dropId] then
        createDrop(dropId, data)
    end
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
    local point = cachedDrops[dropId]
    if point then
        cachedDrops[dropId] = nil
        point:remove()
        if point.entitys then removeObjects(point) end
    end
end)