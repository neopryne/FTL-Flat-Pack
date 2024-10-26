mods.lightweight_lua = {}

--[[Usage:
    local lwl = mods.lightweight_lua
    lwl.isPaused()
    --pull 3d into own file.
]]--
local vter = mods.multiverse.vter
local get_room_at_location = mods.vertexutil.get_room_at_location

local global = Hyperspace.Global.GetInstance()

local TAU = math.pi * 2
local ENEMY_SHIP = 1
local X_RENDER_OFFSET = -15
local Y_RENDER_OFFSET = -15
local HIGHLIGHT_YELLOW = Graphics.GL_Color(.8, .8, .0, 1)
local HIGHLIGHT_GREEN = Graphics.GL_Color(.0, .8, .0, 1)
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

-- Helper function to rotate a point around a fixed point
function mods.lightweight_lua.rotatePointAroundFixed(p, cx, cy, cz, angleX, angleY, angleZ)
    -- Translate the point so the fixed point is at the origin
    local x = p.x - cx
    local y = p.y - cy
    local z = p.z - cz

    -- Rotation around X-axis
    local cosX = math.cos(angleX)
    local sinX = math.sin(angleX)
    local newY = cosX * y - sinX * z
    local newZ = sinX * y + cosX * z
    y = newY
    z = newZ

    -- Rotation around Y-axis
    local cosY = math.cos(angleY)
    local sinY = math.sin(angleY)
    local newX = cosY * x + sinY * z
    newZ = -sinY * x + cosY * z
    x = newX
    z = newZ

    -- Rotation around Z-axis
    local cosZ = math.cos(angleZ)
    local sinZ = math.sin(angleZ)
    newX = cosZ * x - sinZ * y
    newY = sinZ * x + cosZ * y
    x = newX
    y = newY

    -- Translate the point back to its original position
    return {x = x + cx, y = y + cy, z = z + cz}
end

--cs are values of center point of the mesh.
function mods.lightweight_lua.rotateAround(object, cx, cy, cz, angleX, angleY, angleZ)
    local rotatedObject = {}
    for i, vertex in ipairs(object) do
        rotatedObject[i] = mods.lightweight_lua.rotatePointAroundFixed(vertex, cx, cy, cz, angleX, angleY, angleZ)
    end
    return rotatedObject
end

-- Sort faces by their average z-depth for simple face culling
function mods.lightweight_lua.sortFacesByDepth(multifacedObject, active_faces)
    table.sort(active_faces, function(f1, f2)
        -- Compute average z for face f1
        local z1 = 0
        for _, index in ipairs(f1) do
            z1 = z1 + multifacedObject[index].z
        end
        z1 = z1 / #f1

        -- Compute average z for face f2
        local z2 = 0
        for _, index in ipairs(f2) do
            z2 = z2 + multifacedObject[index].z
        end
        z2 = z2 / #f2

        return z1 > z2 -- Sort descending, so that front faces are drawn last
    end)
end

--zeros the location for rendering
function mods.lightweight_lua.relativeX(xPos, position)
    return xPos + position.x + X_RENDER_OFFSET
end

--zeros the location for rendering
function mods.lightweight_lua.relativeY(yPos, position)
    return yPos + position.y + Y_RENDER_OFFSET
end

--discard z for rendering
function mods.lightweight_lua.relativeVertex(vertex, position)
    return Hyperspace.Point(mods.lightweight_lua.relativeX(vertex.x, position), mods.lightweight_lua.relativeY(vertex.y, position))
end

function mods.lightweight_lua.relativeVertexByIndex(mesh, vertexIndex, position)
    return mods.lightweight_lua.relativeVertex(mesh[vertexIndex], position)
end

function mods.lightweight_lua.drawRelativeLine(mesh, vertex1, vertex2, position, line_width, color)
    --Graphics.CSurface.GL_DrawLine(mesh[vertex1].x + position.x,  mesh[vertex1].y + position.y, mesh[vertex2].x + position.x,  mesh[vertex2].y + position.y, 2, BLACK)
    Graphics.CSurface.GL_DrawLine(mods.lightweight_lua.relativeX(mesh[vertex1].x, position),  mods.lightweight_lua.relativeY(mesh[vertex1].y, position), 
            mods.lightweight_lua.relativeX(mesh[vertex2].x, position),  mods.lightweight_lua.relativeY(mesh[vertex2].y, position), line_width, color)
end

function mods.lightweight_lua.glDrawTriangle_Wrapper(mesh, vertex1, vertex2, vertex3, position, color)
    point1 = mods.lightweight_lua.relativeVertexByIndex(mesh, vertex1, position)
    point2 = mods.lightweight_lua.relativeVertexByIndex(mesh, vertex2, position)
    point3 = mods.lightweight_lua.relativeVertexByIndex(mesh, vertex3, position)
    
    --print("rendering triangle", point1.x, ", ", point1.y, " -- ", point2.x, ", ", point2.y, " -- ", point3.x, ", ", point3.y)
    Graphics.CSurface.GL_DrawTriangle(point1, point2, point3, color)
end

--requires that the face points are in order and are a convex polygon
function mods.lightweight_lua.drawFace(mesh, face, position)
    for i = 3, #face do
        --print("drawing triangle ", i)
        if (face.filled) then
            mods.lightweight_lua.glDrawTriangle_Wrapper(mesh, face[1], face[i-1], face[i], position, face.fill_color)
        end
        if (face.outline) then
            mods.lightweight_lua.drawRelativeLine(mesh, face[i-1], face[i], position, face.line_width, face.outline_color)
        end
    end
    if (face.outline) then
        mods.lightweight_lua.drawRelativeLine(mesh, face[1], face[#face], position, face.line_width, face.outline_color)
        mods.lightweight_lua.drawRelativeLine(mesh, face[1], face[2], position, face.line_width, face.outline_color)
    end
end

--I think I have to put everything into a big face list for any given object and render it like that.
--still only works well for one object, but it's something.
function mods.lightweight_lua.drawObject(position, object_points, object_faces)
    mods.lightweight_lua.sortFacesByDepth(object_points, object_faces)
    --all rendering must be done between pop/push actions it seems?  Actually I have no idea what these do.
    -- Draw faces (filled polygons)
    Graphics.CSurface.GL_PushMatrix()
    for i, face in ipairs(object_faces) do
        mods.lightweight_lua.drawFace(object_points, face, position)
    end
    Graphics.CSurface.GL_PopMatrix()
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

--Returns the average of two colors.
function mods.lightweight_lua.mergeColors(c1, c2)
    return Graphics.GL_Color((c1.r + c2.r) / 2, (c1.g + c2.g) / 2, (c1.b + c2.b) / 2, (c1.a + c2.a) / 2)
end

--[[ 
Gives you a new face table with all color rendering info replaced by the given recolor info.
if filled is true, must have a fill_color.  If outline is true, must have an outline_color and line_width.
Unless you know those already exist and are sure you did it right.
example:
    recolor_info = { fill_color = Graphics.GL_Color(.9, .9, .9, 1), outline_color = BLACK, outline = true, line_width=2 }
    (requires that you defined BLACK earlier)
    call with relative = true to perform a merge of the colors, must have an existing fill color to use this
--]]
function mods.lightweight_lua.recolorFaces(object_faces, recolor_info, relativeRecolor)
    local deep_copy_faces = mods.lightweight_lua.deepCopyTable(object_faces)
    for i = 1, #deep_copy_faces do
        local face = deep_copy_faces[i]
        if (recolor_info.filled ~= nil) then
            face.filled = recolor_info.filled
        end
        if (recolor_info.fill_color ~= nil) then
            if (relativeRecolor == nil or relativeRecolor == false) then
                face.fill_color = recolor_info.fill_color
            else
                --print("Relative recolor")
                face.fill_color = mods.lightweight_lua.mergeColors(face.fill_color, recolor_info.fill_color)
            end
        end
        if (recolor_info.outline ~= nil) then
            face.outline = recolor_info.outline
        end
        if (recolor_info.outline_color ~= nil) then
            face.outline_color = recolor_info.outline_color
        end
        if (recolor_info.line_width ~= nil) then
            face.line_width = recolor_info.line_width
        end
    end
    return deep_copy_faces
end

--changes the faces to match the crewmember's selected status
function mods.lightweight_lua.recolorForHighlight(object_faces, crewmem)
    if (crewmem.selectionState == 0) then--not selected, do nothing
        return object_faces
    elseif (crewmem.selectionState == 1) then --selected, relative green fill
        return mods.lightweight_lua.recolorFaces(object_faces, {filled=true, fill_color = HIGHLIGHT_GREEN}, true)
    elseif (crewmem.selectionState == 2) then --hover, green edges
        return mods.lightweight_lua.recolorFaces(object_faces, {outline=true, outline_color=HIGHLIGHT_GREEN, line_width=2})
    end
end

--Applies teleport and selection effects to a list of faces for later rendering with a mesh.
--Only call this once per frame, after you've assembled the entire mesh you're going to render
--crewTable is the table for crewmem. object_faces is the list of faces you want to 
--Always returns a deep copy
function mods.lightweight_lua.applyAlternateAnimations(object_faces, crewmem, crewTable)
    local tele_level = crewTable.tele_level
    if not tele_level then
        tele_level = 0
    end
    local initial_ship = crewTable.initial_ship
    if not initial_ship then
        initial_ship = crewmem.currentShipId
    end
    local copy_faces = mods.lightweight_lua.deepCopyTable(object_faces)
    --print("initial alpha: ", object_faces[1].fill_color.a, "initial ship, ", initial_ship, "current ship", crewmem.currentShipId)

    
    copy_faces = mods.lightweight_lua.recolorForHighlight(copy_faces, crewmem)
    if (crewmem.extend.customTele.teleporting) then --teleporting
        local departing
        if (crewmem.currentShipId == initial_ship) then
            departing = 1
        else
            departing = -1
        end
        --print("departing ", departing, "tele_level ", tele_level, 0 - (tele_level * departing))
        tele_level = tele_level + (.03 * departing)
        for i = 1, #copy_faces do
            copy_faces[i].fill_color = Graphics.GL_Color(copy_faces[i].fill_color.r,
                copy_faces[i].fill_color.g, copy_faces[i].fill_color.b,
                math.min(1, math.max(0, copy_faces[i].fill_color.a - tele_level))) 
        end
    else
        --reset teleport
        tele_level = 0
        crewTable.initial_ship = crewmem.currentShipId
    end
    if (crewmem.health.first <= 0 and not crewmem.bDead) then --dying
        return {} --just make it go away right away
    end
    --print("after alpha: ", copy_faces[1].fill_color.a)
    crewTable.tele_level = tele_level
    return copy_faces
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
    

