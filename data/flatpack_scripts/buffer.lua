local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local get_room_at_location = mods.multiverse.get_room_at_location
local Brightness = mods.brightness
local lwl = mods.lightweight_lua


local ENEMY_SHIP = 1
local global = Hyperspace.Global.GetInstance()
local soundControl = global:GetSoundControl()

local TABLE_NAME_BUFFER = "mods.flatpack.biderman"

local FIRST_SYMBOL_RELATIVE_X = -2  
local FIRST_SYMBOL_RELATIVE_Y = 0 
local SYMBOL_OFFSET_X = 6
local SYMBOL_OFFSET_Y = 5
local INPUT_DELAY = 80 --frames?
local OUTPUT_DELAY = 30
local TAU = math.pi * 2
local MOTION_SEED = math.random() --maybe have this different for all buffers?
local BROWNIAN_PERIOD = 210
local BROWNIAN_RANGE = 1
local LAYER_LAG = .3
local SHOT_DAMAGE = 1.5
local SHOT_BURST = 3
local SHOT_SPEED = 500
local SHOT_DISPERSION = 10
local PUNCH_DAMAGE = 5 --but it stuns
local PUNCH_STUN= 1
local BLITZ_DAMAGE = 7
local BLITZ_STUN= .01
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

local function blitz(crewmem)
    local currentShipManager = global:GetShipManager(crewmem.currentShipId)
    soundControl:PlaySoundMix("fff_buffer_blitz", 3, false)
    local newPoint = lwl.random_valid_space_point_adjacent(crewmem:GetPosition(), currentShipManager)
    if (newPoint ~= nil) then
        crewmem:SetPosition(newPoint)
    end
    lwl.damageFoesInSameSpace(crewmem, 0, BLITZ_STUN, BLITZ_DAMAGE)
    local newSlot = lwl.slotIdAtPoint(crewmem:GetPosition(), currentShipManager)
    local currentRoom = get_room_at_location(currentShipManager, crewmem:GetPosition(), false)
    --redirect crew to new location so it actually counts as being in that room.
    if (newSlot ~= -1) then
        crewmem:MoveToRoom(currentRoom, newSlot, false)
    else
        print("Found no slot at ", crewmem:GetPosition().x, ", ", crewmem:GetPosition().y, "!")
    end
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
            heading = lwl.angleFtlToBrightness(lwl.getAngle(crewPos, targetPos))
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
    lwl.damageFoesInSameSpace(crewmem, 0, PUNCH_STUN, PUNCH_DAMAGE)
    local particle = Brightness.create_particle("particles/buffer/fist", 1, (OUTPUT_DELAY / (CAPPED_FPS * 2)), crewmem:GetPosition(), 0, crewmem.currentShipId, "SHIP_MANAGER")
    particle.movementSpeed = 40
    particle.heading = 270
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

--floatInPeriodicRange(0, 9, -1, 1, number). Turns a circular input into a linear oscilator.
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
        local particle = bufferParticles[i]
        particle.space = crewmem.currentShipId
        local offsetIndex = (((MOTION_SEED * (10^(math.ceil(i / 2)))) % 10) + ((brownianTime % (BROWNIAN_PERIOD * 10)) / BROWNIAN_PERIOD)) % 10
        local brownianOffset = floatInPeriodicRange(0, 10, -BROWNIAN_RANGE, BROWNIAN_RANGE, offsetIndex)
        --print(offsetIndex, " obro ", brownianOffset)
        
        local position_x = crewmem:GetPosition().x + FIRST_SYMBOL_RELATIVE_X + (((i + 1) % 2) * SYMBOL_OFFSET_X) + brownianOffset
        local position_y = crewmem:GetPosition().y + FIRST_SYMBOL_RELATIVE_Y - (math.ceil(i / 2) * SYMBOL_OFFSET_Y)
        
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
    --clear shots as a safeguard
    local crewTable = userdata_table(crewmem, TABLE_NAME_BUFFER)
    crewTable.shotsFired = {}
    
    local particle = Brightness.create_particle("particles/buffer/"..particleType.name, 1, 60, nil, 0, crewmem.currentShipId, "SHIP_MANAGER")
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
        error("fired nil!")
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

local function resetActivePower(crewmem)
    local crewTable = userdata_table(crewmem, TABLE_NAME_BUFFER)
    crewTable.goingOff = false
    crewTable.outputTimer = 0
    for bufferPower in vter(crewmem.extend.crewPowers) do
        bufferPower:CancelPower(false)
    end
end

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, ship)
    --print("Power used!")
    if power.crew:GetSpecies() == "fff_buffer" then
        --print("Was buffer!")
        if (power.crew.fStunTime <= 0) then --can't act if stunned
            userdata_table(power.crew, TABLE_NAME_BUFFER).goingOff = true
        end
        soundControl:PlaySoundMix("fff_buffer_launch", 5, false)
    end
end)

local BUFFERS_RESETTING = true --set to false after all buffers reset.

--on-tick mechanical logic goes here.
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if (crewmem:GetSpecies() == "fff_buffer") then
        local shipManager = global:GetShipManager(crewmem.iShipId)
        local currentShipManager = global:GetShipManager(crewmem.currentShipId)
        local crewTable = userdata_table(crewmem, TABLE_NAME_BUFFER)
        --load vars
        local inputTimer = lwl.setIfNil(crewTable.inputTimer, 0)
        local outputTimer = lwl.setIfNil(crewTable.outputTimer, 0)
        local goingOff = lwl.setIfNil(crewTable.goingOff, false)
        local bufferParticles = lwl.setIfNil(crewTable.bufferParticles, {})
        local brownianTime = lwl.setIfNil(crewTable.brownianTime, 0)
        local shotTimer = lwl.setIfNil(crewTable.shotTimer, 0)
        local hasBeenReset = lwl.setIfNil(crewTable.hasBeenReset, false)
        --end load vars
        --reset active powers on load.
        if (BUFFERS_RESETTING) then
            if (hasBeenReset) then
                --It's the second time around, we don't need to do this anymore.
                BUFFERS_RESETTING = false
            else
                resetActivePower(crewmem)
                hasBeenReset = true
            end
        end
        
        if (goingOff) then
            --not controlable, stun immune, immune to death
            lwl.dumpObject(bufferParticles)
            if #bufferParticles == 0 then
                goingOff = false
                outputTimer = 0
                for bufferPower in vter(crewmem.extend.crewPowers) do
                    bufferPower:CancelPower(false)
                end
            else
                local speedFactor = 1
                speedFactor = speedFactor + (1 * Hyperspace.ships(0).ship:HasAugmentation("LAB_FFF_BUFFER_OVERCLOCK"))
                speedFactor = speedFactor * (Hyperspace.FPS.SpeedFactor * 4) --account for differences in FPS changing ticks per second.
                outputTimer = outputTimer - speedFactor
                if (outputTimer <= 0) then
                    outputTimer = fireParticle(crewmem, bufferParticles)
                end
            end
        else
            --not going off
            if ((crewmem.bActiveManning or crewmem.bDead or (crewmem:Repairing() and not crewmem:Sabotaging()))) then
                if (Hyperspace.ships(0).ship:HasAugmentation("LAB_FFF_BUFFER_EXTENDED_MEMORY") == 0) then
                    --if doing stuff clear the buffer
                    clear_particles(bufferParticles)
                    bufferParticles = {}
                    inputTimer = 0
                end
            else
                inputTimer = inputTimer + (Hyperspace.FPS.SpeedFactor * 4)
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
            shotTimer = shotTimer - (Hyperspace.FPS.SpeedFactor * 4)
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
        crewTable.hasBeenReset = hasBeenReset
    end--end buffer
end)


--rendering logic goes here, this should just be the attack animations.  Actually I can do those with particles, so this is just nothing?
script.on_render_event(Defines.RenderEvents.SHIP_MANAGER, function() end, function(ship)
    local shipManager = global:GetShipManager(ship.iShipId) --Manager for current ship
    for crewmem in vter(shipManager.vCrewList) do
        if (crewmem:GetSpecies() == "fff_buffer") then
            local crewTable = userdata_table(crewmem, TABLE_NAME_BUFFER)
            
            local shotsFired = crewTable.shotsFired
            if (shotsFired == nil) then
                shotsFired = {}
            end
                    --Once I figure out how to get reality to run arbitrary commands, I;ll have true magic.  Magic is telling reality what to do.
            --handle shots
            for i = #shotsFired, 1, -1 do
                local particle = shotsFired[i]
                if (lwl.damageFoesAtSpace(crewmem.iShipId, crewmem.currentShipId, particle.position, 0, 0, SHOT_DAMAGE)) then
                    Brightness.destroy_particle(particle)
                    table.remove(shotsFired, i)
                end
                --print("shots fired", lwl.dumpObject(shotsFired))todo
                --draw triangle
                local deltaX = particle.position.x - crewmem:GetPosition().x
                local deltaY = particle.position.y - crewmem:GetPosition().y
                local innerAngle = math.atan(deltaY, deltaX)
                local x1 = particle.position.x - 2*math.sin(innerAngle)
                local y1 = particle.position.y + 2*math.cos(innerAngle)
                local x2 = particle.position.x + 2*math.sin(innerAngle)
                local y2 = particle.position.y - 2*math.cos(innerAngle)
                local point1 = Hyperspace.Point(x1, y1)
                local point2 = Hyperspace.Point(x2, y2)
                Graphics.CSurface.GL_DrawTriangle(point1, point2, particle.shotOrigin, BLACK)
                if (particle.remainingDuration <= .1) then --idek what's happening here, TODO fix this maybe
                    table.remove(shotsFired, i)
                end
            end
            crewTable.shotsFired = shotsFired
        end--end of buffer
    end
end)