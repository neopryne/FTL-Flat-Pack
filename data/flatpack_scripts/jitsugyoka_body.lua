local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface

local get_room_at_location = mods.multiverse.get_room_at_location


local TABLE_NAME_JITSU = "mods.flatpack.finmechv2.13.9"
local METAVAR_NAME_JITSU = "ffftl_jitsu"



local OFFSET_HEAD = Hyperspace.Point(0, -10)
--local OFFSET_LEGS = Hyperspace.Point(5, 10)
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


--[[
    jitstuyoka
    
    Button that returns you to the game
    Layer that disables clicking under it
    
    Actually, doing it like this means I get to render all the non-foot particles at the exact same location, and have it come out right!
    Without having to do any extra math!

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

--[[
Big jitsu table that tells you if your guy was built yet in this run?

I can take a page out of grimdark expy's 

number of jitsus
jitsu 0-n crew ids

jitsu-id-ID#-head:
jitsu-id-ID#-body:
jitsu-id-ID#-legs:
jitsu-id-ID#-gun:
jitsu-id-ID#-bomb:
jitsu-id-ID#-pod:
facing direction
whatever other variables I need to store.

Honestly it might be time to make a small class abstracting this kind of stuff.

Then I need to grab the reset logic from LWCE and probably extract it into a library, since anything using player variables...
Wait, was that all I needed?  Player variables instead of meta variables, and then I can ditch a bunch of messy logic?
TODO see about replacing LWCE vars with player vars.

]]





--unlocks should be across all, equips should be individual
--keep the id of the char in the varname
--Hyperspace.metaVariables[METAVAR_NAME_JITSU..part.name..crewmem.extend.selfId] = 1
--Actually this might clutter up the meta variables. figure out a way to clean them up or don't do this.

local function getPartFolder(newPart, direction)--have them all the same to start.
    return "particles/jitsugyoka/"..PART_FILE_NAMES[newPart.type].."/"..newPart.name..DIRECTION_FILE_NAMES[direction]
end

local function equipPart(newPart)
    crewTable.parts[newPart.type] = newPart
    registerPart(newPart)
end

--[[
main self turns to point towards target.
When not moving, does not turn head.
In combat or firefight, faces target.
--make it not flicker back and forth.

One foot is always stationary, and one foot moves quickly to a place that it can stay stationary.
When it starts moving, it picks a foot furthest from where it is.
Whump whump whump
This is a big thing made of smaller things.
The angle of the feet should rotate to align with the body, but only while a given foot is moving.


Current challenge: properly showing selection state.
Green outline, green overlay.
This was easy when I was rendering everything, but now they're all image particles.  
If I make the body always have the same outline, I could do something like render a particle over the body.
Actually, an easy thing to do is render a green circle/disk under the unit.  I'll go with that.

]]

local function getHeadPath()
    return "particles/jitsugyoka/head/basic"
end

local function getBodyPath()
    return "particles/jitsugyoka/body/basic"
end

local function createPersistantParticle(path)
    local particle = Brightness.create_particle(path, 1, 100, Hyperspace.Pointf(0,0), 0, 0, "SHIP_MANAGER")
    particle.persists = true
    return particle
end


local mBodyParticle = createPersistantParticle(getBodyPath())
local mNextLocationParticle = createPersistantParticle(getHeadPath())
--local mPreviousPosition

--todo if I was really good, I would wait until
------------------POINT UTILS---------------------

function mods.lightweight_lua.floatEquals(f1, f2, epsilon)
    epsilon = lwl.nilSet(epsilon, .0001)
    return math.abs(f1-f2) < epsilon
end

function mods.lightweight_lua.pointFuzzyEquals(p1, p2, epsilon)
    print("compare xx,yy", p1.x, p2.x, p1.y, p2.y)
    return lwl.floatEquals(p1.x, p2.x, epsilon) and lwl.floatEquals(p1.y, p2.y, epsilon)
end

function mods.lightweight_lua.goalExists(goalPoint)
    return not (lwl.floatEquals(goalPoint.x, -1) and lwl.floatEquals(goalPoint.y, -1))
end

------------------END POINT UTILS---------------------

------------------ANGLE UTILS---------------------

local function getAngle(origin, target)
    local deltaX = origin.x - target.x
    local deltaY = origin.y - target.y
    local innerAngle = math.atan(deltaY, deltaX)
    --print("Angle is ", innerAngle)
    return innerAngle
end

---Returns the angle in degrees, 0 being straight up.
---@param origin Hyperspace.Point|Hyperspace.Pointf
---@param target Hyperspace.Point|Hyperspace.Pointf
---@return number
local function getBrightnessAngle(origin, target)
    return ((getAngle(origin, target) * 180 / math.pi) + 270) % 360
end

local function clockwiseDistance(heading, target)
      return ((target - heading) + 360) % 360
end

local function counterclockwiseDistance(heading, target)
      return ((heading - target) + 360) % 360
end


local function rotateTowards(heading, target, step) --todo how was this not jittering before?
    local clockwise = clockwiseDistance(heading, target)
    local counterclockwise = counterclockwiseDistance(heading, target)
    if clockwise <= 1 or counterclockwise <= 1 then
        --Close enough
        return heading
    end
    if clockwise > counterclockwise then
        return heading - step
    else
        return heading + step
    end
end

local function angleDistance(heading, target)
    return math.min(clockwiseDistance(heading, target), counterclockwiseDistance(heading, target))
end

---Returns the angle the crew is travelling in degrees, 0 being straight up.
---@param crewmem Hyperspace.CrewMember
local function calculateDesiredFacingAngle(crewmem)
    
    if lwl.goalExists(crewmem:GetFinalGoal()) then
        --First, see if we're way off base.
        -- if angleDistance(crewmem:GetPosition(), crewmem:GetFinalGoal()) > 180 then
        --     return getBrightnessAngle(crewmem:GetPosition(), crewmem:GetFinalGoal())
        -- end

        --If we are generally pointed the right direction, do some finer navigation.
        return getBrightnessAngle(crewmem:GetPosition(), crewmem:GetNextGoal())
    else
        --Standing still, don't rotate
        --print("Standing still at ", mBodyParticle.rotation)
        return mBodyParticle.rotation --todo reference from crew table or smthing.
    end     
end

------------------END ANGLE UTILS---------------------




local function adjustParticleDirection(particle, desiredDirection)
    particle.rotation = rotateTowards(particle.rotation, desiredDirection, 1)
end

--todo actually if you're more than 180* off of your target location point, I want you to prioritize rotating so you face the general direction first.


local function adjustFacingDirection(crewmem)
    local desiredDirection = calculateDesiredFacingAngle(crewmem)
    print("Desired Direction:", desiredDirection, "facing", mBodyParticle.rotation)
    adjustParticleDirection(mBodyParticle, desiredDirection)
    adjustParticleDirection(mNextLocationParticle, desiredDirection)
end


--todo only works with one jitsu rn.
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if (crewmem:GetSpecies() == "fff_jitsugyoka") then
        --print("You have a jitsu!")
        mBodyParticle.space = crewmem.currentShipId
        mBodyParticle.position = crewmem:GetPosition()
        if not (crewmem:GetNextGoal() == nil) then
            adjustFacingDirection(crewmem)
            mNextLocationParticle.position = lwl.setIfNil(crewmem:GetNextGoal(), crewmem:GetPosition())
        end
    end
end)



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
            print("Click down", mousePos.x - targetPosition.x, " ", mousePos.y - targetPosition.y - lwl.TILE_SIZE())
            print(get_room_at_location(shipManager, Hyperspace.Point(mousePos.x - targetPosition.x, mousePos.y - targetPosition.y - lwl.TILE_SIZE()), false))
        end
        
        
    end)
--]]
--actually just use crew loop?
--I need to save all jitsu's information in long term storage.
--It can't break when you load it agian.
--[[ man If I really wanted to do this I would make some colored shapes for the different parts.
Because you need to render the shapes differently based on the facing direction.

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


    --[[
--Tests

print("Expect 0", getBrightnessAngle({x=0, y=0}, {x=0, y=-10}))
print("Expect just above 0", getBrightnessAngle({x=0, y=0}, {x=0.1, y=-10}))
print("Expect 45", getBrightnessAngle({x=0, y=0}, {x=10, y=-10}))
print("Expect 90", getBrightnessAngle({x=0, y=0}, {x=10, y=0}))
print("Expect 135", getBrightnessAngle({x=0, y=0}, {x=10, y=10}))
print("Expect almost 180", getBrightnessAngle({x=0, y=0}, {x=0.1, y=10}))
print("Expect 180", getBrightnessAngle({x=0, y=0}, {x=0, y=10}))
print("Expect just above 180", getBrightnessAngle({x=0, y=0}, {x=-.1, y=10}))
print("Expect 270", getBrightnessAngle({x=0, y=0}, {x=-10, y=0}))
print("Expect 315", getBrightnessAngle({x=0, y=0}, {x=-10, y=-10}))
print("Expect almost 360", getBrightnessAngle({x=0, y=0}, {x=-.1, y=-10}))
    
    ]]