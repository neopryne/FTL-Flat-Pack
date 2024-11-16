local vter = mods.multiverse.vter

--add shoot sounds
--if I want danny to have more than one ability, this needs to change.
script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
        if (crewmem:GetSpecies() == "fp_unique_phantom") then
            if (crewmem.health.first <= 1) then
                crewmem.health.first = 100
                print("? ", crewmem.extend.crewPowers)
                local i = 1
                for power in vter(crewmem.extend.crewPowers) do
                    if (i <= 1) then
                        power:PreparePower()
                        power:ActivatePower()
                        print("activated! ", i, power)
                    end
                    i = 2 --this is the worst way to do this
                end
            end
        end
    end)