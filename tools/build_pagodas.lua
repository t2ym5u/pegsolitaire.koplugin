-- build_pagodas.lua — finds pagoda functions that prune the solver's search,
-- one set per (board, goal hole) used by a big puzzle, by cutting planes:
--   1. search from many positions near the puzzle starts, collecting the
--      positions the solver proves dead the slow way (not cut by a pagoda);
--   2. for the biggest of those, solve the LP
--         maximise p(goal) - sum of p over its pegs
--         subject to p(a) + p(b) >= p(c) for every jump,
--                    -2 <= p <= 2, p(goal) <= 1
--      a positive optimum is a pagoda that proves that position dead at once;
--   3. keep it (scaled to integers and checked exactly), repeat.
-- Small puzzles (under MIN_PEGS) are solved instantly and get none.
-- Usage: luajit build_pagodas.lua --list        the board:goal groups needing pagodas
--        luajit build_pagodas.lua <board:goal>  one group's entry (a Lua fragment)
-- build_pagodas.sh runs every group in parallel and writes ../pagodas_data.lua.

local here = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = here .. "../?.lua;" .. here .. "?.lua;" .. package.path
local Geometry = require("geometry")
local Solver   = require("solver")
local LP       = require("lp")

local MIN_PEGS  = 20
local ROUNDS    = tonumber(os.getenv("PAGODA_ROUNDS") or 20)
local PER_ROUND = 6
local MAX_LP    = 300
local LO, HI    = 2, 2      -- weights live in [-LO, HI]: solved as q = p + LO >= 0

local function pagodaFor(geo, goal, X)
    local n = geo.n
    local c, A, b = {}, {}, {}
    for i = 1, n do c[i] = (X[i] == 1) and -1 or 0 end
    c[goal] = c[goal] + 1
    for m = 1, geo.nmoves do
        local row = {}
        for i = 1, n do row[i] = 0 end
        row[geo.A[m]] = row[geo.A[m]] - 1
        row[geo.B[m]] = row[geo.B[m]] - 1
        row[geo.C[m]] = row[geo.C[m]] + 1
        A[#A + 1], b[#b + 1] = row, -LO
    end
    for i = 1, n do
        local row = {}
        for j = 1, n do row[j] = (i == j) and 1 or 0 end
        A[#A + 1], b[#b + 1] = row, ((i == goal) and 1 or HI) + LO
    end
    local x = LP.maximize(c, A, b)
    if not x then return nil end
    local v = x[goal] - LO
    for i = 1, n do if X[i] == 1 then v = v - (x[i] - LO) end end
    if v < 1e-6 then return nil end
    for _, d in ipairs({ 1, 2, 3, 4, 6, 8, 12, 24 }) do
        local ok, p = true, {}
        for i = 1, n do
            local y = (x[i] - LO) * d
            local r = math.floor(y + 0.5)
            if math.abs(y - r) > 1e-6 then ok = false break end
            p[i] = r
        end
        if ok then return p end
    end
    return nil
end

local function prunes(geo, goal, p, X)
    local s = 0
    for i = 1, geo.n do if X[i] == 1 then s = s + p[i] end end
    return s < p[goal]
end

local function generate(geo, goal, starts)
    local n = geo.n
    local pagodas = {}
    math.randomseed(12345)
    local function randomRoot()
        local P = {}
        local s = starts[math.random(#starts)]
        for i = 1, n do P[i] = s[i] end
        for _ = 1, math.random(0, 12) do
            local legal = {}
            for m = 1, geo.nmoves do
                if P[geo.A[m]] == 1 and P[geo.B[m]] == 1 and P[geo.C[m]] == 0 then legal[#legal + 1] = m end
            end
            if #legal == 0 then break end
            local m = legal[math.random(#legal)]
            P[geo.A[m]], P[geo.B[m]], P[geo.C[m]] = 0, 0, 1
        end
        return P
    end
    for round = 1, ROUNDS do
        local found, seen = {}, {}
        for _ = 1, 30 do
            local s = Solver.new(geo, goal, pagodas)
            s.on_dead = function(P, left)
                if left >= 6 then
                    local key = table.concat(P)
                    if not seen[key] then
                        seen[key] = true
                        local X = {}
                        for i = 1, n do X[i] = P[i] end
                        found[#found + 1] = { X = X, left = left }
                    end
                end
            end
            s:solve(randomRoot(), 200000)
        end
        table.sort(found, function(u, v) return u.left > v.left end)
        local added, tried = 0, 0
        for _, f in ipairs(found) do
            -- Most dead positions on some boards have no single-pagoda
            -- proof: cap the LPs per round so a round stays short.
            if added >= PER_ROUND or tried >= MAX_LP then break end
            local cut = false
            for _, p in ipairs(pagodas) do
                if prunes(geo, goal, p, f.X) then cut = true break end
            end
            if not cut then
                tried = tried + 1
                local p = pagodaFor(geo, goal, f.X)
                if p and Solver.isPagoda(geo, p) and prunes(geo, goal, p, f.X) then
                    pagodas[#pagodas + 1] = p
                    added = added + 1
                end
            end
        end
        io.stderr:write(string.format("  round %d: %d dead seen, %d added (%d total)\n",
            round, #found, added, #pagodas))
        if added == 0 then break end
    end
    return pagodas
end

local puzzles = dofile(here .. "../puzzles_data.lua")
local groups, order = {}, {}
for _, pz in ipairs(puzzles) do
    local geo = Geometry.get(pz.board)
    local pegs = Geometry.decode(geo, pz.pegs)
    local count = 0
    for i = 1, geo.n do count = count + pegs[i] end
    if count >= MIN_PEGS then
        local key = pz.board .. ":" .. pz.goal
        if not groups[key] then
            groups[key] = { geo = geo, goal = pz.goal, starts = {} }
            order[#order + 1] = key
        end
        table.insert(groups[key].starts, pegs)
    end
end

if arg[1] == "--list" then
    for _, key in ipairs(order) do print(key) end
    return
end
local key = arg[1]
local g = assert(groups[key], "no such group: " .. tostring(key))
local list = generate(g.geo, g.goal, g.starts)
print(string.format("    [%q] = {", key))
for _, p in ipairs(list) do print("        { " .. table.concat(p, ",") .. " },") end
print("    },")
