-----------------------------
-- Requiered Modules
-----------------------------
require("libs.tableEx")

local BetterVoiding = RegisterMod("Better Voiding", 1)


----------------------------------------------------
-- Test
local debugText = ""

function BetterVoiding:drawDebugText()
    Isaac.RenderText(debugText, 50, 50, 255, 0, 0, 255)
end

BetterVoiding:AddCallback(ModCallbacks.MC_POST_RENDER, BetterVoiding.drawDebugText)
----------------------------------------------------



----------------------------------------------------------
-- Global/Local variables and constants and Getter/Setter
----------------------------------------------------------
local game = Game()
local collDist = {}
local tYourSoulID = TrinketType.TRINKET_YOUR_SOUL


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
        if (collEntity.Type == EntityType.ENTITY_PICKUP and collEntity.Variant == PickupVariant.PICKUP_COLLECTIBLE 
                and collEntity.SubType ~= CollectibleType.COLLECTIBLE_NULL) then
            collDist[collEntity:ToPickup()] = vecDistance2D(playerEntity.Position, collEntity.Position)
        end
    end
end

--------------------------------------------------------
-- Removes the item from the game and the collDist table
--------------------------------------------------------
local function despawnItem(itemPickup)
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
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, item.Position, Vector(0,0), item)
                despawnItem(item)
            end
        end
    end
end

----------------------------------------------------------------------------------------------
-- Removes all items with the same OptionsPickupIndex except the nearest items for each index
----------------------------------------------------------------------------------------------
local function manageAllPickupIndices()
    local indexTables = {}
    local index = 0

    for item,dist in pairs(collDist) do
        index = item.OptionsPickupIndex
        if (index == 0) then -- skip this iteration
            goto continue
        end

        if indexTables[index] == nil then
            indexTables[index] = {}
        end
        indexTables[item.OptionsPickupIndex][item] = dist

        ::continue::
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

    if (itemPickup:IsShopItem()) then    --Item has price

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
                playerEntity:TakeDamage(2, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(itemPickup), 0)

            elseif itemPrice == PickupPrice.PRICE_SOUL then
                if not playerEntity:HasTrinket(tYourSoulID, false) then
                    return nil
                end
                if tostring(playerEntity:TryRemoveTrinket(tYourSoulID)) then
                    return nil
                end
                playerEntity:TryRemoveTrinketCostume(tYourSoulID)

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
        -- Make item free
        itemPickup.Price = 0

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
----- @Return: Table of (Keys: remaining voidable items, Values: Distance to sourceEntity)
-------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingAllItems(sourceEntity)
    local result = {}

    BetterVoiding:payNearestItem(sourceEntity)
    manageAllPickupIndices()
    result = TableEx.copy(collDist)
    for item,_ in pairs(result) do
        if item:IsShopItem() then
            result[item] = nil
        end
    end
    return TableEx.updateTable(result)
end


--        <<< Including removing item(s) and play animation >>>

-----------------------------------------------------------------------
-- Prepares everything for voiding NEAREST item to sourceEntity
----- @Return: CollectibleType/EntitySubtye of nearest item
-----------------------------------------------------------------------
function BetterVoiding:betterVoidingNearestItemRA(sourceEntity)
    local item = BetterVoiding:betterVoidingNearestItem(sourceEntity)
    local collType = nil
    if item ~= nil then
        collType = item.SubType
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, item.Position, Vector(0,0), item) -- play animation
        despawnItem(item)
    end
    return collType
end

-------------------------------------------------------------------------------------------------
-- Prepares everything for voiding ALL items next to sourceEntity !!!(pays only nearest item)!!!
----- @Return: Table of (Values: CollectibleTypes/EntitySubtypes of all voided items)
-------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingAllItemsRA(sourceEntity)
    local items = BetterVoiding:betterVoidingAllItems(sourceEntity)
    local collTypes = {}
    for item,_ in pairs(items) do
        if item.Price == 0 then
            table.insert(collTypes, item.SubType)
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, item.Position, Vector(0,0), item) -- play animation
            despawnItem(item)
        end
    end
    return collTypes
end


---------------------------------------------------------------------------------------------------------
-- ModCallbacks
---------------------------------------------------------------------------------------------------------

-- Function for existing voiding-items and their ModCallbacks
local function betterVoiding()
    BetterVoiding:betterVoidingAllItems(Isaac.GetPlayer())
    return true
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Void"))
BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Abyss"))
---------------------------------------------------------------------------------------------------------