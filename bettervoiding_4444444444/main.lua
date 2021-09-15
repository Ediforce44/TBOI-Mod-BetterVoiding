local BetterVoiding = RegisterMod("Better Voiding", 1)

local debugText = "" --Test
r = 0

function BetterVoiding:drawDebugText()
    Isaac.RenderText(debugText, 100, 100, 255, 0, 0, 255)
end

function BetterVoiding:distance(pos1, pos2)
    return math.sqrt((pos1.X-pos2.X)^2 + (pos1.Y-pos2.Y)^2)
end

------------------------------------------------------
-- Detemines nearest collectable item to the entity
------------------------------------------------------
function BetterVoiding:NearestItem(entity)
    local allEntities = Isaac.GetRoomEntities()
    local test = 0
    --local items = {}
    local nearestItem = nil
    local distance = -1
    for _,e in pairs(allEntities) do    -- Filter room for collectibles
        if (e.Type == EntityType.ENTITY_PICKUP and e.Variant == PickupVariant.PICKUP_COLLECTIBLE) then
            --table.insert(items, e)
            local tempDist = BetterVoiding:distance(entity.Position, e.Position)
            if (tempDist < distance or distance == -1) then 
                distance = tempDist
                nearestItem = e
            end
        end
    end
    return nearestItem
end


--------------------------------------------------------
-- Remove all items in the room exept the nearest Item
--------------------------------------------------------
local function removeOtherItems()
    r = r + 1
    debugText = "It wörks ".. r
    return true
end

BetterVoiding:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, removeOtherItems, Isaac.GetItemIdByName("Void"))

BetterVoiding:AddCallback(ModCallbacks.MC_POST_RENDER, BetterVoiding.drawDebugText)