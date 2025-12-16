











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

local TYPE_COLORLESS = "colorless"

--7x7
local ownBoard = {rows=7, columns=7}
local exampleNode = {type=TYPE_COLORLESS}


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


Then there's the whole animation stack that tracks what items we haven't animated yet that we need to.
Part of future predictions is building the animation stack for if those happen, and keeping that seperate from the main environment.
Actually, I think that says a lot about what these things need to be.  They should be closures that basically have a copy of everything in the current environment.
That seems like something that it's hard to do with most programming languages, but I really need that feature.
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

local function isTypeMatch(node1, node2)
    return node1.type == node2.type
end

--simple function, expects nodes are in a line.
local function detectMatch(nodes)
    return #nodes >= 3
end



local function getNode(board, i, j)
    if i > board.columns or i < 1 or j > board.rows or j < 1 then
        return nil --todo maybe don't use nil for empty.
    end
    return board.nodes[i][j]
end

local function newNode(board, i, j, type)
    local node = {type=type, board=board, i=i, j=j, durability=0,
    above = function(self)
        return getNode(self.board, self.i, self.j+1)
    end, below = function(self)
        return getNode(self.board, self.i, self.j-1)
    end, left = function(self)
        return getNode(self.board, self.i-1, self.j)
    end, right = function(self)
        return getNode(self.board, self.i+1, self.j)
    end}
    return node
end


---Returns all nodes of the same type in a contigious vertical line with this one
---@param currentNode table|node
---@return table list of nodes in a vertical line
local function collectNodes(currentNode, axis)
    local matchingNodes = {currentNode}

    currentNode[axis.name] = true --means it was checked on this axis (todo get the better word for this alignment).
    for _,direction in ipairs(axis) do
        local nextNode = currentNode[direction]()
        if nextNode and (not nextNode[axis.name]) and isTypeMatch(currentNode, nextNode) then
            matchingNodes = lwl.setMerge(matchingNodes, collectNodes(nextNode))
        end
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

    for _,node in ipairs(matchingParallelNodes) do
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

--todo this should probably return a list of animations to happen, somehow?
local function shiftDownInternal(node, quantity)
    --todo this needs to leave nodes alone if they have more than one durability.
    local above = node.above()
    if above == nil then
        --We've reached the top of the board, refill the next QUANTITY nodes with new fodder from the top of the board.
    else
        if node.durability > 1 then
            node.durability = node.durability - 1
            --trigger animation todo
        else
            --trigger animation todo
            shiftDownInternal(above, quantity)
        end
    end
end

local function shiftDown(node)
    shiftDownInternal(node, 0)
end


---comment
---@param matchedNodes table
---@param fromSwap any
local function handleMatch(matchedNodes, fromSwap)
--destroy the nodes, give mana, whatever else.
    ---Destroying nodes is actually pretty involved.  Let's try to do that.
    --for now we don't care about fromSwap

    ---Sort the nodes into columns,
    ---For each column of nodes
    ---return nothing.
    ---Find the bottom most node
    ---Or, uh, actually
    ---Instead of doing all this, what if I just started from the bottom row and checked every node until I got what I wanted?
    ---That would work but is not cool and smart.
    ---I need a method that is cool and smart.
    ---
    ---Ok, so we need to recognize that if we want to do this node by node that we need to go up the entire chain each time.
    ---But doing this is slow and boring, and ends up with double looking at lots of nodes.
    ---Because of how nodes are set up, I do have to visit each node in each affected column at least once
    ---But in order to not to n^2 steps, we need to only make one pass over each node.
    ---
    ---Eh ok, I'm actually fine with going from all nodes on the board instead of sorting the ones we get.
    ---If I actually want to improve performance, I need to sort those as I add them, and then go from the bottom node of each column.
    ---I think the gains are minimal from this.
    
    if #matchedNodes < 1 then
        print("Warning: called handleMatch with no match.")
        return
    end

    local board = matchedNodes[1].board
    for _,node in ipairs(matchedNodes) do
        node.inMatch = true
    end

    for i=1,board.columns do
        shiftDown(board.nodes[i][1])
    end

    --todo do these nodes still exist?  Reset them if they do.
    for _,node in ipairs(matchedNodes) do
        node.inMatch = nil
    end
end
--We're still operating in the same physical paradigm as the generation before us, and before us, and before us.  Time to move to new metaphysical space.

--The last node will always be the first node.
local function checkMatches(changedNodes)
    if not changedNodes then changedNodes = ownBoard.allNodes() end
    for _,node in ipairs(changedNodes) do
        checkMatchesAxis()
        --Find connected blocks of matching type nodes, each of which lie within a line of at least three such nodes.
        --I should be able to do this recursively.
        --For each direction, save the one that this call came from, check for matching nodes. Return the direction you came from and the list of matching nodes in that direction.
        --Once this number hits 3, mark all nodes in that direction as matching. On further hits, mark only the current node.
        --We never mark things as not matching, only matching.  We may mark things as matching multiple times.

    end
    --reset the markings on all nodes.
end

local function swapNodes(node1, node2)
    if not (node1.board == node2.board) then
        error("Nodes on different boards!")
    end
    local board = node1.board
    --First, swap the board locations.  Then, update the nodes with the locations for their new positions.
    local intermediary = lwl.deepCopyTable(node1)
    local savedNode = node1
    board.nodes[node1.i][node1.j] = node2
    board.nodes[node2.i][node2.j] = intermediary

    node1.i = node2.i
    node1.j = node2.j
    node2.i = intermediary.i
    node2.j = intermediary.j
    checkMatches({node1, node2})
end

--some way to find the set of matches that do things.
--Actually, doing this lets us precalculate all of the results of moves the player could make.

--So we need a way of talking about things that might happen, but haven't happened yet, and how to quickly swap those to being real.
--This system of creating multiple futures to preload and latency-hide is something that I want to make such that I can plop it wherever.
--It requires some kind of turn-based system, or at any rate, user gated behavior that we can reasonably predict all (or just many likely) outcomes of.
--You also need to be able to pick up wherever the simulation left off.
--In my case, I also need a way to rewind back to before a thing happened, because the result of a lot of moves (most moves) is they are invalid and must be rolled back.
---We could consider things like this to be virtual?  Things that are briefly real, but then collapse into unreality due to being impossible.
---We could consider everything to be virtually real, with things just taking different amounts of time before they collapse into unreality due to whatever.
---Sometimes, that's just entropy eroding the meaning until it's unreadable.
---Other times, it's more violent.
---

--todo this likely needs more work
--I could have nodes be the sot for their positions, but this is fragile, as I need to ensure to update them.
--Actually, it's probably less of an issue than I expect, as 
--If you make the rule that you can only swap nodes, not remove them, then this gets much simpler.




---Check the connections between nodes of a board.
---You shouldn't call this.  If this is useful, things are broken.  Don't get there in the first place.
---@param board any
local function checkMesh(board)
    for i=1,board.columns do
        for j=1,board.rows do
            local currentNode = getNode(board, i, j)
            currentNode.left = getNode(board, i-1, j)
            currentNode.right = getNode(board, i+1, j)
            currentNode.above = getNode(board, i, j+1)
            currentNode.below = getNode(board, i, j-1)
        end
    end
end

--todo how to decide which types of nodes to use?
--I want to be able to make boards with whatever configuration I want
--And then also random ones.
local function initBoard(board, typeGenerationFunction)
    local nodeArray = {}
    for i=1,board.columns do
        table.insert(nodeArray, {})
        for j=1,board.rows do
            table.insert(nodeArray[i][j], newNode(board, i, j, typeGenerationFunction(i, j)))
        end
    end
    board.nodes = nodeArray
    return board
end



---The use of OO isn't inheritance, it's objects as containers for information.
---Then you get to do more complex things by passing around these data structures.


--#region Tests
--#region Test Helpers
local function checkResults(actual, expected, message)
    if not (actual == expected) then
        print("Test failed, expected", expected, ", got", actual, message)
    else
        print("Check passed", message)
    end
end

--Makes the entire board one color for the sake of-- something.
local function setAllNodes(board, type)
    
end
--#endregion
local testBoard = initBoard({rows=3, columns=3})
--set all types
setAllNodes(testBoard, TYPE_COLORLESS)
local matchedNodes = checkMatches(testBoard[1][2])
--#endregion






