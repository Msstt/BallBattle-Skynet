local skynet = require "skynet"
local runconfig = require "runconfig"

skynet.start(function()
    skynet.error("[main] start")
    skynet.newservice("gateway", "gateway", 1)
    skynet.exit()
end)