-------------------------------------------------------------------------------------------------------------------------------------------
-- Requiered Modules
-------------------------------------------------------------------------------------------------------------------------------------------

require("libs.tableEx")

-------------------------------------------------------------------------------------------------------------------------------------------
--[[ Reserved Optionindices
100 = To manage Genesis
200 = To manage Lost-like characters
-----------------------------------------------------------------------------------------------------------------------------------------]]

-------------------------------------------------------------------------------------------------------------------------------------------
-- Global/Local variables and constants and Getter/Setter
-------------------------------------------------------------------------------------------------------------------------------------------
local modBV = RegisterMod("Better Voiding", 1)
-- Static variables
local game = Game()
local itemPool = game:GetItemPool()
local seeds = game:GetSeeds()
-- Used to detect if player is in Genesis-HOME room
local genesisActive = false
-- Used for PreVoiding animations
local preVoidingAnmEntitys = {}
local preVoidingAnmSprites = {}

-- To access BetterVoiding functions from outside this mod
BetterVoiding = {version = "1.0"}
-- Flags to determine how the voiding of an BetterVoiding item works
BetterVoiding.VoidingFlags = {
    V_ALL_FREE_PICKUPS = 1<<0,              --All free Pickups
    V_NEAREST_PICKUP = 1<<1,                --Nearest Pickup
    V_NEAREST_PAYABLE_PICKUP = 1<<2,        --Nearest payable Pickup
}
-- Flags to select pickups in a room
BetterVoiding.PickupCategoryFlags = {
    PC_ALL_PICKUPS = 0,
    PC_PRICE_FREE = 1<<0,                   --PickupPrices
    PC_PRICE_HEARTS = 1<<1,
    PC_PRICE_COINS = 1<<2,
    PC_PRICE_SPIKES = 1<<3,
    PC_TYPE_COLLECTIBLE = 1<<10,            --PickupTypes
    PC_TYPE_TRINKET = 1<<11,
    PC_TYPE_PILL = 1<<12,
    PC_TYPE_CARD = 1<<13,
    PC_TYPE_CONSUMABLE = 1<<14
}
-- Standard values for BetterVoiding items
local STD_COLOR = Color(0.5,0.5,0.5,0.9,0,0,0)
local STD_FLAGS_V = BetterVoiding.VoidingFlags.V_ALL_FREE_PICKUPS | BetterVoiding.VoidingFlags.V_NEAREST_PAYABLE_PICKUP
local STD_FLAGS_PC = BetterVoiding.PickupCategoryFlags.PC_ALL_PICKUPS | BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE

-- Types to describe the PickupVariant of an BetterVoiding item
BetterVoiding.BetterVoidingItemType = {
    TYPE_COLLECTIBLE = 1,
    TYPE_CARD = 2,
    TYPE_PILL = 3
}
-- Tables for the BetterVoiding items
local voidingColls = {
    TYPE = {CollectibleType.COLLECTIBLE_VOID, CollectibleType.COLLECTIBLE_ABYSS},
    COLOR = {Color(0.38,0.33,0.38,0.9,0,0,0), Color(0.8,0.1,0.1,0.9,0,0,0)},
    V_FLAGS = {STD_FLAGS_V, STD_FLAGS_V},
    PC_FLAGS = {STD_FLAGS_PC, STD_FLAGS_PC},
    COUNT = 2
}
local voidingCards = {
    TYPE = {Card.RUNE_BLACK},
    COLOR = {Color(0.11,0.11,0.11,0.9,0,0,0)},
    V_FLAGS = {STD_FLAGS_V},
    PC_FLAGS = {STD_FLAGS_PC},
    COUNT = 1
}
local voidingPills = {
    TYPE = {},
    COLOR = {},
    V_FLAGS = {},
    PC_FLAGS = {},
    COUNT = 0
}
local betterVoidingItemTables = {voidingColls, voidingCards, voidingPills}
-------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------
-- Spawns a new pickup in the shop on the position of prePickup. Is used to manage GreedShops and for the Restock collectible
----- @Return: New pickup
-------------------------------------------------------------------------------------------------------------------------------------------
local function restockShopPickup(prePickup)
    local newPickup = nil
    local pickupType = nil

    -- Determine type of the new pickup
    if prePickup.Variant == PickupVariant.PICKUP_COLLECTIBLE then
        pickupType =
            itemPool:GetCollectible(itemPool:GetPoolForRoom(game:GetRoom():GetType(), seeds:GetNextSeed()), true, seeds:GetStartSeed())
    elseif prePickup.Variant == PickupVariant.PICKUP_TAROTCARD then
        pickupType = itemPool:GetCard(seeds:GetNextSeed(), true, true, false)
    elseif prePickup.Variant == PickupVariant.PICKUP_PILL then
        pickupType = itemPool:GetPill(seeds:GetNextSeed())
    else
        pickupType = prePickup.SubType
    end
    -- Spawn new pickup without animation
    newPickup = Isaac.Spawn(prePickup.Type, prePickup.Variant, pickupType, prePickup.Position, Vector(0,0), nil):ToPickup()
    newPickup:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE | EntityFlag.FLAG_APPEAR)      --disable spawn animation and damocles effect
    newPickup.ShopItemId = prePickup.ShopItemId     --set new pickup on the same shopposition

    return newPickup
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- In Greedmode shops will spawn new pickups, if the old pickup got payed.
-- If pickup is not forVoiding, it will be moved next to the new shop pickup
----- @Return: Payed pickup
-------------------------------------------------------------------------------------------------------------------------------------------
local function manageGreedShop(pickup, forVoiding)
    local newPickup = restockShopPickup(pickup)

    newPickup.Price = pickup.Price      --price will get updated automatically (important: Price ~= 0)
    if forVoiding then
        return pickup
    else
        return BetterVoiding.clonePickup(pickup, true)      --clone pickup on next free position if it is not forVoiding
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- If the player holds 'Restock', new pickups will spawn in the shop when pickup got payed.
-- If pickup is not forVoiding, it will be moved next to the new shop pickup
-- <<< The price doesn't work if and only if the player is voiding shop pickups and then buying pickup regulary or vice versa >>>
----- @Return: Payed pickup
-------------------------------------------------------------------------------------------------------------------------------------------
local function manageRestock(pickup, forVoiding)
    if (game:GetRoom():GetType() ~= RoomType.ROOM_SHOP) or (not Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_RESTOCK)) then
        return pickup
    end

    local pickupData = pickup:GetData()
    local newPickup = restockShopPickup(pickup)
    local newPickupData = newPickup:GetData()
    local newPickupPrice = nil

    -- Calculate price of the newPickup and manage some metadata
    if Isaac.GetPlayer():HasCollectible(CollectibleType.COLLECTIBLE_POUND_OF_FLESH) then
        newPickup.Price = 1         --price will get updated automatically (important: Price ~= 0)
    else
        if pickupData['restockNum'] == nil then
            newPickupData['startingPrice'] = pickup.Price
            newPickupData['restockNum'] = 1
        else
            newPickupData['startingPrice'] = pickupData['startingPrice']
            newPickupData['restockNum'] = pickupData['restockNum'] + 1
        end
        newPickup.AutoUpdatePrice = false
        --Calculate new price
        newPickupPrice = (newPickupData['restockNum'] * (newPickupData['restockNum'] + 1))
        if newPickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
            newPickupPrice = newPickupPrice / 2
        end
        newPickupPrice = newPickupPrice + newPickupData['startingPrice']
        if newPickupPrice > 99 then
            newPickupPrice = 99
        end
        newPickup.Price = newPickupPrice
        newPickupData['Price'] = newPickupPrice
    end
    -- Check if pickup is forVoiding
    if forVoiding then
        return pickup
    else
        return BetterVoiding.clonePickup(pickup, true)      --clone pickup on next free position if it is not forVoiding
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Returns a LookUpTable for flagsPC
----- @Return: Lookup Table of (Keys: PickupPrices and Variants, Values: True if this price or variant is allowed, nil otherwise6)
-------------------------------------------------------------------------------------------------------------------------------------------
local function getLookUpTableForPCFlags(flagsPC)
    local flagsLUT = {}

    -- Handle PickupCategoryFlags
    local offset = 10
    if (flagsPC == BetterVoiding.PickupCategoryFlags.PC_ALL_PICKUPS) then
        flagsPC = ~0        --activate all flags (= ...111111111)
    elseif ((flagsPC & (2^offset - 1)) == 0) then
        flagsPC = flagsPC | (2^offset - 1)
    end
    if ((flagsPC >> offset) == 0) then
        flagsPC = flagsPC | ~(2^offset - 1)
    end
    -- PriceFlags
    if (flagsPC & BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE ~= 0) then
        flagsLUT[0] = true
    end
    if (flagsPC & BetterVoiding.PickupCategoryFlags.PC_PRICE_HEARTS ~= 0) then
        flagsLUT[PickupPrice.PRICE_ONE_HEART] = true
        flagsLUT[PickupPrice.PRICE_TWO_HEARTS] = true
        flagsLUT[PickupPrice.PRICE_ONE_HEART_AND_TWO_SOULHEARTS] = true
        flagsLUT[PickupPrice.PRICE_THREE_SOULHEARTS] = true
        flagsLUT[PickupPrice.PRICE_SOUL] = true
    end
    if (flagsPC & BetterVoiding.PickupCategoryFlags.PC_PRICE_COINS ~= 0) then
        flagsLUT[1] = true
        flagsLUT[PickupPrice.PRICE_FREE] = true
    end
    if (flagsPC & BetterVoiding.PickupCategoryFlags.PC_PRICE_SPIKES ~= 0) then
        flagsLUT[PickupPrice.PRICE_SPIKES] = true
    end
    -- TypeFlags
    flagsLUT[PickupVariant.PICKUP_COLLECTIBLE] = ((flagsPC & BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE) ~= 0)
    flagsLUT[PickupVariant.PICKUP_TRINKET] =  ((flagsPC & BetterVoiding.PickupCategoryFlags.PC_TYPE_TRINKET) ~= 0)
    flagsLUT[PickupVariant.PICKUP_TAROTCARD] = ((flagsPC & BetterVoiding.PickupCategoryFlags.PC_TYPE_CARD) ~= 0)
    flagsLUT[PickupVariant.PICKUP_PILL] = ((flagsPC & BetterVoiding.PickupCategoryFlags.PC_TYPE_PILL) ~= 0)
    if (flagsPC & BetterVoiding.PickupCategoryFlags.PC_TYPE_CONSUMABLE ~= 0 ) then
        flagsLUT[PickupVariant.PICKUP_HEART] = true
        flagsLUT[PickupVariant.PICKUP_COIN] = true
        flagsLUT[PickupVariant.PICKUP_KEY] = true
        flagsLUT[PickupVariant.PICKUP_BOMB] = true
        flagsLUT[PickupVariant.PICKUP_GRAB_BAG] = true
        flagsLUT[PickupVariant.PICKUP_LIL_BATTERY] = true
    end

    return flagsLUT
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Determins all pickups in the current room, which match flagsPC (default = PC_ALL_PICKUPS | PC_TYPE_COLLECTIBLE) and
--- their distance to position (default = Player_0.Position)
----- @Return: KeyTable of (Keys: Pickups, Values: Distance between the pickup and position)
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.calculatePickupDist(position, flagsPC)
    position = position or Isaac.GetPlayer().Position
    flagsPC = flagsPC or BetterVoiding.PickupCategoryFlags.PC_ALL_PICKUPS

    local flagsLUT = getLookUpTableForPCFlags(flagsPC)
    local pickupDists = {}
    local pickup = nil
    local pickupPrice = 0

    -- Filter room for pickups
    for _,entity in pairs(Isaac.GetRoomEntities()) do
        if (entity.Type == EntityType.ENTITY_PICKUP) then
            pickup = entity:ToPickup()
            pickupPrice = pickup.Price
            if pickupPrice > 0 then pickupPrice = 1 end     --replace price for shop pickups (For Look-Up-Table)
            if (flagsLUT[pickupPrice] and flagsLUT[pickup.Variant]) and (pickup.SubType ~= 0) then      --SupType ~= 0 important for collectible
                pickupDists[pickup] = position:Distance(pickup.Position)
            end
        end
    end

    return pickupDists
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Returns nearest flagsPC (default = PC_ALL_PICKUPS) matching pickup to position (default = Player_0.Position)
----- @Return: Nearest pickup
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.getNearestPickup(position, flagsPC)
    flagsPC = flagsPC or BetterVoiding.PickupCategoryFlags.PC_ALL_PICKUPS
    position = position or Isaac.GetPlayer().Position

    return TableEx.getKeyOfLowestValue(BetterVoiding.calculatePickupDist(position, flagsPC))
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Returns if the pickup is payable by sourceEntity (default = Player_0)
----- @Return: True if the sourceEntity can pay pickup, False otherwise
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.isPickupPayable(pickup, sourceEntity)
    if pickup == nil then return false end
    sourceEntity = sourceEntity or Isaac.GetPlayer(0)

    if (pickup:IsShopItem()) then
        -- Pickup is always payable if sourceEntity is not one of the first 4 players
        local sourceEntityIsPlayer = false
        for i = 0, 3 do
            if GetPtrHash(sourceEntity) == GetPtrHash(Isaac.GetPlayer(i)) then
                sourceEntityIsPlayer = true
            end
        end

        if sourceEntityIsPlayer then
            local playerEntity = sourceEntity:ToPlayer()
            local pickupPrice = pickup.Price

            -- Check if playerEntity could pay for pickup
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

-------------------------------------------------------------------------------------------------------------------------------------------
-- Returns nearest pickup to position (default = sourceEntity.Position), which is payable by sourceEntity (default = Player_0)
-- The Pickup has to match flagsPC (default = PC_ALL_PICKUPS)
----- @Return: Nearest payable collectible
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.getNearestPayablePickup(sourceEntity, flagsPC, position)
    sourceEntity = sourceEntity or Isaac.GetPlayer()
    flagsPC = flagsPC or BetterVoiding.PickupCategoryFlags.PC_ALL_PICKUPS
    position = position or sourceEntity.Position

    local pickupList = BetterVoiding.calculatePickupDist(position, flagsPC)
    local pickup = TableEx.getKeyOfLowestValue(pickupList)

    -- Iterate over all collectibles from nearest to farest and check if one is payable
    while pickup ~= nil do
        if BetterVoiding.isPickupPayable(pickup, sourceEntity) then
            return pickup
        else
            pickupList[pickup] = nil
            pickupList = TableEx.updateTable(pickupList)
            pickup = TableEx.getKeyOfLowestValue(pickupList)
        end
    end
    return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Clones pickup on the next free position to clonePosition (default = pickup.Position) with/without a cloneAnimation (default = true)
----- @Return: Cloned pickup
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.clonePickup(pickup, cloneAnimation, clonePosition)
    if pickup == nil then return nil end
    if cloneAnimation == nil then
        cloneAnimation = true
    end
    clonePosition = clonePosition or pickup.Position

    local clonedPickupData = nil
    local clonedPickup = nil

    -- Spawn clonedPickup
    clonedPickup = Isaac.Spawn(EntityType.ENTITY_PICKUP, pickup.Variant, pickup.SubType
        , game:GetRoom():FindFreePickupSpawnPosition(clonePosition), Vector(0,0), nil):ToPickup()
    clonedPickup:AddEntityFlags(pickup:GetEntityFlags())
    clonedPickup:ClearEntityFlags(EntityFlag.FLAG_ITEM_SHOULD_DUPLICATE)
    if not cloneAnimation then
        clonedPickup:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
    end
    -- Transfer attributes from pickup to clonedPickup
    clonedPickup.OptionsPickupIndex = pickup.OptionsPickupIndex
    clonedPickup.ShopItemId = pickup.ShopItemId
    clonedPickup.AutoUpdatePrice = pickup.AutoUpdatePrice
    clonedPickup.Price = pickup.Price
    clonedPickupData = clonedPickup:GetData()
    for key, value in pairs(pickup:GetData()) do
        clonedPickupData[key] = value
    end
    pickup:Remove()

    return clonedPickup
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Sorts all flagsPC matching pickups in a room based on flagsV, sourceEntity and position.
-- selectedPickups are the selected pickups by flagsV and sourceEntity or position.
-- lostPickups are all pickups which will get lost if the selectedPickups are picked up. (determined by OptionsPickup Index)
-- remainingPickups are all leftover pickups, which matches flagsPC but didn't get selected or get lost.
----- @Return: Table of 3 keyTables (selectedPickups, lostPickups, remainingPickups) For each: (Keys: Pickup, Values: Distance form position to pickup)
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.selectPickups(sourceEntity, flagsV, flagsPC, position)
    sourceEntity = sourceEntity or Isaac.GetPlayer(0)
    flagsV = flagsV or STD_FLAGS_V
    flagsPC = flagsPC or BetterVoiding.PickupCategoryFlags.PC_ALL_PICKUPS
    position = position or sourceEntity.Position

    local pickupIndex = 0
    local nearestPickup = nil
    local pickupIndexTables = {}
    local selectedPickups = {}   --pickups which are voidable
    local lostPickups = {}      --pickups which should be removed if the selectedPickups are taken
    local remainingPickups = BetterVoiding.calculatePickupDist(position, flagsPC)   --pickups which doesn't belong to selectedPickups or lostPickups

    -- Group remainingPickups by OptionsPickupIndex
    for pickup, dist in pairs(remainingPickups) do
        pickupIndex = pickup.OptionsPickupIndex
        if pickupIndexTables[pickupIndex] == nil then
            pickupIndexTables[pickupIndex] = {}
        end
        pickupIndexTables[pickupIndex][pickup] = dist
    end
    -- Handle VoidingFlags:

    --- V_NEAREST_PAYABLE_PICKUP and V_NEAREST_PICKUP
    nearestPickup = nil
    if (flagsV & BetterVoiding.VoidingFlags.V_NEAREST_PAYABLE_PICKUP) ~= 0 then
        nearestPickup = BetterVoiding.getNearestPayablePickup(sourceEntity, flagsPC, position)
    elseif (flagsV & BetterVoiding.VoidingFlags.V_NEAREST_PICKUP) ~= 0 then
        nearestPickup = BetterVoiding.getNearestPickup(position, flagsPC)
    end
    if nearestPickup ~= nil then
        -- Select nearestPickup
        pickupIndex = nearestPickup.OptionsPickupIndex
        for pickup, _ in pairs(pickupIndexTables[pickupIndex]) do
            if GetPtrHash(pickup) == GetPtrHash(nearestPickup) then
                nearestPickup = pickup
                selectedPickups[nearestPickup] = pickupIndexTables[pickupIndex][nearestPickup]
                remainingPickups[nearestPickup] = nil
                pickupIndexTables[pickupIndex][nearestPickup] = nil
                goto DetermineLostPickups
            end
        end
        -- Determine lostPickups
        ::DetermineLostPickups::
        if pickupIndex ~= 0 then
            for pickup, dist in pairs(pickupIndexTables[pickupIndex]) do
                if dist ~= nil then
                    lostPickups[pickup] = dist
                    pickupIndexTables[pickupIndex][pickup] = nil
                end
                remainingPickups[pickup] = nil
            end
        end
        -- Update necessary tables
        pickupIndexTables[pickupIndex] = TableEx.updateTable(pickupIndexTables[pickupIndex])
        remainingPickups = TableEx.updateTable(remainingPickups)
    end

    --- V_ALL_FREE_PICKUPS
    if (flagsV & BetterVoiding.VoidingFlags.V_ALL_FREE_PICKUPS) ~= 0 then
        for index, pickupTable in pairs(pickupIndexTables) do
            if index == 0 then
                -- Select all pickups if their OptionsPickupIndex = 0
                for pickup, dist in pairs(pickupTable) do
                    if pickup.Price == 0 then
                        selectedPickups[pickup] = dist
                        remainingPickups[pickup] = nil
                    end
                end
            else
                -- Select nearestPickup with this index
                nearestPickup = nil
                local nearestPickupDist = -1
                for pickup, dist in pairs(pickupTable) do
                    if pickup.Price == 0 then
                        if (nearestPickupDist == -1) or (dist < nearestPickupDist) then
                            nearestPickup = pickup
                            nearestPickupDist = dist
                        end
                    end
                end
                -- Determine lostPickups
                if nearestPickup ~= nil then
                    selectedPickups[nearestPickup] = pickupTable[nearestPickup]
                    remainingPickups[nearestPickup] = nil
                    pickupTable[nearestPickup] = nil
                    for pickup, dist in pairs(pickupTable) do
                        if dist ~= nil then
                            lostPickups[pickup] = dist
                            remainingPickups[pickup] = nil
                        end
                    end
                end
            end
            pickupIndexTables[index] = {}
        end
        remainingPickups = TableEx.updateTable(remainingPickups)
    end

    return {selectedPickups, lostPickups, remainingPickups}
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Selects pickups out of Table refPickups with different OptionsPickupIndices and despawns all pickups with the same OpitonsPickupIndex.
-- The first pickup in refPickup with a new OptionsPickupIndex is taken, if it contains more than one pickup with the same OptionsPickupIndex.
----- @Return: Table of (Values: Selected pickups) (Order: Same as in refPickups)
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.managePickupIndices(refPickups)
    refPickups = refPickups or {}

    local pickupIndex = 0
    local pickupIndexTables = {}
    local pickupTable = nil
    local selectedPickups = {}
    local allPickups = BetterVoiding.calculatePickupDist()   --pickups which doesn't belong to selectedPickups or lostPickups

    -- Initialise pickupIndexTables
    for i=1, #refPickups do
        pickupIndexTables[refPickups[i].OptionsPickupIndex] = {}
    end
    -- Group allPickups by OptionsPickupIndex
    for pickup, dist in pairs(allPickups) do
        pickupIndex = pickup.OptionsPickupIndex
        if pickupIndexTables[pickupIndex] ~= nil then
            pickupIndexTables[pickupIndex][pickup] = dist
        end
    end
    -- Select or despawn pickups
    for i=1, #refPickups do
        pickupIndex = refPickups[i].OptionsPickupIndex
        pickupTable = pickupIndexTables[pickupIndex]
        for pickup, _ in pairs(pickupTable) do
            if (GetPtrHash(pickup) == GetPtrHash(refPickups[i])) and (pickupTable[pickup] ~= nil) then
                -- Take the refPickup and set its index to 0
                refPickups[i].OptionsPickupIndex = 0
                table.insert(selectedPickups, refPickups[i])
            elseif pickup.OptionsPickupIndex ~= 0 then
                -- Remove all other pickups with same OptionsPickupIndex and play POOF animation
                Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, pickup.Position, Vector(0,0), pickup)
                pickupTable[pickup] = nil      --fix multiple items with same OptionsPickupIndex in refPickup
                pickup:Remove()
            end
        end
    end

    return selectedPickups
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Let sourceEntity (default = Player_0) pay for pickup.
-- If the pickup is not forVoiding (default = true), it will be moved next to the restocked pickup (in a restockable shop)
----- @Return: Payed pickup
-------------------------------------------------------------------------------------------------------------------------------------------
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
        sourceEntity:Kill()
        goto payed

        ::payment::
        playerEntity = sourceEntity:ToPlayer()
        pickupPrice = pickup.Price
        srcEntityIsLostlike = (playerEntity:GetSoulHearts() == 1 and playerEntity:GetMaxHearts() == 0)

        -- Player pays price for the pickup if he can
        -- Price: 1 RedHeart
        if pickupPrice == PickupPrice.PRICE_ONE_HEART then
            if playerEntity:GetMaxHearts() < 2 then
                return nil
            end
            playerEntity:AddMaxHearts(-2)
        -- Price: 2 RedHearts
        elseif pickupPrice == PickupPrice.PRICE_TWO_HEARTS then
            local maxHearts = playerEntity:GetMaxHearts()
            if maxHearts < 2 then
                return nil
            elseif maxHearts >= 4 then
                maxHearts = 4
            end
            playerEntity:AddMaxHearts(-maxHearts)
        -- Price: 3 SoulHearts
        elseif pickupPrice == PickupPrice.PRICE_THREE_SOULHEARTS then
            local maxHeartsSoul = playerEntity:GetSoulHearts()
            if maxHeartsSoul < 1 then
                return nil
            elseif maxHeartsSoul >= 6 then
                maxHeartsSoul = 6
            end
            playerEntity:AddSoulHearts(-maxHeartsSoul)
        -- Price: 1 RedHeart & 2 SoulHearts
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
        -- Price: Spikes
        elseif pickupPrice == PickupPrice.PRICE_SPIKES then
            -- Pay price
            if not srcEntityIsLostlike then
                playerEntity:TakeDamage(2, DamageFlag.DAMAGE_NO_PENALTIES, EntityRef(pickup), 0)
            end
            -- Handle spike animation
            local entityList = Isaac.GetRoomEntities()
            for _,entity in pairs(entityList) do
                if entity.Type == EntityType.ENTITY_EFFECT and entity.Variant == EffectVariant.SHOP_SPIKES then
                    if entity.Position.X == pickup.Position.X and entity.Position.Y == pickup.Position.Y then
                        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.SHOP_SPIKES, 1, entity.Position, Vector(0,0), nil)
                        entity:Remove()
                    end
                end
            end
        -- Price: Soul
        elseif pickupPrice == PickupPrice.PRICE_SOUL then
            if not playerEntity:HasTrinket(TrinketType.TRINKET_YOUR_SOUL, false) then
                return nil
            end
            if not playerEntity:TryRemoveTrinket(TrinketType.TRINKET_YOUR_SOUL) then
                return nil
            end
            playerEntity:TryRemoveTrinketCostume(TrinketType.TRINKET_YOUR_SOUL)
        -- Price: Coins
        elseif pickupPrice > 0 then
            local playersCoins = playerEntity:GetNumCoins()
            if (pickupPrice > playersCoins) then
                return nil
            else
                playerEntity:AddCoins(-pickupPrice)
            end
        -- Price: UNKNOWN
        else
            return nil
        end

        ::payed::
        -- Manages interaction with collectible 'Restock'
        --pickup = manageRestock(pickup, forVoiding) --doesn't work as intended

        -- Manages OptionsPickupIndex of the pickup
        pickup = BetterVoiding.managePickupIndices({pickup})[1]
        -- Manages pickups for TheLost-like characters
        if srcEntityIsLostlike then         --watch out: triggers everytime a lost-like character is paying a pickup
            -- Removes other collectibles which have soulheart or spike prices in this room
            for p, _ in  pairs(BetterVoiding.calculatePickupDist(nil, STD_FLAGS_PC)) do
                if (p.Price == PickupPrice.PRICE_THREE_SOULHEARTS or p.Price == PickupPrice.PRICE_SPIKES) then
                    p.OptionsPickupIndex = 100
                end
            end
            pickup.OptionsPickupIndex = 100
            pickup = BetterVoiding.managePickupIndices({pickup})[1]
        end
        -- Manages shop restocks in Greedmode
        if game:IsGreedMode() then
            if ((game:GetRoom():GetType() == RoomType.ROOM_SHOP) and (pickup.Price ~= 0)) then
                pickup = manageGreedShop(pickup, forVoiding)
            end
        end
        -- Remove AngleDeals if a DevilDeal was payed
        if game:GetRoom():GetType() == RoomType.ROOM_DEVIL then
            game:AddDevilRoomDeal()
        end

        -- Make pickup free
        pickup.Price = 0
    end

    return pickup --return payed pickup
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- ModCallbacks ---------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------
-- Global access
-------------------------------------------------------------------------------------------------------------------------------------------

-- Function for already existing voiding-collectibles and their ModCallbacks to turn them into BetterVoiding items
local function betterVoidingColls(_, collType, _, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    BetterVoiding.betterVoiding((collType << 3 | BetterVoiding.BetterVoidingItemType.TYPE_COLLECTIBLE), playerEntity)
    return nil
end

-- Function for already existing voiding-cards/runes and their ModCallback to turn them into BetterVoiding items
local function betterVoidingCards(_, cardType, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    local playerData = playerEntity:GetData()

    if playerData['mimicedCard'] then
        playerData['mimicedCard'] = nil
    else
        playerData['mimicedCard'] = true
        BetterVoiding.betterVoiding((cardType << 3 | BetterVoiding.BetterVoidingItemType.TYPE_CARD), playerEntity)
        playerEntity:UseCard(cardType)
    end

    return nil
end

-- Function for already existing voiding-pills and their ModCallback to turn them into BetterVoiding items
local function betterVoidingPills(_, pillType, playerEntity)
    playerEntity = playerEntity or Isaac.GetPlayer()
    local playerData = playerEntity:GetData()

    if playerData['mimicedPill'] then
        playerData['mimicedPill'] = nil
    else
        playerData['mimicedPill'] = true
        BetterVoiding.betterVoiding((pillType << 3 | BetterVoiding.BetterVoidingItemType.TYPE_CARD), playerEntity)
        playerEntity:UsePill(pillType)
    end

    return nil
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Needs to be called if BetterVoiding item is added to the game. The function needs the betterVoidingItemType and itemType of the
--- BetterVoiding item. The new BetterVoiding item get registered with flagsV, flagsPC and preVoidingColor (default = grey).
-- If generateModCallback is true, a ModCallback is automatically created for the BetterVoiding item,
--- otherwise you have to implement the function betterVoiding() in your own ModCallback for the item.
-- If betterVoidingItemType is CARD or PILL, the item will be used first then apply BetterVoiding functions and then used a second time.
----- @Return: ID for this BetterVoiding item
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.betterVoidingItemConstructor(betterVoidingItemType, itemType, generateModCallback, flagsV, flagsPC, preVoidingColor)
    if (betterVoidingItemType == nil) or (itemType == nil) then return -1 end
    if generateModCallback == nil then
        generateModCallback = false
    end
    flagsV = flagsV or STD_FLAGS_V
    flagsPC = flagsPC or STD_FLAGS_PC
    preVoidingColor = preVoidingColor or STD_COLOR

    local itemTable = betterVoidingItemTables[betterVoidingItemType]

    -- Check input parameters
    if itemTable == nil then
        return -1       --if betterVoidingItemType doesn't exist
    end
    --[[ If overriding an already existing BetterVoiding item shouldn't be allowed
    for i=1, itemTable.COUNT do
        if itemTable.TYPE[i] == itemType then
            return -2   --BetterVoiding item with this itemType already exists
        end
    end
    --]]

    -- Add a new BetterVoiding item to the corresponding itemTable
    table.insert(itemTable.TYPE, itemType)
    table.insert(itemTable.COLOR, preVoidingColor)
    table.insert(itemTable.V_FLAGS, flagsV)
    table.insert(itemTable.PC_FLAGS, flagsPC)
    itemTable.COUNT = itemTable.COUNT + 1

    if generateModCallback then
        if betterVoidingItemType == BetterVoiding.BetterVoidingItemType.TYPE_COLLECTIBLE then
            modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoidingColls, itemType)
        elseif betterVoidingItemType == BetterVoiding.BetterVoidingItemType.TYPE_CARD then
            modBV:AddCallback(ModCallbacks.MC_USE_CARD, betterVoidingCards, itemType)
        --[[ Work in Progress
        elseif betterVoidingItemType == BetterVoiding.BetterVoidingItemType.TYPE_PILL then
            modBV:AddCallback(ModCallbacks.MC_USE_PILL, betterVoidingPills, itemType)--]]
        end
    end

    return (itemType << 3 | betterVoidingItemType)    --ID for a BetterVoiding item
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Prepares everything for voiding pickups with a BetterVoiding item associated with the betterVoidingItemID and
--- based on sourceEntity (default = Player_0)
----- @Return: KeyTable of (Keys: Remaining voidable pickups, Values: Distance to sourceEntity)
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.betterVoiding(betterVoidingItemID, sourceEntity)
    if betterVoidingItemID == nil then return nil end
    sourceEntity = sourceEntity or Isaac.GetPlayer()

    local itemTable = betterVoidingItemTables[betterVoidingItemID & (2^3 - 1)]      --get BetterVoidingItemTable out of betterVoidingItemID
    local itemType = betterVoidingItemID >> 3       --get the itemType out of betterVoidingItemID
    local betterVoidingItemIndex = -1
    local allPickups = {}
    local voidablePickups = {}

    -- Get the index of the BetterVoiding item in itemTable
    for i=1, itemTable.COUNT do
        if (itemTable.TYPE[i] == itemType) then
            betterVoidingItemIndex = i
            goto skip
        end
    end
    if betterVoidingItemIndex == -1 then
        return nil
    end
    ::skip::

    -- Prepare allPickups in the room for voiding
    allPickups = BetterVoiding.selectPickups(sourceEntity, itemTable.V_FLAGS[betterVoidingItemIndex], itemTable.PC_FLAGS[betterVoidingItemIndex])
    for voidablePickup, dist in pairs(allPickups[1]) do
        local payedPickup = BetterVoiding.payPickup(voidablePickup, sourceEntity, true)
        if payedPickup ~= nil then
            voidablePickups[payedPickup] = dist
        end
    end
    for lostPickup, _ in pairs(allPickups[2]) do
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 1, lostPickup.Position, Vector(0,0), lostPickup)
        lostPickup:Remove()
    end

    return voidablePickups
end

--        <<< Including removing collectible(s) and play animation >>>
-------------------------------------------------------------------------------------------------------------------------------------------
-- Voids ALL pickups with a BetterVoiding item associated with the betterVoidingItemID and
--- based on sourceEntity (default = Player_0) !!!Doesn't work with genesis!!!
----- @Return: Enum of 2 Tables: VARIANT (Values: Variants of all voidable collectibles) SUBTYPE (Values: SubTypes of all voidable pickups)
-------------------------------------------------------------------------------------------------------------------------------------------
function BetterVoiding.betterVoidingRA(betterVoidingItemID, sourceEntity)
    sourceEntity = sourceEntity or Isaac.GetPlayer()

    local voidablePickups = BetterVoiding.betterVoiding(betterVoidingItemID, sourceEntity)     --retuns nil if betterVoidingItemID is invalid
    local voidedPickups = {
        VARIANT = {},
        SUBTYPE = {}
    }

    -- Check if betterVoidingItemID is valid
    if voidablePickups == nil then
        return nil
    end
    -- Remove all voidable pickups and play POOF animation
    for pickup, _ in pairs(voidablePickups) do
        table.insert(voidedPickups.VARIANT, pickup.Variant)
        table.insert(voidedPickups.SUBTYPE, pickup.SubType)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, pickup.Position, Vector(0,0), pickup)        --play animation
        pickup:Remove()
    end

    return voidedPickups
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- Already existing voiding items
-------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------
modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoidingColls, Isaac.GetItemIdByName("Void"))
modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, betterVoidingColls, Isaac.GetItemIdByName("Abyss"))
modBV:AddCallback(ModCallbacks.MC_USE_CARD, betterVoidingCards, Card.RUNE_BLACK)
-------------------------------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------------------------------
-- GENESIS FIX (Fix Genesis as well as possible)
-------------------------------------------------------------------------------------------------------------------------------------------

-- If collectible 'Genesis' is used
local function genesisActivated()
    genesisActive = true
end

-- If the player leaves the Genesis-Home room regulary
local function genesisDeactivated()
    genesisActive = false
end

-- Fixes the OptionsPickupIndex from the collectibles spawned by 'Genesis'
local function genesisFix()
    if (genesisActive and game:GetRoom():GetType() == RoomType.ROOM_ISAACS) then
        local collList = BetterVoiding.calculatePickupDist(nil, STD_FLAGS_PC)
        for coll, _ in pairs(collList) do
            coll.OptionsPickupIndex = 200
        end
    end
end

-------------------------------------------------------------------------------------------------------------------------------------------
modBV:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, genesisActivated, Isaac.GetItemIdByName("Genesis"))
modBV:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, genesisDeactivated)
modBV:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, genesisFix)
-------------------------------------------------------------------------------------------------------------------------------------------


-------------------------------------------------------------------------------------------------------------------------------------------
-- Pre Voiding Animation
-------------------------------------------------------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------------------------------------------------
-- Spawns and Play a PreVoidingAnimation at the same position of parentItem with color.
-- The animationEntitys and sprites are added to the keyTables preVoidingAnmEntity and preVoidingAnmSprites with Key GetPtrHash(parentItem)
-------------------------------------------------------------------------------------------------------------------------------------------
local function spawnPreVoidingAnimation(color, parentItem)
    local preVoidingEntity = preVoidingAnmEntitys[GetPtrHash(parentItem)]
    local preVoidingSprite = nil

    -- Remove old animation entity
    if preVoidingEntity ~= nil then preVoidingEntity:Remove() end

    -- Spawn new one
    preVoidingEntity = Isaac.Spawn(EntityType.ENTITY_EFFECT
        , Isaac.GetEntityVariantByName("BV Item Marks"), 0, parentItem.Position, Vector(0,0), parentItem)
    preVoidingAnmEntitys[GetPtrHash(parentItem)] = preVoidingEntity

    -- Configure sprite
    preVoidingSprite = preVoidingEntity:GetSprite()
    preVoidingSprite.PlaybackSpeed = 0.9
    preVoidingSprite.Scale = Vector(1, 1.2)
    preVoidingSprite.Color = color
    preVoidingSprite:Play("Mark1.1", true)
    preVoidingAnmSprites[GetPtrHash(parentItem)] = preVoidingSprite
end

-------------------------------------------------------------------------------------------------------------------------------------------
-- If the player holdes a BetterVoiding item in an active slot and if it is fully charged, a PreVoidingAnimation is spawn for each pickup,
--- which the BetterVoiding item will void. ORDER: PillSlot > ActiveSlot
-- The PreVoidingAnimations are spawned synchronously, by waiting for all PreVoidingAnimations to end before starting them again.
-------------------------------------------------------------------------------------------------------------------------------------------
local function preVoidingAnimation()
    local betterVoidingItemType = -1
    local itemType = 0
    local itemTypeAlt = 0       --represents itemType of ActiveItem and is used if the CardSlot doesn't contain a BetterVoiding item
    local betterVoidingItemTable = nil
    local betterVoidingItemIndex = -1
    local playerEntity = nil
    local allVoidablePickups = {}

    -- The PreVoidingAnimation is calculated based an the first player with an fully charged BetterVoiding item in an active slot
    for playerIndex=0, 3 do   --for each player
        playerEntity = Isaac.GetPlayer(playerIndex)
        if (playerIndex == 0) or (GetPtrHash(playerEntity) ~= GetPtrHash(Isaac.GetPlayer(0))) then
            -- Check if the playerEntity holdes an BetterVoiding item in an active slot (ORDER: Card, Pill, PocketActiveItem, ActiveItem)
            betterVoidingItemType = BetterVoiding.BetterVoidingItemType.TYPE_CARD
            itemType = playerEntity:GetCard(0)
            if (itemType == 0) then
                betterVoidingItemType = BetterVoiding.BetterVoidingItemType.TYPE_PILL
                itemType = playerEntity:GetPill(0)
                if (itemType == 0) then
                    betterVoidingItemType = BetterVoiding.BetterVoidingItemType.TYPE_COLLECTIBLE         --check item in PillSlot
                    itemType = playerEntity:GetActiveItem(ActiveSlot.SLOT_POCKET)
                    if (itemType == 0) or (playerEntity:NeedsCharge(ActiveSlot.SLOT_POCKET)) then
                        itemType = 0
                    end
                else
                    if itemPool:IsPillIdentified(itemType) then
                        itemType = itemPool:GetPillEffect(itemType, playerEntity)
                    else
                        itemType = 0
                    end
                end
            end
            itemTypeAlt = (playerEntity:NeedsCharge() and 0) or playerEntity:GetActiveItem()        --if item is not fully charged => itemTypeAlt = 0
            -- Check if card or pill is a BetterVoiding item or if a ActiveItem exists and is fully charged
            betterVoidingItemTable = betterVoidingItemTables[betterVoidingItemType]
            ::checkForBetterVoidingItem::
            if itemType ~= 0 then
                for i=1, betterVoidingItemTable.COUNT do
                    if betterVoidingItemTable.TYPE[i] == itemType then
                        betterVoidingItemIndex = i
                        goto ignoreActiveItem
                    end
                end
            end
            if (betterVoidingItemIndex == -1) and (itemTypeAlt == 0) then
                goto skipThisPlayer
            end
            -- Check if ActiveItem is a BetterVoiding item
            betterVoidingItemTable = betterVoidingItemTables[BetterVoiding.BetterVoidingItemType.TYPE_COLLECTIBLE]
            itemType = itemTypeAlt
            itemTypeAlt = 0
            goto checkForBetterVoidingItem
            -- PreVoidingAnimation
            ::ignoreActiveItem::
            allVoidablePickups = BetterVoiding.selectPickups(playerEntity, betterVoidingItemTable.V_FLAGS[betterVoidingItemIndex]
                , betterVoidingItemTable.PC_FLAGS[betterVoidingItemIndex])[1]

            --[[ Alternate PreVoidingAnimaiton behaviour
            local newPickupExists = false
            for pickup, _ in pairs(allVoidablePickups) do
                if preVoidingAnmSprites[GetPtrHash(pickup)] == nil then
                    newPickupExists = true
                end
            end
            if newPickupExists then
                for _, sprite in pairs(preVoidingAnmSprites) do
                    --sprite:Reset()
                end
                preVoidingAnmSprites = {}       --reset keyTable preVoidingAnmSprites
                for pickup, _ in pairs(allVoidablePickups) do
                    spawnPreVoidingAnimation(betterVoidingItemTable.COLOR[betterVoidingItemIndex], pickup)
                end
            else--]]

                -- Check if all PreVoidingAnimations are finished
                for _, sprite in pairs(preVoidingAnmSprites) do
                    if sprite:IsPlaying("Mark1.1") then
                        return
                    end
                end
                -- Start for every voidable pickup a new PreVoidingAnimation
                for pickup, _ in pairs(allVoidablePickups) do
                    spawnPreVoidingAnimation(betterVoidingItemTable.COLOR[betterVoidingItemIndex], pickup)
                end
            --end
            return
        end
        ::skipThisPlayer::
    end
end

-- Resets the table which stores PreVoidingAnimation entities and sprites
local function resetPreVoidingAnimations()
    for _, anmEntity in pairs(preVoidingAnmEntitys) do
        anmEntity:Remove()
    end
    preVoidingAnmEntitys = {}
    preVoidingAnmSprites = {}
end

-------------------------------------------------------------------------------------------------------------------------------------------
modBV:AddCallback(ModCallbacks.MC_POST_PICKUP_RENDER, preVoidingAnimation)
modBV:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, resetPreVoidingAnimations)
-------------------------------------------------------------------------------------------------------------------------------------------