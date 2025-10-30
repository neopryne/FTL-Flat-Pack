mods.lightweight_projectiles = {}
local lwp = mods.lightweight_projectiles

local Brightness = mods.brightness
local lwl = mods.lightweight_lua
local lwst = mods.lightweight_stable_time

lwp.ALLEGIANCE_PLAYER = 0
lwp.ALLEGIANCE_ENEMY = 1

local mProjectileList = {}--self indexing list or something, or whatever way I have to iterate things.  lwl I think.






------------------------Projectile Utils----------------------------

lwl.verticalWall = function(point)
    local justLeft = Hyperspace.Point(point.x - 1, point.y)
    local justRight = Hyperspace.Point(point.x + 1, point.y)
    local roomLeft = lwl.getRoomAtLocation(justLeft)
    local roomRight = lwl.getRoomAtLocation(justRight)

    print("vert wall", roomLeft, roomRight)
    return (roomLeft == nil and roomRight ~= nil) or (roomLeft ~= nil and roomRight == nil)
end

lwl.horizontalWall = function(point)
    local justAbove = Hyperspace.Point(point.x, point.y - 1)
    local justBelow = Hyperspace.Point(point.x, point.y + 1)
    local roomAbove = lwl.getRoomAtLocation(justAbove)
    local roomBelow = lwl.getRoomAtLocation(justBelow)
    print("horiz wall", roomAbove, roomBelow)
    return (roomAbove == nil and roomBelow ~= nil) or (roomAbove ~= nil and roomBelow == nil)
end

--By Claude Sonnet 4.5
-- Function to find parabola through three points
-- Returns a function that computes y = ax^2 + bx + c
--todo if this fails, just make the bomb a bullet instead.
lwl.parabolaThroughPoints = function(p1, p2, p3)
    local x1, y1 = p1.x, p1.y
    local x2, y2 = p2.x, p2.y
    local x3, y3 = p3.x, p3.y
    
    -- Check if points have same x-coordinate (would make system unsolvable)
    if x1 == x2 or x2 == x3 or x1 == x3 then
        error("Points must have distinct x-coordinates")
    end
    
    -- Solve system of equations using Cramer's rule
    -- For y = ax^2 + bx + c, we have:
    -- y1 = a*x1^2 + b*x1 + c
    -- y2 = a*x2^2 + b*x2 + c
    -- y3 = a*x3^2 + b*x3 + c
    
    local x1_sq = x1 * x1
    local x2_sq = x2 * x2
    local x3_sq = x3 * x3
    
    -- Calculate determinant of coefficient matrix
    local det = x1_sq * (x2 - x3) - x1 * (x2_sq - x3_sq) + (x2_sq * x3 - x3_sq * x2)
    
    if math.abs(det) < 1e-10 then
        error("Points are collinear (no unique parabola)")
    end
    
    -- Calculate coefficients using Cramer's rule
    local a = (y1 * (x2 - x3) - y2 * (x1 - x3) + y3 * (x1 - x2)) / det
    local b = (x1_sq * (y2 - y3) - x2_sq * (y1 - y3) + x3_sq * (y1 - y2)) / det
    local c = (x1_sq * (x2 * y3 - x3 * y2) - x1 * (x2_sq * y3 - x3_sq * y2) + y1 * (x2_sq * x3 - x3_sq * x2)) / det
    
    -- Return the parabola function
    return function(x)
        return a * x * x + b * x + c
    end, a, b, c
end
------------------------End Projectile Utils----------------------------
------------------------Particle Utils----------------------------

Brightness.reflectParticle = function(particle)
    --local ftlHeading = lwl.angleBrightnessToFtl(particle.heading)
    if lwl.verticalWall(particle.position) then
        particle.heading = 180 - particle.heading
    end
    if lwl.horizontalWall(particle.position) then
        particle.heading = 360 - particle.heading
    end
    --Uh, figure out how to reflect angles across axis.
end

---comment
---@param particle table particle created with Brightness.create_particle.
---@return boolean true if the particle has been destroyed and false otherwise.
Brightness.isDestroyed = function(particle)
    return particle.indexNum == -1
end
------------------------End Particle Utils----------------------------




local function onTick()
    for _,projectile in ipairs(mProjectileList) do
        if not Brightness.isDestroyed(projectile) then
            if projectile.onTick(projectile) then
                Brightness.destroy_particle(projectile.particle)
            end
        end
    end

    --Remove any particles that have been destroyed.
    lwl.arrayRemove(mProjectileList, function (table, index)
        return not (Brightness.isDestroyed(table[index]))
    end)
end
lwst.registerOnTick(onTick, false)


--Bullet stuff
--Generally, bullets have some out of bounds condition where they despawn, and a hit function where they deal damage to a target.
--The lifetime of these objects are determined by their underlying particles.  Most pods have a simple animation, if any.
--Most bombs and bullets do not have animations.


------------------------API----------------------------

---comment
---@param particle table particle created with Brightness.create_particle.
---@param onTick function run each tick while the game is not paused.
---@  It takes a projectile and should return true if the projectile should destroy itself, and false otherwise.
---@param allegiance number Which side the bullet is fighting for. 0 for the player, 1 for foes.
lwp.createProjectile = function(particle, onTick, allegiance)
    local projectile = {particle=particle, onTick=onTick, allegiance=allegiance}
    table.insert(mProjectileList, projectile)
end

lwp.despawnOutsideRooms = function(projectile)
    local currentRoom = lwl.getRoomAtLocation(projectile.particle.position)
    return currentRoom == nil
end

---comment
---@param damage any
---@param stun any
---@param directDamage any
---@param despawnFunction any
---@return function
lwp.createBulletOnTickFunction = function(damage, stun, directDamage, despawnFunction)
    damage = lwl.setIfNil(damage, 0)
    stun = lwl.setIfNil(stun, 0)
    directDamage = lwl.setIfNil(directDamage, 0)
    return function(projectile)
        local particle = projectile.particle
        if not particle.space then
            error("Bullets only work relative to ships, not in global space.")
            return true
        end --doesn't work for global particles, don't use this.
        if despawnFunction(projectile) then
            return true
        end
        --else, see if you can damage foes at space.
        return lwl.damageFoesAtSpace(projectile.allegiance, particle.space, particle.position, damage, stun, directDamage)
    end
end

lwp.createNormalBullet = function(damage, stun, directDamage)
    return lwp.createBulletOnTickFunction(damage, stun, directDamage, lwp.despawnOutsideRooms)
end

lwp.createPodOnTickFunction = function(damage, stun, directDamage)
    damage = lwl.setIfNil(damage, 0)
    stun = lwl.setIfNil(stun, 0)
    directDamage = lwl.setIfNil(directDamage, 0)
    return function(projectile)
        local particle = projectile.particle
     
        Brightness.reflectParticle(particle)
        particle.rotation = particle.heading
        return lwl.damageFoesAtSpace(projectile.allegiance, particle.space, particle.position, damage, stun, directDamage)
    end
end

--todo make this function in both x directions

---Usage:
---function createBomb(internalBombType, bombParticle, endPos)
---     return lwp.createBombOnTickFunction(internalBombType.damage, internalBombType.stun, internalBombType.directDamage, etc...)
---end
---@param damage any
---@param stun any
---@param directDamage any
---@param startPos any
---@param endPos any
---@param arcHeight any
---@param horizontalSpeed any
---@param explosionPath any
---@param explosionNumFrames any
---@param explosionDuration any
---@return function
lwp.createBombOnTickFunction = function(damage, stun, directDamage, startPos, endPos, arcHeight, horizontalSpeed, explosionPath, explosionNumFrames, explosionDuration)
    damage = lwl.setIfNil(damage, 0)
    stun = lwl.setIfNil(stun, 0)
    directDamage = lwl.setIfNil(directDamage, 0)

    local midpointX = startPos.x + ((endPos.x - startPos.x) / 2)
    local apogeePoint = Hyperspace.Pointf(midpointX, startPos.y + arcHeight)
    local parabolaFunction = lwl.parabolaThroughPoints(startPos, apogeePoint, endPos)
    if endPos.x < startPos.x then --go the other way
        horizontalSpeed = -horizontalSpeed
    end

    if parabolaFunction == nil then
        --Failed to make a parabola, behave like a bullet as a fallback.
        --point the bomb at the target pos in preperation for it being a bullet and give it a speed
        local bulletFunction = lwp.createNormalBullet(damage, stun, directDamage)
        return function(projectile)
            projectile.movementSpeed = horizontalSpeed
            projectile.heading = lwl.angleFtlToBrightness(lwl.getAngle(startPos, endPos))
            projectile.rotation = projectile.heading
            bulletFunction(projectile)
        end
    end
    
    local function advanceProjectile(projectile)
        local particle = projectile.particle
        local previousX = particle.position.x
        local newX = previousX + horizontalSpeed
        local newY = parabolaFunction(newX)
        local newPoint = Hyperspace.Pointf(newX, newY)
        --calculate heading with the rough derivative of the function.
        local newHeading = lwl.getAngle(particle.position, newPoint)
        particle.rotation = lwl.angleFtlToBrightness(newHeading)
        particle.position = newPoint
    end

    --[[
    explode if has passed the halfway point (apogee) horizontally, and is below or to the opposite side of the endPos.
    ]]
    return function (projectile)
        advanceProjectile(projectile)
        local particle = projectile.particle
        if particle.position.x > endPos.x then
            --explode
            Brightness.create_particle(explosionPath, explosionNumFrames, explosionDuration,
                particle.position, particle.rotation, particle.space, particle.renderEvent)
            --Damage guys
            return true
        end
    end
end
------------------------END API----------------------------

--[[
onTick
    Check if any particles have been destroyed, and if so, remove them from the list.
    --particle.indexNum == -1 iff a particle is destroyed.

    run the onTick method of each particle.  bullets don't have any, but bombs and pods do.  Bombs move in an arc, so all their movement is done here.

    Check if any projectiles meet their trigger condition, if so, destroy them and run their onDestroy with several arguments.
    And remove them from the projectile list.
]]