local skynet = require "skynet"
require "skynet.manager"
local runconfig = require "runconfig"
local s = require "service"
local socket = require "skynet.socket"

local node = skynet.getenv("node")

function shutdown_gateway()
    for node, _ in pairs(runconfig.cluster) do
        for i, v in pairs(runconfig[node].gateway or {}) do
            local name = "gateway" .. i
            s.call(node, name, "shutdown")
        end
    end
end

function shutdown_agent()
    while true do
        local online_num = s.call(runconfig.agentmgr.node, "agentmgr", "shutdown", 1)
        if online_num <= 0 then
            break
        end
        skynet.sleep(100)
    end
end

function stop()
    shutdown_gateway()
    shutdown_agent()
    skynet.abort()
end

function connect(client, address)
    socket.start(client)
    socket.write(client, "Please enter cmd\r\n")
    local cmd = socket.readline(client, "\r\n")
    if cmd == "stop" then
        stop()
    end
end

s.init = function()
    
    local server = socket.listen("127.0.0.1", runconfig.admin[node])
    socket.start(server, connect)
end

s.start(...)