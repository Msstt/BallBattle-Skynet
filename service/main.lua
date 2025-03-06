local skynet = require "skynet"
require "skynet.manager"
local runconfig = require "runconfig"
local cluster = require "skynet.cluster"

skynet.start(function()
    skynet.error("[main] start")

    local node = skynet.getenv("node")
    local nodeconfig = runconfig[node]

    -- debug
    skynet.newservice("debug_console", "127.0.0.1", nodeconfig.debug.port)
    -- admin
    skynet.newservice("admin", "admin", 0)
    -- 节点管理
    local nodemgr = skynet.newservice("nodemgr", "nodemgr", 0)
    -- 集群
    cluster.reload(runconfig.cluster)
    cluster.open(node)
    -- gateway
    for i, v in pairs(nodeconfig.gateway or {}) do
        local srv = skynet.newservice("gateway", "gateway", i)
    end
    -- login
    for i, v in pairs(nodeconfig.login or {}) do
        local srv = skynet.newservice("login", "login", i)
    end
    -- scene
    for _, sid in pairs(runconfig.scene[node] or {}) do
        local srv = skynet.newservice("scene", "scene", sid)
    end

    -- agentmgr
    if runconfig.agentmgr.node == node then
        local srv = skynet.newservice("agentmgr", "agentmgr", 0)
    else
        local proxy = cluster.proxy(runconfig.agentmgr.node, "agentmgr")
        skynet.name("agentmgr", proxy)
    end

    skynet.exit()
end)
