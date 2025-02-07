﻿lia.command.add("charvoicetoggle", {
    adminOnly = true,
    privilege = "Toggle Voice Ban Character",
    syntax = "[string name]",
    AdminStick = {
        Name = L("toggleVoice"),
        Category = L("moderationTools"),
        SubCategory = L("miscellaneous"),
        Icon = "icon16/sound_mute.png"
    },
    onRun = function(client, arguments)
        local target = lia.command.findPlayer(client, arguments[1])
        if target == client then
            client:notify(L("cannotMuteSelf"))
            return false
        end

        if IsValid(target) then
            local char = target:getChar()
            if char then
                local isBanned = char:getData("VoiceBan", false)
                char:setData("VoiceBan", not isBanned)
                if isBanned then
                    client:notify(L("voiceUnmuted", target:Name()))
                    target:notify(L("voiceUnmutedByAdmin"))
                else
                    client:notify(L("voiceMuted", target:Name()))
                    target:notify(L("voiceMutedByAdmin"))
                end
            else
                client:notify(L("noValidCharacter"))
            end
        else
            client:notify(L("invalidTarget"))
        end
    end
})