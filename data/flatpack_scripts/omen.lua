local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.vertexutil.get_room_at_location
--[[next:
        checking what omen's doing
        adjusting rotations based on that
        fighting
        anything else
        add the EYE
        
        figure out how the laser does damage
        
        stretch goal: green/white outlines when selected/manning while selected
        This is a slightly larger green/yellow prism on its own face scene
        uniqueing this for omen name?
        No just have a yellow/green color that you logical and with the current one to make a filter
        Works better with omen cause its white but should work decently in general.
        teleport thing, just get transparent.  And then untransparent.
        also dying.
        the more I can do in 3D the better.
--]]
local ENEMY_SHIP = 1 --seriously move this to lib
local global = Hyperspace.Global.GetInstance()
local soundControl = global:GetSoundControl()

--from fishing
local function isPaused() --todo this doesn't seem to work for me.  At all.
    local commandGui = Hyperspace.Global.GetInstance():GetCApp().gui
    --return false
    return commandGui.bPaused or commandGui.bAutoPaused or commandGui.event_pause or commandGui.menu_pause
end

function dumpObject(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dumpObject(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--deep copy of t1 and t2 to t3
function tableMerge(t1, t2)
    local t3 = {}
    for i=1,#t1 do
        t3[#t3+1] = t1[i]
    end
    for i=1,#t2 do
        t3[#t3+1] = t2[i]
    end
    return t3
end

function deepCopyTable(t)
    if type(t) ~= "table" then
        return t  -- Return the value directly if it's not a table (base case)
    end

    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = deepCopyTable(v)  -- Recursively copy nested tables
        else
            copy[k] = v  -- Directly copy non-table values
        end
    end

    return copy
end

function deepTableMerge(t1, t2)
    t1Copy = deepCopyTable(t1)
    t2Copy = deepCopyTable(t2)
    return tableMerge(t1Copy, t2Copy)
end

--returns 0. why.
local function get_room_at_crewmember(crewmem)
    local shipManager = global:GetShipManager(crewmem.currentShipId)
    --need to call this with the shipManager of the ship you want to look at.
    room = get_room_at_location(shipManager, crewmem:GetPosition(), true)
    print(crewmem:GetLongName(), ", Room: ", room, " at ", crewmem:GetPosition().x, crewmem:GetPosition().y)
    return room
end


local function damage_enemy_helper(activeCrew, amount, currentRoom, bystander)
    --print("bystander in helper: " bystander)
    --print(bystander:GetLongName(), "room ", bystander.iRoomId, " ", currentRoom, " ", bystander.currentShipId == activeCrew.currentShipId)
    --print(bystander:GetLongName(), "room ", bystander.iRoomId == currentRoom, " ", bystander.iShipId == ENEMY_SHIP, " ", bystander.currentShipId == activeCrew.currentShipId)
    if bystander.iRoomId == currentRoom and bystander.iShipId == ENEMY_SHIP and bystander.currentShipId == activeCrew.currentShipId then
        print(bystander:GetLongName(), " was in the same room!  Hit for ", amount, " damage!")
        bystander:DirectModifyHealth(-amount)
    end
end

--TODO pull into library, used by: omen, f22, add friendly fire and other options
local function damage_enemy_crew_in_same_room(activeCrew, amount)
    local currentRoom = get_room_at_crewmember(activeCrew)
        -- Modified from brightlord's modification of Arc's get_ship_crew_room().
    if (Hyperspace.ships.enemy) then
      for bystander in vter(Hyperspace.ships.enemy.vCrewList) do
            --print(bystander:GetLongName(), " was in the same room!")
          damage_enemy_helper(activeCrew, amount, currentRoom, bystander)
      end
    end
    --do the same for friendly ship
    for bystander in vter(Hyperspace.ships.player.vCrewList) do
        damage_enemy_helper(activeCrew, amount, currentRoom, bystander)
    end
end

local MAX_POWER = 100
local BASE_BEAM_DAMAGE = 25
local BASE_BLAST_DAMAGE = 0--TODO 20
local BEAM_TIME = 52

local X_RENDER_OFFSET = -15
local Y_RENDER_OFFSET = -15
local OMEN_DEPTH = 20
local OUTER_SQUARE_SIZE = 30
local TOP_POINT_X = OUTER_SQUARE_SIZE / 2 --top point of equilateral triangle
local TOP_POINT_Y = TOP_POINT_X * math.tan(math.pi/3) --60 degrees

local EYE_ANGLE = math.pi/6
local IRIS_ANGLE = math.pi/3
local EYE_Z = -1 --just on top of everything
local BEAM_Z = -76
local LEFT_EYE_X = (TOP_POINT_X / 3)
local LEFT_EYE_Y = (TOP_POINT_Y / 3)
local RIGHT_EYE_X = OUTER_SQUARE_SIZE - LEFT_EYE_X
local RIGHT_EYE_Y = LEFT_EYE_Y
local TOP_EYE_X = TOP_POINT_X
local TOP_EYE_OFFSET_Y = (math.tan(EYE_ANGLE) * (TOP_EYE_X - LEFT_EYE_X))
local TOP_EYE_Y = LEFT_EYE_Y + TOP_EYE_OFFSET_Y
local BOTTOM_EYE_X = TOP_POINT_X
local BOTTOM_EYE_Y = LEFT_EYE_Y - TOP_EYE_OFFSET_Y

local INNER_EYE_OFFSET_X = (math.tan(IRIS_ANGLE / 2) * (TOP_EYE_Y - LEFT_EYE_Y))
local INNER_EYE_RIGHT_X = TOP_EYE_X + INNER_EYE_OFFSET_X
local INNER_EYE_RIGHT_Y = LEFT_EYE_Y
local INNER_EYE_LEFT_X = TOP_EYE_X - INNER_EYE_OFFSET_X
local INNER_EYE_LEFT_Y = LEFT_EYE_Y

--TODO calc this for the library version
local CENTER_POINT = {x = TOP_POINT_X, y = TOP_POINT_X * math.tan(math.pi/6), z = OMEN_DEPTH / 2}
print("c ", CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z)

local ROTATIONS = {x = .01, y = 0, z = .007}

local OMEN_BODY_COLOR = Graphics.GL_Color(.8, .8, .8, 1)
local OMEN_BODY_YELLOW = Graphics.GL_Color(.8, .8, .3, 1)
local OMEN_BODY_GREEN = Graphics.GL_Color(.3, .8, .3, 1)
local HIGHLIGHT_YELLOW = Graphics.GL_Color(.8, .8, .0, 1)
local HIGHLIGHT_GREEN = Graphics.GL_Color(.0, .8, .0, 1)
local WHITE = Graphics.GL_Color(.9, .9, .9, 1) 
local GREY50 = Graphics.GL_Color(0, 0, 0, .5)
local BLACK = Graphics.GL_Color(0, 0, 0, 1) 

--todo may need to deep copy/hardcode
local INITIAL_PRISM = {
    -- Front triangle vertices (x, y, z)
    {x = 0, y = 0, z = 0},
    {x = TOP_POINT_X, y = TOP_POINT_Y, z = 0},
    {x = OUTER_SQUARE_SIZE, y = 0, z = 0},
    
    -- Back triangle vertices (offset in z)
    {x = 0, y = 0, z = OMEN_DEPTH},
    {x = TOP_POINT_X, y = TOP_POINT_Y, z = OMEN_DEPTH},
    {x = OUTER_SQUARE_SIZE, y = 0, z = OMEN_DEPTH},
    
    --Eye points
    {x = LEFT_EYE_X, y = LEFT_EYE_Y, z = EYE_Z},
    {x = TOP_EYE_X, y = TOP_EYE_Y, z = EYE_Z},
    {x = RIGHT_EYE_X, y = RIGHT_EYE_Y, z = EYE_Z},
    {x = BOTTOM_EYE_X, y = BOTTOM_EYE_Y, z = EYE_Z},
    --Inner Eye
    {x = INNER_EYE_LEFT_X, y = INNER_EYE_LEFT_Y, z = EYE_Z},
    {x = INNER_EYE_RIGHT_X, y = INNER_EYE_RIGHT_Y, z = EYE_Z},
    
    --Beam points, not usually rendered.  Comes out of the Inner Eye.
    {x = INNER_EYE_LEFT_X, y = INNER_EYE_LEFT_Y, z = BEAM_Z},
    {x = TOP_EYE_X, y = TOP_EYE_Y, z = BEAM_Z},
    {x = INNER_EYE_RIGHT_X, y = INNER_EYE_RIGHT_Y, z = BEAM_Z},
    {x = BOTTOM_EYE_X, y = BOTTOM_EYE_Y, z = BEAM_Z}
}

-- Faces of the triangular prism (each face is defined by a set of vertex indices)
local PRISM_FACES = {
    {1, 2, 3, fill_color = OMEN_BODY_COLOR, filled = true},        -- Front triangle
    {4, 5, 6, fill_color = OMEN_BODY_COLOR, filled = true},        -- Back triangle
    {1, 2, 5, 4, fill_color = OMEN_BODY_COLOR, filled = true},     -- Side connecting front and back (quad)
    {2, 3, 6, 5, fill_color = OMEN_BODY_COLOR, filled = true},     -- Another side (quad)
    {3, 1, 4, 6, fill_color = OMEN_BODY_COLOR, filled = true}      -- Third side (quad)
}

local eye_faces = {
    {7, 8, 9, 10, outline_color = BLACK, outline = true, line_width=2},     -- Eye outline (quad)  need new render layer value for this on top
    {11, 8, 12, 10, fill_color = BLACK, filled = true}                      -- Iris (quad)
}

--Lines when selected
--Fill when hovering
--Yellow lines when manning
--Green fill when not 0 unselected 2 hovering 1 selected

local beam_faces = {
    {13, 14, 15, 16, fill_color = WHITE, filled = true}, -- endcap
    {13, 14, 8, 11, fill_color = WHITE, filled = true}, -- faces
    {15, 14, 8, 12, fill_color = WHITE, filled = true}, -- faces
    {15, 16, 10, 12, fill_color = WHITE, filled = true}, -- faces
    {13, 16, 10, 11, fill_color = WHITE, filled = true}, -- faces
}

-- Helper function to rotate a point around a fixed point
function rotatePointAroundFixed(p, cx, cy, cz, angleX, angleY, angleZ)
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

--cs are values of center point of the prism.
function rotateAround(object, cx, cy, cz, angleX, angleY, angleZ)
    local rotatedObject = {}
    for i, vertex in ipairs(object) do
        rotatedObject[i] = rotatePointAroundFixed(vertex, cx, cy, cz, angleX, angleY, angleZ)
    end
    return rotatedObject
end



    -- Sort faces by their average z-depth (for simple face culling)
function sortFacesByDepth(multifacedObject, active_faces)
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


local function relativeX(xPos, position)
    return xPos + position.x + X_RENDER_OFFSET
end

local function relativeY(yPos, position)
    return yPos + position.y + Y_RENDER_OFFSET
end

--discard z for rendering
local function relativeVertex(vertex, position)
    return Hyperspace.Point(relativeX(vertex.x, position), relativeY(vertex.y, position))
end

local function relativeVertexByIndex(prism, vertexIndex, position)
    return relativeVertex(prism[vertexIndex], position)
end

local function drawRelativeLine(prism, vertex1, vertex2, position, line_width, color)
    --Graphics.CSurface.GL_DrawLine(prism[vertex1].x + position.x,  prism[vertex1].y + position.y, prism[vertex2].x + position.x,  prism[vertex2].y + position.y, 2, BLACK)
    Graphics.CSurface.GL_DrawLine(relativeX(prism[vertex1].x, position),  relativeY(prism[vertex1].y, position), 
            relativeX(prism[vertex2].x, position),  relativeY(prism[vertex2].y, position), line_width, GREY50)
end

--slightly different bc idk how to do overloading
--broken for some reason
local function drawRelativeLine2(vertex1, point1, position)
    print("c2 ", point1.x, point1.y, point1.z)
    Graphics.CSurface.GL_DrawLine(prism[vertex1].x + position.x,  prism[vertex1].y + position.y, point1.x + position.x,  point1.y + position.y, 2, BLACK)
end


local function glDrawTriangle_Wrapper(prism, vertex1, vertex2, vertex3, position, color)
    point1 = relativeVertexByIndex(prism, vertex1, position)
    point2 = relativeVertexByIndex(prism, vertex2, position)
    point3 = relativeVertexByIndex(prism, vertex3, position)
    
    --print("rendering triangle", point1.x, ", ", point1.y, " -- ", point2.x, ", ", point2.y, " -- ", point3.x, ", ", point3.y)
    Graphics.CSurface.GL_DrawTriangle(point1, point2, point3, color)
    --draw black lines
    --drawRelativeLine(vertex1, vertex2, position, color)
    --drawRelativeLine(vertex2, vertex3, position, color)
    --drawRelativeLine(vertex1, vertex3, position, color)
    --print("c2 ", CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z)
    --drawRelativeLine2(vertex1, CENTER_POINT, position)
end

--requires that the face points are in order and a convex polygon
--only works for three or four points
--maybe call this prism the mesh in lib
local function drawFace(prism, face, position)
    for i = 3, #face do
        --print("drawing triangle ", i)
        if (face.filled) then
            glDrawTriangle_Wrapper(prism, face[1], face[i-1], face[i], position, face.fill_color)
        end
        if (face.outline) then
            drawRelativeLine(prism, face[i-1], face[i], position, face.line_width, face.outline_color)
        end
    end
    if (face.outline) then
        drawRelativeLine(prism, face[1], face[#face], position, face.line_width, face.outline_color)
        drawRelativeLine(prism, face[1], face[2], position, face.line_width, face.outline_color)
    end
end

--right now laser is always behind because there's no way to sort the faces of both together.
--I think I have to put everything into a big face list for any given object and render it like that.
--still only works well for one object, but it's something.

function drawObject(position, object_points, object_faces)
    sortFacesByDepth(object_points, object_faces)
    --all rendering must be done between pop/push actions it seems?  Actually I have no idea what these do.
    -- Draw faces (filled polygons)
    Graphics.CSurface.GL_PushMatrix()
    for i, face in ipairs(object_faces) do
        drawFace(object_points, face, position)
    end
    Graphics.CSurface.GL_PopMatrix()
end

function randomRotation()
    soundControl:PlaySoundMix("fff_omen_spinup", 2, false)
    return {x = math.random() * .01, y = math.random() * .01, z = math.random() * .01}
end


--[[ 
Gives you a new face table with all color rendering info replaced by the given recolor info.
if filled is true, must have a fill_color.  If outline is true, must have an outline_color and line_width.
Unless you know those already exist and are sure you did it right.
example:
    recolor_info = { fill_color = Graphics.GL_Color(.9, .9, .9, 1), outline_color = BLACK, outline = true, line_width=2 }
    (requires that you defined BLACK earlier)
--]]
function recolorFaces(object_faces, recolor_info)
    print("before ", object_faces[1].fill_color)
    local deep_copy_faces = deepCopyTable(object_faces)
    for i = 1, #deep_copy_faces do
        local face = deep_copy_faces[i]
        if (recolor_info.filled ~= nil) then
            face.filled = recolor_info.filled
        end
        if (recolor_info.fill_color ~= nil) then
            face.fill_color = recolor_info.fill_color
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
    print("after ", object_faces[1].fill_color)
    return deep_copy_faces
end

--changes the faces to match the crewmember's selected status
--TODO the fill color should logical and with the base color instead of this hardcoded nonsense.
function recolorForHighlight(object_faces, crewmem)
    if (crewmem.selectionState == 0) then--not selected
        return object_faces
    elseif (crewmem.selectionState == 1) then --selected, green fill
        return recolorFaces(object_faces, {filled=true, fill_color = OMEN_BODY_GREEN})
    elseif (crewmem.selectionState == 2) then --hover, green edges
        return recolorFaces(object_faces, {outline=true, outline_color=HIGHLIGHT_GREEN, line_width=2})
    end
end

--only functions on player ship
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    local shipManager = global:GetShipManager(ship.iShipId)
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_omen") then
             --this doesn't seem to do anything
            local crewTable = userdata_table(crewmem, "mods.flatpack.fatespinner")
            pos = crewmem:GetPosition()
            --local current_room = get_room_at_location(shipManager, pos, false)--todo is vertexUtils buggfy?  does it only work on my ship?  f22 def worked on both.
            --local current_room_crewmember = get_room_at_crewmember(crewmem)
            --print("current_room: ", current_room, " position ", crewmem:GetPosition().x, " ", crewmem:GetPosition().y, "  crw: ", current_room_crewmember)
            
            --VARIABLE DEFINITIONS
            local prism_model = crewTable.prism_model
            if (not prism_model) then
                prism_model = INITIAL_PRISM
            end
            local rotations = crewTable.rotations
            if not (rotations) then
                rotations = randomRotation()
            end
            local beam_render_time = crewTable.beam_render_time
            if not (crewTable.beam_render_time) then --if undefined
                beam_render_time = -1
            end
            local omen_power = crewTable.omen_power
            if not (crewTable.omen_power) then --if undefined
                omen_power = 1
            end
            --VARIABLE DEFINITIONS END
            --always render prism faces
            local renderFaces = recolorForHighlight(PRISM_FACES, crewmem)
            renderFaces = deepTableMerge(renderFaces, eye_faces)
            local is_combat = crewmem.bFighting
            
            print("omen power ", omen_power, " selection state: ", crewmem.selectionState)
            if (not isPaused()) then
                if (beam_render_time == 0) then
                    print("BEAM RESET ")
                    rotations = randomRotation()
                    beam_render_time = -1
                    omen_power = omen_power + 5
                end
                
                --when entering combat, pick new rotation direction and scale it up by POWER until the total power is MAX_POWER
                if (is_combat) then
                    if (not (is_combat == crewTable.was_combat)) then
                        --rerandomize direction on entering combat
                        rotations = randomRotation()
                        omen_power = omen_power + 7
                    end
                    --99 MOB CHORUS
                    omen_power = omen_power + .1, MAX_POWER
                    if (omen_power >= MAX_POWER) then --go off!
                        if (crewmem.bSharedSpot) then
                            print("OMEN BLAST TRIGGERED")
                            soundControl:PlaySoundMix("fff_omen_blast", 6, false)
                            --melee
                            damage_enemy_crew_in_same_room(crewmem, BASE_BLAST_DAMAGE)
                            --brightness particle stuff
                            rotations = randomRotation()
                            omen_power = 55
                        else
                            --ranged
                            print("OMEN BEAM TRIGGERED")
                            soundControl:PlaySoundMix("fff_omen_shoot", 3, false)
                            beam_render_time = BEAM_TIME
                            --draw a random triangle/hyperbola and damage in it.
                            omen_power = MAX_POWER - 1 --idk hacky solution
                        end
                    end
                else
                    omen_power = math.max(omen_power - .05, 1)
                end
                
                if (beam_render_time > 0) then
                    beam_render_time = beam_render_time - 1
                    omen_power = omen_power - .45
                    renderFaces = deepTableMerge(renderFaces, beam_faces)
                end
                
                prism_model = rotateAround(prism_model, CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z, rotations.x * omen_power, rotations.y * omen_power, rotations.z * omen_power)
            end
            
            if (crewmem.bActiveManning) then
                --render some particles based on skiling value
            end
            drawObject(pos, prism_model, renderFaces)
            --FINALLY, write back to crewTable
            crewTable.prism_model = prism_model
            crewTable.was_combat = is_combat
            crewTable.omen_power = omen_power
            crewTable.rotations = rotations
            crewTable.beam_render_time = beam_render_time
        end
    end
end)
