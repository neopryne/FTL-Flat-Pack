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


local FLAK_FORGE_BLUEPRINTS = {"FM_SHOTGUN_ANOMALY", "FM_SHOTGUN_BRONZE", "FM_SHOTGUN_AETHER", "FM_SHOTGUN_CURSED", "FM_ENERGY_RAILBLENDER"}

local function processBlueprints(choiceBox, event, blueprintNames)
	local i = 2
	for choice in vter(choiceBox:GetChoices()) do
        local index = i - 1
        if index <= #FLAK_FORGE_BLUEPRINTS then
            print("adding", FLAK_FORGE_BLUEPRINTS[index], "to", choice.text)
            choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(FLAK_FORGE_BLUEPRINTS[index])
        end
		i = i + 1
	end
end

local function processFlakBlueprints(choiceBox, event)
	local i = 1
	for choice in vter(choiceBox:GetChoices()) do
        local index = i
        if index <= #FLAK_FORGE_BLUEPRINTS then
            print("adding", FLAK_FORGE_BLUEPRINTS[index], "to", choice.text)
            choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(FLAK_FORGE_BLUEPRINTS[index])
        end
		i = i + 1
	end
end

script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
	print(event.eventName)
	if event.eventName == "FM_FORGE_WEAPON_FLAK" then
		processFlakBlueprints(choiceBox, event)
	end
	-- 	
	-- 	
	-- elseif string.sub(event.eventName, 1, 15) == "OG_CRAFT_CRAFT_" then
	-- 	local weapon = string.sub(event.eventName, 16, string.len(event.eventName))
	-- 	local i = 1
	-- 	for choice in vter(choiceBox:GetChoices()) do
	-- 		if i == 2 then
	-- 			choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
	-- 		end
	-- 		i = i + 1
	-- 	end
	-- elseif string.sub(event.eventName, 1, 16) == "OG_CRAFT_HIDDEN_" then
	-- 	local weapon = string.sub(event.eventName, 17, string.len(event.eventName))
	-- 	local i = 1
	-- 	for choice in vter(choiceBox:GetChoices()) do
	-- 		if i == 2 then
	-- 			choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint("OG_TURRET_UNKNOWN")
	-- 		end
	-- 		i = i + 1
	-- 	end
	-- end
end)