local userdata_table = mods.multiverse.userdata_table
local TILE_SIZE = 35
local REDIRECT_RADIUS = TILE_SIZE * 2

--wait, i probably need to make this only apply on your ship, for the lib version
-- otherwise enemy crew will freak the fuck out.  shipid == 0 for your ship.


script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
  if (crewmem:GetSpecies() == "fff_f22") then
    local new_room = 0
    local new_slot = 0
    --print(crewmem.currentSlot.roomId)
    local crewTable = userdata_table(crewmem, "mods.flatpack.crewDestinationTracker")
    --local shipManager = Global.GetShipManager(crewmem.iShipId)
    if crewTable.previousDestination and
        (crewmem.currentSlot.roomId ~= crewTable.previousDestination.roomId or crewmem.currentSlot.slotId ~= crewTable.previousDestination.slotId) then

        --print("Crew ", crewmem:GetLongName(), " changed destination!  old ", crewTable.previousDestination.roomId, " ", crewTable.previousDestination.slotId, "new ", crewmem.currentSlot.roomId, " ", crewmem.currentSlot.slotId)

        --print(id)
        local x = crewmem.currentSlot.worldLocation.x
        local y = crewmem.currentSlot.worldLocation.y
        --local new_dest_point = mods.vertexutil.random_point_radius(crewmem.currentSlot.worldLocation, REDIRECT_RADIUS)
        --inlining until I know how to depend on libs
        local r = REDIRECT_RADIUS*math.random()
        local theta = 2*math.pi*(math.random())
        local new_dest_point = Hyperspace.Pointf(x + r*math.cos(theta), y + r*math.sin(theta))
        
        
        --check if point is valid, pulled from vertexutils because I don't have a shipmanager
        local shunted = false
        new_room = Hyperspace.ShipGraph.GetShipInfo(crewmem.iShipId):GetSelectedRoom(new_dest_point.x, new_dest_point.y, false)
        while new_room == -1 do
          shunted = true
          --redo circle stuff, but smaller
          r = math.min(0, r - .5)
          theta = 2*math.pi*(math.random())
          new_dest_point = Hyperspace.Pointf(x + r*math.cos(theta), y + r*math.sin(theta))
          new_room = Hyperspace.ShipGraph.GetShipInfo(crewmem.iShipId):GetSelectedRoom(new_dest_point.x, new_dest_point.y, false)
          print("moved to non-room position, shunting closer")
        end
        
        --failed to land in a room, shunt loop towards original destination and inflict damage/stun.  reduce radius until it is zero.
        --print("moved to new room position")
        --redirect crew to location.  Random slot for now due to limitations, will make it actually use the real position soon.
        
        local shipGraph = Hyperspace.ShipGraph.GetShipInfo(crewmem.iShipId)
        local shape = shipGraph:GetRoomShape(new_room)
        local width = shape.w / TILE_SIZE
        local height = shape.h / TILE_SIZE
        local count_of_tiles_in_room = width * height
        new_slot = math.floor(math.random() * count_of_tiles_in_room) --assumes zero-indexed
        --print("old ", crewmem.currentSlot.roomId, " ", crewmem.currentSlot.slotId, "new ", new_room, " ", new_slot)
        --crewmem:SetRoomPath(new_room, new_slot) --does this do anything? seems to not work.
        --crewmem.currentSlot.roomId = new_room
        --crewmem.currentSlot.slotId = new_slot
        crewmem:MoveToRoom(new_room, new_slot, false)--doesn nothing. what's force do here?
        
        if shunted then
          print("shunted xn combob")
        end
        crewTable.previousDestination = {roomId = new_room, slotId = new_slot}

    else--need to check for updates and put them here.  Assumes SetRoomPath actually works, we can clobber it if it doesn't.
        crewTable.previousDestination = {roomId = crewmem.currentSlot.roomId, slotId = crewmem.currentSlot.slotId}
    end
  end
  
end)

--LMC will have a check for f22 and exclude it to prevent double coverage.  until I can test both together.
--also what if the spot i pick is occupied?  hmm maybe problem.