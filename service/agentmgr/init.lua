local skynet = require "skynet"
local s = require "service"
local runconfig = require "runconfig"

local node = skynet.getenv("node")
local nodeconfig = runconfig[node]

STATUS = {
    LOGIN = 2,
    GAME = 3,
    LOGOUT = 4
}

local players = {}

function mgrplayer()
    local M = {
        playerid = nil,
        node = nil,
        status = nil,
        agent = nil,
        gate = nil
    }
    return M
end

s.resp.test = function(source)
    s.log("hh")
    return true
end

s.resp.reqlogin = function(source, playerid, node, gate)
    local player = players[playerid]
    if player and player.status == STATUS.LOGIN then
        s.log(playerid .. "'s reqlogin fail because player is login")
        return false
    end
    if player and player.status == STATUS.LOGOUT then
        s.log(playerid .. "'s reqlogin fail because player is logout")
        return false
    end
    if player then -- 强制下线
        local node = player.node
        local gate = player.gate
        local agent = player.agent
        player.status = STATUS.LOGOUT
        s.call(node, agent, "kick")
        s.send(node, agent, "exit")
        s.send(node, gate, "send", playerid, {"kick", "other device login"})
        s.send(node, gate, "kick", playerid)
    end
    local player = mgrplayer();
    player.playerid = playerid
    player.node = node
    player.gate = gate
    player.status = STATUS.LOGIN
    players[playerid] = player
    local agent = s.call(node, "nodemgr", "newservice", "agent", "agent", playerid)
    player.agent = agent
    player.status = STATUS.GAME
    return true, agent
end

s.resp.reqkick = function(source, playerid, reason)
    local player = players[playerid]
    if not player then
        return false
    end
    if player.status ~= STATUS.GAME then
        return false
    end
    local node = player.node
    local gate = player.gate
    local agent = player.agent
    player.status = STATUS.LOGOUT

    s.call(node, agent, "kick")
    s.send(node, agent, "exit")
    s.send(node, gate, "kick", playerid)
    players[playerid] = nil

    return true
end

local get_online_count = function()
    local num = 0
    for i, v in pairs(players) do
        num = num + 1
    end
    return num
end

s.resp.shutdown = function(source, num)
    local count = get_online_count()
    local n = 0
    for playerid, player in pairs(players) do
        skynet.fork(s.resp.reqkick, nil, playerid, "server close.")
        n = n + 1
        if n >= num then
            break
        end
    end
    while true do
        skynet.sleep(200)
        if count - get_online_count() == n then
            break
        end
    end
    return get_online_count()
end

s.start(...)