local vter = mods.multiverse.vter

local LASER_FORGE_BLUEPRINTS = {"FM_LASER_ANOMALY_1", "FM_CHAINGUN_FIRE", "FM_FLAMETHROWER", "FM_PHASER_SUFFOCATION",
         "FM_LASER_PHOTON", "FM_LASER_PHOTON_2", "FM_LASER_HUMAN", "FM_LASER_ION_MEGA", "FM_SURGE_LASER"}
local ION_FORGE_BLUEPRINTS = {"FM_ENERGY_DISC", "FM_ION_TRI_FIRE", "FM_CHAINGUN_ION", "FM_SHOTGUN_ENERGY",
         "FM_PULSE_1", "FM_PULSE_2", "FM_PULSE_3", "FM_PULSEDEEP"}
local BEAM_FORGE_BLUEPRINTS = {"FM_BEAM_MINING_2", "FM_BEAM_PARTICLE_PIERCE", "FM_BEAM_GUILLOTINE_CHAIN",
        "FM_BEAM_EXPLOSION", "FM_BEAM_ION_PIERCE", "FM_BEAM_ETERNITY", "BEAM_PRISM_SCATTER"}
local PINPOINT_FORGE_BLUEPRINTS = {"FM_FOCUS_FUELED_1", "FM_FOCUS_ENERGY_1",
        "FM_FOCUS_ENERGY_2", "FM_FOCUS_ENERGY_3", "FM_FOCUS_ENERGY_CONS", "FM_FOCUS_VIRUS", "FM_FOCUS_ADAPT", "FM_BEAM_MINING_3"}
local FLAK_FORGE_BLUEPRINTS = {"FM_SHOTGUN_ANOMALY", "FM_SHOTGUN_BRONZE", "FM_SHOTGUN_AETHER", "FM_SHOTGUN_CURSED", "FM_ENERGY_RAILBLENDER"}
local EXPLOSIVES_FORGE_BLUEPRINTS = {"FM_MISSILES_BURST_FIRE", "FM_MISSILES_CLOAK_STUN", "FM_BOMB_CRYSTAL_FIRE", "FM_BOMB_CRYSTAL_BIO",
        "FM_MINELAUNCHER_HULL", "FM_MINELAUNCHER_BIO", "FM_ION_MISSILES", "FM_IMPRISMENT_INDUCER", "FM_RVS_AC_CHARGE",
        "MAMMOTH_CANNON"}
local DRONE_FORGE_BLUEPRINTS = {"FM_ENERGY_COMBAT_BEAM1", "FM_AMBER_DRONE", "FM_CRYSTAL_DRONE", "FM_CURA_DRONE",
        "FM_FLAMETHROWER_DRONE", "FM_FORGEMAN_DRONE", "FM_ISHIMURA_DRONE", "FM_KESTREL_DRONE", "FM_MFK_KESTREL_DRONE", "FM_MFK_PICKET_DRONE",
        "FM_SIREN_DRONE"}
local ORGANIC_FORGE_BLUEPRINTS = {"FM_BEAM_BASILISK"}
--[[
Show most weapon blueprints in the crafting menu.
Also reorder the crafting menus to use 1 for back.
]]

local function processWeaponBlueprints(choiceBox, event, blueprintNames)
	local i = 1
	for choice in vter(choiceBox:GetChoices()) do
        local index = i - 1
        if i > 1 and index <= #blueprintNames then
            choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(blueprintNames[index])
        end
		i = i + 1
	end
end

local function processDroneBlueprints(choiceBox, event, blueprintNames)
	local i = 1
	for choice in vter(choiceBox:GetChoices()) do
        local index = i - 1
        if i > 1 and index <= #blueprintNames then
            choice.rewards.drone = Hyperspace.Blueprints:GetDroneBlueprint(blueprintNames[index])
        end
		i = i + 1
	end
end


script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	if event.eventName == "FM_FORGE_WEAPON_FLAK" then
		processWeaponBlueprints(choiceBox, event, FLAK_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_LASER" then
		processWeaponBlueprints(choiceBox, event, LASER_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_ION" then
		processWeaponBlueprints(choiceBox, event, ION_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_BEAM" then
		processWeaponBlueprints(choiceBox, event, BEAM_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_PINPOINT" then
		processWeaponBlueprints(choiceBox, event, PINPOINT_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_EXPLOSIVES" then
		processWeaponBlueprints(choiceBox, event, EXPLOSIVES_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_COMBAT_DRONE" then
		processDroneBlueprints(choiceBox, event, DRONE_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_ORGANIC" then
		processWeaponBlueprints(choiceBox, event, ORGANIC_FORGE_BLUEPRINTS)
	end
end)