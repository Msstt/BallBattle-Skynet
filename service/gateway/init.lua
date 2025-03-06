local skynet = require "skynet"
local socket = require "skynet.socket"
local s = require "service"
local runconfig = require "runconfig"

local connects = {} -- [fd] = conn
local players = {} -- [playerid] = gateplayer

local node = skynet.getenv("node")
local nodeconfig = runconfig[node]

local close = false

function conn()
    local M = {fd = nil, playerid = nil}
    return M
end

function player()
    local M = {
        playerid = nil,
        agent = nil,
        connect = nil,
        key = math.random(1, 99999999),
        lost_connect_time = nil,
        msgcache = {}
    }
    return M
end

local msg_unpack = function(str)
    local msg = {}
    while true do
        local arg, rest = string.match(str, "(.-),(.*)")
        if arg then
            table.insert(msg, arg)
            str = rest
        else
            table.insert(msg, str)
            break
        end
    end
    return msg[1], msg
end

local msg_pack = function(cmd, msg) return table.concat(msg, ",") .. "\r\n" end

local process_reconnect = function(client, msg)
    local playerid = tonumber(msg[2])
    local key = tonumber(msg[3])
    if not players[playerid] then return end
    if players[playerid].connect then return end
    if connects[client].playerid then return end
    if players[playerid].key ~= key then return end
    players[playerid].connect = client
    connects[client].playerid = playerid
    s.resp.send_by_fd(nil, client, {"reconnect", 0})
    for i, msg in pairs(players[playerid].msgcache) do
        s.resp.send_by_fd(nil, client, msg)
    end
    players[playerid].msgcache = {}
end

local process_msg = function(client, str)
    local cmd, msg = msg_unpack(str)
    s.log("Receive from" .. client .. " [" .. cmd .. "] {" ..
              table.concat(msg, ",") .. "}")

    local conn = connects[client]
    if cmd == "reconnect" then
        process_reconnect(client, msg)
    elseif not conn.playerid then
        local login = "login" .. math.random(1, #nodeconfig.login)
        s.send(node, login, "client", client, cmd, msg)
    else
        s.send(node, players[conn.playerid].agent, "client", client, cmd, msg)
    end
end

local process_buffer = function(client, read_buffer)
    while true do
        local msg, rest = string.match(read_buffer, "(.-)\r\n(.*)")
        if msg then
            process_msg(client, msg)
            read_buffer = rest
        else
            return read_buffer
        end
    end
end

local disconnect = function(fd)
    if not connects[fd] then return end
    local playerid = connects[fd].playerid
    if players[playerid] then
        players[playerid].connect = nil
        skynet.timeout(300 * 100, function()
            if players[playerid].connect then return end
            s.log("kick " .. playerid .. " becase reconnect timeout")
            s.send(runconfig.agentmgr.node, "agentmgr", "reqkick", playerid,
                   "reconnect timeout")
        end)
        -- s.send(runconfig.agentmgr.node, "agentmgr", "reqkick", playerid,
        --        "sign out")
    end
end

local recv_loop = function(client)
    socket.start(client)
    local read_buffer = ""
    while true do
        local recv_str = socket.read(client)
        if recv_str then
            read_buffer = read_buffer .. recv_str
            read_buffer = process_buffer(client, read_buffer)
        else
            s.log("Socket close.")
            disconnect(client)
            connects[client] = nil
            socket.close(client)
            break
        end
    end
end

local connect = function(client, address)
    if close then return end
    s.log("Connect from: " .. address)
    local c = conn();
    c.fd = client;
    connects[c.fd] = c;
    skynet.fork(recv_loop, client)
end

function s.init()
    local port = nodeconfig.gateway[s.id].port

    local server = socket.listen("0.0.0.0", port)
    socket.start(server, connect)
    s.log("Listen socket: 0.0.0.0:" .. port)
end

s.resp.send_by_fd = function(source, fd, msg)
    if not connects[fd] then return end
    local str = msg_pack(msg[1], msg)
    s.log(
        "Send to " .. fd .. ": [" .. msg[1] .. "] {" .. table.concat(msg, ",") ..
            "}")
    socket.write(fd, str)
end

s.resp.send = function(source, playerid, msg)
    if not players[playerid] then return end
    if not players[playerid].connect then
        table.insert(players[playerid].msgcache, msg)
        local len = #players[playerid].msgcache
        if len > 500 then
            s.call(runconfig.agentmgr.node, "agentmgr", "reqkick", playerid,
                   "msgcache fill")
        end
        return
    end
    s.resp.send_by_fd(source, players[playerid].connect.fd, msg)
end

s.resp.sure_agent = function(source, fd, playerid, agent)
    if not connects[fd] then
        s.send(runconfig.agentmgr.node, "agentmgr", "reqkick", playerid,
               "socket close")
        return false
    end

    connects[fd].playerid = playerid
    players[playerid] = player()
    players[playerid].playerid = playerid
    players[playerid].agent = agent
    players[playerid].connect = connects[fd]

    s.resp.send(nil, playerid, {"reconnect", players[playerid].key})

    return true
end

s.resp.kick = function(source, playerid)
    if not players[playerid] then return end
    local c = players[playerid].connect
    players[playerid] = nil
    if not c then return end
    disconnect(c.fd)
    connects[c.fd] = nil
    socket.close(c.fd)
end

s.resp.shutdown = function(source)
    close = true
    s.log("gateway have shutdown")
end

s.start(...)
