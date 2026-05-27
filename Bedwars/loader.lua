loadstring(game:HttpGet("https://raw.githubusercontent.com/likegenmMain/bedwars/refs/heads/main/Bedwars/Script.lua", true))()

local queue_on_teleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or queueonteleport

if queue_on_teleport then
    local teleportCode = [[
        task.wait(1)
        if game.GameId == 2619619496 then
            loadstring(game:HttpGet("https://raw.githubusercontent.com/likegenmMain/bedwars/refs/heads/main/Bedwars/Script.lua", true))()
        end
    ]]
    queue_on_teleport(teleportCode)
end
