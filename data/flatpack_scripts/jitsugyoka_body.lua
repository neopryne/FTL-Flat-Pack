local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local lwl = mods.lightweight_lua



local TABLE_NAME_JITSU = "mods.flatpack.finmechv2.13.9"
local METAVAR_NAME_JITSU = "ffftl_jitsu"



local OFFSET_HEAD = Hyperspace.Point(0, -10)
local OFFSET_LEGS = Hyperspace.Point(5, 10)
local OFFSET_BODY = Hyperspace.Point(0, -10)
local OFFSET_GUN = Hyperspace.Point(0, -10)
local OFFSET_BOMB = Hyperspace.Point(0, -10)
local OFFSET_POD = Hyperspace.Point(0, -10)

--The names here are used to find files, so you have to update those if you change this.
--enum like.  This is also the index of the associated particle in parts{}
local PART_HEAD = 1
local PART_BODY = 2
local PART_LEGS = 3
local PART_GUN = 4
local PART_BOMB = 5
local PART_POD = 6

--[[
    jitstuyoka
    
    Button that returns you to the game
    Layer that disables clicking under it
    
    
    The Custom extra powers are hardcoded xml active powers that start disabled and have perm duration.
--]]
local BASIC_HEAD = {name="basic_head", type=PART_HEAD}
local BASIC_BODY = {name="basic_body", type=PART_BODY}
local BASIC_LEGS = {name="basic_legs", type=PART_LEGS}
local BASIC_GUN = {name="basic_legs", type=PART_GUN}

local equippedHead = BASIC_HEAD
local equippedBody = nil
local equippedLegs = nil
local equippedGun = nil
local equippedBomb = nil
local equippedPod = nil

--unlocks should be across all, equips should be individual
--keep the id of the char in the varname
--Hyperspace.metaVariables[METAVAR_NAME_JITSU..part.name..crewmem.extend.selfId] = 1

local function equipPart(newPart)
    
    
end

--actually just use crew loop?
--I need to save all jitsu's information in long term storage.
--It can't break when you load it agian. 

script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(ship) 
    local shipManager = Hyperspace.ships(ship.iShipId)
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_jitsu") then
            local crewTable = userdata_table(crewmem, TABLE_NAME_JITSU)
            local initialized = crewTable.initialized
            --if (initialized == nil) then
                --
            
            
            local parts = {head=nil}
            
            
        end
    end
    end, function() end)


function myModGameStartCode(newGame)
  if (newGame) then
    log("My code was run after a new game started")
  else
    log("My code was run after a saved game loaded")
  end
end

script.on_init(myModGameStartCode)
