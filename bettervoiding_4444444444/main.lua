-----------------------------
-- Requiered Modules
-----------------------------
require("libs.entityMath")
require("libs.tableEx")

local BetterVoiding = RegisterMod("Better Voiding", 1)


----------------------------------------------------
-- Test
local debugText = 0

function BetterVoiding:drawDebugText()
    --bloodyPayNearestItem(Isaac.GetPlayer())
    Isaac.RenderText(debugText, 100, 100, 255, 0, 0, 255)
end

BetterVoiding:AddCallback(ModCallbacks.MC_POST_RENDER, BetterVoiding.drawDebugText)
----------------------------------------------------



-----------------------------------------
-- Local/Global variables and constants
-----------------------------------------
local game = Game()
local collDist = {}
local usedColls = {}


-------------------------------------
-- Simple missing math functions
-------------------------------------

-- Distance between two 2D Vectors/Points
local function vecDistance2D(pos1, pos2)
    return math.sqrt((pos1.X-pos2.X)^2 + (pos1.Y-pos2.Y)^2)
end

-------------------------------------------------------------------
-- Determins all collectibles and its distance to the playerEntity
-------------------------------------------------------------------
local function calculateCollDist(playerEntity)
    collDist = {}
    local allEntities = Isaac.GetRoomEntities()
    for _,collEntity in pairs(allEntities) do    -- Filter room for collectibles
        if (collEntity.Type == EntityType.ENTITY_PICKUP and collEntity.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
            collDist[collEntity] = vecDistance2D(playerEntity.Position, collEntity.Position)
        end
    end
end

--------------------------------------------------------
-- Removes entity from the game and the collDist table
--------------------------------------------------------
local function despawnEntity(entity)
    collDist[entity] = nil
    collDist = TableEx.updateTable(collDist)
    entity:Remove()
end

--------------------------------------------------------
-- Pay nearest item in a heart deal
-------------------------------------------------------
local function payNearestItem(sourceEntity)

    local itemEntity = BetterVoiding:getNearestItem(sourceEntity)

    if itemEntity == nil then
        return nil
    end

    local itemPickup = itemEntity:ToPickup()

    if (itemEntity:ToPickup().Price ~= 0) then    --Item has price

        -- Kill entity if it's not the first player
        if (GetPtrHash(sourceEntity) ~= GetPtrHash(Isaac.GetPlayer())) then
            sourceEntity.Kill()
        else
            local playerEntity = sourceEntity:ToPlayer()
            local itemPrice = itemPickup.Price

            -- Player pay price for the item if he can
            if itemPrice == PickupPrice.PRICE_ONE_HEART then
                if playerEntity:GetMaxHearts() < 2 then
                    return nil
                end
                playerEntity:AddMaxHearts(-2)

            elseif itemPrice == PickupPrice.PRICE_TWO_HEARTS then
                local maxHearts = playerEntity:GetMaxHearts()
                if maxHearts < 2 then
                    return nil
                elseif maxHearts >= 4 then
                    maxHearts = 4
                end
                playerEntity:AddMaxHearts(-maxHearts)

            elseif itemPrice == PickupPrice.PRICE_THREE_SOULHEARTS then
                local maxHeartsSoul = playerEntity:GetSoulHearts()
                if maxHeartsSoul < 1 then
                    return nil
                elseif maxHeartsSoul >= 6 then
                    maxHeartsSoul = 6
                end
                playerEntity:AddSoulHearts(-maxHeartsSoul)

            elseif itemPrice == PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS then
                local maxHearts = playerEntity:GetMaxHearts()
                local maxHeartsSoul = playerEntity:GetSoulHearts()
                if maxHearts < 2 then
                    return nil
                elseif maxHeartsSoul > 4 then
                    maxHeartsSoul = 4
                end
                playerEntity:AddMaxHearts(-maxHearts)
                playerEntity:AddSoulHearts(-maxHeartsSoul)

            elseif itemPrice == PickupPrice.PRICE_SPIKES then
                return nil

            elseif itemPrice == PickupPrice.PRICE_SOUL then
                -- ?
                return nil

            elseif itemPrice > 0 then
                local playersCoins = playerEntity:GetNumCoins()
                if (itemPrice > playersCoins) then
                    return nil
                else
                    playerEntity:AddCoins(-itemPrice)
                end

            else
                return nil
            end
        end
        -- Exchange item
        despawnEntity(itemEntity) -- Despawn item
        Isaac.Spawn(itemPickup.Type, itemPickup.Variant, itemPickup.SubType, itemEntity.Position, Vector(0,0), nil) -- Spawn item without price

        -- Devildeals only
        if game:GetRoom():GetType() == RoomType.ROOM_DEVIL then
            game:AddDevilRoomDeal()
        end

        return itemPickup
    end

    return nil -- If entity is nil or item with no price
end

--------------------------------------------------------
-- Remove all items in the room exept the nearest Item
--------------------------------------------------------
local function removeOtherItems()
    payNearestItem(Isaac.GetPlayer())
    return nil
end

------------------------------------------------------
-- Returns nearest collectible to the playerEntity
------------------------------------------------------
function BetterVoiding:getNearestItem(playerEntity)
    local nearestItem = nil

    calculateCollDist(playerEntity)
    nearestItem = TableEx.getKeyOfLowestValue(collDist)
    if (nearestItem ~= nil) then
        table.insert(usedColls, 1, nearestItem)
    end
    return nearestItem
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, removeOtherItems, Isaac.GetItemIdByName("Void"))
BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, removeOtherItems, Isaac.GetItemIdByName("Abyss"))