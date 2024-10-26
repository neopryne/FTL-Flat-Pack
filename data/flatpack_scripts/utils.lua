mods.lightweight_lua = {}

--[[Usage:
    local lwl = mods.lightweight_lua
    lwl.whatever()
]]--
local vter = mods.multiverse.vter
local get_room_at_location = mods.vertexutil.get_room_at_location

local global = Hyperspace.Global.GetInstance()

local TAU = math.pi * 2
local ENEMY_SHIP = 1
local TILE_SIZE = 35
mods.lightweight_lua.TILE_SIZE = 35

function mods.lightweight_lua.isPaused()
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    --return false
    return commandGui.bPaused or commandGui.bAutoPaused or commandGui.event_pause or commandGui.menu_pause
end

--for use in printing all of a table
function mods.lightweight_lua.dumpObject(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. mods.lightweight_lua.dumpObject(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--deep copy of t1 and t2 to t3
--only one level deep though, it's not recursive.  For that, use deepTableMerge
function mods.lightweight_lua.tableMerge(t1, t2)
    local t3 = {}
    for i=1,#t1 do
        t3[#t3+1] = t1[i]
    end
    for i=1,#t2 do
        t3[#t3+1] = t2[i]
    end
    return t3
end

--note: does not copy objects in the table.
function mods.lightweight_lua.deepCopyTable(t)
    if type(t) ~= "table" then
        return t  -- Return the value directly if it's not a table (base case)
    end

    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = mods.lightweight_lua.deepCopyTable(v)  -- Recursively copy nested tables
        else
            copy[k] = v  -- Directly copy non-table values
        end
    end
    return copy
end

--returns a merged deep copy of both tables.  Non-table objects will not be deep-copied.
function mods.lightweight_lua.deepTableMerge(t1, t2)
    t1Copy = mods.lightweight_lua.deepCopyTable(t1)
    t2Copy = mods.lightweight_lua.deepCopyTable(t2)
    return mods.lightweight_lua.tableMerge(t1Copy, t2Copy)
end



--returns all crew on ship that belong to crewShip.
function mods.lightweight_lua.getCrewOnSameShip(shipManager, crewShipManager)
    crewList = {}
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem.iShipId == crewShipManager.iShipId) then
            table.insert(crewList, crewmem)
        end
    end
    return crewList
end

-- Returns a table of all crew on shipManager ship's belonging to crewShipManager's crew on the room tile at the given point
--booleans getDrones and getNonDrones are optional, but you have to include both if you include one or it calls wrong
--default is returning all crew if not specified.
--maxCount is optional, but you must specify both getDrones and getNonDrones if you use it
function mods.lightweight_lua.get_ship_crew_point(shipManager, crewShipManager, x, y, getDrones, getNonDrones, maxCount)
    res = {}
    x = x//TILE_SIZE
    y = y//TILE_SIZE
    for crewmem in vter(shipManager.vCrewList) do
        if crewmem.iShipId == crewShipManager.iShipId and x == crewmem.x//TILE_SIZE and y == crewmem.y//TILE_SIZE then
            if ((crewmem:IsDrone() and (getDrones == nil or getDrones) or ((not crewmem:IsDrone()) and (getNonDrones == nil or getNonDrones)))) then
                table.insert(res, crewmem)
                if maxCount and #res >= maxCount then
                    return res
                end
            end
        end
    end
    return res
end

-- -1 in the unlikely event no room is found
function mods.lightweight_lua.getRoomAtCrewmember(crewmem)
    local shipManager = global:GetShipManager(crewmem.currentShipId)
    --need to call this with the shipManager of the ship you want to look at.
    room = get_room_at_location(shipManager, crewmem:GetPosition(), true)
    --print(crewmem:GetLongName(), ", Room: ", room, " at ", crewmem:GetPosition().x, crewmem:GetPosition().y)
    return room
end

--returns true if it did anything and false otherwise
function mods.lightweight_lua.damageFoesAtSpace(crewmem, location, damage, stunTime, directDamage)
    local foundFoe = false
    local currentShipManager = global:GetShipManager(crewmem.currentShipId)
    local foeShipManager = global:GetShipManager(1 - crewmem.iShipId)
    if (currentShipManager and foeShipManager) then --null if not in combat
        foes_at_point = mods.lightweight_lua.get_ship_crew_point(currentShipManager, foeShipManager, location.x, location.y)
        for j = 1, #foes_at_point do
            local foe = foes_at_point[j]
            foe.fStunTime = foe.fStunTime + stunTime
            foe:ModifyHealth(-damage)
            foe:DirectModifyHealth(-directDamage)
            foundFoe = true
        end
    end
    return foundFoe
end

--returns true if it did anything and false otherwise
function mods.lightweight_lua.damageFoesInSameSpace(crewmem, damage, stunTime, directDamage)
    return mods.lightweight_lua.damageFoesAtSpace(crewmem, crewmem:GetPosition(), damage, stunTime, directDamage)
end

function mods.lightweight_lua.damageEnemyHelper(activeCrew, amount, stunTime, currentRoom, bystander)
    --print("bystander in helper: " bystander)
    --print(bystander:GetLongName(), "room ", bystander.iRoomId, " ", currentRoom, " ", bystander.currentShipId == activeCrew.currentShipId)
    --print(bystander:GetLongName(), "room ", bystander.iRoomId == currentRoom, " ", bystander.iShipId == ENEMY_SHIP, " ", bystander.currentShipId == activeCrew.currentShipId)
    if bystander.iRoomId == currentRoom and bystander.iShipId == ENEMY_SHIP and bystander.currentShipId == activeCrew.currentShipId then
        --print(bystander:GetLongName(), " was in the same room!  Hit for ", amount, " damage!")
        if (stunTime ~= nil) then
            bystander.fStunTime = bystander.fStunTime + stunTime
        end
        bystander:DirectModifyHealth(-amount)
    end
end

--Does direct damage to all foes in the room. optional stun time
function mods.lightweight_lua.damageEnemyCrewInSameRoom(activeCrew, amount, stunTime)
    local currentRoom = mods.lightweight_lua.getRoomAtCrewmember(activeCrew)
        -- Modified from brightlord's modification of Arc's get_ship_crew_room().
    if (Hyperspace.ships.enemy) then
      for bystander in vter(Hyperspace.ships.enemy.vCrewList) do
            --print(bystander:GetLongName(), " was in the same room!")
          mods.lightweight_lua.damageEnemyHelper(activeCrew, amount, stunTime, currentRoom, bystander)
      end
    end
    --do the same for friendly ship
    for bystander in vter(Hyperspace.ships.player.vCrewList) do
        mods.lightweight_lua.damageEnemyHelper(activeCrew, amount, stunTime, currentRoom, bystander)
    end
end


-- Generate a random point radius away from a point
--modified from vertexUtils random_point_radius
function mods.lightweight_lua.random_point_circle(origin, radius)
    local r = radius
    local theta = TAU*(math.random())
    return Hyperspace.Pointf(origin.x + r*math.cos(theta), origin.y + r*math.sin(theta))
end

-- Generate a random point within the radius of a given point
--modified from vertexUtils random_point_radius
function mods.lightweight_lua.random_point_adjacent(origin)
    local r = TILE_SIZE
    local theta = math.pi*(math.floor(math.random(0, 4))) / 2
    return Hyperspace.Pointf(origin.x + r*math.cos(theta), origin.y + r*math.sin(theta))
end

function mods.lightweight_lua.random_valid_space_point_adjacent(origin, shipManager)
    local r = TILE_SIZE
    local theta = math.pi*(math.floor(math.random(0, 4))) / 2
    for i = 0,3 do
        new_angle = theta + (i * math.pi / 2)
        point = Hyperspace.Point(origin.x + r*math.cos(new_angle), origin.y + r*math.sin(new_angle))
        if (not (get_room_at_location(shipManager, point, true) == -1)) then
            return point
        end
    end
    return nil
end

--returns the closest available slot, or a slot with id and room -1 if none is found.
--isIntruder seems to be iff you want to check slots ignoring ones invading crew occupy, else ignoring ones defending crew occupy.
function mods.lightweight_lua.closestOpenSlot(point, shipId, isIntruder)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    return shipGraph:GetClosestSlot(point, shipId. isIntruder)
end

--Doesn't matter who's in it, returns -1 if no room is found. For use with things like MoveToRoom
function mods.lightweight_lua.slotIdAtPoint(point, shipManager)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
    local roomNumber = get_room_at_location(shipManager, point, true)
    if (roomNumber == -1) then
        return -1
    end
    local shape = shipGraph:GetRoomShape(roomNumber)
    --always l->r, t->bottom.
    --get the x y indexes of the slot.  0,0; 1,1, etc.
    local width = shape.w / TILE_SIZE
    local deltaX = point.x - shape.x
    local deltaY = point.y - shape.y
    local indexX
    indexX = math.floor(deltaX / TILE_SIZE)
    indexY = math.floor(deltaY / TILE_SIZE)
    return indexX + (indexY * width)
end

--Returns a random slot id in the given room.
function mods.lightweight_lua.randomSlotRoom(roomNumber, shipId)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipId)
    local shape = shipGraph:GetRoomShape(roomNumber)
    local width = shape.w / TILE_SIZE
    local height = shape.h / TILE_SIZE
    local count_of_tiles_in_room = width * height
    return math.floor(math.random() * count_of_tiles_in_room) --zero indexed
end
    

