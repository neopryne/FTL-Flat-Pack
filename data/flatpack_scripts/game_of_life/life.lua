local lwl = mods.lightweight_lua
local lwui = mods.lightweight_user_interface
local lwst = mods.lightweight_stable_time
local Brightness = mods.brightness
local Cell = mods.lims_ships.Cell

--The entire grid of ship space is filled with 35x cells.  Cells that are alive provide a kind of boost.
--[[
They drain health from enemy crew.
The unique crew member of this ship is a smaller (1or2x) game of life, with a central cluster that keeps reviving itself in kind of a normal distribution.
So they end up shooting off bits of themselves.
This, of course, means I have to put those objects in a container.  So the game of life will be objects in a container.
This class will be dedicated to just the code for the life board.

Uses brightness particles for the cells, which makes it easy to change stuff about it.
Internally the state updates based on which cells are enabled + alive.  Disabled cells don't have particles and aren't calculated.
When destroying a Life, first all cells and their particles are destroyed.
]]




--A Cell class with logic to handle the brightness particle rendering it.  The calls to set state on a cell affect the particles in the correct way.
local sNumLife = 0

--todo this uses metatables in a way I'm not used to.
mods.lims_ships.Life = {}
local Life = mods.lims_ships.Life
Life.__index = Life

local TAG = "gol_life"
local KEY_UPDATE = "gol_life_update"
local KEY_RENDER = "gol_life_render"


local NEIGHBOR_OFFSETS = {
    {-1,-1}, {0,-1}, {1,-1},
    {-1, 0},         {1, 0},
    {-1, 1}, {0, 1}, {1, 1}
}

function Life:renderKey()
    return KEY_RENDER..self._id
end

function Life:updateKey()
    return KEY_UPDATE..self._id
end

function Life:getCell(x, y)
    local row = self._cells[y]
    if row then return row[x] end
    lwl.logError(TAG, "Failed to get cell in board", self._name, "at", x, y)
    return nil
end


function Life:setRenderSpace(renderSpace)
    self._currentShipId = renderSpace
    for cell in self:cells() do
        cell:setRenderSpace(renderSpace)
    end
end

-- Enable or disable a specific cell
function Life:setEnabled(x, y, enabled)
    local cell = self:getCell(x,y)
    if cell then
        cell:setEnabled(enabled)
    end
end


function Life:countNeighbors(cell)
    local count = 0
    local cellPosition = cell:getBoardPosition()
    for _, o in ipairs(NEIGHBOR_OFFSETS) do
        local nx, ny = cellPosition.x + o[1], cellPosition.y + o[2]
        local neighborCell = self:getCell(nx, ny)
        if neighborCell and neighborCell:isEnabled() and neighborCell:isAlive() then
            count = count + 1
        end
    end
    return count
end

--Iterates over a grid
function Life:cells()
    local x, y = 0, 1
    local width, height = self._width, self._height

    return function()
        x = x + 1
        if x > width then
            x = 1
            y = y + 1
        end

        return self:getCell(x, y), x, y
    end
end


function Life:tick()
    -- phase 1: compute next state
    for cell in self:cells() do
        if not cell:isEnabled() then
            cell:setNextAlive(false)
        else
            local n = self:countNeighbors(cell)

            if cell:isAlive() then
                cell:setNextAlive(n == 2 or n == 3)
            else
                cell:setNextAlive(n == 3)
            end
        end
    end
    -- phase 2: commit
    for cell in self:cells() do
        cell:commit()
    end
end

--If I'm fancy, I'll make the animations affected by temporal.


-- Create a new Life board
--Things should have names for debugging.
--tickEvery can't be changed after initialization.
--These don't have a position, they are just the data.  Write a wrapper for implmentations that render things.
function Life.new(name, shipId, width, height, cellSize, tickEvery, onTick)

    local self = setmetatable({}, Life)
    self._name = name
    self._currentShipId = shipId
    self._width  = width
    self._height = height
    self._cellSize = cellSize or 1
    self._cells = {}
    self._updatePeriod = tickEvery
    self._internalTimer = 0
    self.update = function()
        self:tick()
        onTick(self)
    end

    for y = 1, height do
        self._cells[y] = {}
        for x = 1, width do
            self._cells[y][x] = Cell.new(x, y, self._cellSize, shipId)
        end
    end

    self._id = sNumLife
    lwst.registerOnTick(self:updateKey(), lwl.createTimerFunction(tickEvery, self.update), false)
    sNumLife = sNumLife + 1

    return self
end

function Life:destroy()
    lwst.registerOnTick(self:updateKey(), nil, false)
    lwst.registerTrueOnTick(self:renderKey(), nil, true)
    for cell in self:cells() do
        cell:setEnabled(false)
    end
    self = nil
end





--[[ Example:

math.randomseed(os.time())

local life = Life.new(100, 60, 1)

-- carve a circular board
for y = 1, 60 do
    for x = 1, 100 do
        local dx = x - 50
        local dy = y - 30
        if dx*dx + dy*dy > 25*25 then
            life:setEnabled(x, y, false)
        end
    end
end

-- seed life
life:activateGaussianCircle(50, 30, 10, 4)

-- step simulation
life:tick()

]]




