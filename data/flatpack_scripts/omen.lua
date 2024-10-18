local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter

local global = Hyperspace.Global.GetInstance()
local soundControl = global:GetSoundControl()


--need to add to userdata so you can have two.
--uniqueing this for omen name?

local X_RENDER_OFFSET = -15
local Y_RENDER_OFFSET = -15
local OMEN_DEPTH = 20
local OUTER_SQUARE_SIZE = 30
local TOP_POINT_X = OUTER_SQUARE_SIZE / 2 --top point of equilateral triangle
local TOP_POINT_Y = TOP_POINT_X * math.tan(math.pi/3) --60 degrees

local EYE_ANGLE = math.pi/6
local IRIS_ANGLE = math.pi/3
local EYE_Z = -1 --just on top of everything
local LEFT_EYE_X = (TOP_POINT_X / 3)
local LEFT_EYE_Y = (TOP_POINT_Y / 3)
local RIGHT_EYE_X = OUTER_SQUARE_SIZE - LEFT_EYE_X
local RIGHT_EYE_Y = LEFT_EYE_Y
local TOP_EYE_X = TOP_POINT_X
local TOP_EYE_Y = LEFT_EYE_Y + (math.tan(EYE_ANGLE / 2) * (TOP_EYE_X - LEFT_EYE_X))
local BOTTOM_EYE_X = TOP_POINT_X
local BOTTOM_EYE_Y = TOP_EYE_Y - LEFT_EYE_Y


local INNER_EYE_RIGHT_X = TOP_EYE_X + (math.tan(IRIS_ANGLE) * (TOP_EYE_Y - LEFT_EYE_Y))
local INNER_EYE_RIGHT_Y = LEFT_EYE_Y
local INNER_EYE_LEFT_X = INNER_EYE_RIGHT_X - TOP_EYE_X 
local INNER_EYE_LEFT_Y = LEFT_EYE_Y

--TODO calc this for the library version
local CENTER_POINT = {x = TOP_POINT_X, y = TOP_POINT_X * math.tan(math.pi/6), z = OMEN_DEPTH / 2}
print("c ", CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z)

local ROTATIONS = {x = .01, y = 0, z = .007}

local COLOR = Graphics.GL_Color(.9, 0.9, .9, 1) --a
local COLOR2 = Graphics.GL_Color(.8, .8, .8, 1) --a
local GREY50 = Graphics.GL_Color(0, 0, 0, .5)
local BLACK = Graphics.GL_Color(0, 0, 0, 1) --a

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
    {x = INNER_EYE_RIGHT_X, y = INNER_EYE_RIGHT_Y, z = EYE_Z}
}

local prism = INITIAL_PRISM


-- Faces of the triangular prism (each face is defined by a set of vertex indices)
local faces = {
    {1, 2, 3, color = COLOR, filled = true},        -- Front triangle
    {4, 5, 6, color = COLOR, filled = true},        -- Back triangle
    {1, 2, 5, 4, color = COLOR, filled = true},     -- Side connecting front and back (quad)
    {2, 3, 6, 5, color = COLOR, filled = true},     -- Another side (quad)
    {3, 1, 4, 6, color = COLOR, filled = true},      -- Third side (quad)
    {7, 8, 9, 10, color = BLACK, filled = false},      -- Eye outline (quad)  need new render layer value for this on top
    {11, 8, 12, 10, color = BLACK, filled = true}      -- Eye outline (quad)  need new render layer value for this on top
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

--cs are values of center point of the prism.  Actually you can just calculate this.
function rotateAround(object, cx, cy, cz, angleX, angleY, angleZ)
    local rotatedObject = {}
    for i, vertex in ipairs(object) do
        rotatedObject[i] = rotatePointAroundFixed(vertex, cx, cy, cz, angleX, angleY, angleZ)
    end
    return rotatedObject
end



    -- Sort faces by their average z-depth (for simple face culling)
function sortFacesByDepth()
    table.sort(faces, function(f1, f2)
        -- Compute average z for face f1
        local z1 = 0
        for _, index in ipairs(f1) do
            z1 = z1 + prism[index].z
        end
        z1 = z1 / #f1

        -- Compute average z for face f2
        local z2 = 0
        for _, index in ipairs(f2) do
            z2 = z2 + prism[index].z
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

local function relativeVertexByIndex(vertexIndex, position)
    return relativeVertex(prism[vertexIndex], position)
end

local function drawRelativeLine(vertex1, vertex2, position, color)
    --Graphics.CSurface.GL_DrawLine(prism[vertex1].x + position.x,  prism[vertex1].y + position.y, prism[vertex2].x + position.x,  prism[vertex2].y + position.y, 2, BLACK)
    Graphics.CSurface.GL_DrawLine(relativeX(prism[vertex1].x, position),  relativeY(prism[vertex1].y, position), 
            relativeX(prism[vertex2].x, position),  relativeY(prism[vertex2].y, position), 1, GREY50)
end

--slightly different bc idk how to do overloading
--broken for some reason
local function drawRelativeLine2(vertex1, point1, position)
    print("c2 ", point1.x, point1.y, point1.z)
    Graphics.CSurface.GL_DrawLine(prism[vertex1].x + position.x,  prism[vertex1].y + position.y, point1.x + position.x,  point1.y + position.y, 2, BLACK)
end


local function glDrawTriangle_Wrapper(vertex1, vertex2, vertex3, position, color)
    point1 = relativeVertexByIndex(vertex1, position)
    point2 = relativeVertexByIndex(vertex2, position)
    point3 = relativeVertexByIndex(vertex3, position)
    
    --print("rendering triangle", point1.x, ", ", point1.y, " -- ", point2.x, ", ", point2.y, " -- ", point3.x, ", ", point3.y)
    Graphics.CSurface.GL_DrawTriangle(relativeVertexByIndex(vertex1, position), relativeVertexByIndex(vertex2, position), relativeVertexByIndex(vertex3, position), color)
    --draw black lines
    --drawRelativeLine(vertex1, vertex2, position, color)
    --drawRelativeLine(vertex2, vertex3, position, color)
    --drawRelativeLine(vertex1, vertex3, position, color)
    --print("c2 ", CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z)
    --drawRelativeLine2(vertex1, CENTER_POINT, position)
end

--requires that the face points are in order and a convex polygon
--only works for three or four points
local function drawFace(face, position)
    local i
    for i = 3, #face do
        --print("drawing triangle ", i)
        if (face.filled) then
            glDrawTriangle_Wrapper(face[1], face[i-1], face[i], position, face.color)
        end
        drawRelativeLine(face[i-1], face[i], position, COLOR)
    end
    
    --TODO this is broken but I kind of like it for omen
    --drawRelativeLine(face[1], face[i], position, COLOR)
    drawRelativeLine(face[1], face[2], position, COLOR)
end



function drawOmen(position)
    -- Sort the faces by depth
    --print("draw omen")
    sortFacesByDepth()

    -- Draw faces (filled polygons)
    Graphics.CSurface.GL_PushMatrix()
    for i, face in ipairs(faces) do
        drawFace(face, position)
    end
    Graphics.CSurface.GL_PopMatrix()

    -- Optionally draw edges after filling faces (for clearer visual edges)
    --this needs to be done at the same time as the face or it will render wrong.
    --setColor(0, 0, 0) -- Black for edges
    --[[for i, face in ipairs(faces) do
        local vertices = {}
        for _, index in ipairs(face) do
            local v = project3Dto2D(prism[index])
            table.insert(vertices, v.x)
            table.insert(vertices, v.y)
        end
        love.graphics.polygon("line", vertices) -- Draw the outline
    end--]]
end


--[[next:
        checking what omen's doing
        adjusting rotations based on that
        fighting
        anything else
        add the EYE
        
        big laser?
--]]

--only functions on player ship
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    --local crewTable = userdata_table(crewmem, "mods.flatpack.fatespinner")
    local shipManager = global:GetShipManager(ship.iShipId)
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_omen") then
        --print("found omen")
        --all but the timer do what I want.  skilling is training skills, and tells you what room they are manning.
        --print("Shoot timer: ", crewmem.crewAnim.shootTimer, " shared spot: ", crewmem.bSharedSpot, " fighting: ", crewmem.bFighting, " maning: ", crewmem.bActiveManning, "skiling: ", crewmem.usingSkill)
        --explodes in melee
        --uses laser/beam at range
        --slow deceleration when not fighting
        --powered up = rotation speed
        
      --render oh god
      --so much needs to go in the table
      --actually just the rotation and the rotation speed?
            pos = crewmem:GetPosition()
            drawOmen(pos)
            prism = rotateAround(prism, CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z, ROTATIONS.x, ROTATIONS.y, ROTATIONS.z)
        end
    end
end)
