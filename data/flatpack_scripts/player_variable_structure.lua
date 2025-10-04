local lwl = mods.lightweight_lua

--[[
Ok, this library is all about letting you define player variables for things that are kind of clunky.

You can have numbers or number-indexed tables.  You can't store strings here.
]]

local GLOBAL_NAME = "name_tbd"
local GLOBAL_NUMBER_KEY = "howMany"
local GLOBAL_UUID_KEY = "uuidindex"

local numThings = Hyperspace.playerVariables["numThings"]

local thingIndexKey = "thingIndex" --plus some number from 1-numThings., contents are the UUID for the thing

--Then we have a number of fields of the form thing-UUID-fieldname = number
--These numbers don't mean anything by themselves, you will need to parse them, or build a layer.
--Maybe having people define an enum is enough.  Yeah, just build a table of the things you want this to return, and it will do that.

--tables are implicitly indexed by number.
local typeTable = {"basic", "advanced", "custom"}

local registeredNames = {}

function CreatePlayerVariableInterface(name)
    if (registeredNames[name] ~= nil) then
        error(name.." is already registered.")
    end
    registeredNames[name] = true

    local interface

    interface.buildKey = function(uuid, key)
        return GLOBAL_NAME..name..uuid..key
    end

    interface.accessVariable = function(uuid, key)
        return Hyperspace.playerVariables[interface.buildKey(uuid, key)]
    end

    interface.getCount = function()
        return Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_NUMBER_KEY]
    end

    ---
    ---@return table of uuids
    interface.getUuids = function ()
        local uuids = {}
        for i=1,interface.getCount() do
            table.insert(uuids, Hyperspace.playerVariables[GLOBAL_NAME..name..GLOBAL_UUID_KEY..i])
        end
        return uuids
    end
end


--accessVariable(crewmem.extend.selfid, "numHats")
local function accessVariable(uuid, key)
    
end