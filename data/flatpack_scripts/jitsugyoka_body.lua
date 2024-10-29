local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local Brightness = mods.brightness
local lwl = mods.lightweight_lua

local get_room_at_location = mods.vertexutil.get_room_at_location


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
local PART_FILE_NAMES = {"head", "body", "legs", "gun", "bomb", "pod"}
local UP = 1
local DOWN = 2
local LEFT = 3
local RIGHT = 4
local DIRECTION_FILE_NAMES = {"up", "down", "left", "right"}


--[[
    jitstuyoka
    
    Button that returns you to the game
    Layer that disables clicking under it
    
    
    The Custom extra powers are hardcoded xml active powers that start disabled and have perm duration.
--]]
local BASIC_HEAD = {name="basic_head", type=PART_HEAD}
local BASIC_BODY = {name="basic_body", type=PART_BODY, health=50} --todo make powers for all of the equips I can't assign.
local BASIC_LEGS = {name="basic_legs", type=PART_LEGS}
local BASIC_GUN = {name="basic_legs", type=PART_GUN, damage=3, shots=3, shot_delay=.3, cooldown=2}

--vars that need to be moved to loop
local equippedHead = BASIC_HEAD
local equippedBody = nil
local equippedLegs = nil
local equippedGun = nil
local equippedBomb = nil
local equippedPod = nil

local gunCooldown = 0
local bombCooldown = 0
local podCooldown = 0


--unlocks should be across all, equips should be individual
--keep the id of the char in the varname
--Hyperspace.metaVariables[METAVAR_NAME_JITSU..part.name..crewmem.extend.selfId] = 1
--Actually this might clutter up the meta variables. figure out a way to clean them up or don't do this.

local function getPartFolder(newPart, direction)--have them all the same to start.
    return "particles/jitsugyoka/"..PART_FILE_NAMES[newPart.type].."/"..newPart.name..DIRECTION_FILE_NAMES[direction]
end

--adds four particles, one for each direction.  They all start on, then get toggled in the render? loop.
local function registerPart(crewmem, newPart) --register with brightness, create a new particle.
    local part_particles = crewTable.part_particles
    if (part_particles == nil) then
        part_particles = {}
    end
    local oldParticleSet = part_particles[newPart.type]
    if (oldParticleSet ~= nil) then
        for k,v in pairs(oldParticleSet) do
            Brightness.destroy_particle(v)
        end
    end
    local newParticleSet = {}
    for i = 1,4 do
        table.insert(newParticleSet, 1, Brightness.create_particle(getPartFolder(newPart, i), 1, 1, Hyperspace.point(0,0), 0, crewmem.currentShipId, "SHIP_MANAGER"))
    end
    part_particles[newPart.type] = newParticleSet --todo check that this correctly assigns things via reference and all that
    crewTable.part_particles = part_particles
end


local function equipPart(newPart)
    crewTable.parts[newPart.type] = newPart
    registerPart(newPart)
end

--onclick, print stuff   ON_MOUSE_L_BUTTON_DOWN
--enemy ship begins 1288,63  bosses different?
--Ship graph positions are the top right corner of the ship and what I need to calculate the world location.
--Every ship graph thinks that it lives at -1 negative 1 this isn't useful.
--[[
script.on_internal_event(Defines.InternalEvents.ON_MOUSE_L_BUTTON_DOWN, function(x, y) --x and y are unused
        local mousePos = Hyperspace.Mouse.position
        local shipManager = Hyperspace.ships(0)
        local enemyShipManager = Hyperspace.ships(1)
        local shipGraph = Hyperspace.ShipGraph.GetShipInfo(0)
        local enemyShipGraph = Hyperspace.ShipGraph.GetShipInfo(1)
        local wps2
        
        --This appears to do some wonky ********* when full screen .
        
        local cApp = Hyperspace.Global.GetInstance():GetCApp()
        local targetPosition = cApp.gui.combatControl.targetPosition
        
        if (x > 832) then
            --enemy ship
            --if exists
            if (enemyShipGraph ~= nil) then
                print(get_room_at_location(enemyShipManager, Hyperspace.Point(mousePos.x - targetPosition.x - 747, mousePos.y - targetPosition.y), false))
            else
                print(-1)
            end
        else
            --ownship
            --Manager dot my blueprint .
            --one strat: get The ship blueprint and calculate the offset from the graph there .  .layoutFile, open that and do math.
            wps = shipGraph:ConvertToLocalPosition(Hyperspace.Pointf((x - targetPosition.x),(y - targetPosition.y)), true)
            print("Click down", mousePos.x - targetPosition.x, " ", mousePos.y - targetPosition.y - lwl.TILE_SIZE)
            print(get_room_at_location(shipManager, Hyperspace.Point(mousePos.x - targetPosition.x, mousePos.y - targetPosition.y - lwl.TILE_SIZE), false))
        end
        
        
    end)
--]]

--actually just use crew loop?
--I need to save all jitsu's information in long term storage.
--It can't break when you load it agian.
--[[ man 
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function(ship) 
    local shipManager = Hyperspace.ships(ship.iShipId)
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_jitsu") then
            local crewTable = userdata_table(crewmem, TABLE_NAME_JITSU)

            local parts = crewTable.parts
            if (parts == nil) then --Yeah this isn't actually where you edit this value .
                parts = {BASIC_HEAD, BASIC_BODY, BASIC_LEGS, BASIC_GUN, nil, nil} --equip default loadout TODO update with metavars
                for key,value in ipairs(parts) do
                    --registerPart(value)
                end
            end
            local part_particles = crewTable.part_particles --never nil
            
            --get latest brightness to order these.
            
            --uh render the parts in layer order.  Facing direction matters here, so get that maybe.  Not actually sure if that's possible.
            --make these as voxels and export the different faces?
            --crewmem.crewAnim.direction
            
            
            --animations here are scuffed, doing this with lua?  am i mad?  do-- do I sprite the legs???
            
            
            crewTable.parts = parts
        end
    end
    end, function() end)--]]
