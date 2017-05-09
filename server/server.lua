
Server = { port = 80, clients = {}, connections = {} }

function Server.getMacByIp(ip1)
    local table1 = wifi.ap.getclient()
    for mac, ip in pairs(table1) do
        if ip == ip1 then
            return mac
        end
    end
end

function Server.sendToMac(mac, data)
    local _, json = pcall(cjson.encode, data)
    pcall(function()
        Server.connections[mac]:send(json .. " ")
        print("out:", mac, json)
    end)
end

function Server.startPingTimer()
    tmr.alarm(1, 1000, 1, function()
        for mac, v in pairs(Server.clients) do
            if v < Clock.seconds - 5 and v >= Clock.seconds - 10 then
                Server.sendToMac(mac, { action = "ping" })
            end
            if v < Clock.seconds - 16 then
                print("Client not responding to pings, deauth: ", mac)
                wifi.ap.deauth(mac)
                Server.clients[mac] = nil
                Server.connections[mac] = nil
                if Game.currentNode == mac then
                    Game.repeatStep()
                end
            end
        end
    end)
end

function Server.start(callback)

    Server.socket = net.createServer(net.TCP)
    Server.socket:listen(Server.port, function(connection)

        local _, ip = connection:getpeer()
        Server.clients[Server.getMacByIp(ip)] = Clock.seconds
        Server.connections[Server.getMacByIp(ip)] = connection

        connection:on("connection", function(_, _)
            local _, ip = connection:getpeer()
            print("New client", Server.getMacByIp(ip))
            Server.sendToMac(Server.getMacByIp(ip), { action = "config", config = Game.config })
            if not Game.running then
                Game.startAfter(2)
            end
        end)

        connection:on("receive", function(connection, bundledData)
            for data in string.gmatch(bundledData, "%S+") do
                callback(connection, data)
            end
        end)

    end)

    Server.startPingTimer()

end
