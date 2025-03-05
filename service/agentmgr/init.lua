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

s.start(...)