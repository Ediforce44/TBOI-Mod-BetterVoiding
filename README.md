# Better Voiding API

## Preamble

This is my first mod for The Binding of Isaac. So I don't know what I did. Just kidding. But if you want to help me and find better solutions for problems, that I solved in this mod, you can contact me.
Also just let me know if you have any ideas for improvement or wishes (for example: more Flags).
You can contact me via Discord: Ediforce44#3385

## Introduction

- This is a mod for The Binding of Isaac: Repentance.
- First of all, if you want to know how the mod internally works feel free to take a look into the sourcecode.
- The mod isn't only a API. It also turns The Void, Abyss and Black Rune into Better Voiding items.
- If you want to use the mod in The Binding of Isaac you can download here: [Better Voiding mod on Steam](https://steamcommunity.com/sharedfiles/filedetails/?id=2622094959)

## What is a Better Voiding Item?

- A Better Voiding item can pay any pickup in the game you want, if Better Voiding item can void the pickup.
- It also indicates which pickups got payed or voided by playing a Pre Voiding Animation beneath it, as long as the Better Voiding item is hold in an active slot and is fully charged.

## API basics

Now let's start talking about the Better Voiding API.
- Every global variable, function or field from this API is callable by simply starting with a `BetterVoiding`
    - Example for a function call: `BetterVoiding.getNearestPickup()`
    - You don't even need a `require(..)` for this API
- This mod contains functions for grouping pickups in a room, selecting them, paying them, clone them, void them and manage their OptionsPickupIndices.
- But don't worry. If you only want to add a Better Voiding item with full functionality, you can do this in a single step (look [here](#how-to-add-a-better-voiding-item)).

## API Member

> Don't forget to use a `BetterVoiding.` in front of them, if you want to access any of the members.
- **Fields**
   - `VoidingFlags` Is an Enum, which can easily be used to set Voiding Flags for your functions from this API.
   - `PickupCategoryFlags` Is also an Enum, which can be used to set Pickup Category Flags for functions from this API.
   - `BetterVoidingItemType` Is an Enum to simply set the item type (collectible, card etc.) of a Better Voiding item, if you initialise it in this mod.
- **Functions**
  - > Many of the functions have ***default*** values set for their parameters. They are written in italic. But maybe also take a look at the sourcecode docs.
  - `calculatePickupDist(position, flagsPC) : KeyTable(Pickup,Distance)` Determins all ***flagsPC*** matching pickups in the current room and their distance to **position***.
  - `getNearestPickup(position, flagsPC) : Pickup` Returns nearest ***flagsPC*** matching pickup to ***position***.
  - `isPickupPayable(pickup, sourceEntity) : Boolean` Returns if the **pickup** is payable by ***sourceEntity***.
  - `getNearestPayablePickup(sourceEntity, flagsPC, position) : Pickup` Returns nearest ***flagsPC*** matching pickup to ***position***, which is payable by ***sourceEntity***.
  - `clonePickup(pickup, cloneAnimation, clonePosition) : Pickup` Clones **pickup** on the next free ***position*** to clonePosition with/without a ***cloneAnimation***.
  - `selectPickups(sourceEntity, flagsV, flagsPC, position) : Table` Sorts all ***flagsPC*** matching pickups in a room based on ***flagsV***, ***sourceEntity*** and ***position***. 
    - It returns a table of three `KeyTable(Pickup, Distance to position)`.
    - The first one contains all selected/"ready for voiding" pickups, the second one all pickups which will get lost due to OptionsPickupIndices and the third one contains all remaining pickups.
  - `managePickupIndices(refPickups) : Table(selectedPickups)` Selects pickups out of Table **refPickups** with different OptionsPickupIndices and despawns all pickups with the same OpitonsPickupIndex.
  - `payPickup(pickup, sourceEntity, forVoiding) : Pickup` Let ***sourceEntity*** pay for **pickup**.
    - If the pickup is **not** ***forVoiding***, it will be moved next to the restocked pickup (in a restockable shop)
  - `betterVoidingItemConstructor(betterVoidingItemType, itemType, generateModCallback, flagsV, flagsPC, preVoidingColor) : BVIID` Registers a new Better Voiding item and returns a unique *BetterVoidingItemID* for it.
    - It sets the **betterVoidingItemType**, **itemType**, ***flagsV***, ***flagsPC*** and ***preVoidingColor***.
    - If **generateModCallback** is true, a new ModCallback for the Better Voiding item is automatically created. This will turn it into a Better Voiding item.
    - The *BVIID* should be safed, because it is important for the following functions.
  - `betterVoiding(betterVoidingItemID, sourceEntity) : KeyTable(Pickup, Distance)` Prepares everything for voiding pickups with a BetterVoiding item associated with the **betterVoidingItemID** and based on ***sourceEntity***.
    - It returns a KeyTable of pickups, which are selected by the Better Voiding item based on its set flags.
  - `betterVoidingRA(betterVoidingItemID, sourceEntity) : Enum` Voids ALL pickups with a BetterVoiding item associated with the **betterVoidingItemID** and based on ***sourceEntity***.
    - It removes all pickups selected by the Better Voiding item and spawns a POOF animation for them.
    - It returns an *Enum*, which consits of two keyTables. The first one for the Variants of the pickups and the second one for the SubTypes. One index in both tables represents one selected pickup.

## How to add a Better Voiding item

If you have already created a voiding item mod or you want simply creat a voiding item, there is one easy way to turn it into a Better Voiding item. **But maybe it's not the best way. So also look at example [2].**
- **Example[1]** Add a Better Voiding item, which voids the nearest heart deal to the player and all free collectibles:
    ```lua
    local exampleItemType = Isaac.GetItemIdByName("Example Item")
    local exampleBVIType = BetterVoiding.BetterVoidingItemType.TYPE_COLLECTIBLE
    local preVoidingColor = Color(0.5, 0.5, 1, 1, 0, 0, 0)
    local flagsV = BetterVoiding.VoidingFlags.V_NEAREST_PAYABLE_PICKUP | BetterVoiding.VoidingFlags.V_ALL_FREE_PICKUPS
    local flagsPC = BetterVoiding.PickupCategoryFlags.PC_PRICE_HEARTS | BetterVoiding.PickupCategoryFlags.PC_TYPE_COLLECTIBLE
    local exampleBVIID = BetterVoiding.betterVoidingItemConstructor(exampleBVIType, exampleItemType, true, flagsV, flagsPC, preVoidingColor)

    local function voiding()
        Get all free collectibles in the room and
        Do what your voiding item does
    end

    mod:AddCallback(ModCallbacks.MC_USE_ITEM, voiding, exampleItemType)
    ```

     - And that's it. The only important thing is that you call the `betterVoidingItemConstructor()`, which pays the pickups and makes them free
        > But maybe you realise that you can't do complex things with this. Like voiding only the nearest heart deal. Why? Because you don't know how to get it in your *voiding()* function. Or you want to do something with alternate item choices (same OptionsPickupIndex). But that is possible with the next **Example[2]**, if you use `betterVoiding()`.

- **Example[2]** Add a Better Voiding item, but manage the voiding manually. The Better Voiding item is a card and voids the nearest consumable to isaac, which costs coins:

    ```lua
    local exampleItemType = Isaac.GetCardIdByName("Example Card")
    local exampleBVIType = BetterVoiding.BetterVoidingItemType.TYPE_CARD
    local preVoidingColor = Color(0.5, 0.5, 0, 1, 0, 0, 0)
    local flagsV = BetterVoiding.VoidingFlags.V_NEAREST_PAYABLE_PICKUP
    local flagsPC = BetterVoiding.PickupCategoryFlags.PC_PRICE_COINS | BetterVoiding.PickupCategoryFlags.PC_TYPE_CONSUMABLE
    local exampleBVIID = BetterVoiding.betterVoidingItemConstructor(exampleBVIType, exampleItemType, false, flagsV, flagsPC, preVoidingColor)

    local function voiding()
        local consumablesForVoiding = BetterVoiding.betterVoiding(exampleBVIID)
        for cons, dist in pairs(consumablesForVoiding)
            Do what your voiding item does
        end
    end

    mod:AddCallback(ModCallbacks.MC_USE_CARD, voiding, exampleItemType)
    ```

    - If you want that the voidable pickups get automatically removed, just call `betterVoidingRA()` instead of `betterVoiding()`.

## If you have any ideas for improvement or wishes (for example: more Flags) just let me know. You can contact me via discord: Ediforce44#3385

