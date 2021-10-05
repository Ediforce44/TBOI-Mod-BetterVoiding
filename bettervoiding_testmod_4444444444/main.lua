
local betterVoidingTestMod = RegisterMod("BetterVoidingTestMod", 1)

local debugTexts = {}

-------------------------------------------------------------------------------------------------------------------------------------------
--[[
local function test()
    debugTexts[1] = ""
    debugTexts[2] = ""
    debugTexts[3] = ""
    debugTexts[4] = ""
    debugTexts[5] = ""
    debugTexts[6] = ""
    debugTexts[7] = ""
    debugTexts[8] = ""
    debugTexts[9] = ""
end
betterVoidingTestMod:AddCallback(ModCallbacks.MC_POST_RENDER, test) local function setTitl() debugTexts[0] = "test" end
-------------------------------------------------------------------------------------------------------------------------------------------]]
-------------------------------------------------------------------------------------------------------------------------------------------
--[[
local function test()
    local player = Isaac.GetPlayer(0)
    local playerData = player:GetData()
    local nextTest = true

    if playerData["test"] == nil then
        playerData["test"] = 0
        debugTexts[1] = "----"
        debugTexts[2] = ""

        debugTexts[3] = ""
    end
    if playerData["test"] == 1 then

        debugTexts[3] = ""
    end
    if playerData["test"] == 2 then

        debugTexts[3] = ""
    end
    if playerData["test"] == 3 then

        debugTexts[3] = ""
    end
    if playerData["test"] == 4 then

        debugTexts[3] = ""
    end
    if playerData["test"] == 5 then

        nextTest = false
    end
    if nextTest then
        debugTexts[1] = debugTexts[2]
        debugTexts[2] = debugTexts[3]
        debugTexts[3] = ""
        playerData["test"] = playerData["test"] + 1
    end
    return true
end
betterVoidingTestMod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, test, CollectibleType.COLLECTIBLE_BUTTER_BEAN) local function setTitl() debugTexts[0] = "test" end-- 5.100.294
-------------------------------------------------------------------------------------------------------------------------------------------]]
-------------------------------------------------------------------------------------------------------------------------------------------

local function calculatePickupDistTest()
    debugTexts[1] = "Standard: "
    debugTexts[2] = "Standard Player(1): "
    debugTexts[3] = "Only Price Error: "
    debugTexts[12] = "Only Type COLLS: "
    debugTexts[4] = "FREE CARD: "
    debugTexts[5] = "FREE COLL: "
    debugTexts[6] = "FREE CONS: "
    debugTexts[7] = "FREE PILL: "
    debugTexts[8] = "FREE TRINKET: "
    debugTexts[9] = "COINS CONS: "
    debugTexts[10] = "HEART COLL: "
    debugTexts[11] = "SPIKE COLL: "

    local pickupDists = nil
    pickupDists = BetterVoiding.calculatePickupDist()
    for key, value in pairs(pickupDists) do
        debugTexts[1] = debugTexts[1] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(1))
    for key, value in pairs(pickupDists) do
        debugTexts[2] = debugTexts[2] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE)
    for key, value in pairs(pickupDists) do
        debugTexts[3] = debugTexts[3] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE | BetterVoiding.PickupCategoryFlags.PC_TYPE_CARD)
    for key, value in pairs(pickupDists) do
        debugTexts[4] = debugTexts[4] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE | BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
    for key, value in pairs(pickupDists) do
        debugTexts[5] = debugTexts[5] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE | BetterVoiding.PickupCategoryFlags.PC_TYPE_CONSUMABLE)
    for key, value in pairs(pickupDists) do
        debugTexts[6] = debugTexts[6] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE | BetterVoiding.PickupCategoryFlags.PC_TYPE_PILL)
    for key, value in pairs(pickupDists) do
        debugTexts[7] = debugTexts[7] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_FREE | BetterVoiding.PickupCategoryFlags.PC_TYPE_TRINKET)
    for key, value in pairs(pickupDists) do
        debugTexts[8] = debugTexts[8] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_COINS | BetterVoiding.PickupCategoryFlags.PC_TYPE_CONSUMABLE)
    for key, value in pairs(pickupDists) do
        debugTexts[9] = debugTexts[9] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_HEARTS | BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
    for key, value in pairs(pickupDists) do
        debugTexts[10] = debugTexts[10] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_PRICE_SPIKES | BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
    for key, value in pairs(pickupDists) do
        debugTexts[11] = debugTexts[11] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
    pickupDists = BetterVoiding.calculatePickupDist(Isaac.GetPlayer(0), BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
    for key, value in pairs(pickupDists) do
        debugTexts[12] = debugTexts[12] .. tostring(key.SubType) .. " " .. tostring(math.floor(value)) .. "; "
    end
end

local function getNearestPickupTest()
    debugTexts[1] = "Standard: "
    debugTexts[2] = "TYPE COLL Player(1): "
    local pickup = nil
    pickup = BetterVoiding.getNearestPickup()
    if pickup == nil then
        debugTexts[1] = debugTexts[1] .. tostring(nil)
    else
        debugTexts[1] = debugTexts[1] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
    end
    pickup = BetterVoiding.getNearestPickup(Isaac.GetPlayer(1), BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
    if pickup == nil then
        debugTexts[2] = debugTexts[2] .. tostring(nil)
    else
        debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
    end
end

local function isPickupPayableTest()
    debugTexts[1] = "Nearest Item: "
    debugTexts[2] = "First entity: "
    local pickup = nil
    local enemy = nil
    pickup = BetterVoiding.getNearestPickup()
    if pickup == nil then
        debugTexts[1] = debugTexts[1] .. tostring(nil)
    else
        debugTexts[1] = debugTexts[1] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; " .. tostring(BetterVoiding.isPickupPayable(pickup))
    end
    pickup = BetterVoiding.getNearestPickup()
    for _, entity in pairs(Isaac.GetRoomEntities()) do
        if entity.Type > 9 then
            enemy = entity
        end
    end
    if enemy == nil then
        debugTexts[2] = debugTexts[2] .. tostring(nil)
    else
        debugTexts[2] = debugTexts[2] .. tostring(enemy.Type)
        if pickup == nil then
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; " .. tostring(BetterVoiding.isPickupPayable(pickup))
        end
    end
end

local function getNearestPayablePickupTest()
    debugTexts[1] = "Standard: "
    debugTexts[2] = "TYPE COLL Player(1): "
    local pickup = nil
    pickup = BetterVoiding.getNearestPayablePickup()
    if pickup == nil then
        debugTexts[1] = debugTexts[1] .. tostring(nil)
    else
        debugTexts[1] = debugTexts[1] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
    end
    pickup = BetterVoiding.getNearestPayablePickup(Isaac.GetPlayer(1), BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
    if pickup == nil then
        debugTexts[2] = debugTexts[2] .. tostring(nil)
    else
        debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
    end
end

local function clonePickupTest()
    local player = Isaac.GetPlayer(0)
    local playerData = player:GetData()
    local pickup = nil
    local nextTest = true
    if playerData["clonePickupTest"] == nil then
        playerData["clonePickupTest"] = 0
        debugTexts[1] = "----"
        debugTexts[2] = "All pickups:"
        local allPickups = BetterVoiding.calculatePickupDist()
        if allPickups == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            for key, _ in pairs(allPickups) do
                pickup = BetterVoiding.clonePickup(key)
                if pickup == nil then
                    nextTest = false
                    debugTexts[2] = debugTexts[2] .. tostring(nil)
                else
                    debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
                end
            end
            debugTexts[3] = "Nearest pickup: "
        end
    end
    if playerData["clonePickupTest"] == 1 then
        pickup = BetterVoiding.getNearestPickup()
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.clonePickup(pickup)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "No Animation: "
    end
    if playerData["clonePickupTest"] == 2 then
        pickup = BetterVoiding.getNearestPickup()
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.clonePickup(pickup, false)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "Next to Player: "
    end
    if playerData["clonePickupTest"] == 3 then
        pickup = BetterVoiding.getNearestPickup()
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.clonePickup(pickup, false, Isaac.GetPlayer(0).Position)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "COLL Position (100,100): "
    end
    if playerData["clonePickupTest"] == 4 then
        pickup = BetterVoiding.getNearestPickup(Isaac.GetPlayer(), BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.clonePickup(pickup, false, Vector(100,200))
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        nextTest = false
    end
    if nextTest then
        debugTexts[1] = debugTexts[2]
        debugTexts[2] = debugTexts[3]
        debugTexts[3] = ""
        playerData["clonePickupTest"] = playerData["clonePickupTest"] + 1
    end
    return true
end

local function selectPickupsTest()
    debugTexts[4] = ""
    debugTexts[5] = ""
    debugTexts[6] = ""
    local player = Isaac.GetPlayer(0)
    local playerData = player:GetData()
    local nextTest = true
    local allPickups = nil

    if playerData["selectPickupsTest"] == nil then
        playerData["selectPickupsTest"] = 0
        debugTexts[1] = "----"
        debugTexts[2] = "Standard: "
        allPickups = BetterVoiding.selectPickups()
        debugTexts[3] = "Standard Player(1): "
    end
    if playerData["selectPickupsTest"] == 1 then
        allPickups = BetterVoiding.selectPickups(Isaac.GetPlayer(1))
        debugTexts[3] = "V_NEAREST_PICKUP: "
    end
    if playerData["selectPickupsTest"] == 2 then
        allPickups = BetterVoiding.selectPickups(player, BetterVoiding.VoidingFlags.V_NEAREST_PICKUP)
        debugTexts[3] = "V_ALL_FREE_PICKUPS: "
    end
    if playerData["selectPickupsTest"] == 3 then
        allPickups = BetterVoiding.selectPickups(player, BetterVoiding.VoidingFlags.V_ALL_FREE_PICKUPS)
        debugTexts[3] = "Nearest All Free COLL: "
    end
    if playerData["selectPickupsTest"] == 4 then
        allPickups = BetterVoiding.selectPickups(player, BetterVoiding.VoidingFlags.V_ALL_FREE_PICKUPS | BetterVoiding.VoidingFlags.V_NEAREST_PICKUP, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        debugTexts[3] = "Nearest CONS: "
    end
    if playerData["selectPickupsTest"] == 5 then
        allPickups = BetterVoiding.selectPickups(player, BetterVoiding.VoidingFlags.V_NEAREST_PICKUP, BetterVoiding.PickupCategoryFlags.PC_TYPE_CONSUMABLE)
        debugTexts[3] = "Nearest All Free COLL: "
    end
    if playerData["selectPickupsTest"] == 6 then
        allPickups = BetterVoiding.selectPickups(player, BetterVoiding.VoidingFlags.V_ALL_FREE_PICKUPS | BetterVoiding.VoidingFlags.V_NEAREST_PICKUP, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        nextTest = false
    end
    for key, value in pairs(allPickups[1]) do
        debugTexts[4] = debugTexts[4] .. tostring(key.SubType) .. " " .. tostring(value) .. "; "
    end
    for key, value in pairs(allPickups[2]) do
        debugTexts[5] = debugTexts[5] .. tostring(key.SubType) .. " " .. tostring(value) .. "; "
    end
    for key, value in pairs(allPickups[2]) do
        debugTexts[6] = debugTexts[6] .. tostring(key.SubType) .. " " .. tostring(value) .. "; "
    end

    if nextTest then
        debugTexts[1] = debugTexts[2]
        debugTexts[2] = debugTexts[3]
        debugTexts[3] = ""
        playerData["selectPickupsTest"] = playerData["selectPickupsTest"] + 1
    end
    return true
end

local function managePickupIndicesTest()
    local player = Isaac.GetPlayer(0)
    local playerData = player:GetData()
    local nextTest = true
    local pickups

    if playerData["managePickupIndicesTest"] == nil then
        playerData["managePickupIndicesTest"] = 0
        debugTexts[1] = "----"
        debugTexts[2] = "All pickups"
        local pickupsDist = BetterVoiding.calculatePickupDist()
        if pickupsDist == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            for key, _ in pairs(pickupsDist) do
                table.insert(pickups, key)
            end
            pickups = BetterVoiding.managePickupIndices(pickups)
            for i=1, #pickups do
                debugTexts[2] = debugTexts[2] .. tostring(pickups[i].Variant) .. " " .. tostring(pickups[i].SubType) .. "; "
            end
        end
        debugTexts[3] = "All COLLS: "
    end
    if playerData["managePickupIndicesTest"] == 1 then
        local pickupsDist = BetterVoiding.calculatePickupDist(player, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        if pickupsDist == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            for key, _ in pairs(pickupsDist) do
                table.insert(pickups, key)
            end
            pickups = BetterVoiding.managePickupIndices(pickups)
            for i=1, #pickups do
                debugTexts[2] = debugTexts[2] .. tostring(pickups[i].Variant) .. " " .. tostring(pickups[i].SubType) .. "; "
            end
        end
        debugTexts[3] = "Nearest COLL: "
    end
    if playerData["managePickupIndicesTest"] == 2 then
        local pickup = BetterVoiding.getNearestPickup(player, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickups = BetterVoiding.managePickupIndices({pickup})
            for i=1, #pickups do
                debugTexts[2] = debugTexts[2] .. tostring(pickups[i].Variant) .. " " .. tostring(pickups[i].SubType) .. "; "
            end
        end
        debugTexts[4] = "Try to stand next to not payable collectible (= nil)"
        nextTest = false
    end

    if nextTest then
        debugTexts[1] = debugTexts[2]
        debugTexts[2] = debugTexts[3]
        debugTexts[3] = ""
        playerData["managePickupIndicesTest"] = playerData["managePickupIndicesTest"] + 1
    end
    return true
end

local function payPickupTest()
    local player = Isaac.GetPlayer(0)
    local playerData = player:GetData()
    local nextTest = true
    local pickup = nil

    if playerData["payPickupTest"] == nil then
        playerData["payPickupTest"] = 0
        debugTexts[1] = "----"
        debugTexts[2] = "Standard: "
        pickup = BetterVoiding.getNearestPickup()
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "NotVoiding: "
    end
    if playerData["payPickupTest"] == 1 then
        pickup = BetterVoiding.getNearestPickup()
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup, player, false)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "COLL NotVoiding: "
    end
    if playerData["payPickupTest"] == 2 then
        pickup = BetterVoiding.getNearestPickup(player, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup, player, false)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "Player(1): "
    end
    if playerData["payPickupTest"] == 3 then
        pickup = BetterVoiding.getNearestPickup(Isaac.GetPlayer(1))
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup, Isaac.GetPlayer(1))
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "Enemy pay: "
    end
    if playerData["payPickupTest"] == 4 then
        local enemy = nil
        pickup = BetterVoiding.getNearestPickup()
        for _, entity in pairs(Isaac.GetRoomEntities()) do
            if entity.Type > 9 then
                enemy = entity
            end
        end
        if (enemy == nil) then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            debugTexts[2] = debugTexts[2] .. tostring(enemy.Type)
            pickup = BetterVoiding.payPickup(pickup, enemy)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, TrinketType.TRINKET_YOUR_SOUL, player.Position, Vector(0,0), nil)
            end
        end
        debugTexts[3] = "SOUL DEAL: "
    end
    if playerData["payPickupTest"] == 5 then
        pickup = BetterVoiding.getNearestPickup(player, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE | BetterVoiding.PickupCategoryFlags.PC_PRICE_HEARTS)
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
                Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_POUND_OF_FLESH, player.Position, Vector(0,0), nil)
            end
        end
        debugTexts[3] = "Spikes CONS: "
    end
    if playerData["payPickupTest"] == 6 then
        pickup = BetterVoiding.getNearestPickup(player, BetterVoiding.PickupCategoryFlags.PC_PRICE_SPIKES | BetterVoiding.PickupCategoryFlags.PC_TYPE_CONSUMABLE)
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "Spikes COLL: "
    end
    if playerData["payPickupTest"] == 7 then
        pickup = BetterVoiding.getNearestPickup(player, BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE)
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[3] = "Nearest Pickup: "
    end
    if playerData["payPickupTest"] == 8 then
        pickup = BetterVoiding.getNearestPickup()
        if pickup == nil then
            nextTest = false
            debugTexts[2] = debugTexts[2] .. tostring(nil)
        else
            pickup = BetterVoiding.payPickup(pickup)
            if pickup == nil then
                nextTest = false
                debugTexts[2] = debugTexts[2] .. tostring(nil)
            else
                debugTexts[2] = debugTexts[2] .. tostring(pickup.Variant) .. " " .. tostring(pickup.SubType) .. "; "
            end
        end
        debugTexts[4] = "Test the Lost"
        debugTexts[5] = "Test Shops, Devildeals and Free Pickups"
        debugTexts[6] = "Test Greedmode"
        nextTest = false
    end
    if nextTest then
        debugTexts[1] = debugTexts[2]
        debugTexts[2] = debugTexts[3]
        debugTexts[3] = ""
        playerData["payPickupTest"] = playerData["payPickupTest"] + 1
    end
    return true
end

--betterVoidingTestMod:AddCallback(ModCallbacks.MC_POST_RENDER, calculatePickupDistTest) local function setTitle() debugTexts[0] = "CalculatePickupDistTest" end
--betterVoidingTestMod:AddCallback(ModCallbacks.MC_POST_RENDER, getNearestPickupTest) local function setTitle() debugTexts[0] = "GetNearestPickupTest" end
--betterVoidingTestMod:AddCallback(ModCallbacks.MC_POST_RENDER, isPickupPayableTest) local function setTitle() debugTexts[0] = "IsPickupPayableTest" end
--betterVoidingTestMod:AddCallback(ModCallbacks.MC_POST_RENDER, getNearestPayablePickupTest) local function setTitle() debugTexts[0] = "GetNearestPayablePickupTest" end
--betterVoidingTestMod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, clonePickupTest, CollectibleType.COLLECTIBLE_BUTTER_BEAN) local function setTitl() debugTexts[0] = "ClonePickupTest" end -- 5.100.294
--betterVoidingTestMod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, selectPickupsTest, CollectibleType.COLLECTIBLE_BUTTER_BEAN) local function setTitle() debugTexts[0] = "SelectPickupsTest" end -- 5.100.294
--betterVoidingTestMod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, managePickupIndicesTest, CollectibleType.COLLECTIBLE_BUTTER_BEAN) local function setTitl() debugTexts[0] = "ManagePickupIndicesTest" end -- 5.100.294
betterVoidingTestMod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, payPickupTest, CollectibleType.COLLECTIBLE_BUTTER_BEAN) local function setTitl() debugTexts[0] = "PayPickupTest" end-- 5.100.294

-------------------------------------------------------------------------------------------------------------------------------------------
local function drawDebugText()
    for i=1, #debugTexts do
        Isaac.RenderText(debugTexts[i], 60, 40+(15*i), 255, 0, 0, 255)
    end
    setTitle()
    Isaac.RenderText(debugTexts[0], 160, 25, 255, 0, 0, 255)
end

betterVoidingTestMod:AddCallback(ModCallbacks.MC_POST_RENDER, drawDebugText)
-------------------------------------------------------------------------------------------------------------------------------------------