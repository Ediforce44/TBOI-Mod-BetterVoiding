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

local modBV = RegisterMod("Better Voiding", 1)

local game = Game()
local itemPool = game:GetItemPool()
local seeds = game:GetSeeds()
local genesisActive = false

local preVoidingAnmEntitys = {}
local preVoidingAnmSpites = {}

-- To access BetterVoiding functions from outside this mod
BetterVoiding = {version = "1.0"}

-- TODO
BetterVoiding.VoidingFlags = {
    V_ALL_FREE_ITEMS = 1<<0,        --Flags for voiding
    V_NEAREST_ITEM = 1<<1,
}
BetterVoiding.ItemCategoryFlags = {
    IC_ALL_ITEMS = 0,               --Flags for itemCategory
    IC_FREE_ITEMS = 1<<0,
    IC_HEARTDEAL_ITEMS = 1<<1,
    IC_SHOP_ITEMS = 1<<2,
    IC_SPIKE_ITEMS = 1<<3,
}

-- Standard values for voiding items
local STD_COLOR = Color(0.5,0.5,0.5,0.9,0,0,0)
local STD_FLAGS_V = BetterVoiding.VoidingFlags.V_ALL_FREE_ITEMS | BetterVoiding.VoidingFlags.V_NEAREST_ITEM
local STD_FLAGS_IC = BetterVoiding.ItemCategoryFlags.IC_ALL_ITEMS

-- TODO
BetterVoiding.VoidingItemTypes = {
    TYPE_COLLECTIBLE = 1,
    TYPE_CARD = 2,
    TYPE_PILL = 3
}
local voidingColls = {
    TYPE = {CollectibleType.COLLECTIBLE_VOID, CollectibleType.COLLECTIBLE_ABYSS},
    COLOR = {Color(0.4,0.32,0.4,0.9,0,0,0), Color(0.8,0.1,0.1,0.9,0,0,0)},
    V_FLAGS = {STD_FLAGS_V, STD_FLAGS_V},
    IC_FLAGS = {STD_FLAGS_IC, STD_FLAGS_IC},
    COUNT = 2
}
local voidingCards = {
    TYPE = {Card.RUNE_BLACK},
    COLOR = {Color(0.1,0.1,0.1,0.9,0,0,0)},
    V_FLAGS = {STD_FLAGS_V},
    IC_FLAGS = {STD_FLAGS_IC},
    COUNT = 1
}
local voidingPills = {
    TYPE = {},
    COLOR = {},
    V_FLAGS = {},
    IC_FLAGS = {},
    COUNT = 0
}
local betterVoidingItemTables = {voidingColls, voidingCards, voidingPills}

----------------------------------------------------
-- Test
local debugText = ""

local function drawDebugText()
    Isaac.RenderText(debugText, 50, 50, 255, 0, 0, 255)
end

modBV:AddCallback(ModCallbacks.MC_POST_RENDER, drawDebugText)
----------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Determins all collectibles in the current room, which match flagsIC (default = IC_ALL_ITEMS) and their distance to the sourceEntity (default = Player_0)
----- @Return: Table of (Keys: Collectibles, Values: Distance between the collectible and sourceEntity)
------------------------------------------------------------------------------------------------------------------------------------------------------------
local function calculateCollDist(sourceEntity, flagsIC)
    sourceEntity = sourceEntity or Isaac.GetPlayer() --set default value
    flagsIC = flagsIC or STD_FLAGS_IC

    local allEntities = BetterVoiding.calculatePickupDist(sourceEntity)
    local collDists = {}

    for pickup, dist in pairs(allEntities) do    -- Filter room for collectibles
        if (pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.SubType ~= CollectibleType.COLLECTIBLE_NULL) then
            collDists[pickup] = dist
        end
    end
    return collDists
end

-------------------------------------
-- TODO
-------------------------------------
local function managePickupIndices(sourceEntity, flagsV, flagsIC)
    local index = 0
    local indexItemTable = {}
    local nearestPickup = nil
    local voidingPickups = {}
    local otherPickups = {}
    local remainingPickups = calculateCollDist(sourceEntity, flagsIC)

    if (flagsV & BetterVoiding.VoidingFlags.V_NEAREST_ITEM) ~= 0 then
        nearestPickup = BetterVoiding.getNearestPayableItem(sourceEntity, flagsIC)
        if nearestPickup ~= nil then
            index = nearestPickup.OptionsPickupIndex
            if index ~= 0 then
                for pickup, dist in pairs(remainingPickups) do
                    if pickup.OptionsPickupIndex == index then
                        if not (GetPtrHash(pickup) == GetPtrHash(nearestPickup)) then
                            otherPickups[pickup] = dist
                        else
                            voidingPickups[nearestPickup] = sourceEntity.Position:Distance(nearestPickup.Position)
                        end
                        remainingPickups[pickup] = nil
                    end
                end
            end
        end
        remainingPickups = TableEx.updateTable(remainingPickups)
    end

    if (flagsV & BetterVoiding.VoidingFlags.V_ALL_FREE_ITEMS) ~= 0 then
        for pickup, dist in pairs(remainingPickups) do
            index = pickup.OptionsPickupIndex
            if (pickup.Price == 0) then
                if (index == 0) then            --Items without OptionsPickupIndex
                    voidingPickups[pickup] = dist
                    remainingPickups[pickup] = nil
                    goto continue
                end
                if indexItemTable[index] == nil then
                    indexItemTable[index] = {}
                end
                indexItemTable[index][pickup] = dist
            end
            ::continue::
        end
        for _,table in pairs(indexItemTable) do
            nearestPickup = TableEx.getKeyOfLowestValue(table)
            for pickup, dist in pairs(table) do
                if not (pickup == nearestPickup) then
                    otherPickups[pickup] = dist
                end
                remainingPickups[pickup] = nil
            end
            voidingPickups[nearestPickup] = table[nearestPickup]
        end
        remainingPickups = TableEx.updateTable(remainingPickups)
    end

    return {voidingPickups, otherPickups}
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
        return BetterVoiding.clonePickup(pickup, true)
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
        return BetterVoiding.clonePickup(pickup, true)
    end
end

---------------------------------
-- TODO
-----------------------------------
local function getLookUpTableForICFlags(flagsIC)
    local flagsLUT = {}
    flagsLUT[1] = false
    flagsLUT[0] = false
    flagsLUT[PickupPrice.PRICE_ONE_HEART] = false
    flagsLUT[PickupPrice.PRICE_TWO_HEARTS] = false
    flagsLUT[PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS] = false
    flagsLUT[PickupPrice.PRICE_THREE_SOULHEARTS] = false
    flagsLUT[PickupPrice.PRICE_SOUL] = false
    flagsLUT[PickupPrice.PRICE_SPIKES] = false
    flagsLUT[PickupPrice.PRICE_FREE] = false

    if (flagsIC == BetterVoiding.ItemCategoryFlags.IC_ALL_ITEMS) then
        flagsIC = -1 --Activate all flags
    end
    if (flagsIC & BetterVoiding.ItemCategoryFlags.IC_FREE_ITEMS ~= 0) then
        flagsLUT[0] = true
    end
    if (flagsIC & BetterVoiding.ItemCategoryFlags.IC_HEARTDEAL_ITEMS ~= 0) then
        flagsLUT[PickupPrice.PRICE_ONE_HEART] = true
        flagsLUT[PickupPrice.PRICE_TWO_HEARTS] = true
        flagsLUT[PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS] = true
        flagsLUT[PickupPrice.PRICE_THREE_SOULHEARTS] = true
        flagsLUT[PickupPrice.PRICE_SOUL] = true
    end
    if (flagsIC & BetterVoiding.ItemCategoryFlags.IC_SHOP_ITEMS ~= 0) then
        flagsLUT[1] = true
        flagsLUT[PickupPrice.PRICE_FREE] = true
    end
    if (flagsIC & BetterVoiding.ItemCategoryFlags.IC_SPIKE_ITEMS ~= 0) then
        flagsLUT[PickupPrice.PRICE_SPIKES] = true
    end
    return flagsLUT
end

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Determins all pickups in the current room, which match flagsIC (default = IC_ALL_ITEMS) and their distance to the sourceEntity (default = Player_0)
----- @Return: Table of (Keys: Pickups, Values: Distance between the pickup and sourceEntity)
-------------------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.calculatePickupDist(sourceEntity, flagsIC)
    sourceEntity = sourceEntity or Isaac.GetPlayer() --set default value
    flagsIC = flagsIC or STD_FLAGS_IC

    local flagsLUT = getLookUpTableForICFlags(flagsIC)
    local pickupDists = {}
    local pickup = nil

    for _,entity in pairs(Isaac.GetRoomEntities()) do    -- Filter room for pickups
        if (entity.Type == EntityType.ENTITY_PICKUP) then
            pickup = entity:ToPickup()
            if flagsLUT[pickup.Price] then
                pickupDists[pickup] = sourceEntity.Position:Distance(pickup.Position)
            end
        end
    end
    return pickupDists
end

-----------------------------------------------------------------------------------------
-- Clones pickup on the next free position to clonePosition (default = pickup.Position)
----- @Return: Cloned pickup
-----------------------------------------------------------------------------------------
function BetterVoiding.clonePickup(pickup, cloneAnimation, clonePosition)
    if pickup == nil then return nil end
    if cloneAnimation == nil then
        cloneAnimation = true
    end
    clonePosition = clonePosition or pickup.Position

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

-----------------------------------------------------------------------------------------------------------
-- Returns nearest flagsIC (default = IC_ALL_ITEMS) matching item to the sourceEntity (default = Player_0)
----- @Return: Nearest item
-----------------------------------------------------------------------------------------------------------
function BetterVoiding.getNearestItem(sourceEntity, flagsIC)
    sourceEntity = sourceEntity or Isaac.GetPlayer() --set default value
    flagsIC = flagsIC or STD_FLAGS_IC

    return TableEx.getKeyOfLowestValue(calculateCollDist(sourceEntity, flagsIC))
end

----------------------------------------------------------------------------------------------------------------------
-- Returns nearest payable flagsIC (default = IC_ALL_ITEMS) matching item to the sourceEntity (default = Player_0)
----- @Return: Nearest payable item
----------------------------------------------------------------------------------------------------------------------
function BetterVoiding.getNearestPayableItem(sourceEntity, flagsIC)
    sourceEntity = sourceEntity or Isaac.GetPlayer() --set default value
    flagsIC = flagsIC or STD_FLAGS_IC

    local itemList = calculateCollDist(sourceEntity, flagsIC)
    local item = TableEx.getKeyOfLowestValue(itemList)

    while item ~= nil do
        if BetterVoiding.isPickupPayable(item, sourceEntity) then
            return item
        else
            itemList[item] = nil
            itemList = TableEx.updateTable(itemList)
            item = TableEx.getKeyOfLowestValue(itemList)
        end
    end
    return nil
end

--------------------------------------------------------------------------
-- Returns if the pickup is payable by sourceEntity (default = Player_0)
----- @Return: True if the sourceEntity can pay pickup, False otherwise
--------------------------------------------------------------------------
function BetterVoiding.isPickupPayable(pickup, sourceEntity)
    if pickup == nil then return false end
    sourceEntity = sourceEntity or Isaac.GetPlayer(0)

    if (pickup:IsShopItem()) then
        -- Item is always payable if sourceEntity is not one of the first 4 players
        local sourceEntityIsPlayer = false
        for i = 0, 3 do
            if GetPtrHash(sourceEntity) == GetPtrHash(Isaac.GetPlayer(i)) then
                sourceEntityIsPlayer = true
            end
        end

        if sourceEntityIsPlayer then
            local playerEntity = sourceEntity:ToPlayer()
            local pickupPrice = pickup.Price

            -- Player pays price for the pickup if he can
            if pickupPrice == PickupPrice.PRICE_ONE_HEART then
                if playerEntity:GetMaxHearts() < 2 then
                    return false
                end
            elseif pickupPrice == PickupPrice.PRICE_TWO_HEARTS then
                if playerEntity:GetMaxHearts() < 2 then
                    return false
                end
            elseif pickupPrice == PickupPrice.PRICE_THREE_SOULHEARTS then
                if playerEntity:GetSoulHearts() < 1 then
                    return false
                end
            elseif pickupPrice == PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS then
                if playerEntity:GetMaxHearts() < 2 or playerEntity:GetSoulHearts() < 2 then
                    return false
                end
            elseif pickupPrice == PickupPrice.PRICE_SOUL then
                if not playerEntity:HasTrinket(TrinketType.TRINKET_YOUR_SOUL, false) then
                    return false
                end
            elseif pickupPrice > 0 then
                if (playerEntity:GetNumCoins() < pickupPrice) then
                    return false
                end
            end
        end
    end

    return true
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Let sourceEntity (default = Player_0) pay for pickup.
-- If the pickup, which will be payed, is not forVoiding and it's in a restockable shop, it will be moved next to the restocked pickup
----- @Return: Payed pickup
-----------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.payPickup(pickup, sourceEntity, forVoiding)
    if pickup == nil then return nil end
    sourceEntity = sourceEntity or Isaac.GetPlayer()
    if forVoiding == nil then
        forVoiding = true
    end

    local playerEntity = nil
    local pickupPrice = nil
    local srcEntityIsLostlike = false

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
            if maxHearts < 2 or maxHeartsSoul < 2 then
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

        -- Manages OptionsPickupIndex of the pickup
        managePickupIndices(pickup, BetterVoiding.VoidingFlags.V_NEAREST_ITEM)

        -- Manages items for TheLost-like characters
        if srcEntityIsLostlike then
            for item,_ in  pairs(calculateCollDist()) do
                --removes other soulheart or spike deals in this room on next call of managePickupIndices
                if (item.Price == PickupPrice.PRICE_THREE_SOULHEARTS or item.Price == PickupPrice.PRICE_SPIKES) then
                    item.OptionsPickupIndex = 100
                end
            end
            managePickupIndices(pickup, BetterVoiding.VoidingFlags.V_NEAREST_ITEM)
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

----------------------------------
-- TODO
----------------------------------
function BetterVoiding.voidingItemConstructor(betterVoidingItemType, itemType, flagsV, flagsIC, preVoidingColor)
    if (betterVoidingItemType == nil) or (itemType == nil) then return end
    flagsV = flagsV or STD_FLAGS_V
    flagsIC = flagsIC or STD_FLAGS_IC
    preVoidingColor = preVoidingColor or STD_COLOR

    local itemTable = betterVoidingItemTables[betterVoidingItemType]

    if itemTable == nil then
        return -1
    end
    table.insert(itemTable.TYPE, itemType)
    table.insert(itemTable.COLOR, preVoidingColor)
    table.insert(itemTable.V_FLAGS, flagsV)
    table.insert(itemTable.IC_FLAGS, flagsIC)
    itemTable.COUNT = itemTable.COUNT + 1

    return (itemType << 3 | betterVoidingItemType)    --ID for a BetterVoiding item
end

-----------------------------------------------------------------------------------------------------------------------------------------------------
-- Prepares everything for voiding collectibles with the betterVoidingItem associated with betterVoidingItemID and
--- based on sourceEntity (default = Player_0)
----- @Return: Table of (Keys: Remaining voidable collectibles, Values: Distance to sourceEntity)
-----------------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.betterVoiding(betterVoidingItemID, sourceEntity)
    sourceEntity = sourceEntity or Isaac.GetPlayer()

    local itemTable = betterVoidingItemTables[betterVoidingItemID & 7] --Get betterVoidingItemType back from betterVoidingItemID
    local itemIndex = -1
    local allPickups = {}

    for i=1, #(itemTable.TYPE) do
        if (itemTable.TYPE[i] == betterVoidingItemID >> 3) then
            itemIndex = i
            goto skip
        end
    end
    ::skip::

    if itemIndex == -1 then
        return {}
    end

    allPickups = managePickupIndices(sourceEntity, itemTable.V_FLAGS[itemIndex], itemTable.IC_FLAGS[itemIndex])
    for pickup, _ in pairs(allPickups[1]) do
        BetterVoiding.payPickup(pickup, sourceEntity, true)
    end
    for pickup, _ in pairs(allPickups[2]) do
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, pickup.Position, Vector(0,0), pickup)
        pickup:Remove()
    end

    return allPickups[1]
end


--        <<< Including removing collectible(s) and play animation >>>
--------------------------------------------------------------------------------------------------------------------------------
-- Voiding ALL collectibles with the betterVoidingItem associated with betterVoidingItemID and
--- based on sourceEntity (default = Player_0) !!!Doesn't work with genesis!!!
----- @Return: Table of (Values: CollectibleTypes/EntitySubtypes of all voided collectibles)
--------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.betterVoidingRA(betterVoidingItemID, sourceEntity)
    sourceEntity = sourceEntity or Isaac.GetPlayer()

    local items = BetterVoiding.betterVoiding(betterVoidingItemID, sourceEntity)
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
local function betterVoidingColls(_, collType, _, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    BetterVoiding.betterVoiding((collType << 3 | BetterVoiding.VoidingItemTypes.TYPE_COLLECTIBLE), playerEntity)
    return true
end


-- Function for already existing voiding-cards/runes and its ModCallback
local function betterVoidingCards(_, cardType, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    local playerData = playerEntity:GetData()

    if playerData['mimicedCard'] then
        playerData['mimicedCard'] = nil
    else
        playerData['mimicedCard'] = true
        BetterVoiding.betterVoiding((cardType << 3 | BetterVoiding.VoidingItemTypes.TYPE_CARD), playerEntity)
        playerEntity:UseCard(cardType)
    end

    return nil
end

--------------------------------------------------------------------------------------------------------------------------
-- This function is for already existing mods with voiding-cards. It returns a function for a MC_USE_CARD ModCallback.
-- The returned functions pays the nearest item and activates the card a second time.
----- @Return: Function for ModCallbacks
--------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.betterVoidingReadyForCards()
    return betterVoidingCards
end

modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoidingColls, Isaac.GetItemIdByName("Void"))
modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoidingColls, Isaac.GetItemIdByName("Abyss"))
modBV:AddCallback(ModCallbacks.MC_USE_CARD, betterVoidingCards, Card.RUNE_BLACK)

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

modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, genesisActivated, Isaac.GetItemIdByName("Genesis"))
modBV:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, genesisDeactivated)
modBV:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, genesisFix)

----------------------------
-- TODO
----------------------------
local function spawnPreVoidingAnimation(color, parentItem)
    local preVoidingEntity = preVoidingAnmEntitys[GetPtrHash(parentItem)]
    local preVoidingSprite = preVoidingAnmSpites[GetPtrHash(parentItem)]

    if ((preVoidingEntity == nil) or (not preVoidingSprite:IsPlaying("Mark1"))) then
        if preVoidingEntity ~= nil then preVoidingEntity:Remove() end
        preVoidingEntity = Isaac.Spawn(EntityType.ENTITY_EFFECT, Isaac.GetEntityVariantByName("BV Item Marks"), 0, parentItem.Position, Vector(0,0), parentItem)
        preVoidingAnmEntitys[GetPtrHash(parentItem)] = preVoidingEntity

        preVoidingSprite = preVoidingEntity:GetSprite()
        preVoidingSprite.PlaybackSpeed = 0.9
        preVoidingSprite.Scale = Vector(1, 1.2)
        preVoidingSprite.Color = color
        preVoidingSprite:Play("Mark1", true)
        preVoidingAnmSpites[GetPtrHash(parentItem)] = preVoidingSprite
    end
end

----------------------------
-- TODO
----------------------------
local function preVoidingAnimation() -- PreVoiding animations will be removed if the corresponding item is removed
    local betterVoidingItemType = -1
    local itemType = 0
    local betterVoidingItemTable = nil
    local player = nil
    local allColls = {}

    for playerIndex=0, 3 do   --For each player
        player = Isaac.GetPlayer(playerIndex)
        if player ~= nil then
            betterVoidingItemType = BetterVoiding.VoidingItemTypes.TYPE_COLLECTIBLE         --Check item in PillSlot
            itemType = player:GetActiveItem(ActiveSlot.SLOT_POCKET)
            if (itemType == 0) or (player:NeedsCharge(ActiveSlot.SLOT_POCKET)) then
                betterVoidingItemType = BetterVoiding.VoidingItemTypes.TYPE_CARD
                itemType = player:GetCard(0)
                if (itemType == 0) then
                    betterVoidingItemType = BetterVoiding.VoidingItemTypes.TYPE_PILL
                    itemType = player:GetPill(0)
                    if (itemType == 0) then
                        betterVoidingItemType = BetterVoiding.VoidingItemTypes.TYPE_COLLECTIBLE
                        itemType = player:GetActiveItem()                                   --Check item in ActiveSlot
                        if (itemType == 0) then
                            goto skipThisPlayer
                        end
                    end
                end
            end

            betterVoidingItemTable = betterVoidingItemTables[betterVoidingItemType]

            for i=1, betterVoidingItemTable.COUNT do
                if betterVoidingItemTable.TYPE[i] == itemType then
                    allColls = managePickupIndices(player, betterVoidingItemTable.V_FLAGS[i], betterVoidingItemTable.IC_FLAGS[i])
                    for item, _ in pairs(allColls[1]) do
                        spawnPreVoidingAnimation(betterVoidingItemTable.COLOR[i], item)
                    end
                    return
                end
            end
        end
        ::skipThisPlayer::
    end
end

modBV:AddCallback(ModCallbacks.MC_POST_PICKUP_RENDER, preVoidingAnimation, PickupVariant.PICKUP_COLLECTIBLE)
---------------------------------------------------------------------------------------------------------