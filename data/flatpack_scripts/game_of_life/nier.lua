--[[
This is a unique crew made of a cluster of game of life objects.  The center of it is constantly replenished in a gaussian distribution.
]]
local lwl = mods.lightweight_lua
local lwcco = mods.lightweight_crew_change_observer
local lwst = mods.lightweight_stable_time


local Life = mods.lims_ships.Life

local NIER_NAME = "gol_nier"

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
    local radius, sigma, strength = 15, 1, 6
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

function Nier:getName()
    return NIER_NAME..self._crewmem.extend.selfId
end

function Nier.new(crewmem)
    local self = setmetatable({}, Nier)
    self._crewmem = crewmem --unique id w/self id.  If crew goes out of memory this will be corrupt, but CCO will destroy it before then.
    local name = self:getName()
    local width, cellSize, refreshRate = 35, 1, 8
    self._board = Life.new(name, self._crewmem.extend.selfId, width, width, cellSize, refreshRate, activateGaussianCircle)
    
    self.onTick = function ()
        self._board:setRenderSpace(self._renderSpace)
        offsetFromCrew(crewmem, self._board)
    end
    lwst.registerOnTick(name, self.onTick, false)
end

function Nier:destroy()
    lwst.registerOnTick(self:getName(), nil, true)
    self._board:destroy()
end

--it might be more efficienct to register no filter and filter on this side.
local function NierFilterFunction(crewmem)
    return crewmem:GetSpecies() == NIER_NAME
end

local mNierObserver = lwcco.createCrewChangeObserver(NierFilterFunction)
local mActiveNiers = {}


--todo pull this into an interface for any kind of crew that needs lua bindings.  I'm going to make more of them at any rate.
local function onTick() --make another one if I need things while paused.
    if not mNierObserver.isInitialized() then return end
    
    for _,crewId in ipairs(mNierObserver.getAddedCrew()) do
        --todo should I load from saved values or stock definition?
        mActiveNiers[crewId] = Nier.new(lwl.getCrewById(crewId))
    end
    for _,crewId in ipairs(mNierObserver.getRemovedCrew()) do
        local removedCrew = mActiveNiers[crewId]
        mActiveNiers[crewId] = nil
        removedCrew.destroySelf()
    end
    mNierObserver.saveLastSeenState()
end
lwst.registerOnTick("nier_life_xp", onTick, false)

--todo each nier must track its own 