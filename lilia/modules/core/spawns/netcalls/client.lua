﻿net.Receive("death_client", function()
    local date = lia.time.GetFormattedDate("%Y-%m-%d %H:%M:%S", true, true, true, true, true) -- Formatting the date
    local charid = net.ReadFloat()
    local steamid = net.ReadString()
    chat.AddText(Color(255, 0, 0), "[DEATH]: ", Color(255, 255, 255), date, " - You were killed by ", Color(255, 215, 0), "Character ID: ", Color(255, 255, 255), charid, " (", Color(0, 255, 0), steamid, Color(255, 255, 255), ")")
end)