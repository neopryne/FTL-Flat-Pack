local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.vertexutil.get_room_at_location
local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lw3 = mods.lightweight_3d


--[[next:
        stretch goal:
        better dying animation
        blast particles
--]]
local ENEMY_SHIP = 1
local global = Hyperspace.Global.GetInstance()
local soundControl = global:GetSoundControl()

local MAX_POWER = 100
local BASE_BEAM_DAMAGE = 22
local BASE_BLAST_DAMAGE = 20
local OMEN_STEP = .11
local BEAM_TIME = 52

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

local ROTATIONS = {x = .01, y = 0, z = .007}

local OMEN_BODY_COLOR = Graphics.GL_Color(.8, .8, .8, 1)
local OMEN_BODY_YELLOW = Graphics.GL_Color(.8, .8, .3, 1)
local OMEN_BODY_GREEN = Graphics.GL_Color(.3, .8, .3, 1)
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

local beam_faces = {
    {13, 14, 15, 16, fill_color = WHITE, filled = true}, -- endcap
    {13, 14, 8, 11, fill_color = WHITE, filled = true}, -- faces
    {15, 14, 8, 12, fill_color = WHITE, filled = true}, -- faces
    {15, 16, 10, 12, fill_color = WHITE, filled = true}, -- faces
    {13, 16, 10, 11, fill_color = WHITE, filled = true}, -- faces
}


--you have to pass in the rotated matrix
--which means I have to move things around some
--should be crewmem.iCurrentShipId manager
--returns a list of crew that are immune this round
--this must be reset externally
--this damages the crew of the ship you're on as is.
local function beamAttack(rotated_mesh, position, shipManager, crewShipManager, crewTable)
    immuneCrewIds = crewTable.immuneCrewIds
    if not immuneCrewIds then
        immuneCrewIds = {}
    end
    
    --points were' tracking are 16 and 13, the bottom line of the beam
    point1 = lw3.relativeVertexByIndex(rotated_mesh, 16, position)
    point2 = lw3.relativeVertexByIndex(rotated_mesh, 13, position)
    local x = point1.x
    local y = point1.y
    local delta_x = point2.x - point1.x
    local delta_y = point2.y - point1.y
    local partitions = 10
    for i = 0, partitions do
        ix = point1.x + (delta_x / partitions * i)
        iy = point1.y + (delta_y / partitions * i)
        foes_at_point = lwl.get_ship_crew_point(shipManager, crewShipManager, ix, iy)--no need to check if in combat, because this requires enemy crew to exist.
        for j = 1, #foes_at_point do
            local foe = foes_at_point[j]
            --print("Found foe", foe.selfId)
            should_exclude = false
            for k = 1, #immuneCrewIds do
                if (foe.extend.selfId == immuneCrewIds[k]) then
                    should_exclude = true
                end
            end
            
            if (not should_exclude) then
                --apply .1s stun before damage to kill Things
                foe.fStunTime = foe.fStunTime + .1
                foe:DirectModifyHealth(-BASE_BEAM_DAMAGE)
                immuneCrewIds = lwl.tableMerge(immuneCrewIds, {foe.extend.selfId})
            end
        end
    end
    crewTable.immuneCrewIds = immuneCrewIds
end

local function randomRotation()
    soundControl:PlaySoundMix("fff_omen_spinup", 2, false)
    return {x = math.random() * .01, y = math.random() * .01, z = math.random() * .01}
end

script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    local shipManager = global:GetShipManager(crewmem.iShipId)
        if (crewmem:GetSpecies() == "fff_omen") then
            crewShipManager = global:GetShipManager(1 - crewmem.iShipId) --Manager for enemy crew
            local crewTable = userdata_table(crewmem, "mods.flatpack.fatespinner")
            pos = crewmem:GetPosition()
            --local current_room = get_room_at_location(shipManager, pos, false)--todo is vertexUtils buggfy?  does it only work on my ship?  f22 def worked on both.
            --local current_room_crewmember = getRoomAtCrewmember(crewmem)
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
            local is_combat = crewmem.bFighting
            
            --crewmem.bDead this is true only on the frame the crew dies.  And maybe when it's cloned but idk.
            --print("omen power ", omen_power, " teleport: ", crewmem.extend.customTele.teleporting, " dying: ", crewmem.health.first, crewmem.health.second)
            if (not lwl.isPaused()) then
                if (beam_render_time == 0) then
                    --print("BEAM RESET ")
                    rotations = randomRotation()
                    beam_render_time = -1
                    omen_power = omen_power + (5 * (Hyperspace.FPS.SpeedFactor * 4))
                    --reset immunities
                    crewTable.immuneCrewIds = {}
                end
                
                --when entering combat, pick new rotation direction and scale it up by POWER until the total power is MAX_POWER
                if (is_combat) then
                    if (not (is_combat == crewTable.was_combat)) then
                        --rerandomize direction on entering combat
                        rotations = randomRotation()
                        omen_power = omen_power + 7
                    end
                    --99 MOB CHORUS
                    omen_power = omen_power + (OMEN_STEP * (Hyperspace.FPS.SpeedFactor * 4))
                    if (omen_power >= MAX_POWER) then --go off!
                        if (crewmem.bSharedSpot) then
                            --print("OMEN BLAST TRIGGERED")
                            soundControl:PlaySoundMix("fff_omen_blast", 6, false)
                            for i = 1, 40 do
                                local circle_pos = lwl.random_point_circle(pos, 24)
                                circle_pos.y = circle_pos.y - 5
                                blastParticle = Brightness.create_particle("particles/omen/blast", 4, .4,
                                        circle_pos, math.random(0,3)*90, shipManager.iShipId, "SHIP_MANAGER")
                                blastParticle.heading = math.random(0, 359)
                                blastParticle.movementSpeed = 160
                            end
                            --melee
                            lwl.damageEnemyCrewInSameRoom(crewmem, BASE_BLAST_DAMAGE, 3)
                            --brightness particle stuff
                            rotations = randomRotation()
                            omen_power = 55
                        else
                            --ranged
                            --print("OMEN BEAM TRIGGERED")
                            soundControl:PlaySoundMix("fff_omen_shoot", 3, false)
                            beam_render_time = BEAM_TIME
                            --draw a random triangle/hyperbola and damage in it.
                            omen_power = MAX_POWER - (4 * Hyperspace.FPS.SpeedFactor ) --idk hacky solution
                        end
                    end
                else
                    omen_power = math.max(omen_power - .05, 1)
                end
                
                prism_model = lw3.rotateAround(prism_model, CENTER_POINT.x, CENTER_POINT.y, CENTER_POINT.z, rotations.x * omen_power, rotations.y * omen_power, rotations.z * omen_power)
                
                if (beam_render_time > 0) then
                    beamAttack(prism_model, pos, shipManager, crewShipManager, crewTable)
                    beam_render_time = beam_render_time - (4 * Hyperspace.FPS.SpeedFactor )
                    omen_power = omen_power - (.35 + OMEN_STEP)
                end
            end
            
            if (crewmem.bActiveManning) then
                if (not lwl.isPaused()) then
                    if (math.random() > .975) then
                        currentSkill = math.floor(crewmem.iManningId)
                        local circle_pos = lwl.random_point_circle(pos, 15)
                        circle_pos.y = circle_pos.y - 5
                        --render some particles based on skiling value
                        local manningParticle = Brightness.create_particle("particles/manning_"..currentSkill, 4, 2,
                                circle_pos, 0, shipManager.iShipId, "SHIP_MANAGER")
                        manningParticle.heading = 0
                        manningParticle.movementSpeed = 3
                        manningParticle.loops = 2
                    end
                end
            end
            --FINALLY, write back to crewTable
            crewTable.prism_model = prism_model
            crewTable.was_combat = is_combat
            crewTable.omen_power = omen_power
            crewTable.rotations = rotations
            crewTable.beam_render_time = beam_render_time
        end
end)


--only functions on player ship
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(shipManager)
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_omen") then
            crewShipManager = global:GetShipManager(1 - crewmem.iShipId) --Manager for enemy crew
            local crewTable = userdata_table(crewmem, "mods.flatpack.fatespinner")
            pos = crewmem:GetPosition()
            --local current_room = get_room_at_location(shipManager, pos, false)--todo is vertexUtils buggfy?  does it only work on my ship?  f22 def worked on both.
            --local current_room_crewmember = getRoomAtCrewmember(crewmem)
            --print("current_room: ", current_room, " position ", crewmem:GetPosition().x, " ", crewmem:GetPosition().y, "  crw: ", current_room_crewmember)
            
            --VARIABLE DEFINITIONS
            local prism_model = crewTable.prism_model
            if (not prism_model) then
                prism_model = INITIAL_PRISM
            end
            local beam_render_time = crewTable.beam_render_time
            if not (crewTable.beam_render_time) then --if undefined
                beam_render_time = -1
            end
            --VARIABLE DEFINITIONS END
            --always render prism faces
            local renderFaces = lw3.applyAlternateAnimations(PRISM_FACES, crewmem, crewTable)--the eye stays even in death
            renderFaces = lwl.deepTableMerge(renderFaces, eye_faces)
            
            --crewmem.bDead this is true only on the frame the crew dies.  And maybe when it's cloned but idk.
            --print("omen power ", omen_power, " teleport: ", crewmem.extend.customTele.teleporting, " dying: ", crewmem.health.first, crewmem.health.second)

            if (beam_render_time > 0) then
                renderFaces = lwl.deepTableMerge(renderFaces, beam_faces)
            end
            
            if (not (shipManager.bJumping or shipManager.bDestroyed)) then --I kind of like Omen existing outside of jumps.
                lw3.drawObject(pos, prism_model, renderFaces)
            end
            --FINALLY, write back to crewTable
            crewTable.prism_model = prism_model
            crewTable.beam_render_time = beam_render_time
        end
    end
end)
