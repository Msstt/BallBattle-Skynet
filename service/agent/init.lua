local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"

s.client = {}
s.gate = nil

local node = skynet.getenv("node")
local nodeconfig = runconfig[node]

s.resp.client = function(source, fd, cmd, msg)
    s.gate = source
    if s.client[cmd] then
        local result = s.client[cmd](msg)
        s.send(node, source, "send_by_fd", fd, result)
    else
        s.log(cmd .. "is missing")
    end
end

s.init = function()
    skynet.sleep(200)
    s.data = {coin = 100}
end

s.leave_scene = function()
    if not s.scene_name then return end
    s.call(s.scene_node, s.scene_name, "leave", s.id)
    s.scene_node = nil
    s.scene_name = nil
end

s.resp.kick = function(source)
    s.leave_scene()
    skynet.sleep(200)
end

s.resp.exit = function(source) skynet.exit() end

s.resp.send = function(source, msg)
    s.send(node, s.gate, "send", s.id, msg)
end

s.client.work = function()
    s.data.coin = s.data.coin + 1;
    return {"work", s.data.coin}
end

local function random_scene()
    local nodes = {}
    for i, v in pairs(runconfig.scene) do
        table.insert(nodes, i)
        if runconfig.scene[node] then table.insert(nodes, node) end
    end
    local scene_node = nodes[math.random(1, #nodes)]
    local scenes = runconfig.scene[scene_node]
    local scene_id = scenes[math.random(1, #scenes)]
    return scene_node, scene_id
end

s.client.enter = function()
    if s.scene_name then return {"enter", 1, "have in scene"} end
    local scene_node, scene_id = random_scene()
    local scene_name = "scene" .. scene_id
    local ret = s.call(scene_node, scene_name, "enter", s.id, node,
                       skynet.self())
    if not ret then return {"enter", 1, "enter scene failed"} end
    s.scene_node = scene_node
    s.scene_name = scene_name
    return {"enter", 0, ""}
end

s.client.shift = function(msg)
    if not s.scene_name then return end
    local x = msg[2] or 0
    local y = msg[3] or 0
    s.call(s.scene_node, s.scene_name, "shift", s.id, x, y)
    return {"shift", 0, ""}
end

s.start(...)
