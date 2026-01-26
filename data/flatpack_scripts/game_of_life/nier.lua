--[[
This is a unique crew made of a cluster of game of life objects.  The center of it is constantly replenished in a gaussian distribution.
]]
local lwl = mods.lightweight_lua
local lwcco = mods.lightweight_crew_change_observer
local lwst = mods.lightweight_stable_time


local Life = mods.lims_ships.Life

local NIER_NAME = "gol_nier"
local TAG = NIER_NAME

--#region utility functions

local function gaussian2D(dx, dy, sigma)
    local r2 = dx*dx + dy*dy
    return math.exp(-r2 / (2 * sigma * sigma))
end

-- Turn on nodes in a circle with Gaussian probability
-- cx, cy     : center in grid coordinates (integer)
-- radius     : hard cutoff radius
-- sigma      : standard deviation of Gaussian
-- strength   : optional multiplier (default 1)
local function activateGaussianCircle(life)
    local radius, sigma, strength = 15, 1, 50
    local r2max = radius * radius
    local cy = lwl.round(life._height / 2)
    local cx = lwl.round(life._width / 2)

    for y = math.max(1, cy - radius), math.min(life._height, cy + radius) do
        for x = math.max(1, cx - radius), math.min(life._width, cx + radius) do
            local cell = life:getCell(x, y)

            if cell:isEnabled() then
                local dx = x - cx
                local dy = y - cy
                local r2 = dx*dx + dy*dy

                if r2 <= r2max then
                    local p = gaussian2D(dx, dy, sigma) * strength
                    if math.random() < p then
                        --print("Forcing alive at", x, y)
                        cell:setAlive(true)
                    end
                end
            end
        end
    end
end

local function offsetFromCrew(crewmem, life)
    local crewPos = crewmem:GetPosition()
    local x = crewPos.x - (life._width / 2)
    local y = crewPos.y - (life._height / 2)
    local offsetPos = Hyperspace.Pointf(x, y)
    for cell in life:cells() do
        cell:updatePosition(offsetPos)
    end
end
--#endregion

local Nier = {}
Nier.__index = Nier

function Nier.new(crewId)
    local self = setmetatable({}, Nier)
    self._crewId = crewId --unique id w/self id.  If crew goes out of memory this will be corrupt, but CCO will destroy it before then.
    local crewmem = lwl.getCrewById(crewId)
    self._name = NIER_NAME..crewmem.extend.selfId
    self._crewname = crewmem:GetName()
    local width, cellSize, refreshRate = 35, 1, 4
    self._board = Life.new(self._name, crewmem.currentShipId, width, width, cellSize, refreshRate, activateGaussianCircle)
    
    self.onTick = function ()
        self._board:setRenderSpace(self._renderSpace)
        local realCrew = lwl.getCrewById(self._crewId)
        if realCrew then
            offsetFromCrew(realCrew, self._board)
        end
    end
    lwst.registerOnTick(self._name, self.onTick, false)
    return self
end

function Nier:destroy()
    lwst.registerOnTick(self._name, nil, true)
    self._board:destroy()
end

--it might be more efficienct to register no filter and filter on this side.
local function NierFilterFunction(crewmem)
    return (crewmem:GetSpecies() == NIER_NAME) and lwl.filterTrueCrewNoDrones(crewmem)
end

local mNierObserver = lwcco.createCrewChangeObserver(NierFilterFunction)
local mActiveNiers = {}
--TODO this pattern isn't enough to track crew that get kicked off the ship.  I also need a death observer or something.
--Really, I need to make a better crew change observer.  Like, this should already be enough to get kicked off the ship.
--It seems to work for CEL, idk why it's not working here.

--[[
jitsu, hack, and nier are all broken.  Omen works, because omen uses userdata_tables.

I need to switch this over to lwui so I can have different colors.

maybe I need to make a generic cco and check after it passes me stuff?  Something like, check race on add, don't check on remove.
No, that's what it is.  I have to filter true crew (not ownship though).  
]]
local mNierNames = {}

--todo pull this into an interface for any kind of crew that needs lua bindings.  I'm going to make more of them at any rate.
local function onTick() --make another one if I need things while paused.
    if not mNierObserver.isInitialized() then return end
    
    for _,crewId in ipairs(mNierObserver.getAddedCrew()) do
        print("Nier adding crew with id", crewId)
        mNierNames[crewId] = lwl.getCrewById(crewId):GetName()
        --todo should I load from saved values or stock definition?
        mActiveNiers[crewId] = Nier.new(crewId)
    end
    for _,crewId in ipairs(mNierObserver.getRemovedCrew()) do
        print("Nier removing crew with id", crewId)
        local removedCrew = mActiveNiers[crewId]
        if not removedCrew then
            local name = ""
            if mNierNames[crewId] then
                name = mNierNames[crewId]
            else
                name = "unknown crew"
            end
            lwl.logError(TAG, "Already removed crew with id "..crewId.." "..name)
        else
            removedCrew:destroy()
        end
        mActiveNiers[crewId] = nil
    end
    mNierObserver.saveLastSeenState()
end
lwst.registerOnTick("nier_life_xp", onTick, false)

--todo each nier must track its own 

-- script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
--     local shipManager = Hyperspace.ships(crewmem.iShipId)
--         if (crewmem:GetSpecies() == "fff_omen") then
--             local crewTable = userdata_table(crewmem, "mods.flatpack.automata")
--             --if not initialized, set up.
--             local nier = lwl.setIfNil(crewTable.nier, Nier.new(crewmem))
--             local rotations = lwl.setIfNil(crewTable.rotations, randomRotation())
--             local beam_render_time = lwl.setIfNil(crewTable.beam_render_time, -1)
--             local omen_power = lwl.setIfNil(crewTable.omen_power, 1)




--             --FINALLY, write back to crewTable
--             crewTable.nier = nier
--         end
--     end)