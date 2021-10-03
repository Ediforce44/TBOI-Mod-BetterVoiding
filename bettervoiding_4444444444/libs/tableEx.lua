------------------------------------------
-- Local/Global variables and constants
------------------------------------------

-- Global access to this lib
TableEx = {version = "1.0"}


----------------------------------------------------
-- Removes all entrys with nil values in keyTable
----- @Return: New table with updated entries
----------------------------------------------------
--   !!! Doesn't obtain positions of entries !!!
function TableEx.updateTable(keyTable)
    local updatedTable = {}
    for k,v in pairs(keyTable) do
        if not (v == nil) then
            updatedTable[k] = v
        end
    end
    return updatedTable
end

------------------------------------------------
-- Returns key for lowest value in a keyTable
----- @Return: Key from keyTable
------------------------------------------------
function TableEx.getKeyOfLowestValue(keyTable)
    local key = nil
    local value = nil

    for k,v in pairs(keyTable) do
        if (value == nil or v < value) then
            value = v
            key = k
        end
    end

    return key
end

------------------------------------------------
-- Returns key for highest value in a keyTable
----- @Return: Key from keyTable
------------------------------------------------
function TableEx.getKeyOfHighestValue(keyTable)
    local key = nil
    local value = nil

    for k,v in pairs(keyTable) do
        if (value == nil or v > value) then
            value = v
            key = k
        end
    end

    return key
end

--------------------------------------------------------------------
-- Concatenate two keyTables.
-- If table2 entries with same key as in table1 will replace them
----- @Return: Resulting keyTable
--------------------------------------------------------------------
function TableEx.concat(table1, table2)
    local concatTable = {}
    for key, value in pairs(table1) do
        concatTable[key] = value
    end
    for key, value in pairs(table2) do
        concatTable[key] = value
    end
    return concatTable
end

---------------------------------
-- Copy a keyTable
----- @Return: Copy of keyTable
---------------------------------
function TableEx.copy(keyTable)
    local copiedTable = {}
    for key, value in pairs(keyTable) do
        copiedTable[key] = value
    end
    return copiedTable
end

-------------------------------------------------------------------------------------------------------
return TableEx