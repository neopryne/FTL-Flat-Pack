--[[
An example of how to register events with the DiscoVerse engine.
Follow the instructions in xmlEventGeneration.lua.
]]
local mde = mods.multiverseDiscoEngine
local dvsd = mods.discoVerseStaticDefinitions
if not mde then
    error("Multiverse Disco Engine was not patched, or was patched after FFFTL.  Install it properly or see crappy looking events.")
end

--You should make sure the event names you use for active checks are unique to your mod to avoid conflicts.
--blue=true for success, false for failure.
local function appendEvents()
    local eventList = {}
    --EVENT CODE HERE V
    
    --[[
    local crazyZoltan = mde.buildEvent("DROPPOINT_CRAZYZOLTAN")
    table.insert(crazyZoltan, mde.buildPassiveCheck("empathy", 10, "mde_passive_1", "His words have power, but it is out of his control; they devour him even as he threatens you.  He will not be a threat for long."))
    table.insert(eventList, crazyZoltan)]]

    local omenEntry1 = mde.buildEvent("FFF_OMEN_ENTRY_MAIN")
    table.insert(omenEntry1, mde.buildActiveCheck(dvsd.s_authority.internalName, 13, "fff_active_1", "Nobody I want to meet.",
    "FFF_OMEN_ENTRY_AUTHORITY_SUCCESS", "FFF_OMEN_ENTRY_AUTHORITY_FAILURE"))
    table.insert(eventList, omenEntry1)

    local omenEntry2 = mde.buildEvent("FFF_OMEN_ENTRY_RESPONSE")
    table.insert(omenEntry2, mde.buildActiveCheck(dvsd.s_volition.internalName, 16, "fff_active_1", "Shove it out.",
            "FFF_OMEN_ENTRY_VOLITION_SUCCESS", "FFF_OMEN_ENTRY_VOLITION_FAILURE"))
    table.insert(eventList, omenEntry2)

    --EVENT CODE HERE ^
    mde.registerEventList(eventList)
end
appendEvents()