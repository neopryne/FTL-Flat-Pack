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
local INPUT_DELAY = 40--120 --frames?
local OUTPUT_DELAY = 30
local TAU = math.pi * 2
local MOTION_SEED = math.random() --maybe have this different for all buffers?
local BROWNIAN_PERIOD = 210
local BROWNIAN_RANGE = 1
local LAYER_LAG = .3
local SHOT_DAMAGE = 4
local SHOT_BURST = 3
local PUNCH_DAMAGE = 4 --but it stuns
local PUNCH_STUN= .45 --but it stuns
local BLITZ_DAMAGE = 10

--[[
    buffer
    
    needs to modify the positions of all its particles each tick
    when firing, needs to iterate through its particles and move their positions up one, removing the latest
    
    blitz doesnt move anymore
    shots arent firing
--]]

local ID_PUNCH = 0
local ID_BLITZ = 1
local ID_SHOOT = 2
local TYPE_PUNCH = {name="punch", id=ID_PUNCH}
local TYPE_BLITZ = {name="blitz", id=ID_BLITZ}
local TYPE_SHOOT = {name="shoot", id=ID_SHOOT}

local function damageFoesInSameSpace(crewmem, damage, stunTime, directDamage)
    currentShipManager = global:GetShipManager(crewmem.currentShipId)
    foeShipManager = global:GetShipManager(1 - crewmem.iShipId)
    if (currentShipManager) then --null if not in combat
        foes_at_point = lwl.get_ship_crew_point(currentShipManager, foeShipManager, crewmem:GetPosition().x, crewmem:GetPosition().y)
        for j = 1, #foes_at_point do
            local foe = foes_at_point[j]
            foe.fStunTime = foe.fStunTime + stunTime
            foe:ModifyHealth(-damage)
            foe:DirectModifyHealth(-directDamage)
        end
    end
end

local function blitz(crewmem)
    currentShipManager = global:GetShipManager(crewmem.currentShipId)
    foeShipManager = global:GetShipManager(1 - crewmem.iShipId)
    soundControl:PlaySoundMix("fff_buffer_input", 3, false)
    newPoint = lwl.random_valid_space_point_adjacent(crewmem:GetPosition(), currentShipManager)
    if (newPoint ~= nil) then
        crewmem:SetPosition(newPoint)
    end
    damageFoesInSameSpace(crewmem, BLITZ_DAMAGE, 0, 0)
    --animate stuff
end

local function fireShot()
    print("BUFFER SHOT!")
    soundControl:PlaySoundMix("fff_buffer_shoot", 4, false)
    damageFoesInSameSpace(crewmem, SHOT_DAMAGE, 0, 0)
end

local function shoot(crewTable)
   --this has to call back into the main loop to proc the delayed effects.
    crewTable.shots = SHOT_BURST
end

local function punch(crewmem)
    soundControl:PlaySoundMix("fff_buffer_punch", 4, false)
    damageFoesInSameSpace(crewmem, PUNCH_DAMAGE, PUNCH_STUN, 0)
    --animate stuff
end

local function executeCommand(particleId, crewmem, crewTable)
    if (particleId == ID_SHOOT) then
        print("BUFFER SHOOT!")
        shoot(crewTable)
    elseif (particleId == ID_PUNCH) then
        print("BUFFER PUNCH!")
        punch(crewmem)
    elseif (particleId == ID_BLITZ) then
        print("BUFFER BLITZ!")
        blitz(crewmem)
    else
        print("Invalid particle id ", particleId)
    end
end 

--floatInPeriodicRange(0, 9, -1, 1, number)
local function floatInPeriodicRange(inputMin, inputMax, outputMin, outputMax, number)
    theta = TAU * number / (inputMax - inputMin)
    unscaledLength = math.sin(theta)
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
    
    rand = math.random(0, 2)
    if (rand >= 2) then
        addParticleInner(TYPE_SHOOT, crewmem, bufferParticles)
    elseif (rand >= 1) then
        addParticleInner(TYPE_BLITZ, crewmem, bufferParticles)
    else
        addParticleInner(TYPE_PUNCH, crewmem, bufferParticles)
    end
end

--return updated list of particles
local function fireParticle(crewmem, bufferParticles, crewTable)
    local particle = bufferParticles[1]
    if (particle == nil) then
        print("fired nil!")
        return bufferParticles
    end
    executeCommand(particle.fff_buffer_id, crewmem, crewTable)
    --pull the stack down
    for j = #bufferParticles, 2, -1 do
        bufferParticles[j].position = bufferParticles[j - 1].position
    end
    Brightness.destroy_particle(particle)
    table.remove(bufferParticles, 1)
    return bufferParticles
end

script.on_internal_event(Defines.InternalEvents.ACTIVATE_POWER, function(power, ship)
    print("Power used!")
    if power.crew:GetSpecies() == "fff_buffer" then
        print("Was buffer!")
        userdata_table(power.crew, "mods.flatpack.biderman").goingOff = true
        soundControl:PlaySoundMix("fff_buffer_launch", 5, false)
    end
end)

--on-tick mechanical logic goes here.
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
    if (crewmem:GetSpecies() == "fff_buffer") then
        local shipManager = global:GetShipManager(crewmem.iShipId)
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
        local shots = crewTable.shots
        if (shots == nil) then
            shots = 0
        end
        --end load vars
        
        if (goingOff) then
            --shouldn't be controlable, stun immune, immune to death? --lab upgrade
            lwl.dumpObject(bufferParticles)
            if #bufferParticles == 0 then
                goingOff = false
                outputTimer = 0
            else
                outputTimer = outputTimer - 1
                if (outputTimer <= 0) then
                    bufferParticles = fireParticle(crewmem, bufferParticles, crewTable)
                    outputTimer = OUTPUT_DELAY
                end
            end
        else
            --not going off
            if (crewmem.bActiveManning or crewmem.bDead or crewmem:Repairing()) then
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
        
        if (shots > 0) then
            shotTimer = shotTimer - 1
            if (shotTimer <= 0) then
                shotTimer = OUTPUT_DELAY / SHOT_BURST
                shots = shots - 1
                fireShot()
            end
        end
        
        
        --print(crewmem.bActiveManning, crewmem:Repairing(), crewmem.bDead)
        
    
        repositionBufferStack(crewmem, bufferParticles, brownianTime)
        brownianTime = brownianTime + 1 --could be less
        --Finally write back to table
        crewTable.shots = shots
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
            crewShipManager = global:GetShipManager(1 - crewmem.iShipId) --Manager for enemy crew
            local crewTable = userdata_table(crewmem, "mods.flatpack.biderman")
            pos = crewmem:GetPosition()
            

            local is_combat = crewmem.bFighting --i don't think this matters here.

                
        end--end of buffer
    end
end)