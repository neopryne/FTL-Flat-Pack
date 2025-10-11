local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwcco = mods.lightweight_crew_change_observer

local get_room_at_location = mods.multiverse.get_room_at_location


local TABLE_NAME_JITSU = "mods.flatpack.finmechv2.13.9"
local METAVAR_NAME_JITSU = "ffftl_jitsu"


------------------POINT UTILS---------------------

function mods.lightweight_lua.floatEquals(f1, f2, epsilon)
    epsilon = lwl.nilSet(epsilon, .0001)
    return math.abs(f1-f2) < epsilon
end

function mods.lightweight_lua.pointFuzzyEquals(p1, p2, epsilon)
    --print("compare xx,yy", p1.x, p2.x, p1.y, p2.y)
    return lwl.floatEquals(p1.x, p2.x, epsilon) and lwl.floatEquals(p1.y, p2.y, epsilon)
end

function mods.lightweight_lua.goalExists(goalPoint)
    return not (lwl.floatEquals(goalPoint.x, -1) and lwl.floatEquals(goalPoint.y, -1))
end

---Returns the angle in degrees, 0 being straight up.
---@param point1 Hyperspace.Point|Hyperspace.Pointf
---@param point2 Hyperspace.Point|Hyperspace.Pointf
---@return number
function lwl.distanceBetweenPoints(point1, point2)
    return math.sqrt((point1.x - point2.x)^2 + (point1.y - point2.y)^2)
end

---Returns a new point given an existing point, an angle, and a distance.
---@param origin Hyperspace.Point|Hyperspace.Pointf Point to calculate from.
---@param angle number Angle in radians, 0 is straight right.
---@param distance number
---@return Hyperspace.Pointf
function lwl.getPoint(origin, angle, distance)
    return Hyperspace.Pointf(origin.x - (distance * math.cos(angle)), origin.y - (distance * math.sin(angle)))
end


------------------END POINT UTILS---------------------
function lwl.crewSpeedToScreenSpeed(crewSpeed)
    --1.333 ~= .4, it's probably linear.  And 0=0
    return crewSpeed --* .4 / 1.334
end
------------------ANGLE UTILS---------------------

local function getAngle(origin, target)
    local deltaX = origin.x - target.x
    local deltaY = origin.y - target.y
    local innerAngle = math.atan(deltaY, deltaX)
    --print("Angle is ", innerAngle)
    return innerAngle
end

---Converts an FTL style angle to a Brightness Particles style one.
---That is, it rotates it by 90 degrees and converts it to degrees.
---@param angle number
---@return number
local function angleFtlToBrightness(angle)
    return ((angle * 180 / math.pi) + 270) % 360
end

local function angleBrightnessToFtl(angle)
    return (((angle + 90) % 360) * math.pi / 180)
end

local function clockwiseDistance(heading, target)
      return ((target - heading) + 360) % 360
end

local function counterclockwiseDistance(heading, target)
      return ((heading - target) + 360) % 360
end

local function angleDistance(heading, target)
    return math.min(clockwiseDistance(heading, target), counterclockwiseDistance(heading, target))
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

---Returns the angle the crew is travelling in degrees, 0 being straight right.
---@param crewmem Hyperspace.CrewMember
---@return number the angle the crew is travelling in degrees, 0 being straight right.
function lwl.getMovementDirection(crewmem)
    return getAngle(crewmem:GetPosition(), crewmem:GetNextGoal())
end

---TODO! IT'S VERY IMPORTANT NOT TO MIX BRIGHTNESS ANGLES WITH NON-BRIGHTNESS ANGLES!
------------------END ANGLE UTILS---------------------




--[[
    jitstuyoka
    
    Button that returns you to the game
    Layer that disables clicking under it
    
    Actually, doing it like this means I get to render all the non-foot particles at the exact same location, and have it come out right!
    Without having to do any extra math!

    The Custom extra powers are hardcoded xml active powers that start disabled and have perm duration.

    All values should scale off of base crew values where possible so that he's affected by things that affect things.
    Like all FFFTL crew, he should be strong when slowed?
    
    I could get very into making all the stuff spawn exactly right from all the parts/attachments.
--]]

--The names here are used to find files, so you have to update those if you change this.
--enum like.  This is also the index of the associated particle in parts{}
local PART_HEAD = 1
local PART_BODY = 2
local PART_LEGS = 3
local PART_GUN = 4
local PART_BOMB = 5
local PART_POD = 6
local PART_FILE_NAMES = {"head", "body", "legs", "gun", "bomb", "pod"} --SSOT for these strings.

local HEAD_INFO = {subunits={}}
local BODY_INFO = {subunits={}}
local LEGS_INFO = {subunits={"left", "right"}}
local GUN_INFO = {subunits={}}
local BOMB_INFO = {subunits={}}
local POD_INFO = {subunits={}}
--Parts with subunits have main units that are tables of their subunits.
local PART_INFO_LIST = {HEAD_INFO, BODY_INFO, LEGS_INFO, GUN_INFO, BOMB_INFO, POD_INFO}
--[[
Ok so I'm going to define my variables in a structure along with keys for use with the player var stuff.

if #PART_INFO_LIST[part.type].subunits > 0 then
    --do legs stuff
else
    --everything else
end

So that the structure looks like
    jitsu.setVar(whateverVar, 7)
    And this internally goes and pulls the values to call
    mJitsuPlayerVariableInterface.setVariable(jitsu.uuid, whateverVar.key, 7)
]]

local FEET_MAX_DISTANCE = 30
local FEET_MAX_BODY_DISTANCE = 15

local MODEL_BASIC = "basic"

local BASIC_HEAD = {model=MODEL_BASIC, type=PART_HEAD}
local BASIC_BODY = {model=MODEL_BASIC, type=PART_BODY, health=50} --todo make powers for all of the equips I can't assign.
local BASIC_LEGS = {model=MODEL_BASIC, type=PART_LEGS}
local BASIC_GUN = {model=MODEL_BASIC, type=PART_GUN, damage=3, shots=3, shot_delay=.3, cooldown=2}
local BASIC_BOMB = {model=MODEL_BASIC, type=PART_BOMB}
local BASIC_POD = {model=MODEL_BASIC, type=PART_POD}

local HEADS = {BASIC_HEAD}
local BODIES = {BASIC_BODY}
local GUNS = {BASIC_GUN}
local BOMBS = {BASIC_BOMB}
local PODS = {BASIC_POD}
local LEGS = {BASIC_LEGS}
local PART_MODELS_BY_TYPE = {HEADS, BODIES, LEGS, GUNS, BOMBS, PODS}


--todo do I need to stub this for testing?
local mJitsuPlayerVariableInterface = lwl.CreatePlayerVariableInterface(METAVAR_NAME_JITSU)
local mJitsuList = {} --todo load this from cco
local mInitialized = false
local mJitsuObserver
local mScaledLocalTime = 0 --todo make a time ticker.
--[[
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


--unlocks should be across all, equips should be individual

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


local function getPartPath(part)
    --print("Getting path for", lwl.dumpObject(part))
    return "particles/jitsugyoka/"..PART_FILE_NAMES[part.type] .."/"..part.model
end

local function createPersistantParticle(path)
    local particle = Brightness.create_particle(path, 1, 100, Hyperspace.Pointf(0,0), 0, 0, "SHIP_MANAGER")
    particle.persists = true
    return particle
end

--TODO the movement noise will come from the feet, as they move and stop. whiiir bang whiir bang

local function adjustParticleDirection(particle, desiredDirection)
    particle.rotation = rotateTowards(particle.rotation, desiredDirection, 1)
end






local function footTooFar(crewmem)
    -- local footDistance = lwl.distanceBetweenPoints(mFeet[1 + mActiveFootZeroIndex].position, crewmem:GetPosition())
    -- --print("Foot body distance", footDistance)
    -- return lwl.distanceBetweenPoints(mFeet[1 + mActiveFootZeroIndex].position, crewmem:GetPosition()) > FEET_MAX_BODY_DISTANCE
end

local function feetTooFar(foot1, foot2)
    local footDistance = lwl.distanceBetweenPoints(foot1.position, foot2.position)
    --print("Foot distance", footDistance)
    return lwl.distanceBetweenPoints(foot1.position, foot2.position) > FEET_MAX_DISTANCE
end



---comment
---@param crewmem Hyperspace.CrewMember
local function advanceFeet(crewmem)
    -- if lwl.goalExists(crewmem:GetFinalGoal()) then
    --     --Assume left starts active, then swap if needed.
    --     --Move active foot 2x speed along path.
    --     --Getting the movement vector is easy.  Getting the speed is less so.

    --     --todo nothing here actually makes sure that the feet track the main body, I should add that.
    --     --print("speed:", crewmem:GetMoveSpeed())
    --     local movementDirection = lwl.getMovementDirection(crewmem) --todo pull out for efficiency
    --     local activeFoot = mFeet[1 + mActiveFootZeroIndex]
    --     activeFoot.position = lwl.getPoint(activeFoot.position, movementDirection, lwl.crewSpeedToScreenSpeed(crewmem:GetMoveSpeed()) * 2)
    --     --Bring the foot in a little to keep it in the correct radius.
    --     activeFoot.position = lwl.getPoint(activeFoot.position, getAngle(activeFoot.position, crewmem:GetPosition()), lwl.crewSpeedToScreenSpeed(crewmem:GetMoveSpeed()) * .1)
    --     if feetTooFar(mLeftFootParticle, mRightFootParticle) or footTooFar(crewmem) then
    --         if mFootSwapReady then
    --             --print("Swapped feet.")
    --             mActiveFootZeroIndex = 1 - mActiveFootZeroIndex
    --             --mFootSwapReady = false
    --         end
    --     else
    --         mFootSwapReady = true
    --     end
    -- end
end


local function getBasePathForPart(jitsu, partType)
    --print("partType", partType)
    local modelIndex = 1--jitsu:getVar(PART_FILE_NAMES[partType]) todo add
    --print("modelIndex", modelIndex)
    return getPartPath(PART_MODELS_BY_TYPE[partType][modelIndex])
end

--The game will create a new jitsu table to track a crewmember that's a jitsu.
local function newJitsu(crewmem)
    print("new jitsu", crewmem:GetName())
    local jitsu = {}
    jitsu.baseCrew = crewmem

    local gunCooldown = 0
    local bombCooldown = 0
    local podCooldown = 0

    -- jitsu.setVar = function(self, varKey, value)
    --     mJitsuPlayerVariableInterface.setVariable(self.baseCrew.extend.selfId, varKey, value)
    -- end

    -- jitsu.getVar = function (self, varKey)
    --     mJitsuPlayerVariableInterface.getVariable(self.baseCrew.extend.selfId, varKey)
    -- end

    -- jitsu.initVar = function (self, varKey, defaultValue)
    --     jitsu:setVar(varKey, lwl.setIfNil(jitsu:getVar(varKey), defaultValue))
    -- end

    -- jitsu.destroySelf = function(self)
    --     for partType=1,#PART_FILE_NAMES do
    --         local partTypeName = PART_FILE_NAMES[partType]
    --         if #PART_INFO_LIST[partType].subunits > 0 then
    --             for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
    --                 self[partTypeName..subunitName].destroy()
    --             end
    --         else
    --             self[partTypeName].destroy()
    --         end
    --     end
    --     mJitsuPlayerVariableInterface.removeObject(self.baseCrew.extend.selfId)
    -- end

    -- jitsu.swapParticles = function(self, partPath, partName)
    --     local newParticle = createPersistantParticle(partPath)
    --     if self[partName] then
    --         self[partName].destroy()
    --     end
    --     self[partName] = newParticle
    -- end

    -- --Called during init, load, and part swap.  todo maybe change arguments
    -- jitsu.equipPart = function(self, partList, modelIndex)
    --     local part = partList[modelIndex]
    --     local partTypeName = PART_FILE_NAMES[part.type]
    --     local partPath = getPartPath(part)

    --     if #PART_INFO_LIST[part.type].subunits > 0 then
    --         for _,subunitName in ipairs(PART_INFO_LIST[part.type].subunits) do
    --             self:swapParticles(partPath.."/"..subunitName, partTypeName..subunitName)
    --         end
    --     else
    --         self:swapParticles(partPath, partTypeName)
    --     end
    --     --todo also change the statistics.

    --     self:setVar(partTypeName, modelIndex)
    -- end

    -- ---Returns the direction this crew should face as a BRIGHTNESS ANGLE
    -- ---@return number the angle the crew is travelling in degrees, 0 being straight up.
    -- jitsu.calculateDesiredFacingAngle = function(self)
    --     local bodyParticle = self[PART_FILE_NAMES[2]]
    --     if lwl.goalExists(self.baseCrew:GetFinalGoal()) then
    --         --First, see if we're way off base.  Uh this is throwing errors.  Rotate to face the general direction.
    --         local immediateHeading = angleFtlToBrightness(getAngle(self.baseCrew:GetPosition(), self.baseCrew:GetNextGoal()))
    --         local overallHeading = angleFtlToBrightness(getAngle(self.baseCrew:GetPosition(), self.baseCrew:GetFinalGoal()))
    --         local facingDistance = angleDistance(bodyParticle.heading, overallHeading) --body heading
    --         if facingDistance > 180 then
    --             print("big angle", facingDistance)
    --             return overallHeading
    --         end

    --         --If we are generally pointed the right direction, do some finer navigation.
    --         return immediateHeading
    --     else
    --         --Standing still, don't rotate
    --         --We want to rotate in combat or manning systems or fighting fires.
    --         --print("Standing still at ", mBodyParticle.rotation)
    --         return bodyParticle.rotation
    --     end
    -- end

    -- ---comment
    -- jitsu.adjustFacingDirection = function(self)
    --     local desiredDirection = self:calculateDesiredFacingAngle()
    --     --print("Desired Direction:", desiredDirection, "facing", mBodyParticle.rotation)
        
    --     for partType=1,#PART_FILE_NAMES do
    --         local partTypeName = PART_FILE_NAMES[partType]
    --         if #PART_INFO_LIST[partType].subunits > 0 then
    --             for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
    --                 --todo make this depend on foot activeness.
    --                 --adjustParticleDirection(self[partTypeName..subunitName], desiredDirection)
    --             end
    --         else
    --             adjustParticleDirection(self[partTypeName], desiredDirection)
    --         end
    --     end
    --     --todo do this in the same style as the other stuff, just note that feet might be on the ground and not able to turn.
    --     --but also i can save that part for later.
    -- end

    jitsu.onFrame = function (self)
        --for all particles
        --if it doesn't have subparticles, snap it to yourself.
        --always snap it to your space.
        for partType=1,#PART_FILE_NAMES do
            local partTypeName = PART_FILE_NAMES[partType]
            if #PART_INFO_LIST[partType].subunits > 0 then
                for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
                    -- self[partTypeName..subunitName].space = self.baseCrew.currentShipId
                end
            else
                self[partTypeName].position = self.baseCrew:GetPosition()
                print(self)
                print(self.baseCrew)
                print(self.baseCrew.currentShipId)
                --self[partTypeName].space = 0--self.baseCrew.currentShipId  --todo these are the lines that break it.
                --print("did all that and didn't crash", partTypeName, self[partTypeName].space)
                ----todo it just crashes, it doesn't even get here.  Brightness bug?  HS bug?
                --Also it snaps the parts onto one of the other crew.
                --and then after another refresh, forgets their attached to anyone.
            end
        end

        if not (self.baseCrew:GetNextGoal() == nil) then
            -- self:adjustFacingDirection()
            -- --advanceFeet(crewmem)
            -- ----mNextLocationParticle.position = lwl.setIfNil(crewmem:GetNextGoal(), crewmem:GetPosition())
        end
    end

    ---comment
    jitsu.snapFeet = function(self)
        -- mLeftFootParticle.position = crewmem:GetPosition()
        -- mLeftFootParticle.position.x = mLeftFootParticle.position.x - 5
        -- mRightFootParticle.position = crewmem:GetPosition()
        -- mRightFootParticle.position.x = mRightFootParticle.position.x + 5
    end

    ---Start all parts at the lowest level if not already set.
    for i,partTypeName in ipairs(PART_FILE_NAMES) do
        --jitsu:initVar(partTypeName, 1) todo add
        if #PART_INFO_LIST[i].subunits > 0 then
            jitsu[partTypeName] = {}
            for _,subunitName in ipairs(PART_INFO_LIST[i].subunits) do
                local subunitParticle = createPersistantParticle(getBasePathForPart(jitsu, i).."/"..subunitName)
                jitsu[partTypeName..subunitName] = subunitParticle
                table.insert(jitsu[partTypeName], subunitParticle)
            end
        else
            jitsu[partTypeName] = createPersistantParticle(getBasePathForPart(jitsu, i))
        end
        --todo this doesn't handle feet/legs right.
    end

    -- local mActiveFootZeroIndex = 0
    -- local mFootSwapReady = true
    
    -- jitsu:snapFeet()
    Brightness.send_to_front(jitsu[PART_FILE_NAMES[PART_HEAD]])
    return jitsu
end

-- local function equipGun(self, index)
--     self:equipPart(GUNS, index)
-- end




---------------------------------------------------------

local function renderJitsus()
    for _,jitsu in ipairs(mJitsuList) do
        jitsu:onFrame()
    end
end

local function generateCrewMatchFilter(crewId)
    return function(table, i)
        return false --table[i].baseCrew.extend.selfId == crewId todo extend should not be nil.
    end
end

local function jitsuOnRemove(jitsu)
    --jitsu:destroySelf()
end

--All the jitsus, both sides.
local function jitsuFilter(crewmem)
    return crewmem:GetSpecies() == "fff_jitsugyoka"
end

script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    --This doesn't actually render anything, but does compute that should happen during a render.
    if lwl.isPaused() then return end
    --todo maybe scale for framerate.
    renderJitsus()
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not mJitsuObserver then
        mJitsuObserver = lwcco.createCrewChangeObserver(jitsuFilter)
    end
    if not mJitsuObserver.isInitialized() then return end
    
    --todo put stuff that should happen while paused here.
    if lwl.isPaused() then return end
    mScaledLocalTime = mScaledLocalTime + (Hyperspace.FPS.SpeedFactor * 16 / 10)
    if (mScaledLocalTime > 1) then
        mScaledLocalTime = 0
        for _,crewId in ipairs(mJitsuObserver.getAddedCrew()) do
            table.insert(mJitsuList, newJitsu(lwl.getCrewById(crewId)))
        end
        for _,crewId in ipairs(mJitsuObserver.getRemovedCrew()) do
            lwl.arrayRemove(mJitsuList, generateCrewMatchFilter(crewId), jitsuOnRemove)
        end
        mJitsuObserver.saveLastSeenState()
    end
end)



-----------------------------------------------------------


--[[
This crashes when you quit to menu and try to continue.  I think because the brightness particles get destroyed or something?
I don't have this issue with gexpy, or at least not since I last checked.
It's likely the brightness particles that I have lying around which I expect to be there and aren't.
Time to comment out large blocks of code and see what happens.

Ok I changed nothing and now the particles don't show up.

Buffer works fine, but the old particles stick around.  There should be something in Brightness to deal with particles that you lose track of.
I wonder if old versions of this crash also, or if that's more of a complex interaction.

Restarting also breaks it.  But only with brightness particles?
--]]


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