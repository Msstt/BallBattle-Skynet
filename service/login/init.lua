local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"

s.client = {}

local node = skynet.getenv("node")
local nodeconfig = runconfig[node]

s.resp.client = function(source, fd, cmd, msg)
    if s.client[cmd] then
        local result = s.client[cmd](fd, msg, source)
        s.send(node, source, "send_by_fd", fd, result)
    else
        s.log(cmd .. "is missing")
    end
end

s.client.login = function(fd, msg, source)
    local playerid = tonumber(msg[2])
    local pw = tonumber(msg[3])
    local gate = source
    if pw ~= 123 then
        return {"login", 1, "password error"}
    end
    local ret, agent = s.call(runconfig.agentmgr.node, "agentmgr", "reqlogin", playerid, node, gate)
    if not ret then
        return {"login", 1, "agentmgr's reqlogin failed"}
    end
    local ret = s.call(node, gate, "sure_agent", fd, playerid, agent)
    if not ret then
        return {"login", 1, "gateway's sure_agent failed"}
    end
    s.log(playerid .. " login success")
    return {"login", 0, ""}
end

s.start(...)