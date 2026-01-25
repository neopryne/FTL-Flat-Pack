local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.multiverse.get_room_at_location
local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lwsb = mods.lightweight_statboosts
local lwst = mods.lightweight_stable_time

if not mods.nightfall then
    mods.nightfall = {}
end
mods.nightfall.program = {}
local np = mods.nightfall.program

---TODO renaming this to program
local TABLE_NAME_HACK = "mods.nightfall.hack_2.0"
local VERY_SMALL_NUMBER = .000001 --todo move this to crew definition.
local TURBO_SPEED = 999999

local CHILD_KEY = ""

local PROGRAM_PARENT_NAMES = {"nightfall_hack2_0"}

--Used to load the correct properties for a crew.  This table can also include if this is a parent or a child.
local raceToDefinitionTable = {nightfall_hack2_0 = {}, nightfall_hack2_0_child = {}}
--Uh, I'm actually not sure that children need a definition.

local mSavedPrograms = lwl.CreatePlayerVariableInterface(name)
local mProgramList = {}

--it might be more efficienct to register no filter and filter on this side.
local function programFilterFunction(crewmem)
    for _,name in ipairs(PROGRAM_PARENT_NAMES) do
        if crewmem:GetSpecies() == name then
            return true
        end
    end
    return false
end

local mProgramObserver = lwcco.createCrewChangeObserver(programFilterFunction)


local function nearestCardinalAngle(angle)
    local index = lwl.round(angle / (math.pi / 2)) % 4
    return index * (math.pi / 2)
end

local function getTeleportLocation(crewmem)
    local crewPos = crewmem:GetPosition()
    local shipManager = Hyperspace.ships(crewmem.currentShipId)
    local immediateHeading = lwl.getAngle(crewPos, crewmem:GetNextGoal())
    local snappedAngle = nearestCardinalAngle(immediateHeading)
    local currentRoom = get_room_at_location(shipManager, crewPos, true)
    local currentSlot = lwl.slotIdAtPoint(crewPos, shipManager)
    local currentSlotCenter = lwl.slotCenter(crewmem.currentShipId, currentRoom, currentSlot)

    --Snap to nearest 90* angle
    --Return the center of the tile #TILE_SIZE above you
    return lwl.getPoint(currentSlotCenter, snappedAngle, lwl.TILE_SIZE())
end

local function getMissingHealth(crewmem)
    return crewmem.health.second - crewmem.health.first
end

local function damageWithOverflow(crewmem, damageAmount)
    local overspillDamage = crewmem.health.first - damageAmount
    crewmem.health.first = overspillDamage
    return math.min(0, overspillDamage)
end

--[[
hack: {child=hackChild, maxSize=4, name=swag}
hackChild {name=}
program definition: {self, child}
]]

---Exactly one of programDefinition or parent should be defined.  If both are present, the programDefinition will be ignored.
---@param crewmem any
---@param programDefinition table|nil {name=string}
---@param parent table|nil
---@return table
np.createProgram = function(crewmem, programDefinition, parent)
    local program = {}

    local function initSelf(index)
        program.index = index
    end

    --todo actually you could make a map from crewmem's race to the definitions, and that's probably better.
    if parent then
        --set from parent
        local childDef = parent.childDefinition
        initSelf(parent.index + 1)
    elseif programDefinition then
        program.maxSize = programDefinition.maxSize
        program.moveEvery = programDefinition.moveEvery
        --set from definition/defaults
    else
        error("One of programDefinition or parent must not be nil!")
    end

    program.realCrew = crewmem
    program.index = 0 --tlp is zero
    local longName = "nightfall_"..program.realCrew.extend.selfId
    --parent only values
    program.maxSize = 3 --only parents have this
    program.moveEvery = 170
    program.childDefinition = {}
    --end parent only values
    program.immediateChild = nil
    program.topLevelParent = nil --Parent has no parent.
    program.moveTimer = 0
    program.teleportLocation = nil
    program.speedBoostId = nil

    function program.loadChild(underlyingCrew)
        program.immediateChild = np.createProgram(underlyingCrew, nil, program)
    end

    function program.spawnChild(point)
        assert(not program.immediateChild)
        local shipManager = Hyperspace.ships(program.realCrew.currentShipId)
        local childDef = program.childDefinition
        local isIntruder = not (shipManager.iShipId == program.realCrew.iShipId)
        local roomId = lwl.getRoomAtLocation(point)
        local newCrew = shipManager:AddCrewMemberFromString(
            childDef.friendlyName, childDef.raceName, isIntruder, roomId, true, false) --todo what does the init argument do?
        program.immediateChild = np.createProgram(newCrew, nil, program)
    end

    function program.getTopLevelProperty(propertyName)
        if program.topLevelParent then
            return program.topLevelParent.getTopLevelProperty(propertyName)
        else
            return program[propertyName]
        end
    end

    function program.isParent() --Parents have no parents.
        return not program.topLevelParent
    end

    --TODO put in onTick.
    function program.destroySelf()
        if program.topLevelParent then
            --remove child
            mSavedPrograms.setVariable(program.realCrew.extend.selfId, )
        else
            --remove parent
            mSavedPrograms.setVariable()
        end
        if program.immediateChild then
            program.immediateChild.destroySelf()
        end
    end

    function program.getMaxSize()
        program.getTopLevelProperty("maxSize")
    end
    ---Actually, a program only needs to know the next child in line, doesn't it?
    ---Well, I guess it needs to know the total size, to prevent spawning new forks forever
    ---But that's fine, each node just needs to know which one it is in the line, and the total size this program can be.
    ---This does mean that 
    function program.doctor(damage)
        ---Transfer all damage to the last node
        ---When children die, they have a listener registered that removes them from their parent.
        ---Children are noclone, noslot crew. They have no gexpy slots.  They are immune to crew loss events.
        local totalDamage = damage + getMissingHealth(program.realCrew)
        if program.immediateChild then
            local overspillDamage = program.immediateChild.doctor(totalDamage)
            return damageWithOverflow(program.realCrew, overspillDamage)
        else
            --Apply damage to self and send any excess back up the ladder.
            return damageWithOverflow(program.realCrew, totalDamage)
        end
    end

    function program.Movement()
        if program.moveTimer == 0 then
            --teleport if the unit (still) has a destination.
            program.moveTimer = program.moveTimer + program.realCrew:GetMoveSpeedMultiplier() --so this actually does something.  Tully screws this up good.
            lwsb.removeStatBoostAllowNil(program.speedBoostId)
            if lwl.isMoving(program.realCrew) and program.teleportLocation then
                --todo teleport all children also
                program.realCrew:SetPosition(program.teleportLocation)
                program.teleportLocation = nil
                if program.immediateChild then
                    program.immediateChild.Movement()
                else --no child
                    --todo 
                    if program.getMaxSize() > (program.index + 1) then
                        --spawn new child
                    end
                end
            end
            --Set the speed to near zero.
        elseif program.moveTimer == program.moveEvery then
            --Set move speed high, mark target location
            program.moveTimer = 0
            program.speedBoostId = lwsb.addStatBoost(Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, lwsb.ACTION_SET, TURBO_SPEED, lwl.generateCrewFilterFunction(program.realCrew))
            program.teleportLocation = getTeleportLocation(program.realCrew)
            --TODO boost and set tele locations for children.
        else
            program.moveTimer = program.moveTimer + 1
        end
    end


    --only parents should call their doctor/move methods then chain through children.
    if (program.isParent()) then
        lwst.registerOnTick(program.getLongName(), function ()
            program.Movement()--todo args
            program.doctor(0)
        end, false)
    end


    mSavedPrograms.createObject(program.realCrew.extend.selfId)
    return program
end



--todo pull this into an interface for any kind of crew that needs lua bindings.  I'm going to make more of them at any rate.
local function onTick() --make another one if I need things while paused.
    if not mJitsuObserver.isInitialized() then return end
    
    for _,crewId in ipairs(mProgramObserver.getAddedCrew()) do
        --todo should I load from saved values or stock definition?
        mProgramList[crewId] = np.createProgram(lwl.getCrewById(crewId), 0, 0)
    end
    for _,crewId in ipairs(mProgramObserver.getRemovedCrew()) do
        local removedCrew = mProgramList[crewId]
        mProgramList[crewId] = nil
        removedCrew.destroySelf()
    end
    mProgramObserver.saveLastSeenState()
end
lwst.registerOnTick("nightfall_crew_watch", onTick, false)


---actually, how do thee get linked in the first place?  like when I spawn a crew, what knows to create this?
---When you get a new program on your ship, how does it set itself up?
---CrewChangeObserver I guess, with a filter for all of the parents.
---The parents are responsible for linking all children.
---actually, I can't quite do that.  I need to know that playerVars are loaded by the time the CCO is ready.
--I'm pretty sure they will be.
--God saving and loading state is the worst in this system.
---Because you have to persist to stuff that's not even good.
---Really what I want to do is just have a container variable that I can get/set with, but also updates the background.
---Of course the issue with this is loading properly.  I know this has been solved before.
---Wait that's actually what this stuff is supposed to be.  I already did this,/.
---I should make all children the same, and all they know is that when that spawn in they match their parent's color.  Or something.
---Otherwise I need to make so many.
---
---children need to force deselect themselves each tick
---this is just a crewloop.
---Oh, children get to snap to their slot.  Let me see what that does on a normal crew.
local function loadAndLinkChild(crewId)
    --TODO first load the crew.


    local childId = mSavedPrograms.getVariable(id, CHILD_KEY)
    if childId ~= nil then
        local childCrew = lwl.getCrewById(childId)
        if not childCrew then print("ERROR no kid", childId) return end
        loadAndLinkChild(childId)
    end
end

--Force deselect all children
script.on_internal_event(Defines.InternalEvents_CREW_LOOP, function(crewmem)
    if crewmem:GetSpecies() == "nightfall_child" then
        crewmem.selectionState = 0
    end
end)







