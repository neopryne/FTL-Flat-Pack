
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
---The typeGenerationFunction of each board should use some sort of seeded random generator that I can track so I can preserve state across devices.

local MINIMUM_MATCH_LENGTH = 3
--This can swap any two nodes, and does not assume they are adjacent.
local DIRECTION_UP = "above"
local DIRECTION_DOWN = "below"
local DIRECTION_LEFT = "left"
local DIRECTION_RIGHT = "right"
local DIRECTIONS = {DIRECTION_UP, DIRECTION_LEFT, DIRECTION_DOWN, DIRECTION_RIGHT}
local HORIZONTAL_AXIS = {DIRECTION_RIGHT, DIRECTION_LEFT, name=direction_horizontal}
local VERTICAL_AXIS = {DIRECTION_DOWN, DIRECTION_UP, name=direction_vertical}

local TYPE_COLORLESS = "colorless"
local TYPE_LIST = {TYPE_COLORLESS}

local ownBoard = {rows=7, columns=7}
local exampleNode = {types={TYPE_COLORLESS}}


--#region queue data structure
lwl.list = {}
function lwl.list.new()
    return {first = 1, last = 0, size=0}
end
-- queueNode = {next, previous, data}
-- queue = {first, last}


lwl.queue = {}
function lwl.queue.new()
    local queue = lwl.list.new()
    queue.enqueue = function(self, item)
        self.size = self.size + 1
        self.last = self.last + 1
        self[last] = item
    end
    queue.dequeue = function(self)
        if self.size == 0 then return nil end
        self.size = self.size - 1

        local retval = self[self.first]
        self[self.first] = nil
        self.first = self.first + 1

         --Reset values if empty
        if self.size == 0 then
            self.first = 0
            self.last = -1
        end
        return retval
    end
    return queue
end

---Empties append into original, resulting in a single queue with all items from both in order.
---@param original any
---@param append any
local function mergeQueues(original, append)
    while append.size > 0 do
        original:enqueue(append:dequeue())
    end
end
--#endregion


--#region misc functions
local function getOtherAxis(axis)
    if axis == HORIZONTAL_AXIS then
        return VERTICAL_AXIS
    end
    if axis == VERTICAL_AXIS then
        return HORIZONTAL_AXIS
    end
    error("Unexpected axis "..axis)
end

local function compareTypes(type1, type2)
    return type1 == type2
end

local function isTypeMatch(node1, node2)
    local matchFound = false
    for _,type1 in ipairs(node1.types) do
        for _,type2 in ipairs(node2.types) do
            if compareTypes(type1, type2) then
                matchFound = true
            end
        end
    end
    return matchFound
end

--simple function, expects nodes are in a line.
local function detectMatch(nodes)
    return #nodes >= MINIMUM_MATCH_LENGTH
end


local function inverseDirection(direction)
    
end
--#endregion

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

Where is my dorito bird rougelike game?  That's forge, actually, and it's a really cool game.

"I have some properties I want a language to have.  I was writing an algorithm to traverse a 2D board and I ended up writing a vertical and horizontal part with recursive calls.  I realized that what I would really like is a way to describe the mathimatical space that I'm working in, and let the computer generate the algorithm for how this works, likely with a lookup table of some kind for how to do things like this."
The deckbuilding screen is one of the best parts of MTGPQ, but it could still use some work.  For instance, caching searches you expect the user to try.
This can be a silly thing you should not do very easilly.

Then there's the whole animation stack that tracks what items we haven't animated yet that we need to.
Part of future predictions is building the animation stack for if those happen, and keeping that seperate from the main environment.
Actually, I think that says a lot about what these things need to be.  They should be closures that basically have a copy of everything in the current environment.
That seems like something that it's hard to do with most programming languages, but I really need that feature.

I don't have enough built now to make the time system, waiting..
]]

--#region gameController
---Creates a GC, which will set up the board and help players talk to each other.  More of a matchController really, but that doesn't flow as well.
local function gameControllerNew()
    --initBoard
end

--#endregion

--#region Character

--[[
Characters, like other objects, have a long list of configurable properties.
This includes: decks, their level, and any dodads that I might choose to let people put on them
It also includes their abilities that affect the game.
Most characters do not have passive abilities, because those are bs.

{abilities={first={}, second={}, third={}, passive=nil}, images={portait, full}, manaBonuses={}}
]]

--#endregion

--#region player object

local function playerNew(character, gameController)
    
end


--#endregion

--Can't be negative.  To remove mana, do other things.
--Draining mana will mostly be done as a shield that you have to break through, but which decays with some scaling each turn.
--Different characters have different scaling for applying and breaking through mana drain.
---Actually, the main issue I had here was the lack of interction in this model of gameplay.
---There's no way to respond to a card that another player is playing.  I need to do that, with a proper priority system.
---It should be smart about it, knowing the timing restrictions on the cards in your hand that have full mana.
---You can set your spells to autocast if they are able to be cast, and you can do this on a card by card basis, and on a deck-by-deck basis.
---This will override any prompts that the card may have had.
---     There are some other behaviors you can modify for cards, like what they do in selection dialogs, but I'm not going to automate those because I think that's not fun.
---     I will still make AI for this, a dumb one that always picks the first card, and other AI that do things like take the cheapest card they don't have, or that "knows" what cards do.  The AI here I am not going to try to optimize for now.
---Very neat, very cool.  
local function giveMana(player, matchedNodes, type)
    local bonusMana = player.manaBonuses[type]
    player:addMana(math.max(0, bonusMana + #matchedNodes))
end


--#region Node methods
local function getNode(board, i, j)
    if i > board.columns or i < 1 or j > board.rows or j < 1 then
        return nil --todo maybe don't use nil for empty.
    end
    return board.nodes[i][j]
end

---how do you cross-encode a bunch of information?
---It's ok if it's messy, but 



--Doesn't change the position of this node???  i and j are just for convenience.

local function newNode(board, i, j, type)
    local node = {type=type, board=board, i=i, j=j, durability=0}
    node[DIRECTION_UP] = function(self)
        return getNode(self.board, self.i, self.j+1)
    end
    node[DIRECTION_DOWN] = function(self)
        return getNode(self.board, self.i, self.j-1)
    end
    node[DIRECTION_LEFT] = function(self)
        return getNode(self.board, self.i-1, self.j)
    end
    node[DIRECTION_RIGHT] = function(self)
        return getNode(self.board, self.i+1, self.j)
    end
    return node
end

local function generateRandomNode(board, i, j)
    return newNode(board, i, j, board.typeGenerationFunction())
end

--TODO see if useful
local function replaceNode(node)
    node = generateRandomNode(node.board, node.i, node.j)
    node.board.nodes[node.i][node.j] = node
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
--#endregion

--#region match checking methods

--Each node can be part of one match for each type.  For nodes that only have one type, this is that type.
--Multiple type nodes can be part of multiple matches.  A row of 2-type nodes is a match of both types.
--How to properly handle this is a new mapping challenge.
--types is an array of all types the node has.
---Returns all nodes of the same type in a contigious vertical line with this one
---@param currentNode table|node
---@return table list of nodes in a vertical line
local function collectNodes(currentNode, axis)
    local matchingNodes = {currentNode}

    currentNode[axis.name] = true --means it was checked on this axis (todo get the better word for this alignment).
    for _,direction in ipairs(axis) do
        local nextNode = currentNode[direction]()
        --TODO ok this actually isn't ok.  I had been assuming there would only be one color checked the entire time.
        --But this means that instead of one check, and just comparing neighboring nodes, I need to have a type associated with each check function running.
        --Otherwise red red/green green would be a match, which it isn't.  RR R/G GG is also not a five-match, but two three-matches.
        --This also means I need to change how I start the search, because multiple type nodes can return multiple matches.
        --Return a table instead of a single match?
        --This also lets me stop using nil.
        --So, one of the ways that I can do this is to order the types the same way every time.
        --And then do each type one after the other.  This prevents... does this actually prevent anything?
        ---
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

--Needs to save each match and its associated animations/resulting computation.  Animations must have everything they need to render contained inside them, because the board state will have changed by the time they execute.
--TODO this is going to involve making deep copies of A LOT of boards to handle just, so many closures that all have their own idea of the world.
--This makes for computationally kind of expensive code, but very nice logical seperation/compartmentalization.
--The thing I need to consider is just how computationally expensive it is to do this.
--A good game has lots of bits like this that make copies of local state to figure out what they should do, and then they act on the actual big things.
--In particular, this method is useful for when you have things that are one way causal relations.  Animations will never influence game logic, they are purely cosmetic.
--Game logic stuff must be done in order lock step.  But what I can do in those cases is generate predictions on what will happen and save those to save on computation later.

--hahahah, do I make this a self-indexed list for nice properties?
--Basically I actually want this to be a queue.
local mGlobalAnimationQueue = lwl.queue.new()
--todo I need a way to mark things as blocking other animations or not blocking.
--Or something that lets some things happen simultaniously but not others.  This can wait until I get the internals done.
--uh right, you have channels.  So from the global animation queue, you pop them off into different kinds of things.

local exampleMatch = {nodes={}, animations={"ordered list of animations to play out."}, beforeBoardState, afterBoardState}
--The last node will always be the first node.

---TODO this needs to call itself recursively whenever it finds a match, because it's entirely possible for it to just go forever if very lucky.
---Matched nodes with durability or permanence need to recheck even if they didn't change.
---Basically, you need to recall this function with all of the matched nodes every time a match is made.
---
---Just pass board.allNodes() if that's what you mean to do.  Bad to put that logic in this function.  It needs at least one node so it knows what board it's using, and no I'm not having you pass a board unless there are no other options.

--#region board refill methods
local function fillFromTop(node, number)
    if number < 1 then return end
    if node == nil then
        error("fillFromTop called with"..number.."too many calls!")
        return
    end
    replaceNode(node)
    fillFromTop(node.below(), number - 1)
end

--I can make a bunch of things work with just brightness particles that snap to locations, it's very abrupt though.
--todo this should probably return a list of animations to happen, somehow?
local function shiftDownInternal(node, quantity)
    local above = node.above()
    if above == nil then
        --We've reached the top of the board, refill the next QUANTITY nodes with new fodder from the top of the board.
        fillFromTop(node, quantity)
    else
        if (node.inMatch) then
            if node.permanent then
                --todo trigger type shift, add animation
                shiftDownInternal(above, quantity)
            elseif node.durability > 1 then
                node.durability = node.durability - 1
                shiftDownInternal(above, quantity)
                --trigger animation todo
            else
                --trigger animation todo
                
                --mark node as destroyed
                shiftDownInternal(above, quantity + 1)
            end
        else
            --todo animate
            shiftDownInternal(above, quantity)
        end
    end
end

local function shiftDown(node)
    shiftDownInternal(node, 0)
end
--#endregion


---I'm redefining what a match is.  Now that I'm doing that, I realize how freeing it is to not have methods and classes, and instead have everything be a single data type.
---Everything is a table, and so methods just work.
---A match is now {type=TYPE, nodes={}, fromSwap=boolean}
--TODO improve if I want wildcard types, or multi type matching.
--YEAH a match needs to store its type inside itself.
--TODO this must change NOW.
local function getMatchType(match)
    return match.type
end

---comment
---@param matchedNodes table
---@param fromSwap any
local function handleMatch(match)
--destroy the nodes, give mana, whatever else.
    ---If I actually want to improve performance, I need to sort those as I add them, and then go from the bottom node of each column.
    ---I think the gains are minimal from this.
    if #matchedNodes < 1 then
        print("Warning: called handleMatch with no match.")
        return
    elseif #matchedNodes < MINIMUM_MATCH_LENGTH then
        error("handleMatch called with incomplete match! Expected at least "..MINIMUM_MATCH_LENGTH.." nodes, got "..#matchedNodes..".")
    end

    local sampleNode = matchedNodes[1]
    local board = sampleNode.board
    local type = getMatchType(matchedNodes)
    for _,node in ipairs(matchedNodes) do
        node.inMatch = true
    end

    --Give mana
    giveMana(mActivePlayer, matchedNodes, type)

    --Destroy the nodes and shift them down.
    ---TODO no, shifting down comes after node checking.  Multiple matches can happen at the same time, with all of them needing to fall at the same time.
    ---This doesn't account for that as currently written.
    ---todo fix this after I finish my current work.
    for i=1,board.columns do
        shiftDown(board.nodes[i][1])
    end

    --todo do these nodes still exist?  Reset them if they do.
    for _,node in ipairs(matchedNodes) do
        node.inMatch = nil
    end
end

local function createEmptyMatchSet()
    local matcheSet = {}
    for _,type in ipairs(TYPE_LIST) do
        matcheSet[type] = {}
    end
    return matcheSet
end

local function checkMatches(changedNodes, fromSwap)
    if #changedNodes == 0 then return {} end
    local matches = createEmptyMatchSet()
    for _,node in ipairs(changedNodes) do
        local currentMatches = checkMatchesAxis(node, HORIZONTAL_AXIS)
        for type,match in pairs(currentMatches) do
            match.fromSwap = fromSwap
            table.insert(matches, match)
        end
        handleMatch(match)
    end

    local matchedNodes = {}
    --matches will be non-overlapping
    for _,match in ipairs(matches) do
        for _,node in match.nodes do
            table.insert(matchedNodes, node)
            --reset the markings on all nodes.
            node[HORIZONTAL_AXIS.name] = nil
            node[VERTICAL_AXIS.name] = nil
        end
    end
    checkMatches(matchedNodes, false)
end
--#endregion


--We're still operating in the same physical paradigm as the generation before us, and before us, and before us.  Time to move to new metaphysical space.




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
local function initBoard(board)
    local nodeArray = {}
    for i=1,board.columns do
        table.insert(nodeArray, {})
        for j=1,board.rows do
            table.insert(nodeArray[i][j], newNode(board, i, j, board.typeGenerationFunction(i, j)))
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
local testBoard = initBoard({rows=3, columns=3, typeGenerationFunction=function()
    return TYPE_COLORLESS
end})
--set all types
setAllNodes(testBoard, TYPE_COLORLESS)
local matchedNodes = checkMatches(testBoard[1][2])
--#endregion




