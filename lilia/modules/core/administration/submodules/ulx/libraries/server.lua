local MODULE = MODULE
util.AddNetworkString("NetTicket")
util.AddNetworkString("TicketSync")
util.AddNetworkString("UpdateTicketStatus")
MODULE.Active = {}
net.Receive("TicketSync", function()
    MODULE.Active = net.ReadTable()
    net.Start("TicketSync")
    net.WriteTable(MODULE.Active)
    net.Broadcast()
end)

function MODULE:NewTicket(ply, msg)
    net.Start("NetTicket")
    net.WriteEntity(ply)
    net.WriteString(msg)
    net.WriteInt(#MODULE.Active + 1, 8)
    net.Broadcast()
    MODULE.Active[ply] = {
        active = true,
        claimer = nil
    }

    net.Start("TicketSync")
    net.WriteTable(MODULE.Active)
    net.Broadcast()
end

lia.command.add("ticket", {
    adminOnly = false,
    onRun = function(client)
        client:requestString("Enter Ticket Details", "Please provide a brief description for your ticket.", function(text)
            MODULE:NewTicket(client, text)
            lia.log.add(client, "ticketOpen")
        end)
    end
})

net.Receive("UpdateTicketStatus", function(_, client)
    local ticketState = net.ReadBool()
    if ticketState then
        hook.Run("OnTicketTaken", client)
        lia.log.add(client, "ticketTook")
    else
        hook.Run("OnTicketClosed", client)
        lia.log.add(client, "ticketClosed")
    end
end)

function MODULE:InitializedModules()
    MsgC(Color(255, 0, 0), "WE DO NOT RECOMMEND THE USE OF ULX AS IT MAY CREATE PERFOMANCE ISSUES!" .. "\n")
end

hook.Remove("PlayerSay", "ULXMeCheck")
lia.log.addType("ticketOpen", function(client) return string.format("%s opened a ticket.", client:Name()) end, "Tickets", Color(255, 0, 0), "Tickets")
lia.log.addType("ticketTook", function(client) return string.format("%s took a ticket.", client:Name()) end, "RT  Tickets", Color(255, 0, 0), "Tickets")
lia.log.addType("ticketClosed", function(client) return string.format("%s closed a ticket.", client:Name()) end, "Tickets", Color(255, 0, 0), "Tickets")