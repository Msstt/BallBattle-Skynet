local skynet = require "skynet"
require "skynet.manager"
local cluster = require "skynet.cluster"

local M = {name = "", id = 0, exit = nil, init = nil, resp = {}}

function traceback(err)
    skynet.error(err)
    skynet.error(debug.traceback())
end

local dispatch = function(session, address, cmd, ...)
    local func = M.resp[cmd]
    if not func then
        skynet.ret()
        return
    end

    local ret = table.pack(xpcall(func, traceback, address, ...))
    if not ret[1] then
        skynet.ret()
        return
    end
    skynet.retpack(table.unpack(ret, 2))
end

function init()
    if M.id ~= 0 then
        skynet.register("." .. M.name .. M.id)
    else
        skynet.register("." .. M.name)
    end
    skynet.dispatch("lua", dispatch)
    if M.init then M.init() end
end

function M.start(name, id, ...)
    M.name = name
    M.id = tonumber(id)
    skynet.start(init)
end

function M.call(node, srv, ...)
    local mynode = skynet.getenv("node")
    if type(srv) == "string" then
        srv = "." .. srv
    end
    if node == mynode then
        return skynet.call(srv, "lua", ...)
    else
        return cluster.call(node, srv, ...)
    end
end

function M.send(node, srv, ...)
    local mynode = skynet.getenv("node")
    if type(srv) == "string" then
        srv = "." .. srv
    end
    if node == mynode then
        return skynet.send(srv, "lua", ...)
    else
        return cluster.send(node, srv, ...)
    end
end

function M.log(log)
    if M.id ~= 0 then
        skynet.error("[" .. M.name .. "_" .. M.id .. "] " .. log)
    else
        skynet.error("[" .. M.name .. "] " .. log)
    end
end

return M
