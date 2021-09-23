-----------------------------
-- Requiered Modules
-----------------------------

require("libs.tableEx")


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
    local collDist = {}
    local allEntities = Isaac.GetRoomEntities()

    for _,collEntity in pairs(allEntities) do    -- Filter room for collectibles
        if (collEntity.Type == EntityType.ENTITY_PICKUP and collEntity.Variant == PickupVariant.PICKUP_COLLECTIBLE
                and collEntity.SubType ~= CollectibleType.COLLECTIBLE_NULL) then
            collDist[collEntity:ToPickup()] = sourceEntity.Position:Distance(collEntity.Position)
        end
    end
    return collDist
end

-------------------------------------------------------------------------
-- Removes all items with the same OptionsPickupIndex as the itemPickup
----- @Retrun: itemPickup if it is payed
-------------------------------------------------------------------------
local function managePickupIndex(itemPickup)
    if itemPickup == nil then
        return nil
    end

    local index = itemPickup.OptionsPickupIndex
    if index ~= 0 then
        for item,_ in pairs(calculateCollDist()) do
            if (GetPtrHash(item) ~= GetPtrHash(itemPickup) and item.OptionsPickupIndex == index) then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, item.Position, Vector(0,0), item)
                item:Remove()
            end
        end
        itemPickup.OptionsPickupIndex = 0
    end

    return (itemPickup:IsShopItem() and nil) or itemPickup --if shopitem then nil else itemPickup
end

---------------------------------------------------------------------------------------------------------------
-- Removes all items with the same OptionsPickupIndex except the nearest items to sourceEntity for each index
----- @Return: Table of (Keys: Items, Values: Distance between the item and sourceEntity)
---------------------------------------------------------------------------------------------------------------
local function manageAllPickupIndices(sourceEntity)
    local indexTables = {}
    local index = 0
    local remainingItems = {}

    for item,dist in pairs(calculateCollDist(sourceEntity)) do
        if item:IsShopItem() then --ignore shop items
            goto continue
        end

        index = item.OptionsPickupIndex
        if (index == 0) then      --items without OptionsPickupIndex
            remainingItems[item] = dist
            goto continue
        end

        if indexTables[index] == nil then
            indexTables[index] = {}
        end
        indexTables[item.OptionsPickupIndex][item] = dist

        ::continue::
    end

    for _,table in pairs(indexTables) do
        local nearestItem = TableEx.getKeyOfLowestValue(table)
        remainingItems[nearestItem] = table[nearestItem]
        for item,_ in pairs(table) do
            if not (item == nearestItem) then
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, item.Position, Vector(0,0), item)
                item:Remove()
            end
        end
        nearestItem.OptionsPickupIndex = 0
    end
    return remainingItems
end

------------------------------------------------------------------------------------------------------------------
-- If the player holds 'Restock', new items will spawn in the shop when itemPickup got payed
-- <<< The price doesn't work if and only if: Voiding shop items and then buying them regulary or vice versa>>>
------------------------------------------------------------------------------------------------------------------
local function manageRestock(itemPickup)
    local roomType = game:GetRoom():GetType()
    if (roomType ~= RoomType.ROOM_SHOP or (not Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_RESTOCK))) then
        return
    end

    local itemPickupData = itemPickup:GetData()
    local newItem = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE
        , itemPool:GetCollectible(itemPool:GetPoolForRoom(roomType, seeds:GetStartSeed()), true, seeds:GetStartSeed()), itemPickup.Position, Vector(0,0), nil):ToPickup()

    newItem:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE | EntityFlag.FLAG_APPEAR)
    newItem.ShopItemId = itemPickup.ShopItemId

    if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_POUND_OF_FLESH) then
        newItem.Price = 1 --Price will get updated (important: Price ~= 0)
        return
    end

    local newItemData = newItem:GetData()
    if itemPickupData['restockNum'] == nil then
        newItemData['startingPrice'] = itemPickup.Price
        newItemData['restockNum'] = 1
    else
        newItemData['startingPrice'] = itemPickupData['startingPrice']
        newItemData['restockNum'] = itemPickupData['restockNum'] + 1
    end

    newItem.AutoUpdatePrice = false
    local newPrice = (newItemData['startingPrice'] + (newItemData['restockNum'] * (newItemData['restockNum'] + 1)))
    if newPrice > 99 then
        newPrice = 99
    end
    newItem.Price = newPrice
    newItemData['Price'] = newPrice

    return
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

    local pickupClone = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, pickup.SubType
        , game:GetRoom():FindFreePickupSpawnPosition(clonePosition), Vector(0,0), nil):ToPickup()

    pickupClone:AddEntityFlags(pickup:GetEntityFlags())
    pickupClone:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
    if cloneAnimation then
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

------------------------------------------
-- Let sourceEntity pay for itemPickup
----- @Return: Payed item
------------------------------------------
function BetterVoiding:payItem(itemPickup, sourceEntity)
    local playerEntity = nil
    local itemPrice = nil

    if itemPickup == nil or sourceEntity == nil then
        return nil
    end

    if (itemPickup:IsShopItem()) then
        -- Kill entity if it's not one of the first 4 players
        for i=0, 3 do
            if GetPtrHash(sourceEntity) == GetPtrHash(Isaac.GetPlayer(i)) then
                goto payment
            end
        end
        sourceEntity.Kill()
        goto payed

        ::payment::
        playerEntity = sourceEntity:ToPlayer()
        itemPrice = itemPickup.Price

        -- Player pays price for the item if he can
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
            local entityList = Isaac.GetRoomEntities()
            for _,entity in pairs(entityList) do
                if entity.Type == EntityType.ENTITY_EFFECT and entity.Variant == EffectVariant.SHOP_SPIKES then
                    if entity.Position.X == itemPickup.Position.X and entity.Position.Y == itemPickup.Position.Y then
                        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SHOP_SPIKES, 1, entity.Position, Vector(0,0), nil)
                        entity:Remove()
                    end
                end
            end

        elseif itemPrice == PickupPrice.PRICE_SOUL then
            if not playerEntity:HasTrinket(TrinketType.TRINKET_YOUR_SOUL, false) then
                return nil
            end
            if not playerEntity:TryRemoveTrinket(TrinketType.TRINKET_YOUR_SOUL) then
                return nil
            end
            playerEntity:TryRemoveTrinketCostume(TrinketType.TRINKET_YOUR_SOUL)

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

        ::payed::

        --manageRestock(itemPickup) --doesn't work as intended

        -- Manage items for TheLost-like characters
        if (playerEntity:GetSoulHearts() == 1 and playerEntity:GetMaxHearts() == 0) then
            for item,_ in  pairs(calculateCollDist()) do
               if (item.Price == PickupPrice.PRICE_THREE_SOULHEARTS or item.Price == PickupPrice.PRICE_SPIKES) then
                    item.OptionsPickupIndex = 200
                end
            end
            managePickupIndex(itemPickup) --removes other soulheart or spike deals in this room
        end

        -- Make item free
        itemPickup.Price = 0

        -- Devildeals only
        if game:GetRoom():GetType() == RoomType.ROOM_DEVIL then
            game:AddDevilRoomDeal()
        end
    end

    return itemPickup --return payed item
end

------------------------------------------------------------------
-- Prepares everything for voiding NEAREST item to sourceEntity
----- @Return: Nearest item if it could be payed
------------------------------------------------------------------
function BetterVoiding:betterVoidingNearestItem(sourceEntity)
    local item = BetterVoiding:payItem(BetterVoiding:getNearestItem(sourceEntity), sourceEntity)

    return managePickupIndex(item)
end

-------------------------------------------------------------------------------------------------
-- Prepares everything for voiding ALL items next to sourceEntity !!!(pays only nearest item)!!!
----- @Return: Table of (Keys: remaining voidable items, Values: Distance to sourceEntity)
-------------------------------------------------------------------------------------------------
function BetterVoiding:betterVoidingAllItems(sourceEntity)
    BetterVoiding:payItem(BetterVoiding:getNearestItem(sourceEntity), sourceEntity)

    return manageAllPickupIndices(sourceEntity)
end


--        <<< Including removing item(s) and play animation >>>

----------------------------------------------------------------------------------
-- Voiding NEAREST item to sourceEntity !!!Doesn't work with genesis!!!
----- @Return: CollectibleType/EntitySubtye of nearest item if it could be payed
----------------------------------------------------------------------------------
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

---------------------------------------------------------------------------------------------------------
-- Voiding ALL items next to sourceEntity !!!(pays only nearest item)!!! !!!Doesn't work with genesis!!!
----- @Return: Table of (Values: CollectibleTypes/EntitySubtypes of all voided items)
---------------------------------------------------------------------------------------------------------
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

-- Function for existing voiding-items and their ModCallbacks
local function betterVoiding()
    local item = BetterVoiding:betterVoidingAllItems(Isaac.GetPlayer())
    --[[debugText = ""
    for key, value in pairs(list) do
        debugText = debugText .. " " .. tostring(key.OptionsPickupIndex)
    end]]
    --debugText = tostring(item:GetData()['restockNum'])
    return true
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
            item.OptionsPickupIndex = 10
        end
    end
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Void"))
BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoiding, Isaac.GetItemIdByName("Abyss"))

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, genesisActivated, Isaac.GetItemIdByName("Genesis"))
BetterVoiding:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, genesisDeactivated)
BetterVoiding:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, genesisFix)
---------------------------------------------------------------------------------------------------------