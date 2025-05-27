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
        print("renaming ", name, "to", NAMES[#mRenamedDanielIds])
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
