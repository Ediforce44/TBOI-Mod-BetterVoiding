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
    Isaac.RenderText(debugText, 50, 50, 255, 0, 0, 255)
end

BetterVoiding:AddCallback(ModCallbacks.MC_POST_RENDER, BetterVoiding.drawDebugText)
----------------------------------------------------



-----------------------------------------
-- Local/Global variables and constants
-----------------------------------------
local game = Game()
local collDist = {}


-------------------------------------
-- Simple missing math functions
-------------------------------------

-- Distance between two 2D Vectors/Points
local function vecDistance2D(pos1, pos2)
    return math.sqrt((pos1.X-pos2.X)^2 + (pos1.Y-pos2.Y)^2)
end

-------------------------------------------------------------------
-- Determins all collectibles and its distance to the playerEntity
--      <<< !Needs to be called before everything else! >>>
-------------------------------------------------------------------
local function calculateCollDist(playerEntity)
    collDist = {}
    local allEntities = Isaac.GetRoomEntities()
    for _,collEntity in pairs(allEntities) do    -- Filter room for collectibles
        if (collEntity.Type == EntityType.ENTITY_PICKUP and collEntity.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
            collDist[collEntity:ToPickup()] = vecDistance2D(playerEntity.Position, collEntity.Position)
        end
    end
end

--------------------------------------------------------
-- Removes entity from the game and the collDist table
--------------------------------------------------------
local function despawnColl(itemPickup)
    collDist[itemPickup] = nil
    collDist = TableEx.updateTable(collDist)
    itemPickup:Remove()
end

-------------------------------------------------------------------------
-- Removes all items with the same OptionsPickupIndex as the itemPickup
-------------------------------------------------------------------------
local function managePickupIndex(itemPickup)
    if itemPickup == nil then
        return
    end

    local index = itemPickup.OptionsPickupIndex
    if index ~= 0 then
        for item,_ in pairs(collDist) do
            if (item ~= itemPickup and item.OptionsPickupIndex == index) then
                despawnColl(item)
            end
        end
    end
end

----------------------------------------------------------------------------------------------
-- Removes all items with the same OptionsPickupIndex except the nearest items for each index
----------------------------------------------------------------------------------------------
local function manageAllPickupIndices()
    local indexTables = {}

    for item,dist in pairs(collDist) do
        local index = item.OptionsPickupIndex
        if indexTables[index] == nil then
            indexTables[index] = {}
        end
        if item.OptionsPickupIndex ~= 0 then
            indexTables[item.OptionsPickupIndex][item] = dist
        end
    end

    for _,table in pairs(indexTables) do
        local item = TableEx.getKeyOfLowestValue(table)
        managePickupIndex(item)
    end
end

----------------------------------------------
-- Returns nearest item to the sourceEntity
----- @Return: Nearest item
----------------------------------------------
function BetterVoiding:getNearestItem(sourceEntity)
    local nearestItem = nil

    calculateCollDist(sourceEntity)
    nearestItem = TableEx.getKeyOfLowestValue(collDist)
    return nearestItem
end

-------------------------------------
-- Pay nearest item to sourceEntity
----- @Return: Nearest item
-------------------------------------
function BetterVoiding:payNearestItem(sourceEntity)

    local itemPickup = BetterVoiding:getNearestItem(sourceEntity)

    if itemPickup == nil then
        return nil
    end

    if (itemPickup.Price ~= 0) then    --Item has price

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
        despawnColl(itemPickup)
        itemPickup = Isaac.Spawn(itemPickup.Type, itemPickup.Variant, itemPickup.SubType
                                    , itemPickup.Position, Vector(0,0), nil):ToPickup()

        -- Devildeals only
        if game:GetRoom():GetType() == RoomType.ROOM_DEVIL then
            game:AddDevilRoomDeal()
        end
    end

    return itemPickup --return nearest item
end

----------------------------------------------------------------
-- Prepares everything for voiding NEAREST item to sourceEntity
----- @Return: Nearest item
----------------------------------------------------------------
function BetterVoiding:betterVoidingNearestItem(sourceEntity)
    local item = BetterVoiding:payNearestItem(sourceEntity)

    managePickupIndex(item)
    return item
end

-------------------------------------------------------------------------------------------------
-- Prepares everything for voiding ALL items next to sourceEntity !!!(pays only nearest item)!!!
----- @Return: Table of (Keys: remaining items, Values: Distance to sourceEntity)
-------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingAllItems(sourceEntity)
    BetterVoiding:payNearestItem(sourceEntity)

    manageAllPickupIndices()
    return {table.unpack(collDist)}
end


---------------------------------------------------------------------------------------------------------
--ModCallbacks
---------------------------------------------------------------------------------------------------------

-- Function for existing voiding-items and their ModCallbacks
local function betterVoiding()
    BetterVoiding:betterVoidingAllItems(Isaac.GetPlayer())
    return nil
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Void"))
BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Abyss"))
---------------------------------------------------------------------------------------------------------