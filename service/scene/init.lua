local skynet = require "skynet"
local s = require "service"

local balls = {} -- [playerid] = ball
local foods = {} -- [foodid] = food
local max_foodid = 0
local food_count = 0

local ball = function()
    local M = {
        playerid = nil,
        node = nil,
        agent = nil,
        x = math.random(0, 100),
        y = math.random(0, 100),
        size = 2,
        vx = 0,
        vy = 0
    }
    return M
end


local food = function()
    local M = {
        id = nil,
        x = math.random(0, 100),
        y = math.random(0, 100),
        size = 2,
        vx = 0,
        vy = 0
    }
    return M
end

local ball_msg = function()
    local msg = {"balllist"}
    for i, v in pairs(balls) do
        table.insert(msg, v.playerid)
        table.insert(msg, v.x)
        table.insert(msg, v.y)
        table.insert(msg, v.size)
    end
    return msg
end

local food_msg = function()
    local msg = {"foodlist"}
    for _, food in pairs(foods) do
        table.insert(msg, food.id)
        table.insert(msg, food.x)
        table.insert(msg, food.y)
    end
    return msg
end

local broadcast = function(msg)
    for _, ball in pairs(balls) do
        s.send(ball.node, ball.agent, "send", msg)
    end
end

s.resp.enter = function(source, playerid, node, agent)
    if balls[playerid] then
        return false
    end
    local b = ball()
    b.playerid = playerid
    b.node = node
    b.agent = agent
    local entermsg = {"enter", playerid, b.x, b.y, b.size}
    broadcast(entermsg)
    balls[playerid] = b
    local retmsg = {"enter", 0, ""}
    s.send(b.node, b.agent, "send", retmsg)
    s.send(b.node, b.agent, "send", ball_msg())
    s.send(b.node, b.agent, "send", food_msg())
    return true
end

s.resp.leave = function(source, playerid)
    if not balls[playerid] then
        return false
    end
    balls[playerid] = nil
    local leavemsg = {"leave", playerid}
    broadcast(leavemsg)
    return true
end

s.resp.shift = function(source, playerid, x, y)
    if not balls[playerid] then
        return false
    end
    balls[playerid].vx = x
    balls[playerid].vy = y
    return true
end

function food_update()
    if food_count >= 50 then
        return
    end
    if math.random(1, 100) < 98 then
        return
    end

    max_foodid = max_foodid + 1
    food_count = food_count + 1
    local f = food()
    f.id = max_foodid
    foods[f.id] = f

    local msg = {"addfood", f.id, f.x, f.y}
    broadcast(msg)
end

function move_update()
    for i, v in pairs(balls) do
        v.x = v.x + v.vx * 0.2
        v.y = v.y + v.vy * 0.2
        if v.vx ~= 0 or v.vy ~= 0 then
            local msg = {"move", v.playerid, v.x, v.y}
            broadcast(msg)
        end
    end
end

function eat_update()
    for pid, b in pairs(balls) do
        for fid, f in pairs(foods) do
            if (b.x - f.x) ^ 2 + (b.y - f.y) ^ 2 < b.size ^ 2 then
                b.size = b.size + 1
                food_count = food_count - 1
                local msg = {"eat", pid, fid, b.size}
                broadcast(msg)
                foods[fid] = nil
            end
        end
    end
end

function update(frame)
    food_update()
    move_update()
    eat_update()
end

s.init = function()
    skynet.fork(function()
        local start_time = skynet.now()
        local frame = 0
        while true do
            frame = frame + 1
            local ret, err = pcall(update, frame)
            if not ret then
                s.log(err)
            end
            local now_time = skynet.now()
            local wait_time = 20 * frame - (now_time - start_time)
            if wait_time < 0 then
                wait_time = 2
            end
            skynet.sleep(wait_time)
        end
    end)
end

s.start(...)