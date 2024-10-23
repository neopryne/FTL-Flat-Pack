local userdata_table = mods.multiverse.userdata_table
local vter = mods.multiverse.vter
local lwl = mods.lightweight_lua
local get_room_at_location = mods.vertexutil.get_room_at_location
local random_point_radius = mods.vertexutil.random_point_radius
local TILE_SIZE = 35
local REDIRECT_RADIUS = TILE_SIZE * 2
local ENEMY_SHIP = 1
local DASH_DAMAGE = 10
local global = Hyperspace.Global.GetInstance()
local soundControl = global:GetSoundControl()

local function damage_enemy_helper(activeCrew, currentRoom, bystander)
      --print(bystander:GetLongName(), "room ", bystander.iRoomId, " ", currentRoom, " ", bystander.currentShipId == activeCrew.currentShipId)
    if bystander.iRoomId == currentRoom and bystander.iShipId == ENEMY_SHIP and bystander.currentShipId == activeCrew.currentShipId then
        --print(bystander:GetLongName(), " was in the same room!")
        bystander:DirectModifyHealth(-DASH_DAMAGE)
    end
end

local function damage_enemy_crew(activeCrew, currentRoom)
        -- Modified from brightlord's modification of Arc's get_ship_crew_room(). Determines the crew of either team in a room.
    if (Hyperspace.ships.enemy) then
      for bystander in vter(Hyperspace.ships.enemy.vCrewList) do
          damage_enemy_helper(activeCrew, currentRoom, bystander)
      end
    end
    --do the same for friendly ship
    for bystander in vter(Hyperspace.ships.player.vCrewList) do
        damage_enemy_helper(activeCrew, currentRoom, bystander)
    end
end


script.on_internal_event(Defines.InternalEvents.CREW_LOOP, function(crewmem)
  if (crewmem:GetSpecies() == "fff_f22") then
    local shipManager = global:GetShipManager(crewmem.currentShipId)
    local new_room = 0
    local new_slot = 0
    --print(crewmem.currentSlot.roomId)
    local crewTable = userdata_table(crewmem, "mods.flatpack.crewDestinationTracker")
    if crewTable.previousDestination and
        (crewmem.currentSlot.roomId ~= crewTable.previousDestination.roomId or crewmem.currentSlot.slotId ~= crewTable.previousDestination.slotId) then
          crewTable.moving_to_new_dest = true
        --print("Crew ", crewmem:GetLongName(), " changed destination!  old ", crewTable.previousDestination.roomId, " ", crewTable.previousDestination.slotId, "new ", crewmem.currentSlot.roomId, " ", crewmem.currentSlot.slotId)

        --print(id)
        local x = crewmem.currentSlot.worldLocation.x
        local y = crewmem.currentSlot.worldLocation.y
        radius = REDIRECT_RADIUS
        local new_dest_point = random_point_radius(crewmem.currentSlot.worldLocation, radius)

        crewTable.shunted = false
        new_room = get_room_at_location(shipManager, new_dest_point, false)
        --failed to land in a room, shunt loop towards original destination. reduce radius until it is zero.
        while new_room == -1 do
          crewTable.shunted = true
          --redo circle stuff, but smaller.  You can upgrade the lab to reduce the circle size.
          radius = math.min(0, radius - .5)
          new_dest_point = random_point_radius(crewmem.currentSlot.worldLocation, radius)
          new_room = get_room_at_location(shipManager, new_dest_point, false)
          --print("moved to non-room position, shunting closer")
        end
        
        --redirect crew to location.  Random slot for now due to limitations, will make it actually use the real position soon.
        crewmem:MoveToRoom(new_room, lwl.randomSlotRoom(new_room, crewmem.currentShipId), false)
        soundControl:PlaySoundMix("fff_f22_dash", 3, false)
        
        crewTable.previousDestination = {roomId = new_room, slotId = new_slot}
    else
        crewTable.previousDestination = {roomId = crewmem.currentSlot.roomId, slotId = crewmem.currentSlot.slotId}
    end
    --Check if we've reached the end of movement
    local current_room = get_room_at_location(shipManager, crewmem:GetPosition(), false)
    --print("current_room: ", current_room, " position ", crewmem:GetPosition().x, " ", crewmem:GetPosition().y)
    --print("moving to ", crewmem.currentSlot.roomId, " new? ", crewTable.moving_to_new_dest)
    if (crewTable.moving_to_new_dest and current_room == crewmem.currentSlot.roomId) then
        crewTable.moving_to_new_dest = false
        soundControl:PlaySoundMix("fff_f22_boom", 3, false)
        damage_enemy_crew(crewmem, current_room)
        if crewTable.shunted then
          --print("shunted xn combob")
          crewmem.fStunTime = .5 + ((1 - (crewmem:GetIntegerHealth() / crewmem:GetMaxHealth())) * 8.5) -- scale stun with health loss
          crewmem:ModifyHealth(-5)
        end
    end
  end
end)