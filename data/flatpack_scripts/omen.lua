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
local CENTER_POINT = {x = TOP_POINT_X, y = TOP_POINT_X * math.tan(math.pi/6), z = OMEN_DEPTH / 2}
print("c ", CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z)

local ROTATIONS = {x = .01, y = 0, z = .007}

local COLOR = Graphics.GL_Color(.9, 0.9, .9, 1) --a
local COLOR2 = Graphics.GL_Color(.8, .8, .8, 1) --a
local BLACK = Graphics.GL_Color(0, 0, 0, .5) --a

local INITIAL_PRISM = {
    -- Front triangle vertices (x, y, z)
    {x = 0, y = 0, z = 0},
    {x = TOP_POINT_X, y = TOP_POINT_Y, z = 0},
    {x = OUTER_SQUARE_SIZE, y = 0, z = 0},
    
    -- Back triangle vertices (offset in z)
    {x = 0, y = 0, z = OMEN_DEPTH},
    {x = TOP_POINT_X, y = TOP_POINT_Y, z = OMEN_DEPTH},
    {x = OUTER_SQUARE_SIZE, y = 0, z = OMEN_DEPTH}
}

local prism = INITIAL_PRISM


-- Faces of the triangular prism (each face is defined by a set of vertex indices)
local faces = {
    {1, 2, 3},        -- Front triangle
    {4, 5, 6},        -- Back triangle
    {1, 2, 5, 4},     -- Side connecting front and back (quad)
    {2, 3, 6, 5},     -- Another side (quad)
    {3, 1, 4, 6}      -- Third side (quad)
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
function rotatePrism(prism, cx, cy, cz, angleX, angleY, angleZ)
    local rotatedPrism = {}
    for i, vertex in ipairs(prism) do
        rotatedPrism[i] = rotatePointAroundFixed(vertex, cx, cy, cz, angleX, angleY, angleZ)
    end
    return rotatedPrism
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
            relativeX(prism[vertex2].x, position),  relativeY(prism[vertex2].y, position), 2, BLACK)
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
    drawRelativeLine(vertex1, vertex2, position, color)
    drawRelativeLine(vertex2, vertex3, position, color)
    drawRelativeLine(vertex1, vertex3, position, color)
    --print("c2 ", CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z)
    --drawRelativeLine2(vertex1, CENTER_POINT, position)
end

--requires that the face points are in order
--only works for three or four points
local function drawFace(face, position)
    for i = 3, #face do
        print("drawing triangle ", i)
        glDrawTriangle_Wrapper(face[1], face[i-1], face[i], position, COLOR)
        drawRelativeLine(face[i-1], face[i], position, COLOR)
    end
    
    drawRelativeLine(face[1], face[i], position, COLOR)
    drawRelativeLine(face[1], face[2], position, COLOR)

    --[[if (#face == 3) then
        --print("rendering triangle ", face[1], face[2], face[3], " at ", position.x, ", ", position.y)
        glDrawTriangle_Wrapper(face[1], face[2], face[3], position, COLOR)
    else
        --I should move the line rendering code here so that I don't draw them on the unused diagonals
        --also make this general.
        --print("rendering rectangle ", face[1], face[2], face[3], face[4])
        --split face into triangles and render the triangles.
        --assume 1,2,3;1,4,3
        glDrawTriangle_Wrapper(face[1], face[2], face[3], position, COLOR2)
        glDrawTriangle_Wrapper(face[1], face[4], face[3], position, COLOR2)
    end--]]
    --draw the last two lines
end



function drawOmen(position)
    -- Sort the faces by depth
    --print("draw omen")
    sortFacesByDepth()

    -- Draw faces (filled polygons)
    Graphics.CSurface.GL_PushMatrix()
    for i, face in ipairs(faces) do
        --print("draw face")
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
script.on_render_event(Defines.RenderEvents.SHIP, function() end, function(ship)
    local crewTable = userdata_table(crewmem, "mods.flatpack.fatespinner")
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
            prism = rotatePrism(prism, CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z, ROTATIONS.x, ROTATIONS.y, ROTATIONS.z)
        end
    end
end)
