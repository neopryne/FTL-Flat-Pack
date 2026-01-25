
local lwl = mods.lightweight_lua
local lwk = mods.lightweight_keybinds

--[[
Limrix Adaptive Repair Terminal

]]

local SYSTEM_NAME = "limrix_adaptive_repair"
local SYSTEM_POWER_HOTKEY = Defines.SDL_KEY_h --whatever cloak uses by default.
local SYSTEM_ACTIVATE_HOTKEY = Defines.SDL_KEY_c

local MIN_REPAIR_AMOUNT = 3
local REPAIR_SCALING = .75

local mDamageTaken = 0
local mSavedHull
local mLastKeyDown


---Utility function to check if the SystemBox instance is for our customs system
---@param systemBox Hyperspace.SystemBox
---@return boolean
local function isCorrectSystem(systemBox)
    local systemName = Hyperspace.ShipSystem.SystemIdToName(systemBox.pSystem.iSystemType)
    return systemName == SYSTEM_NAME and systemBox.bPlayerUI
end

local function systemInstalled()
    --Return true if the ship has the given system.
end



local function activate(power)
    local allowedHeal = math.max(3, math.floor(mDamageTaken * REPAIR_SCALING))
    local actualHeal = math.min(power, allowedHeal)
    Hyperspace.ships.player:DamageHull(actualHeal * -1, false)
    --play sound or something
    --breach sound if that's enabled
    return actualHeal
end







script.on_internal_event(Defines.InternalEvents.SYSTEM_BOX_KEY_DOWN, function(systemBox, key, shift)
    if Hyperspace.metaVariables.limrix_system_hotkey_enabled == 0 and ((not mLastKeyDown) or mLastKeyDown ~= key) and isCorrectSystem(systemBox) then
        --print("press key:"..key.." shift:"..tostring(shift))
        mLastKeyDown = key
        local shipManager = Hyperspace.ships.player
        if not Hyperspace.ships.player:HasSystem(Hyperspace.ShipSystem.NameToSystemId(SYSTEM_NAME)) then return end
        if key == SYSTEM_POWER_HOTKEY then
            local repairSystem = shipManager:GetSystem(Hyperspace.ShipSystem.NameToSystemId(SYSTEM_NAME))
            if shift then
                repairSystem:DecreasePower(true)
            else
                repairSystem:IncreasePower(1, false)
            end
        end
    end
end)

script.on_internal_event(Defines.InternalEvents.ON_KEY_UP, function(key)
    mLastKeyDown = nil
end)






--[[
This system is unmanned, no skilling required.

]]





---Applies heals that happen after sector turns.
---@param ship Hyperspace.ShipManager
local function time_passes(ship)
    --reset damage taken
    mDamageTaken = 0
    mSavedHull = Hyperspace.ships.player.ship.hullIntegrity.first
end

script.on_internal_event(Defines.InternalEvents.JUMP_ARRIVE, function(ship) -- only player ships trigger JUMP_ARRIVE
    time_passes(ship)
end)

script.on_internal_event(Defines.InternalEvents.ON_WAIT, function(ship) -- similar
    time_passes(ship)
end)


