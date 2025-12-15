











--[[

A board is a 2d array of nodes.  Each node has lots of attributes, the most important of which is its type, used for finding matches.
A [match] is a continious group of at least three nodes.

Functions should probably have some kind of wait function to let the animations catch up with them.
Either that, or they queue up animations as they run, so the brain can be ahead of the visuals.  That's definitely way better, and how others do it.



The board should always know what possible matches exist.  It will select one of them as the suggested move.  If none exist, the board must be shuffled until one does.
Shuffling the board involves taking all nodes, putting them in an array, and then making a new board from random selections from it.  This is the last thing that happens before a player's turn starts.
You don't actually have to put them in an array if you do a bit of math first, but you do have to not overwrite things.
Nodes can have shield, which takes a hit for a node during one match.
They can also be durable, which means they cannot be destroyed by match, instead changing to another random type.

 

Manual abort:
This is a feature that lets you clear the stack.  In the return of each function, it checks if it should abort.
]]
local lwl = {}
--7x7
local ownBoard = {rows=7, columns=7}
local exampleNode = {above=nil, below=nil, left=nil, right=nil, type="colorless"}


local MINIMUM_MATCH_LENGTH = 3
--This can swap any two nodes, and does not assume they are adjacent.
local DIRECTION_UP = "above"
local DIRECTION_DOWN = "below"
local DIRECTION_LEFT = "left"
local DIRECTION_RIGHT = "right"
local DIRECTIONS = {DIRECTION_UP, DIRECTION_LEFT, DIRECTION_DOWN, DIRECTION_RIGHT}

local function inverseDirection(direction)
    
end

local function refillBoard()
    --Each row drops down as far as it can.
end

local checkMatchesVertical
local checkMatchesHorizontal
--This would be such a pain without multiple returns.
--[[
Needs to return both the total matched nodes as well as the current straight of nodes.

I think this fails at the corner of a 3x3.

collect all nodes in a line.
Check how many there are
Fire off perpendicular checks on each of them.

Returns the list of matching nodes: empty set if no match.


Right, because beyond just "if there's a match in the whole section", we also need to mark whether each node is part of a vertical or horizontal match.


Really, what I want to do is define a system with symmetry 2 and show what kinds of symmetries the system should have and have the computer make the right kind of
algorithms for traversing such a space.

Like, I define the mathimatical properties of the space and the algorithm I want to traverse over it, and the computer does this.
Basically, horizontal and vertical should be things that the comptuer can generate given the defintions of what I'm describing to it.
And then we should abstract these properties into things like "2D-board", 3D-continious space, different kinds of spaces and structures that we want to work over.
This is good for algorithms.


"I have some properties I want a language to have.  I was writing an algorithm to traverse a 2D board and I ended up writing a vertical and horizontal part with recursive calls.  I realized that what I would really like is a way to describe the mathimatical space that I'm working in, and let the computer generate the algorithm for how this works, likely with a lookup table of some kind for how to do things like this."

]]

local HORIZONTAL_DIRECTIONS = {DIRECTION_RIGHT, DIRECTION_LEFT, name=direction_horizontal}
local VERTICAL_DIRECTIONS = {DIRECTION_DOWN, DIRECTION_UP, name=direction_vertical}

local function getOtherAxis(axis)
    if axis == HORIZONTAL_DIRECTIONS then
        return VERTICAL_DIRECTIONS
    end
    if axis == VERTICAL_DIRECTIONS then
        return HORIZONTAL_DIRECTIONS
    end
    error("Unexpected axis "..axis)
end

--simple function, expects nodes are in a line.
local function detectMatch(nodes)
    return #nodes >= 3
end

local function getNeighbor(currentNode, direction)

end

---Returns all nodes of the sane type in a contigious vertical line with this one
---@param currentNode table|node
---@return table list of nodes in a vertical line
local function collectNodes(currentNode, axis)
    local matchingNodes = {currentNode}

    currentNode[axis.name] = true --means it was checked on this axis (todo get the better word for this alignment).
    if currentNode[axis[1]] then
         matchingNodes = lwl.setMerge(matchingNodes, collectNodes(currentNode.above))
    end
    if currentNode[axis[2]] then
        matchingNodes = lwl.setMerge(matchingNodes, collectNodes(currentNode.below))
    end

    return matchingNodes
end

---Collect all nodes in a line, mark then as checked, and fire off parallel checks for each of them.
---@param currentNode any
---@return table
local checkMatchesAxis = function(currentNode, axis)
    if currentNode[axis.name] then
        return {}
    end

    local matchFound = false
    local allMatchedNodes = {}
    local matchingParallelNodes = collectNodes(currentNode, axis)
    matchFound = detectMatch(matchingParallelNodes) or matchFound
    allMatchedNodes = lwl.setMerge(allMatchedNodes, matchingParallelNodes)

    for node in matchingParallelNodes do
        local matchingPerpendicularNodes = checkMatchesAxis(node, getOtherAxis(axis))
        local currentPerpendicularMatch = detectMatch(matchingPerpendicularNodes)
        if currentPerpendicularMatch then
            allMatchedNodes = lwl.setMerge(allMatchedNodes, matchingPerpendicularNodes)
        end
        matchFound = currentPerpendicularMatch or matchFound
    end
    
    if matchFound then
        return allMatchedNodes
    else
        return {}
    end
end

--The last node will always be the first node.
local function checkMatches(changedNodes)
    if not changedNodes then changedNodes = ownBoard.allNodes() end
    for node in ipairs(changedNodes) do
        --Find connected blocks of matching type nodes, each of which lie within a line of at least three such nodes.
        --I should be able to do this recursively.
        --For each direction, save the one that this call came from, check for matching nodes. Return the direction you came from and the list of matching nodes in that direction.
        --Once this number hits 3, mark all nodes in that direction as matching. On further hits, mark only the current node.
        --We never mark things as not matching, only matching.  We may mark things as matching multiple times.

    end
    --reset the markings on all nodes.
end

local function swapNodes(node1, node2)
    local placeholder = {above=node1.above, below=node1.above, left=node1.above, right=node1.above}
    node1.above = node2.above
    node1.below = node2.below
    node1.left = node2.left
    node1.right = node2.right
    node2.above = placeholder.above
    node2.below = placeholder.below
    node2.left = placeholder.left
    node2.right = placeholder.right
    checkMatches({node1, node2})
end


local function initBoard(board)
    
end



---The use of OO isn't inheritance, it's objects as containers for information.
---Then you get to do more complex things by passing around these data structures.









