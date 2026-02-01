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
local TABLE_NAME_NIGHTFALL = "mods.fff.nightfall.saved_programs"
local VERY_SMALL_NUMBER = .000001 --todo move this to crew definition.
local TURBO_SPEED = 999999
local RENDER_LAYER = "SHIP_MANAGER"

local CHILD_KEY = ""

local PROGRAM_PARENT_NAMES = {} --todo replace

--Used to load the correct properties for a crew.  This table can also include if this is a parent or a child.
local raceToDefinitionTable = {nightfall_hack2_0 = {}, nightfall_hack2_0_child = {}}
--Uh, I'm actually not sure that children need a definition.

local mSavedPrograms = lwl.CreatePlayerVariableInterface(TABLE_NAME_NIGHTFALL)
local mProgramList = {}

--it might be more efficienct to register no filter and filter on this side.
local function programFilterFunction(crewmem)
    for _,name in ipairs(PROGRAM_PARENT_NAMES) do
        if crewmem:GetSpecies() == name and lwl.filterTrueCrewNoDrones(crewmem) then
            return true
        end
    end
    return false
end

local mProgramObserver = lwcco.createCrewChangeObserver(programFilterFunction)

--#region utility functions
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
    local newHealth = crewmem.health.first - damageAmount
    crewmem.health.first = newHealth
    return math.min(0, newHealth)
end
--#endregion
--[[
hack: {child=hackChild, maxSize=4, name=swag}
hackChild {name=}
program definition: {self, child}
]]

---
---@param crewmem any
---@param parent table|nil If this is used, the parent's childDefinition... will be used.  
---   Children actually need to use Brightness for their icon, since I don't want to make a million of them.
---@return table
np.createProgram = function(crewmem, parent)
    local program = {}

    local function initSelf(index)
        program.index = index
    end

    local programDefinition
    if parent then
        local childDef = parent.childDefinition
        initSelf(parent.index + 1)
    end

    --todo actually you could make a map from crewmem's race to the definitions, and that's probably better.
    if parent then
        --set from parent
        local childDef = parent.childDefinition
        program.iconParticle = Brightness.create_particle(childDef.iconFolder, 1, 1, crewmem:GetPosition(), 0, crewmem.currentShipId, RENDER_LAYER)
        initSelf(parent.index + 1)
    elseif programDefinition then
        program.maxSize = programDefinition.maxSize
        program.moveEvery = programDefinition.moveEvery
        --set from definition/defaults
    else
        error("One of programDefinition or parent must not be nil!")
    end

    program.crewId = crewmem.extend.crewId
    program.index = 0 --tlp is zero
    local longName = "nightfall_"..program.crewId
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

    ---load child from crewmember.
    ---@param underlyingCrew Hyperspace.CrewMember
    function program.loadChild(underlyingCrew)
        program.immediateChild = np.createProgram(underlyingCrew, program)
    end

    --Create a new child and underlying crewmember.
    function program.spawnChild(point)
        assert(not program.immediateChild) --todo might be a stronger statement than I want
        local realCrew = lwl.getCrewById(program.crewId)
        if not realCrew then
            lwl.logWarn("Could not spawn child, self crew was nil.")
            return
        end
        
        local shipManager = Hyperspace.ships(program.realCrew.currentShipId)
        local childDef = program.childDefinition
        local isIntruder = not (shipManager.iShipId == program.realCrew.iShipId)
        local roomId = lwl.getRoomAtLocation(point)
        local newCrew = shipManager:AddCrewMemberFromString(
            childDef.friendlyName, childDef.raceName, isIntruder, roomId, true, false) --todo what does the init argument do?
        program.immediateChild = np.createProgram(newCrew, program)
        return program.immediateChild
    end

    function program.getTopLevelProperty(propertyName)
        if program.topLevelParent then
            return program.topLevelParent.getTopLevelProperty(propertyName)
        else
            return program[propertyName]
        end
    end

    function program.getMaxSize()
        program.getTopLevelProperty("maxSize")
    end

    function program.isParent() --Parents have no parents.
        return not program.topLevelParent
    end

    function program.destroySelf()
        if program.isParent() then
            --child self
            mSavedPrograms.setVariable(program.realCrew.extend.selfId, 0)--todo check
            Brightness.destroy_particle(program.iconParticle)
        else
            --parent self
            mSavedPrograms.setVariable()
        end
        if program.immediateChild then
            program.immediateChild.destroySelf()
        end
    end

    function program.allocateDamage(damage)
        ---Transfer all damage to the last node
        ---When children die, they have a listener registered that removes them from their parent.
        ---Children are noclone, noslot crew. They have no gexpy slots.  They are immune to crew loss events.
        if program.immediateChild then
            local totalDamage = damage + getMissingHealth(program.realCrew)
            local overspillDamage = program.immediateChild.allocateDamage(totalDamage)
            return damageWithOverflow(program.realCrew, overspillDamage)
        else
            --Apply damage to self and send any excess back up the ladder.
            return damageWithOverflow(program.realCrew, damage)
        end
    end

    function program.performMove()
        --teleport if the unit (still) has a destination.
        lwsb.removeStatBoostAllowNil(program.speedBoostId)
        if lwl.isMoving(program.realCrew) and program.teleportLocation then
            local previousPosition = program.realCrew:GetPosition()
            program.realCrew:SetPosition(program.teleportLocation)
            program.teleportLocation = nil
            if program.immediateChild then
                program.immediateChild.performMove()
            else
                if program.getMaxSize() > (program.index + 1) then
                    --spawn new child
                    program.spawnChild(previousPosition)
                end
            end
        end
    end

    function program.prepareMove()
        --Set move speed high, mark target location
        program.moveTimer = 0
        program.speedBoostId = lwsb.addStatBoost(Hyperspace.CrewStat.MOVE_SPEED_MULTIPLIER, lwsb.TYPE_NUMERIC, 
                lwsb.ACTION_SET, TURBO_SPEED, lwl.generateCrewFilterFunction(program.realCrew))
        program.teleportLocation = getTeleportLocation(program.realCrew)
        if program.immediateChild then
            program.immediateChild.prepareMove()
        end
    end

    function program.Movement()
        if program.moveTimer == 0 then
            program.performMove()
        end
        program.moveTimer = program.moveTimer + program.realCrew:GetMoveSpeedMultiplier() --Tully screws this up good.
        if program.moveTimer >= program.moveEvery then
            program.prepareMove()
        end
    end


    --only parents should call their allocateDamage/move methods then chain through children.
    if (program.isParent()) then
        lwst.registerOnTick(program.getLongName(), function ()
            program.Movement()--todo args
            program.allocateDamage(0)
        end, false)
    end


    mSavedPrograms.createObject(program.realCrew.extend.selfId)
    return program
end



--todo pull this into an interface for any kind of crew that needs lua bindings.  I'm going to make more of them at any rate.
local function onTick()
    if not mProgramObserver.isInitialized() then return end
    
    for _,crewId in ipairs(mProgramObserver.getAddedCrew()) do
        --todo should I load from saved values or stock definition?
        local crewmem = lwl.getCrewById(crewId)
        if not crewmem then
            lwl.logError("Crew added but not found, id:", crewId)
        else
            mProgramList[crewId] = np.createProgram(crewmem, 0, 0)
        end
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
--A thing that lets you assign crew to downtime duties.  Actually I really like this.
--Things like, collect scrap, craft items, perform repairs, do research on future sectors,
--All of this uses, if installed, the disco stat blocks
--

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







