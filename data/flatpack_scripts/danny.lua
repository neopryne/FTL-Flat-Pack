local vter = mods.multiverse.vter
local lwl = mods.lightweight_lua

local FALLBACK_NAME = "ERROR DANIEL"
local NAMES = {"Daniel", "Dark Daniel", "Alive Daniel", "Ghost-King Daniel"}

local mRenamedDanielIds = {}

local function setName(crewmem)
    local name = crewmem:GetName()
    if name == FALLBACK_NAME or (#lwl.getNewElements({name}, NAMES) == 0) then return end
    if #mRenamedDanielIds < #NAMES then
        mRenamedDanielIds = lwl.setMerge(mRenamedDanielIds, {crewmem.extend.selfId})
        --print("renaming ", name, "to", NAMES[#mRenamedDanielIds])
        lwl.setCrewName(crewmem, NAMES[#mRenamedDanielIds])
    else
        lwl.setCrewName(crewmem, FALLBACK_NAME)
    end
end

--add shoot sounds
--if I want danny to have more than one ability, this needs to change.
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
        if (crewmem:GetSpecies() == "fp_unique_phantom") or (crewmem:GetSpecies() == "fp_unique_phantom_ghost") then
            --print(lwl.dumpObject(mRenamedDanielIds))
            setName(crewmem)
        end
        if (crewmem:GetSpecies() == "fp_unique_phantom") then
            if (crewmem.health.first <= 1) then
                crewmem.bDead = false
                crewmem.health.first = 100
                local activated = false
                for power in vter(crewmem.extend.crewPowers) do
                    if not activated then
                        power:PreparePower()
                        power:ActivatePower()
                    end
                    activated = true --this is the second worst way to do this
                end
            end
        end
    end)


local LASER_FORGE_BLUEPRINTS = {"FM_LASER_ANOMALY_1", "FM_CHAINGUN_FIRE", "FM_FLAMETHROWER", "FM_PHASER_SUFFOCATION",
         "FM_LASER_PHOTON", "FM_LASER_PHOTON_2", "FM_LASER_HUMAN", "FM_LASER_ION_MEGA", "FM_SURGE_LASER", "FM_GATLING_ANCIENT"}
local ION_FORGE_BLUEPRINTS = {"FM_ENERGY_DISC", "FM_ION_TRI_FIRE", "FM_CHAINGUN_ION", "FM_SHOTGUN_ENERGY",
         "FM_PULSE_1", "FM_PULSE_2", "FM_PULSE_3", "FM_PULSEDEEP"}
local BEAMPOINT_FORGE_BLUEPRINTS = {"FM_BEAM_MINING_2", "FM_BEAM_MINING_3", "FM_BEAM_PARTICLE_PIERCE", "FM_BEAM_GUILLOTINE_CHAIN",
        "FM_BEAM_EXPLOSION", "FM_FOCUS_FUELED_1", "FM_FOCUS_ENERGY_1", "FM_FOCUS_ENERGY_2", "FM_FOCUS_ENERGY_3",
        "FM_FOCUS_ENERGY_CONS", "FM_FOCUS_VIRUS", "FM_FOCUS_ADAPT", "FM_BEAM_ION_PIERCE", "FM_BEAM_ETERNITY",
        "BEAM_PRISM_SCATTER", }
local FLAK_FORGE_BLUEPRINTS = {"FM_SHOTGUN_ANOMALY", "FM_SHOTGUN_BRONZE", "FM_SHOTGUN_AETHER", "FM_SHOTGUN_CURSED", "FM_ENERGY_RAILBLENDER"}

local function processBlueprints(choiceBox, event, blueprintNames)
	local i = 2
	for choice in vter(choiceBox:GetChoices()) do
        local index = i - 1
        if index <= #blueprintNames then
            print("adding", blueprintNames[index], "to", choice.text)
            choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(blueprintNames[index])
        end
		i = i + 1
	end
end



script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	print(event.eventName)
	if event.eventName == "FM_FORGE_WEAPON_FLAK" then
		processBlueprints(choiceBox, event, FLAK_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_LASER" then
		processBlueprints(choiceBox, event, LASER_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_ION" then
		processBlueprints(choiceBox, event, ION_FORGE_BLUEPRINTS)
    elseif event.eventName == "FM_FORGE_WEAPON_BEAM" then
		processBlueprints(choiceBox, event, BEAMPOINT_FORGE_BLUEPRINTS)
	end
end)