local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"

s.client = {}
s.gate = nil

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

s.init = function()
    skynet.sleep(200)
    s.data = {
        coin = 100
    }
end

s.resp.kick = function(source)
    skynet.sleep(200)
end

s.resp.exit = function(source)
    skynet.exit()
end

s.client.work = function()
    s.data.coin = s.data.coin + 1;
    return {"work", s.data.coin}
end

s.start(...)