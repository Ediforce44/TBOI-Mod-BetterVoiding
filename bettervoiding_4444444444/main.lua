-----------------------------
-- Requiered Modules
-----------------------------

require("libs.tableEx")

-----------------------------------------------------------
--[[ Reserved Optionindices
100 = To manage Genesis
200 = To manage Lost-like characters
----------------------------------------------------------]]

----------------------------------------------------------
-- Global/Local variables and constants and Getter/Setter
----------------------------------------------------------

local BetterVoiding = RegisterMod("Better Voiding", 1)

local game = Game()
local itemPool = game:GetItemPool()
local seeds = game:GetSeeds()
local genesisActive = false


----------------------------------------------------
-- Test
local debugText = ""

function BetterVoiding:drawDebugText()
    Isaac.RenderText(debugText, 50, 50, 255, 0, 0, 255)
end

BetterVoiding:AddCallback(ModCallbacks.MC_POST_RENDER, BetterVoiding.drawDebugText)
----------------------------------------------------

---------------------------------------------------------------------------------------------------------------
-- Determins all collectibles in the current room and their distance to the sourceEntity (default = Player_0)
----- @Return: Table of (Keys: Collectibles, Values: Distance between the collectible and sourceEntity)
---------------------------------------------------------------------------------------------------------------
local function calculateCollDist(sourceEntity)
    sourceEntity = sourceEntity or Isaac.GetPlayer() --set default value
    local collDists = {}
    local allEntities = BetterVoiding:calculatePickupDist(sourceEntity)

    for pickup, dist in pairs(allEntities) do    -- Filter room for collectibles
        if (pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.SubType ~= CollectibleType.COLLECTIBLE_NULL) then
            collDists[pickup] = dist
        end
    end
    return collDists
end

-------------------------------------------------------------------------
-- Removes all pickups with the same OptionsPickupIndex as the refPickup
----- @Retrun: refPickup if it is payed
-------------------------------------------------------------------------
local function managePickupIndex(refPickup)
    if refPickup == nil then
        return nil
    end

    local index = refPickup.OptionsPickupIndex
    if index ~= 0 then
        for pickup,_ in pairs(calculateCollDist()) do
            if (GetPtrHash(pickup) ~= GetPtrHash(refPickup) and pickup.OptionsPickupIndex == index) then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, pickup.Position, Vector(0,0), item)
                pickup:Remove()
            end
        end
        refPickup.OptionsPickupIndex = 0
    end

    return (refPickup:IsShopItem() and nil) or refPickup --if shopitem then nil else refPickup
end

-------------------------------------------------------------------------------------------------------------------
-- Removes all pickups with the same OptionsPickupIndex except the nearest pickups to sourceEntity for each index
----- @Return: Table of (Keys: Pickups, Values: Distance between the pickup and sourceEntity)
-------------------------------------------------------------------------------------------------------------------
local function manageAllPickupIndices(sourceEntity)
    local indexTables = {}
    local index = 0
    local remainingPickups = {}

    for pickup,dist in pairs(calculateCollDist(sourceEntity)) do
        if pickup:IsShopItem() then --ignore shop items
            goto continue
        end

        index = pickup.OptionsPickupIndex
        if (index == 0) then      --items without OptionsPickupIndex
            remainingPickups[pickup] = dist
            goto continue
        end

        if indexTables[index] == nil then
            indexTables[index] = {}
        end
        indexTables[pickup.OptionsPickupIndex][pickup] = dist

        ::continue::
    end

    for _,table in pairs(indexTables) do
        local nearestPickup = TableEx.getKeyOfLowestValue(table)
        remainingPickups[nearestPickup] = table[nearestPickup]
        for item,_ in pairs(table) do
            if not (item == nearestPickup) then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, item.Position, Vector(0,0), item)
                item:Remove()
            end
        end
        nearestPickup.OptionsPickupIndex = 0
    end
    return remainingPickups
end

----------------------------------------------------------------
-- Spawns a new pickup in the shop on the position of prePickup
----- @Return: New pickup
----------------------------------------------------------------
local function restockShopPickup(prePickup)
    local newPickup = nil
    local pickupType = nil

    if prePickup.Variant == PickupVariant.PICKUP_COLLECTIBLE then
        pickupType = itemPool:GetCollectible(itemPool:GetPoolForRoom(game:GetRoom():GetType(), seeds:GetNextSeed()), true, seeds:GetStartSeed())
    elseif prePickup.Variant == PickupVariant.PICKUP_TAROTCARD then
        pickupType = itemPool:GetCard(seeds:GetNextSeed(), true, true, false)
    elseif prePickup.Variant == PickupVariant.PICKUP_PILL then
        pickupType = itemPool:GetPill(seeds:GetNextSeed())
    else
        pickupType = prePickup.SubType
    end
    newPickup = Isaac.Spawn(prePickup.Type, prePickup.Variant, pickupType, prePickup.Position, Vector(0,0), nil):ToPickup()
    newPickup:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE | EntityFlag.FLAG_APPEAR)
    newPickup.ShopItemId = prePickup.ShopItemId

    return newPickup
end

----------------------------------------------------------------------------------
-- In Greedmode shops will spawn new pickups, if the old pickup got payed.
-- If pickup is not forVoiding, it will be moved next to the new shop item
----- @Return: Payed pickup
----------------------------------------------------------------------------------
local function manageGreedShop(pickup, forVoiding)
    if (game:GetRoom():GetType() ~= RoomType.ROOM_SHOP) then
        return pickup
    end

    local newPickup = restockShopPickup(pickup)
    newPickup.Price = pickup.Price --Price will get updated (important: Price ~= 0)

    if forVoiding then
        return pickup
    else
        return BetterVoiding:clonePickup(pickup, true)
    end
end

----------------------------------------------------------------------------------------------------------------------
-- If the player holds 'Restock', new items will spawn in the shop when pickup got payed.
-- If pickup is not forVoiding, it will be moved next to the new shop pickup
-- <<< The price doesn't work if and only if: Voiding shop pickups and then buying pickup regulary or vice versa >>>
----- @Return: Payed pickup
----------------------------------------------------------------------------------------------------------------------
local function manageRestock(pickup, forVoiding)
    if (game:GetRoom():GetType() ~= RoomType.ROOM_SHOP or (not Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_RESTOCK))) then
        return pickup
    end

    local pickupData = pickup:GetData()
    local newPickup = restockShopPickup(pickup)

    if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_POUND_OF_FLESH) then
        newPickup.Price = 1 --Price will get updated (important: Price ~= 0)
    else
        local newPickupData = newPickup:GetData()
        if pickupData['restockNum'] == nil then
            newPickupData['startingPrice'] = pickup.Price
            newPickupData['restockNum'] = 1
        else
            newPickupData['startingPrice'] = pickupData['startingPrice']
            newPickupData['restockNum'] = pickupData['restockNum'] + 1
        end

        newPickup.AutoUpdatePrice = false
        --Calculate new price
        local newPrice = (newPickupData['restockNum'] * (newPickupData['restockNum'] + 1))
        if newPickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
            newPrice = newPrice / 2
        end
        newPrice = newPrice + newPickupData['startingPrice']
        if newPrice > 99 then
            newPrice = 99
        end
        newPickup.Price = newPrice
        newPickupData['Price'] = newPrice
    end
    if forVoiding then
        return pickup
    else
        return BetterVoiding:clonePickup(pickup, true)
    end
end

---------------------------------------------------------------------------------------------------------------
-- Determins all pickups in the current room and their distance to the sourceEntity (default = Player_0)
----- @Return: Table of (Keys: Pickups, Values: Distance between the pickup and sourceEntity)
---------------------------------------------------------------------------------------------------------------
function BetterVoiding:calculatePickupDist(sourceEntity)
    sourceEntity = sourceEntity or Isaac.GetPlayer() --set default value
    local pickupDists = {}
    local allEntities = Isaac.GetRoomEntities()

    for _,collEntity in pairs(allEntities) do    -- Filter room for pickups
        if (collEntity.Type == EntityType.ENTITY_PICKUP) then
            pickupDists[collEntity:ToPickup()] = sourceEntity.Position:Distance(collEntity.Position)
        end
    end
    return pickupDists
end

-----------------------------------------------------------------------------------------
-- Clones pickup on the next free position to clonePosition (default = pickup.Position)
----- @Return: Cloned pickup
-----------------------------------------------------------------------------------------
function BetterVoiding:clonePickup(pickup, cloneAnimation, clonePosition)
    if cloneAnimation == nil then
        cloneAnimation = true
    end
    clonePosition = clonePosition or pickup.Position

    if pickup == nil then return nil end

    local pickupClone = Isaac.Spawn(EntityType.ENTITY_PICKUP, pickup.Variant, pickup.SubType
        , game:GetRoom():FindFreePickupSpawnPosition(clonePosition), Vector(0,0), nil):ToPickup()

    pickupClone:AddEntityFlags(pickup:GetEntityFlags())
    pickupClone:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
    if not cloneAnimation then
        pickupClone:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    end
    pickupClone.OptionsPickupIndex = pickup.OptionsPickupIndex
    pickupClone.ShopItemId = pickup.ShopItemId
    pickupClone.AutoUpdatePrice = pickup.AutoUpdatePrice
    pickupClone.Price = pickup.Price
    local cloneData = pickupClone:GetData()
    for key, value in pairs(pickup:GetData()) do
        cloneData[key] = value
    end
    pickup:Remove()

    return pickupClone
end

----------------------------------------------
-- Returns nearest item to the sourceEntity
----- @Return: Nearest item
----------------------------------------------
function BetterVoiding:getNearestItem(sourceEntity)
    return TableEx.getKeyOfLowestValue(calculateCollDist(sourceEntity))
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Let sourceEntity (default = Player_0) pay for pickup.
-- If the pickup, which will be payed, is not forVoiding and it's in a restockable shop, it will be moved next to the restocked pickup
----- @Return: Payed pickup
-----------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding:payPickup(pickup, sourceEntity, forVoiding)
    sourceEntity = sourceEntity or Isaac.GetPlayer(0)
    if forVoiding == nil then
        forVoiding = true
    end

    local playerEntity = nil
    local pickupPrice = nil
    local srcEntityIsLostlike = false

    if pickup == nil or sourceEntity == nil then
        return nil
    end

    if (pickup:IsShopItem()) then
        -- Kill entity if it's not one of the first 4 players
        for i = 0, 3 do
            if GetPtrHash(sourceEntity) == GetPtrHash(Isaac.GetPlayer(i)) then
                goto payment
            end
        end
        sourceEntity.Kill()
        goto payed

        ::payment::
        playerEntity = sourceEntity:ToPlayer()
        pickupPrice = pickup.Price
        srcEntityIsLostlike = (playerEntity:GetSoulHearts() == 1 and playerEntity:GetMaxHearts() == 0)

        -- Player pays price for the pickup if he can
        if pickupPrice == PickupPrice.PRICE_ONE_HEART then
            if playerEntity:GetMaxHearts() < 2 then
                return nil
            end
            playerEntity:AddMaxHearts(-2)

        elseif pickupPrice == PickupPrice.PRICE_TWO_HEARTS then
            local maxHearts = playerEntity:GetMaxHearts()
            if maxHearts < 2 then
                return nil
            elseif maxHearts >= 4 then
                maxHearts = 4
            end
            playerEntity:AddMaxHearts(-maxHearts)

        elseif pickupPrice == PickupPrice.PRICE_THREE_SOULHEARTS then
            local maxHeartsSoul = playerEntity:GetSoulHearts()
            if maxHeartsSoul < 1 then
                return nil
            elseif maxHeartsSoul >= 6 then
                maxHeartsSoul = 6
            end
            playerEntity:AddSoulHearts(-maxHeartsSoul)

        elseif pickupPrice == PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS then
            local maxHearts = playerEntity:GetMaxHearts()
            local maxHeartsSoul = playerEntity:GetSoulHearts()
            if maxHearts < 2 then
                return nil
            elseif maxHeartsSoul > 4 then
                maxHeartsSoul = 4
            end
            playerEntity:AddMaxHearts(-maxHearts)
            playerEntity:AddSoulHearts(-maxHeartsSoul)

        elseif pickupPrice == PickupPrice.PRICE_SPIKES then
            --Pay price
            if not srcEntityIsLostlike then
                playerEntity:TakeDamage(2, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(pickup), 0)
            end
            --Handle spike animation
            local entityList = Isaac.GetRoomEntities()
            for _,entity in pairs(entityList) do
                if entity.Type == EntityType.ENTITY_EFFECT and entity.Variant == EffectVariant.SHOP_SPIKES then
                    if entity.Position.X == pickup.Position.X and entity.Position.Y == pickup.Position.Y then
                        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SHOP_SPIKES, 1, entity.Position, Vector(0,0), nil)
                        entity:Remove()
                    end
                end
            end

        elseif pickupPrice == PickupPrice.PRICE_SOUL then
            if not playerEntity:HasTrinket(TrinketType.TRINKET_YOUR_SOUL, false) then
                return nil
            end
            if not playerEntity:TryRemoveTrinket(TrinketType.TRINKET_YOUR_SOUL) then
                return nil
            end
            playerEntity:TryRemoveTrinketCostume(TrinketType.TRINKET_YOUR_SOUL)

        elseif pickupPrice > 0 then
            local playersCoins = playerEntity:GetNumCoins()
            if (pickupPrice > playersCoins) then
                return nil
            else
                playerEntity:AddCoins(-pickupPrice)
            end

        else
            return nil
        end

        ::payed::

        --pickup = manageRestock(pickup, forVoiding) --doesn't work as intended

        -- Manages items for TheLost-like characters
        if srcEntityIsLostlike then
            for item,_ in  pairs(calculateCollDist()) do
               if (item.Price == PickupPrice.PRICE_THREE_SOULHEARTS or item.Price == PickupPrice.PRICE_SPIKES) then
                    item.OptionsPickupIndex = 100
                end
            end
            managePickupIndex(pickup) --removes other soulheart or spike deals in this room
        end

        -- Manages shop restocks in Greedmode
        if game:IsGreedMode() then
            pickup = manageGreedShop(pickup, forVoiding)
        end

        -- Make pickup free
        pickup.Price = 0

        -- Devildeals only
        if game:GetRoom():GetType() == RoomType.ROOM_DEVIL then
            game:AddDevilRoomDeal()
        end
    end

    return pickup --return payed pickup
end

------------------------------------------------------------------
-- Prepares everything for voiding NEAREST collectible to sourceEntity
----- @Return: Nearest collectible if it could be payed
------------------------------------------------------------------
function BetterVoiding:betterVoidingNearestItem(sourceEntity)
    local item = BetterVoiding:payPickup(BetterVoiding:getNearestItem(sourceEntity), sourceEntity)

    return managePickupIndex(item)
end

-----------------------------------------------------------------------------------------------------------------
-- Prepares everything for voiding ALL collectibles next to sourceEntity !!!(pays only nearest collectible)!!!
----- @Return: Table of (Keys: Remaining voidable collectibles, Values: Distance to sourceEntity)
-----------------------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingAllItems(sourceEntity)
    BetterVoiding:payPickup(BetterVoiding:getNearestItem(sourceEntity), sourceEntity)

    return manageAllPickupIndices(sourceEntity)
end


--        <<< Including removing collectible(s) and play animation >>>

-----------------------------------------------------------------------------------------
-- Voiding NEAREST collectible to sourceEntity !!!Doesn't work with genesis!!!
----- @Return: CollectibleType/EntitySubtye of nearest collectible if it could be payed
-----------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingNearestItemRA(sourceEntity)
    local item = BetterVoiding:betterVoidingNearestItem(sourceEntity)
    local collType = nil
    if item ~= nil then
        collType = item.SubType
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, item.Position, Vector(0,0), item) -- play animation
        item:Remove()
    end
    return collType
end

------------------------------------------------------------------------------------------------------------------------
-- Voiding ALL collectibles next to sourceEntity !!!(pays only nearest collectible)!!! !!!Doesn't work with genesis!!!
----- @Return: Table of (Values: CollectibleTypes/EntitySubtypes of all voided collectibles)
------------------------------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingAllItemsRA(sourceEntity)
    local items = BetterVoiding:betterVoidingAllItems(sourceEntity)
    local collTypes = {}
    for item,_ in pairs(items) do
        table.insert(collTypes, item.SubType)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, item.Position, Vector(0,0), item) -- play animation
        item:Remove()
    end
    return collTypes
end


---------------------------------------------------------------------------------------------------------
-- ModCallbacks
---------------------------------------------------------------------------------------------------------

-- Function for already existing voiding-items and their ModCallbacks
local function betterVoiding(_, _, _, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    BetterVoiding:betterVoidingAllItems(playerEntity)
    return nil
end


-- Function for already existing voiding-cards/runes and its ModCallback
local function betterVoidingCard(_, cardType, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    local playerData = playerEntity:GetData()
    if playerData['mimicedCard'] then
        playerData['mimicedCard'] = nil
    else
        playerData['mimicedCard'] = true
        BetterVoiding:betterVoidingAllItems(playerEntity)
        playerEntity:UseCard(cardType)
    end
    return nil
end

--------------------------------------------------------------------------------------------------------------------------
-- This function is for already existing mods with voiding-cards. It returns a function for a MC_USE_CARD ModCallback.
-- The returned functions pays the nearest item and activates the card a second time.
----- @Return: Function for ModCallbacks
--------------------------------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingReadyForCards()
    return betterVoidingCard
end

-- Fix Genesis as well as possible
local function genesisActivated()
    genesisActive = true
end

local function genesisDeactivated()
    genesisActive = false
end

local function genesisFix()
    if (genesisActive and game:GetRoom():GetType() == RoomType.ROOM_ISAACS) then
        local list = calculateCollDist()
        for item,_ in pairs(list) do
            item.OptionsPickupIndex = 200
        end
    end
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Void"))
BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Abyss"))
BetterVoiding:AddCallback(ModCallbacks.MC_USE_CARD, betterVoidingCard, Card.RUNE_BLACK)

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, genesisActivated, Isaac.GetItemIdByName("Genesis"))
BetterVoiding:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, genesisDeactivated)
BetterVoiding:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, genesisFix)
---------------------------------------------------------------------------------------------------------