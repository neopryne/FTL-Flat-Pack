



-- local FLAK_FORGE_BLUEPRINTS = {"FM_SHOTGUN_ANOMALY", "FM_SHOTGUN_BRONZE", "FM_SHOTGUN_AETHER", "FM_SHOTGUN_CURSED", "FM_ENERGY_RAILBLENDER"}

-- local function processFlakBlueprints(choiceBox, event)
-- 	local i = 1
-- 	for choice in vter(choiceBox:GetChoices()) do
-- 		if i % 2 == 1 then
-- 			local index = math.ceil(i/2)
-- 			if index <= #FLAK_FORGE_BLUEPRINTS then
-- 				print("adding", FLAK_FORGE_BLUEPRINTS[index], "to", choice.text)
-- 				choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(FLAK_FORGE_BLUEPRINTS[index])
-- 			end
-- 		end
-- 		i = i + 1
-- 	end
-- end

-- script.on_internal_event(Defines.InternalEvents.POST_CREATE_CHOICEBOX, function(choiceBox, event)
-- 	print(event.eventName)
-- 	if event.eventName == "FM_FORGE_WEAPON_FLAK" then
-- 		processFlakBlueprints(choiceBox, event)
-- 	end
-- 	-- 	
-- 	-- 	
-- 	-- elseif string.sub(event.eventName, 1, 15) == "OG_CRAFT_CRAFT_" then
-- 	-- 	local weapon = string.sub(event.eventName, 16, string.len(event.eventName))
-- 	-- 	local i = 1
-- 	-- 	for choice in vter(choiceBox:GetChoices()) do
-- 	-- 		if i == 2 then
-- 	-- 			choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint(weapon)
-- 	-- 		end
-- 	-- 		i = i + 1
-- 	-- 	end
-- 	-- elseif string.sub(event.eventName, 1, 16) == "OG_CRAFT_HIDDEN_" then
-- 	-- 	local weapon = string.sub(event.eventName, 17, string.len(event.eventName))
-- 	-- 	local i = 1
-- 	-- 	for choice in vter(choiceBox:GetChoices()) do
-- 	-- 		if i == 2 then
-- 	-- 			choice.rewards.weapon = Hyperspace.Blueprints:GetWeaponBlueprint("OG_TURRET_UNKNOWN")
-- 	-- 		end
-- 	-- 		i = i + 1
-- 	-- 	end
-- 	-- end
-- end)