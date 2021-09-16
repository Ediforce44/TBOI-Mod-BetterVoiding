local BetterVoiding = RegisterMod("Better Voiding", 1)

local debugText = 0 --Test

-------------------------------------
-- Local variables and constants
-------------------------------------
local game = Game()
local collDist = {}
local usedColls = {}

----------------------------------------------------
-- Removes all entrys with nil values in keyTable
----------------------------------------------------
local function updateTable(keyTable)
    local updatedTable = {}
    for k,v in pairs(keyTable) do
        if not (v == nil) then
            updatedTable[k] = v
        end
    end
    return updatedTable
end


-------------------------------------
-- Simple missing math functions
-------------------------------------

-- Distance between two 2D Vectors/Points
local function vecDistance2D(pos1, pos2)
    return math.sqrt((pos1.X-pos2.X)^2 + (pos1.Y-pos2.Y)^2)
end

-- Returns key for lowest value in a keyTable
local function getKeyOfLowestValue(keyTable)
    local key = nil
    local value = nil

    updateTable(keyTable)

    for k,v in pairs(keyTable) do
        if (value == nil or v < value) then
            value = v
            key = k
        end
    end
    if (value ~= nil) then
       return key
    else
        return nil
    end
end

-------------------------------------------------------------------
-- Determins all collectibles and its distance to the sourceEntity
-------------------------------------------------------------------
local function calculateCollDist(sourceEntity)
    collDist = {}
    local allEntities = Isaac.GetRoomEntities()
    for _,collEntity in pairs(allEntities) do    -- Filter room for collectibles
        if (collEntity.Type == EntityType.ENTITY_PICKUP and collEntity.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
            collDist[collEntity] = vecDistance2D(sourceEntity.Position, collEntity.Position)
        end
    end
end

---------------------------------------
-- 
---------------------------------------
local function despawnEntity(entity)
    collDist[entity] = nil
    entity:Remove()
end


------------------------------------------------------
-- Returns nearest collectible to the sourceEntity
------------------------------------------------------
function BetterVoiding:getNearestItem(sourceEntity)
    local nearestItem = nil

    calculateCollDist(sourceEntity)
    nearestItem = getKeyOfLowestValue(collDist)
    if (nearestItem ~= nil) then
        table.insert(usedColls, 1, nearestItem)
    end
    return nearestItem
end

--------------------------------------------------------
-- Pay nearest item in a heart deal
-------------------------------------------------------
local function bloodyPayNearestItem(entity)
    local itemEntity = BetterVoiding:getNearestItem(entity)
    if (itemEntity ~= nil and itemEntity:ToPickup().Price ~= PickupPrice.PRICE_FREE and itemEntity:ToPickup().Price ~= 0) then
        local itemPickup = itemEntity:ToPickup()

        -- Kill entity if it's not the first player
        if (GetPtrHash(entity) ~= GetPtrHash(Isaac.GetPlayer())) then
            entity.Kill()
            return nil
        end

        -- Pay hearts for the item
        if itemPickup.Price == PickupPrice.PRICE_ONE_HEART then
            if entity:GetMaxHearts() < 2 then
                return nil
            end
            entity:AddMaxHearts(-2)
        end
        if itemPickup.Price == PickupPrice.PRICE_TWO_HEARTS then
            if entity:GetMaxHearts() < 4 then
                return nil
            end
            entity:AddMaxHearts(-4)
        end
        if itemPickup.Price == PickupPrice.PRICE_THREE_SOULHEARTS then
            if entity:GetSoulHearts() < 6 then
                return nil
            end
            entity:AddSoulHearts(-6)
        end
        if itemPickup.Price == PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS then
            if entity:GetMaxHearts() < 2 or entity:GetSoulHearts() < 4 then
                return nil
            end
            entity:AddMaxHearts(-2)
            entity:AddSoulHearts(-4)
        end
        if itemPickup.Price == PickupPrice.PRICE_SPIKES then
            return nil
        end
        if itemPickup.Price == PickupPrice.PRICE_SOUL then
            -- ?
            return nil
        end
        -- Exchange item
        despawnEntity(itemEntity) -- Despawn item
        Isaac.Spawn(itemPickup.Type, itemPickup.Variant, itemPickup.SubType, itemEntity.Position, Vector(0,0), nil) -- Spawn item without price
        game:AddDevilRoomDeal() -- Mimics: Deal-Taken
        return itemPickup
    end 
    
    return nil -- If entity is nil or free
end


--------------------------------------------------------
-- Remove all items in the room exept the nearest Item
--------------------------------------------------------
local function removeOtherItems()
    bloodyPayNearestItem(Isaac.GetPlayer())
    return nil
end


function BetterVoiding:drawDebugText()
    --bloodyPayNearestItem(Isaac.GetPlayer())
    Isaac.RenderText(debugText, 100, 100, 255, 0, 0, 255)
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, removeOtherItems, Isaac.GetItemIdByName("Void"))


BetterVoiding:AddCallback(ModCallbacks.MC_POST_RENDER, BetterVoiding.drawDebugText)