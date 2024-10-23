local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.vertexutil.get_room_at_location
local Brightness = mods.brightness
local lwl = mods.lightweight_lua

local ENEMY_SHIP = 1
local global = Hyperspace.Global.GetInstance()
local soundControl = global:GetSoundControl()

local FIRST_SYMBOL_RELATIVE_X = -2  
local FIRST_SYMBOL_RELATIVE_Y = 0 
local SYMBOL_OFFSET_X = 6
local SYMBOL_OFFSET_Y = 5
local INPUT_DELAY = 40 --120 --frames?
local OUTPUT_DELAY = 30
local TAU = math.pi * 2
local MOTION_SEED = math.random() --maybe have this different for all buffers?
local BROWNIAN_PERIOD = 210
local BROWNIAN_RANGE = 1
local LAYER_LAG = .3
local SHOT_DAMAGE = 2
local SHOT_BURST = 3
local SHOT_SPEED = 500
local SHOT_DISPERSION = 10
local PUNCH_DAMAGE = 4 --but it stuns
local PUNCH_STUN= .45
local BLITZ_DAMAGE = 0--10
local CAPPED_FPS = 60
local BLACK = Graphics.GL_Color(0, 0, 0, 1) 

--[[
    buffer
    
    try giving ability really long cooldown and then force-ending it when the stack is empty, that would let me use the attribute modifiers there for immutable stuff
    --I can prepare and cancel powers, so I can do this there.
    --speed 0, immune to stun, not controllable
--]]

local ID_PUNCH = 0
local ID_BLITZ = 1
local ID_SHOOT = 2
local TYPE_PUNCH = {name="punch", id=ID_PUNCH}
local TYPE_BLITZ = {name="blitz", id=ID_BLITZ}
local TYPE_SHOOT = {name="shoot", id=ID_SHOOT}

--returns true if it did anything and false otherwise
local function damageFoesAtSpace(crewmem, location, damage, stunTime, directDamage)
    local foundFoe = false
    local currentShipManager = global:GetShipManager(crewmem.currentShipId)
    local foeShipManager = global:GetShipManager(1 - crewmem.iShipId)
    if (currentShipManager) then --null if not in combat
        foes_at_point = lwl.get_ship_crew_point(currentShipManager, foeShipManager, location.x, location.y)
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

local function damageFoesInSameSpace(crewmem, damage, stunTime, directDamage)
    damageFoesAtSpace(crewmem, crewmem:GetPosition(), damage, stunTime, directDamage)
end

local function blitz(crewmem)
    local currentShipManager = global:GetShipManager(crewmem.currentShipId)
    local foeShipManager = global:GetShipManager(1 - crewmem.iShipId)
    soundControl:PlaySoundMix("fff_buffer_blitz", 3, false)
    local newPoint = lwl.random_valid_space_point_adjacent(crewmem:GetPosition(), currentShipManager)
    if (newPoint ~= nil) then
        crewmem:SetPosition(newPoint)
    end
    damageFoesInSameSpace(crewmem, 0, 0, BLITZ_DAMAGE)
    --animate stuff
end

--shots have to check colision in loop/render triangle
local function fireShot(crewmem, heading)
    local crewTable = userdata_table(crewmem, "mods.flatpack.biderman")
    --print("BUFFER SHOT!")
    soundControl:PlaySoundMix("fff_buffer_shot", 4, false)
    local shotParticle = Brightness.create_particle("particles/buffer/shot", 1, (OUTPUT_DELAY / CAPPED_FPS), crewmem:GetPosition(), 0, crewmem.currentShipId, "SHIP_MANAGER")
    shotParticle.heading = (heading + math.random(0, SHOT_DISPERSION)) % 360
    shotParticle.movementSpeed = SHOT_SPEED
    shotParticle.shotOrigin = crewmem:GetPosition()
    local shotsFired = crewTable.shotsFired
    table.insert(shotsFired, shotParticle)
end


local function shoot(crewmem)
   --this has to call back into the main loop to proc the delayed effects.
    local crewTable = userdata_table(crewmem, "mods.flatpack.biderman")
    local currentShipManager = global:GetShipManager(crewmem.currentShipId) --Manager for current ship
    local enemyShipManager = global:GetShipManager(1 - crewmem.iShipId) --Manager for current ship
    local heading
    if (enemyShipManager == nil) then
        heading = math.random() * 360
    else
        local enemyCrewOnSameShip = lwl.getCrewOnSameShip(currentShipManager, enemyShipManager)
        if (#enemyCrewOnSameShip > 0) then
        -- aim at a random enemy on the same ship, if there are any.
            local target = enemyCrewOnSameShip[math.random(1, #enemyCrewOnSameShip)]
            local targetPos = target:GetPosition()
            local crewPos = crewmem:GetPosition()
            
            heading = ((math.atan((targetPos.x - crewPos.x), (crewPos.y - targetPos.y)) * (180/math.pi))) % 360 --degrees
            --print("Targeting ", target:GetLongName(), " at ", targetPos.x, targetPos.y, " heading ", heading)
        else
            heading = math.random() * 360
        end
    end
    
    for i = 1, SHOT_BURST do
        table.insert(crewTable.shotHeadings, heading)
    end
    --print(lwl.dumpObject(crewTable))
end

local function punch(crewmem)
    soundControl:PlaySoundMix("fff_buffer_punch", 4, false)
    damageFoesInSameSpace(crewmem, 0, PUNCH_STUN, PUNCH_DAMAGE)
    --animate stuff
end

local function executeCommand(particleId, crewmem)
    if (particleId == ID_SHOOT) then
        --print("BUFFER SHOOT!")
        shoot(crewmem)
        return (OUTPUT_DELAY * 4 / 3)
    elseif (particleId == ID_PUNCH) then
        --print("BUFFER PUNCH!")
        punch(crewmem)
        return OUTPUT_DELAY
    elseif (particleId == ID_BLITZ) then
        --print("BUFFER BLITZ!")
        blitz(crewmem)
        return OUTPUT_DELAY
    else
        print("Invalid particle id ", particleId)
    end
end

--floatInPeriodicRange(0, 9, -1, 1, number)
local function floatInPeriodicRange(inputMin, inputMax, outputMin, outputMax, number)
    local theta = TAU * number / (inputMax - inputMin)
    local unscaledLength = math.sin(theta)
    if (unscaledLength > 0) then
        return unscaledLength * outputMax
    else
        return -1 * unscaledLength * outputMin
    end
end

--call every move tick after doing all other logic
local function repositionBufferStack(crewmem, bufferParticles, brownianTime)
    for i = 1, #bufferParticles do
        particle = bufferParticles[i]
        particle.space = crewmem.currentShipId
        offsetIndex = (((MOTION_SEED * (10^(math.ceil(i / 2)))) % 10) + ((brownianTime % (BROWNIAN_PERIOD * 10)) / BROWNIAN_PERIOD)) % 10
        brownianOffset = floatInPeriodicRange(0, 10, -BROWNIAN_RANGE, BROWNIAN_RANGE, offsetIndex)
        --print(offsetIndex, " obro ", brownianOffset)
        
        position_x = crewmem:GetPosition().x + FIRST_SYMBOL_RELATIVE_X + (((i + 1) % 2) * SYMBOL_OFFSET_X) + brownianOffset
        position_y = crewmem:GetPosition().y + FIRST_SYMBOL_RELATIVE_Y - (math.ceil(i / 2) * SYMBOL_OFFSET_Y)
        
        if (particle.position ~= nil) then
            position_x = math.min(math.max(particle.position.x, position_x - (i*LAYER_LAG)), position_x + (i*LAYER_LAG))
        else
            particle.position = crewmem:GetPosition()
        end
                
        particle.position.x = position_x
        particle.position.y = position_y
    end
end

local function clear_particles(bufferParticles)
    for i = 1, #bufferParticles do
        Brightness.destroy_particle(bufferParticles[i])
    end
end

local function addParticleInner(particleType, crewmem, bufferParticles)
    particle = Brightness.create_particle("particles/buffer/"..particleType.name, 1, 60, nil, 0, crewmem.currentShipId, "SHIP_MANAGER")
    particle.persists = true
    particle.fff_buffer_id = particleType.id
    table.insert(bufferParticles, particle)
end

local function addParticle(crewmem, bufferParticles)
    soundControl:PlaySoundMix("fff_buffer_input", 3, false)
    
    local rand = math.random(0, 2)
    if (rand >= 2) then
        addParticleInner(TYPE_SHOOT, crewmem, bufferParticles)
    elseif (rand >= 1) then
        addParticleInner(TYPE_BLITZ, crewmem, bufferParticles)
    else
        addParticleInner(TYPE_PUNCH, crewmem, bufferParticles)
    end
end

--return updated list of particles
local function fireParticle(crewmem, bufferParticles)
    local particle = bufferParticles[1]
    if (particle == nil) then
        print("fired nil!")
    end
    local commandDelay = executeCommand(particle.fff_buffer_id, crewmem)
    --pull the stack down
    for j = #bufferParticles, 2, -1 do
        bufferParticles[j].position = bufferParticles[j - 1].position
    end
    Brightness.destroy_particle(particle)
    table.remove(bufferParticles, 1)
    return commandDelay
end

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, ship)
    --print("Power used!")
    if power.crew:GetSpecies() == "fff_buffer" then
        --print("Was buffer!")
        if (power.crew.fStunTime <= 0) then --can't act if stunned
            userdata_table(power.crew, "mods.flatpack.biderman").goingOff = true
        end
        soundControl:PlaySoundMix("fff_buffer_launch", 5, false)
    end
end)

--on-tick mechanical logic goes here.
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if (crewmem:GetSpecies() == "fff_buffer") then
        local shipManager = global:GetShipManager(crewmem.iShipId)
        local currentShipManager = global:GetShipManager(crewmem.currentShipId)
        local crewTable = userdata_table(crewmem, "mods.flatpack.biderman")
        --load vars
        local inputTimer = crewTable.inputTimer
        if (inputTimer == nil) then
            inputTimer = 0
        end
        local outputTimer = crewTable.outputTimer
        if (outputTimer == nil) then
            outputTimer = 0
        end
        local goingOff = crewTable.goingOff
        if (goingOff == nil) then
            goingOff = false
        end
        local bufferParticles = crewTable.bufferParticles
        if (bufferParticles == nil) then
            bufferParticles = {}
        end
        local brownianTime = crewTable.brownianTime
        if (brownianTime == nil) then
            brownianTime = 0
        end
        local shotTimer = crewTable.shotTimer
        if (shotTimer == nil) then
            shotTimer = 0
        end
        --end load vars
        
        if (goingOff) then
            --shouldn't be controlable, stun immune, immune to death? --lab upgrade , can't man systems
            lwl.dumpObject(bufferParticles)
            if #bufferParticles == 0 then
                goingOff = false
                outputTimer = 0
                for bufferPower in vter(crewmem.extend.crewPowers) do
                    bufferPower:CancelPower(false)
                end
                local currentRoom = get_room_at_location(currentShipManager, crewmem:GetPosition(), true)
                --redirect crew to location.  Random slot for now due to limitations, will make it actually use the real position soon.
                --onced fixed, call after every dash instead of here.
                if (currentRoom ~= nil) then
                    newSlot = lwl.randomSlotRoom(currentRoom, crewmem.currentShipId)
                    if (newSlot ~= nil) then
                        crewmem:MoveToRoom(currentRoom, newSlot, false)
                    else
                        print("Slot was nil! Room ", currentRoom)
                    end
                else
                    print("Room was nil! Room ", currentRoom)
                end
            else
                outputTimer = outputTimer - 1
                if (outputTimer <= 0) then
                    outputTimer = fireParticle(crewmem, bufferParticles)
                end
            end
        else
            --not going off
            if (crewmem.bActiveManning or crewmem.bDead or (crewmem:Repairing() and not crewmem:Sabotaging())) then
                --if doing stuff clear the buffer
                clear_particles(bufferParticles)
                bufferParticles = {}
                inputTimer = 0
            else
                inputTimer = inputTimer + 1
                if (inputTimer >= INPUT_DELAY) then
                    addParticle(crewmem, bufferParticles)
                    inputTimer = 0
                end
            end
        end
        
        --this is modified in the loop, so we have to load it here.
        local shotHeadings = crewTable.shotHeadings
        if (shotHeadings == nil) then
            shotHeadings = {}
        end
        --print("shotHeadings", lwl.dumpObject(crewTable))
        if (#shotHeadings > 0) then
            shotTimer = shotTimer - 1
            --print("shotTimer", shotTimer)
            if (shotTimer <= 0) then
                shotTimer = OUTPUT_DELAY / 2
                fireShot(crewmem, shotHeadings[1])
                table.remove(shotHeadings, 1)
            end
        end

        --print("manning", crewmem.bActiveManning, "repair", crewmem:Repairing(), "sabot", crewmem:Sabotaging(), "tele", crewmem.extend.customTele.teleporting,  "dead", crewmem.bDead, crewmem:GetPosition().x, crewmem:GetPosition().y)--asdf
        
    
        repositionBufferStack(crewmem, bufferParticles, brownianTime)
        brownianTime = brownianTime + 1 --could be less
        --Finally write back to table
        crewTable.shotHeadings = shotHeadings
        crewTable.shotTimer = shotTimer
        crewTable.brownianTime = brownianTime
        crewTable.bufferParticles = bufferParticles
        crewTable.goingOff = goingOff
        crewTable.inputTimer = inputTimer
        crewTable.outputTimer = outputTimer
    end--end buffer
end)


--rendering logic goes here, this should just be the attack animations.  Actually I can do those with particles, so this is just nothing?
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    local shipManager = global:GetShipManager(ship.iShipId) --Manager for current ship
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_buffer") then
            local crewTable = userdata_table(crewmem, "mods.flatpack.biderman")
            
            local shotsFired = crewTable.shotsFired
            if (shotsFired == nil) then
                shotsFired = {}
            end
                    --Once I figure out how to get reality to run arbitrary commands, I;ll have true magic.  Magic is telling reality what to do.
            --handle shots
            for i = #shotsFired, 1, -1 do
                local particle = shotsFired[i]
                if (damageFoesAtSpace(crewmem, particle.position, 0, 0, SHOT_DAMAGE)) then
                    Brightness.destroy_particle(particle)
                    table.remove(shotsFired, i)
                end
                --print("shots fired", lwl.dumpObject(shotsFired))todo
                --draw triangle
                local particleRadius = 2
                local deltaX = particle.position.x - crewmem:GetPosition().x
                local deltaY = particle.position.y - crewmem:GetPosition().y
                local innerAngle = math.atan(deltaY/deltaX)
                local x1 = particle.position.x - 2*math.sin(innerAngle)
                local y1 = particle.position.y + 2*math.cos(innerAngle)
                local x2 = particle.position.x + 2*math.sin(innerAngle)
                local y2 = particle.position.y - 2*math.cos(innerAngle)
                local point1 = Hyperspace.Point(x1, y1)
                local point2 = Hyperspace.Point(x2, y2)
                Graphics.CSurface.GL_DrawTriangle(point1, point2, particle.shotOrigin, BLACK)
                if (particle.remainingDuration <= .05) then --idek what's happening here, TODO fix this maybe
                    table.remove(shotsFired, i)
                end
            end
            crewTable.shotsFired = shotsFired
        end--end of buffer
    end
end)