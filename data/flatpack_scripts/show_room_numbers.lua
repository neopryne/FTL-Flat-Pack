local lwl = mods.lightweight_lua
local vter = mods.multiverse.vter


--only prints last row for some reason.
script.on_render_event(Defines.RenderEvents.SHIP_SPARKS, function() end, function(ship)
    shipManager = Hyperspace.ships(ship.iShipId)
    local shipGraph = Hyperspace.ShipGraph.GetShipInfo(shipManager.iShipId)
    for room in vter(shipGraph.rooms) do
        local shape = shipGraph:GetRoomShape(room.iRoomId)
        Graphics.CSurface.GL_SetColor(Graphics.GL_Color(0, 0, 0, 1))
        Graphics.freetype.easy_print(8, shape.x + 5, shape.y, tostring(math.floor(room.iRoomId)))
        local width = shape.w / lwl.TILE_SIZE
        local height = shape.h / lwl.TILE_SIZE
        local count_of_tiles_in_room = width * height
        for i = 1, width do
            for j = 1, height do
                x = shape.x - 15 + (lwl.TILE_SIZE * i)
                y = shape.y - 15 + (lwl.TILE_SIZE * j)
                local slot = lwl.slotIdAtPoint(Hyperspace.Point(x,y), shipManager)
                Graphics.freetype.easy_print(8, x, y, tostring(math.floor(slot)))
            end
        end
    end
end)
