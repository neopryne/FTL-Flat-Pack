local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwsb = mods.lightweight_statboosts
local lwcco = mods.lightweight_crew_change_observer
local lweb = mods.lightweight_event_broadcaster

local get_room_at_location = mods.multiverse.get_room_at_location


local TABLE_NAME_JITSU = "mods.flatpack.finmechv2.13.9"
local METAVAR_NAME_JITSU = "ffftl_jitsu"

-----------------------MEMORY_SAFE_CREW---------------------------

---Creates a memory safe wrapper around a crewmember object.
---@param crewmem Hyperspace.CrewMember
---@return table wrapper
lwl.createMemorySafeCrewWrapper = function(crewmem)
    local crewWrapper = {}
    crewWrapper.internalCrew = crewmem
    crewWrapper.internalId = crewmem.extend.selfId

    ---Call with a colon, returns the crew member this was created around, even if the original has gone out of scope.
    ---@param self table
    ---@return Hyperspace.CrewMember|nil Nil if no crew can be found with this id.
    crewWrapper.get = function(self)
        --When an object gets invalidated, all its fields become garbage.  We can use this to check
        --when it happens, but also need to save selfId outside of that so we can get the crew again.
        ---todo this might be too hacky, and we need a game-loaded hook because everything else is going to be a major hack.
        if (not (self.internalCrew.currentShipId == 0 or self.internalCrew.currentShipId == 1)) or
        (not (self.internalCrew.iShipId == 0 or self.internalCrew.iShipId == 1)) then
            print("wsschrag resetting crew ", self.internalId) --todo it can't access selfId which is why we do it this way.
            --It's not perfect, but it only happens when using jitsus.
            self.internalCrew = lwl.getCrewById(self.internalId)
        end
        return self.internalCrew
    end
    return crewWrapper
end

-----------------------END MEMORY_SAFE_CREW---------------------------
function lwl.floatEquals(f1, f2, epsilon)
    epsilon = lwl.nilSet(epsilon, .0001)
    return math.abs(f1-f2) < epsilon
end

function lwl.isMoving(crewmem)
    return crewmem.speed_x + crewmem.speed_y > 0
end

------------------POINT UTILS---------------------
function lwl.pointFuzzyEquals(p1, p2, epsilon)
    if not epsilon then
        epsilon = 1
    end
    --print("compare xx,yy", p1.x, p2.x, p1.y, p2.y)
    return lwl.floatEquals(p1.x, p2.x, epsilon) and lwl.floatEquals(p1.y, p2.y, epsilon)
end

function lwl.goalExists(goalPoint)
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

function lwl.getDistance(origin, target)
    return math.abs(math.sqrt((origin.x - target.x)^2 + (origin.y - target.y)^2))
end

function lwl.getAngle(origin, target)
    local deltaX = origin.x - target.x
    local deltaY = origin.y - target.y
    local innerAngle = math.atan(deltaY, deltaX)
    --print("Angle is ", innerAngle)
    return innerAngle
end
------------------END POINT UTILS---------------------
function lwl.crewSpeedToScreenSpeed(crewSpeed)
    --1.333 ~= .4, it's probably linear.  And 0=0
    return crewSpeed --* .4 / 1.334
end
------------------ANGLE UTILS---------------------
---Converts an FTL style angle to a Brightness Particles style one.
---That is, it rotates it by 90 degrees and converts it to degrees.
---@param angle number
---@return number
function lwl.angleFtlToBrightness(angle)
    return ((angle * 180 / math.pi) + 270) % 360
end

function lwl.angleBrightnessToFtl(angle)
    return (((angle + 90) % 360) * math.pi / 180)
end

function lwl.clockwiseDistanceDegrees(heading, target)
      return ((target - heading) + 360) % 360
end

function lwl.counterclockwiseDistanceDegrees(heading, target)
      return ((heading - target) + 360) % 360
end

---
---@param heading number angle in degrees
---@param target number angle in degrees
---@return number the shortest angular distance between the heading and the target directions.
function lwl.angleDistanceDegrees(heading, target)
    return math.min(lwl.clockwiseDistanceDegrees(heading, target), lwl.counterclockwiseDistanceDegrees(heading, target))
end

function lwl.rotateTowardsDegrees(heading, target, step) --todo how was this not jittering before?
    local clockwise = lwl.clockwiseDistanceDegrees(heading, target)
    local counterclockwise = lwl.counterclockwiseDistanceDegrees(heading, target)
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
    return lwl.getAngle(crewmem:GetPosition(), crewmem:GetNextGoal())
end

---comment
---@param direction number from CrewAnimation
---@return number FTL angle in radians
function lwl.animationDirectionToFtlAngle(direction)
    return ((3 - direction) % 4) * math.pi / 2
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

    Ok, so each gun, bomb, and pod need their own projectiles
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
local LEFT_FOOT_INDEX = 1 --to help with finding these
local RIGHT_FOOT_INDEX = 2
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


local function getFootName(index)
    return PART_FILE_NAMES[PART_LEGS]..LEGS_INFO.subunits[index]
end

local function leftFootName()
    return getFootName(LEFT_FOOT_INDEX)
end

local function rightFootName()
    return getFootName(RIGHT_FOOT_INDEX)
end

local MODEL_BASIC = "basic"

local BASIC_HEAD = {model=MODEL_BASIC, type=PART_HEAD, compute=30} --targeting? Processing power?
local BASIC_BODY = {model=MODEL_BASIC, type=PART_BODY, health=95, compute=10} --todo make powers for all of the equips I can't assign.
local BASIC_LEGS = {model=MODEL_BASIC, type=PART_LEGS, traverseSpeed=1, movementSpeed=.8}
local BASIC_GUN = {model=MODEL_BASIC, type=PART_GUN, damage=3, shots=3, shot_delay=.3, cooldown=2}
local BASIC_BOMB = {model=MODEL_BASIC, type=PART_BOMB} --todo remove the basic pod and bomb from default.  You have to buy them.
local BASIC_POD = {model=MODEL_BASIC, type=PART_POD}
local NONE = {} --todo see what I need to stub.  Also I need an id-indexed list of jitsus.

local HEADS = {BASIC_HEAD}
local BODIES = {BASIC_BODY}
local GUNS = {BASIC_GUN}
local BOMBS = {NONE, BASIC_BOMB}
local PODS = {NONE, BASIC_POD}
local LEGS = {BASIC_LEGS}
local PART_MODELS_BY_TYPE = {HEADS, BODIES, LEGS, GUNS, BOMBS, PODS}

local FOOT_FORWARD_FACTOR = 2
local STEP_DISTANCE = 33
local INDEXING_OFFSET = 1 --nonsense for 1 indexing
local FOOT_OFFSET = 5
local HIGHLIGHT_YELLOW = Graphics.GL_Color(.8, .8, .0, .5)
local HIGHLIGHT_GREEN = Graphics.GL_Color(.0, .8, .0, .5)
local HOVER_GREEN = Graphics.GL_Color(.0, .8, .0, .3)
local SELECT_CIRCLE_RADIUS = 15
local SPECIES_JITSU = "fff_jitsugyoka"

local mJitsuPlayerVariableInterface = lwl.CreatePlayerVariableInterface(METAVAR_NAME_JITSU)
local mJitsuList = {}
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

legs: speed, rotation
body: health, DR
head: swag for targeting algorithm?

--unlocks should be across all, equips should be individual


One foot is always stationary, and one foot moves quickly to a place that it can stay stationary.
When it starts moving, it picks a foot furthest from where it is.
Whump whump whump
This is a big thing made of smaller things.
The angle of the feet should rotate to align with the body, but only while a given foot is moving.



Firefighting poof bits if the game doesn't do them itself.
Make sure it turns towards fires and people it fights.
]]
local function getGunProjectilePath(model)
    return ""
end

local function getBombProjectilePath(model)
    return ""
end

local function getPodProjectilePath(model)
    return ""
end

local function getPartPath(part)
    --print("Getting path for", lwl.dumpObject(part))
    if not part.model then
        return "" --todo if this doesn't create a particle, might return a path to an empty image. --nah it should work.
    end
    return "particles/jitsugyoka/"..PART_FILE_NAMES[part.type] .."/"..part.model
end

local function createPersistantParticle(path)
    local particle = Brightness.create_particle(path, 1, 100, Hyperspace.Pointf(0,0), 0, 0, "SHIP_MANAGER")
    particle.persists = true
    return particle
end

--TODO the movement noise will come from the feet, as they move and stop. whiiir bang whiir bang
local function launchParticle(particle)
    --random heading, random speed, random rotation
    particle.heading = math.random(0,360)
    particle.imageSpin = math.random(-32, 32)
    particle.movementSpeed = math.random(2,8)
end

local function adjustParticleDirection(particle, desiredDirection)
    particle.rotation = lwl.rotateTowardsDegrees(particle.rotation, desiredDirection, 1)
end

local function iterateParticles(jitsu, effectFunction)
    for partType=1,#PART_FILE_NAMES do
        local partTypeName = PART_FILE_NAMES[partType]
        if #PART_INFO_LIST[partType].subunits > 0 then
            for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
                effectFunction(jitsu[partTypeName..subunitName])
            end
        else
            effectFunction(jitsu[partTypeName])
        end
    end
end

--The game will create a new jitsu table to track a crewmember that's a jitsu.
local function newJitsu(crewmem)
    print("new jitsu", crewmem:GetName())
    local jitsu = {}
    jitsu.baseCrewWrapper = lwl.createMemorySafeCrewWrapper(crewmem)
    --todo if this is created while dead, it will be in a bad state.

    local gunCooldown = 0
    local bombCooldown = 0
    local podCooldown = 0

    jitsu.setVar = function(self, varKey, value)
        print("setting var", self.baseCrewWrapper:get().extend.selfId, varKey, value)
        mJitsuPlayerVariableInterface.setVariable(self.baseCrewWrapper:get().extend.selfId, varKey, value)
    end

    jitsu.getVar = function (self, varKey)
        --print("getvar3", self.baseCrewWrapper:get().extend.selfId, varKey)
        return mJitsuPlayerVariableInterface.getVariable(self.baseCrewWrapper:get().extend.selfId, varKey)
    end

    jitsu.initVar = function (self, varKey, defaultValue)
        print("initiing var")
        local previousValue = math.floor(lwl.setIfNil(jitsu:getVar(varKey), defaultValue))
        if previousValue < 1 then
            previousValue = 1 --todo hack to deal with zeros left over, remove later.
        end
        jitsu:setVar(varKey, previousValue)
        return previousValue
    end

    jitsu.destroySelf = function(self)
        local destroyFunction = function (particle)
            particle.destroy()
        end
        iterateParticles(self, destroyFunction)
        print("destroy self")
        mJitsuPlayerVariableInterface.removeObject(self.baseCrewWrapper:get().extend.selfId)
    end

    ---comment
    ---@param self table
    ---@param partType any
    ---@return table
    jitsu.getCurrentPart = function(self, partType)
        return PART_MODELS_BY_TYPE[partType][self:getVar(PART_FILE_NAMES[partType])]
    end
    
    ---comment
    jitsu.snapFeet = function(self)
        local crew = self.baseCrewWrapper:get() --todo make this base on the facing direction.
        self[leftFootName()].position = crew:GetPosition()
        self[leftFootName()].position.x = self[leftFootName()].position.x - FOOT_OFFSET
        self[rightFootName()].position = crew:GetPosition()
        self[rightFootName()].position.x = self[rightFootName()].position.x + FOOT_OFFSET
    end

    jitsu.swapParticles = function(self, partPath, partName)
        local newParticle = createPersistantParticle(partPath)
        if self[partName] then
            newParticle.position = self[partName].position
            newParticle.visible = self[partName].visible
            newParticle.rotation = self[partName].rotation
            self[partName].destroy()
        end
        self[partName] = newParticle
    end

    --Called during init, load, and part swap.  todo maybe change arguments
    jitsu.equipPart = function(self, partType, modelIndex)
        local newPart = PART_MODELS_BY_TYPE[partType][modelIndex]
        local partTypeName = PART_FILE_NAMES[partType]
        local partPath = getPartPath(newPart)

        if #PART_INFO_LIST[partType].subunits > 0 then
            for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
                self:swapParticles(partPath.."/"..subunitName, partTypeName..subunitName)
            end
        else
            self:swapParticles(partPath, partTypeName)
        end
        --Part stats are baked in, and change immediately.
        self:setVar(partTypeName, modelIndex)
    end

    --Start death animation
    jitsu.onDeathAnim = function (self)
        local deathAnimationFunction = function (particle)
            launchParticle(particle)
        end
        iterateParticles(self, deathAnimationFunction)
        self.isDying = true
    end

    --make the particles stop rendering and stop them.
    jitsu.onDeath = function (self)
        local deathFunction = function (particle)
            particle.heading = 0
            particle.movementSpeed = 0
            particle.visible = false
            particle.imageSpin = 0
            particle.rotation = 0
        end
        iterateParticles(self, deathFunction)
    end

    --make the things show up again
    jitsu.onClone = function (self)
        local cloneFunction = function (particle)
            particle.visible = true
        end
        iterateParticles(self, cloneFunction)
        self.isDying = false
        self:snapFeet()
    end

    ---Returns the direction this crew should face as a BRIGHTNESS ANGLE
    ---@return number the angle the crew is travelling in degrees, 0 being straight up.
    jitsu.calculateDesiredFacingAngle = function(self)
        local bodyParticle = self[PART_FILE_NAMES[PART_BODY]]
        --print("calc angle")
        local crew = self.baseCrewWrapper:get()
        if lwl.goalExists(crew:GetFinalGoal()) then
            --First, see if we're way off base.  Uh this is throwing errors.  Rotate to face the general direction.
            self.immediateHeading = lwl.getAngle(crew:GetPosition(), crew:GetNextGoal())
            local immediateHeadingBrightness = lwl.angleFtlToBrightness(self.immediateHeading)
            self.overallHeading = lwl.getAngle(crew:GetPosition(), crew:GetFinalGoal())
            local overallHeadingBrightness = lwl.angleFtlToBrightness(self.overallHeading)
            self.facingDistance = lwl.angleDistanceDegrees(bodyParticle.rotation, overallHeadingBrightness) --body heading
            if self.facingDistance > 90 then
                return overallHeadingBrightness
            end

            --If we are generally pointed the right direction, do some finer navigation.
            return immediateHeadingBrightness
        else
            --We want to rotate in combat or manning systems or fighting fires.
            if crew.bActiveManning or crew:RepairingFire() then
                return lwl.angleFtlToBrightness(lwl.animationDirectionToFtlAngle(crew.crewAnim.direction))
            end
            --Standing still, don't rotate
            return bodyParticle.rotation
        end
    end

    ---comment
    jitsu.adjustFacingDirection = function(self)
        local desiredDirection = self:calculateDesiredFacingAngle()
        local crew = self.baseCrewWrapper:get()
        --print("Desired Direction:", desiredDirection, "facing", mBodyParticle.rotation)
        
        for partType=1,#PART_FILE_NAMES do
            local partTypeName = PART_FILE_NAMES[partType]
            if #PART_INFO_LIST[partType].subunits > 0 then
                --for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
                    if lwl.isMoving(crew) then
                        adjustParticleDirection(self.activeFootParticle, desiredDirection)
                    end
                --end
            else
                adjustParticleDirection(self[partTypeName], desiredDirection)
            end
        end
    end
    
    jitsu.getNextFoot = function(self)
        if not self.activeFootIndex then
            self.activeFootIndex = LEFT_FOOT_INDEX
        else
            self.activeFootIndex = (1 - (self.activeFootIndex - INDEXING_OFFSET)) + INDEXING_OFFSET
            --print("checking feet", self.activeFootParticle, self[leftFootName()], self.activeFootIndex)
        end
        self.activeFootParticle = self[getFootName(self.activeFootIndex)]
        return self.activeFootParticle
    end

    jitsu.getActiveFootPosition = function(self)
        return self.activeFootParticle.position
    end

    --Must not be called when stationary/goal does not exist, or before feet are set.
    jitsu.getFootGoal = function(self)
        local crew = self.baseCrewWrapper:get()
        ---get a point that is STEP_DISTANCE away from self in the direction of the current movement.
        local crewPos = crew:GetPosition()
        local straightFootGoal = lwl.getPoint(crewPos, self.immediateHeading, STEP_DISTANCE)
        local headingAdjustment = (math.pi / 2) - math.pi * (self.activeFootIndex - 1)
        self.footGoal = lwl.getPoint(straightFootGoal, self.immediateHeading + headingAdjustment, FOOT_OFFSET)
        self.footStart = lwl.deepCopyTable(self.activeFootParticle.position)
        local footGoalOriginalDistance = lwl.getDistance(self.footStart, self.footGoal)
        self.footGoalDirection = lwl.getAngle(self.footStart, self.footGoal)
        local bodyGoalOriginalDistance = STEP_DISTANCE / FOOT_FORWARD_FACTOR--todo do I need these?
        self.footGoalDistanceRatio = footGoalOriginalDistance / bodyGoalOriginalDistance
        self.bodyGoal = lwl.getPoint(crewPos, self.immediateHeading, bodyGoalOriginalDistance)
        self.bodyStart = crewPos
        return self.footGoal --idk about this return
    end

    jitsu.swapFeet = function(self)
        self.activeFootParticle = self:getNextFoot()
        self:getFootGoal() --todo rename?
    end

    --todo make a menu state broadcaster instead of this terrible ugly cludgy crewwrapper .
    
    ---comment
    ---Ok, what we do is track the current desired position.  Then we do some trig? to get approx? where the feet should go if they move 2x the speed of the main body.
    ---But remember, speed doesn't matter, only position.
    ---Ok, this version has introduced a new bug that crashes when you tab away and tab back.  That's pretty bad.
    jitsu.advanceFeet = function(self)--todo send feet to back
        local crew = self.baseCrewWrapper:get()
        if lwl.goalExists(crew:GetFinalGoal()) then
            --Assume left starts active, then swap if needed.
            --Move active foot 2x speed along path.
            --Getting the movement vector is easy.  Getting the speed is less so.
            local shouldSwap = false
            if lwl.pointFuzzyEquals(self:getActiveFootPosition(), self.footGoal) then
                print("foot goal reached", self.activeFootIndex)
                shouldSwap = true
            end
            local nextGoal = crew:GetNextGoal()
            if (not self.nextGoal) or (not lwl.pointFuzzyEquals(nextGoal, self.nextGoal)) then
                print("next goal changed", nextGoal.x, nextGoal.y)
                shouldSwap = true
                self.nextGoal = nextGoal
            end
            local bodyDistance = lwl.getDistance(crew:GetPosition(), self.bodyGoal)
            if bodyDistance < 1 then
                shouldSwap = true
            end

            if shouldSwap then
                self:swapFeet()
                bodyDistance = lwl.getDistance(crew:GetPosition(), self.bodyGoal)
            end

            local footDistance = bodyDistance * self.footGoalDistanceRatio
            --print("Moving foot ", bodyDistance, footDistance, self.footGoalDistanceRatio)
            --todo the hard part is getting the initial position to line up with where it landed last time.
            --totp um actually, just draw a line based on the place the foot started and the place the foot is going
            --it's not hard to math.
            self.activeFootParticle.position = lwl.getPoint(self.footGoal, self.footGoalDirection + math.pi, footDistance)
        end
    end

    jitsu.onFrame = function(self, ship)
        --for all particles
        --if it doesn't have subparticles, snap it to yourself.
        local crew = self.baseCrewWrapper:get()
        if (not (crew.currentShipId == ship.iShipId)) or (self.isDying or crew.bDead) then return end

        --render selection state
        local position = crew:GetPosition()
        local color
        if (crew.selectionState == 0) then--not selected, do nothing
            color = HIGHLIGHT_YELLOW
        elseif (crew.selectionState == 1) then --selected, relative green fill
            color = HIGHLIGHT_GREEN
        elseif (crew.selectionState == 2) then --hover, green edges
            color = HOVER_GREEN
        end
        Graphics.CSurface.GL_DrawCircle(position.x, position.y, SELECT_CIRCLE_RADIUS, color)

        if crew.bDead then return end --don't try to render crew that's not on screen.
        if not crew.crewAnim.sub_direction == crew.crewAnim.moveDirection then
            print("directions differed!", crew.crewAnim.sub_direction, crew.crewAnim.moveDirection)
        end
        for partType=1,#PART_FILE_NAMES do
            local partTypeName = PART_FILE_NAMES[partType]
            if #PART_INFO_LIST[partType].subunits > 0 then
                for _,subunitName in ipairs(PART_INFO_LIST[partType].subunits) do
                    self[partTypeName..subunitName].space = crew.currentShipId
                end
            else
                -- print("wow this printed4 current", crew.currentShipId)
                -- print("wow this printed4 i", crew.iShipId)
                -- print("wow this printed4 pos", crew:GetPosition())
                self[partTypeName].position = crew:GetPosition() ---god this is undefined behavior bugs. rippy.
                self[partTypeName].space = crew.currentShipId
            end
        end

        if not (crew:GetNextGoal() == nil) then
            self:adjustFacingDirection()
            self:advanceFeet()
            -- print("stepping start", lwl.dumpObject(self.footStart), "goal", lwl.dumpObject(self.footGoal),
            -- "left foot", lwl.dumpObject(self[leftFootName()]), "right foot", lwl.dumpObject(self[rightFootName()]))
            --mNextLocationParticle.position = lwl.setIfNil(crewmem:GetNextGoal(), crewmem:GetPosition())
        
        end
    end

    ---Start all parts at the lowest level if not already set.
    for i,partTypeName in ipairs(PART_FILE_NAMES) do
        local partModelIndex = jitsu:initVar(partTypeName, 1)
        jitsu:equipPart(i, partModelIndex)
    end
    
    jitsu.immediateHeading = 0
    jitsu:snapFeet()
    jitsu:swapFeet()
    Brightness.send_to_front(jitsu[PART_FILE_NAMES[PART_BODY]])
    Brightness.send_to_front(jitsu[PART_FILE_NAMES[PART_BOMB]])
    Brightness.send_to_front(jitsu[PART_FILE_NAMES[PART_GUN]])
    Brightness.send_to_front(jitsu[PART_FILE_NAMES[PART_POD]])
    Brightness.send_to_front(jitsu[PART_FILE_NAMES[PART_HEAD]])

    local BAD_VALUE = 50085

    local crewFilterFunction = lwl.generateCrewFilterFunction(crewmem)
    --NOTE: Values of parts may be empty, and 
    local healthFunction = function()
        local body = jitsu:getCurrentPart(PART_BODY)
        if body.health == nil then error("Body health was nil!"..lwl.dumpObject(body)) end
        return body.health
    end
    local stunFunction = function()
        local body = jitsu:getCurrentPart(PART_BODY)
        local head = jitsu:getCurrentPart(PART_HEAD)
        return lwl.setIfNil(body.stunResist, 1) * lwl.setIfNil(head.stunResist, 1)
    end
    local moveSpeedFunction = function()
        local part = jitsu:getCurrentPart(PART_LEGS)
        if part.movementSpeed == nil then error("Leg move speed was nil!"..lwl.dumpObject(part)) end
        return part.movementSpeed
    end
    -- local healthFunction = function()
    --     local body = jitsu:getCurrentPart(PART_BODY)
    --     return body.health
    -- end

    --todo this is where all the stuff happens that I control with parts
    
    lwsb.addStatBoost(Hyperspace.CrewStat.MAX_HEALTH, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, healthFunction, crewFilterFunction)
    lwsb.addStatBoost(Hyperspace.CrewStat.STUN_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, stunFunction, crewFilterFunction)
    lwsb.addStatBoost(Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.REPAIR_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.RANGED_DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DOOR_DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.FIRE_REPAIR_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.SUFFOCATION_MODIFIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.FIRE_DAMAGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.OXYGEN_CHANGE_SPEED, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DAMAGE_TAKEN_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CLONE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.PASSIVE_HEAL_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.TRUE_PASSIVE_HEAL_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.TRUE_HEAL_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.PASSIVE_HEAL_DELAY, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.ACTIVE_HEAL_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.SABOTAGE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.ALL_DAMAGE_TAKEN_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.HEAL_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.HEAL_CREW_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DAMAGE_ENEMIES_AMOUNT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.BONUS_POWER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_DRAIN,  lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.ESSENTIAL, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_FIGHT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_REPAIR, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_SABOTAGE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    --weird head thing that means you can't man systems.  Hyperspecific war head.
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_MAN, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_TELEPORT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_SUFFOCATE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CONTROLLABLE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_BURN, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.IS_TELEPATHIC, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.RESISTS_MIND_CONTROL, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.IS_ANAEROBIC, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_PHASE_THROUGH_DOORS, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DETECTS_LIFEFORMS, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CLONE_LOSE_SKILLS, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_DRAIN_FRIENDLY, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DEFAULT_SKILL_LEVEL, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_RECHARGE_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.HACK_DOORS, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.NO_CLONE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.NO_SLOT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.NO_AI, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.VALID_TARGET, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    --Several legs things
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CAN_MOVE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.TELEPORT_MOVE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.TELEPORT_MOVE_OTHER_SHIP, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.SILENCED, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
        --Head can give immunity
    -- lwsb.addStatBoost(Hyperspace.CrewStat.LOW_HEALTH_THRESHOLD, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.NO_WARNING, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.CREW_SLOTS, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.ACTIVATE_WHEN_READY, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.STAT_BOOST, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.DEATH_EFFECT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_EFFECT, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_MAX_CHARGES, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_CHARGES_PER_JUMP, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.POWER_COOLDOWN, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    -- lwsb.addStatBoost(Hyperspace.CrewStat.TRANSFORM_RACE, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, moveSpeedFunction, crewFilterFunction)
    return jitsu
end

-- local function equipGun(self, index)
--     self:equipPart(GUNS, index)
-- end




---------------------------------------------------------

local function onDeathAnim(crewmem)
    if crewmem:GetSpecies() == SPECIES_JITSU then
        for _,jitsu in ipairs(mJitsuList) do
            if jitsu.baseCrewWrapper:get().extend.selfId == crewmem.extend.selfId then
                jitsu:onDeathAnim()
                return
            end
        end
    end
end
local function onDeath(crewmem)
    if crewmem:GetSpecies() == SPECIES_JITSU then
        for _,jitsu in ipairs(mJitsuList) do
            if jitsu.baseCrewWrapper:get().extend.selfId == crewmem.extend.selfId then
                jitsu:onDeath()
                return
            end
        end
    end
end
local function onClone(crewmem)
    if crewmem:GetSpecies() == SPECIES_JITSU then
        for _,jitsu in ipairs(mJitsuList) do
            if jitsu.baseCrewWrapper:get().extend.selfId == crewmem.extend.selfId then
                jitsu:onClone()
                return
            end
        end
    end
end
lweb.registerDeathAnimationListener(onDeathAnim)
lweb.registerDeathListener(onDeath)
lweb.registerClonedListener(onClone)

local function renderJitsus(ship)
    for _,jitsu in ipairs(mJitsuList) do
        jitsu:onFrame(ship)
    end
end

local function generateCrewMatchFilter(crewId)
    return function(table, i)
        return table[i].baseCrewWrapper:get().extend.selfId == crewId
    end
end

local function jitsuOnRemove(jitsu)
    jitsu:destroySelf()
end

--All the jitsus, both sides.
local function jitsuFilter(crewmem)
    return crewmem:GetSpecies() == SPECIES_JITSU
end

script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    --This doesn't actually render anything, but does compute that should happen during a render.
    if lwl.isPaused() then return end
    --todo maybe scale for framerate.
    renderJitsus(ship)
end)

script.on_internal_event(Defines.InternalEvents.ON_TICK, function()
    if not mJitsuObserver then
        mJitsuObserver = lwcco.createCrewChangeObserver(jitsuFilter)
    end
    if not mJitsuObserver.isInitialized() then return end
    
    --todo put stuff that should happen while paused here.
    if lwl.isPaused() then return end
    mScaledLocalTime = mScaledLocalTime + (Hyperspace.FPS.SpeedFactor * 16 / 10) --todo make timing classes for onTick that calls functions registered to it based on time elapsed.
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

script.on_init(function(newGame)
    print("Loaded, is new game?", newGame)
end)
--when swapping parts, make sure to carry over attributes of particles that get set.  position, facing, visibility, etc.


-----------------------------------------------------------


--[[
This crashes when you quit to menu and try to continue.  I think because the brightness particles get destroyed or something?
I don't have this issue with gexpy, or at least not since I last checked.
It's likely the brightness particles that I have lying around which I expect to be there and aren't.
Time to comment out large blocks of code and see what happens.

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