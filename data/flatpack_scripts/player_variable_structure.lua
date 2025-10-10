local lwl = mods.lightweight_lua

--[[
Ok, this library is all about letting you define player variables for things that are kind of clunky.

You can have numbers or number-indexed tables.  You can't store strings here.

The hard thing this helps with is being able to return you a list of all the uuids for a given interface.

There is no way to remove items from the list as it stands.
]]

local GLOBAL_NAME = "lwl_player_vars"
local GLOBAL_NUMBER_KEY = "NUM_ENTRIES"
local GLOBAL_UUID_KEY = "_uuidindex_"


--Then we have a number of fields of the form thing-UUID-fieldname = number
--These numbers don't mean anything by themselves, you will need to parse them, or build a layer.
--Maybe having people define an enum is enough.  Yeah, just build a table of the things you want this to return, and it will do that.
--tables are implicitly indexed by number.  You should define them yourself, and the translations from number to other thing.
local typeTable = {"basic", "advanced", "custom"}

local mRegisteredNames = {}

function lwl.CreatePlayerVariableInterface(name)
    if (mRegisteredNames[name] ~= nil) then
        error(name.." is already registered, aborting.")
        return
    end
    mRegisteredNames[name] = true
    local interface = {}
    interface.uuidToIndexTable = {}

    local buildKey = function(uuid, key)
        return GLOBAL_NAME..name..uuid..key
    end

    interface.getVariable = function(uuid, key)
        return Hyperspace.playerVariables[buildKey(uuid, key)]
    end

    interface.getCount = function()
        return Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_NUMBER_KEY]
    end

    ---@return table of uuids
    interface.getUuids = function()
        local uuids = {}
        for i=1,interface.getCount() do
            table.insert(uuids, Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_UUID_KEY..i])
        end
        return uuids
    end

    local function buildUuidToIndexTable()
        local uuids = {}
        for i=1,interface.getCount() do
            uuids[Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_UUID_KEY..i]] = i
        end
        return uuids
    end

    interface.setVariable = function(uuid, key, value)
        local uuidIndex = interface.uuidToIndexTable[uuid]
        ---If variable is not present, create it, else find its index.
        if not uuidIndex then
            --insert new variable into all places that track it.
            uuidIndex = 1 + #interface.uuidToIndexTable
            interface.uuidToIndexTable[uuid] = uuidIndex
            Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_UUID_KEY..uuidIndex] = uuid
            Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_NUMBER_KEY] = lwl.setIfNil(interface.getCount(), 0) + 1
        end
        Hyperspace.playerVariables[buildKey(uuid, key)] = value
    end

    interface.removeObject = function(uuid)
        local uuidIndex = interface.uuidToIndexTable[uuid]
        if not uuidIndex then
            error("No such object found", uuid)
            return
        end
        
        for i=uuidIndex, interface.getCount() - 1 do
            Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_UUID_KEY..i] = Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_UUID_KEY..i + 1]
        end
        interface.uuidToIndexTable[uuid] = nil
        Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_NUMBER_KEY] = lwl.setIfNil(interface.getCount(), 0) - 1
    end

    interface.clearAll = function()
        Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_NUMBER_KEY] = 0
        interface.uuidToIndexTable = buildUuidToIndexTable()
    end

    --if the interface has any local structure, populate it from stored vars.
    interface.uuidToIndexTable = buildUuidToIndexTable()
    return interface
end

lwl.CreatePlayerVariableInterface("testInterface")

