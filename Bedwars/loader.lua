loadstring(game:HttpGet("https://raw.githubusercontent.com/likegenmMain/bedwars/refs/heads/main/Bedwars/Script.lua", true))()

local queue_on_teleport = queue_on_teleport or syn.queue_on_teleport or fluxus.queue_on_teleport

if queue_on_teleport then
    queue_on_teleport([[
        if game.GameId == 2619619496 then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/likegenmMain/bedwars/refs/heads/main/Bedwars/Script.lua", true))()
        end
    ]])
end
