-- ---------------------------------------------------------------------------
-- solver.lua — decides whether a position can still be reduced to one peg in
-- the goal hole, and finds the jumps that do it. Pure Lua; used on the device
-- (hints, the "unsolvable" warning) and by the offline tools.
--
-- Depth-first search over jumps with three things that keep it small:
--   * a memo of positions already proved dead, keyed on the position up to the
--     board's symmetries that fix the goal hole (one proof covers up to 8
--     mirror images). It lives as long as the Solver, across calls, so every
--     question makes the next one cheaper, and a budget-limited search can be
--     resumed by asking again;
--   * pagoda functions (built offline by tools/gen_pagodas.lua): weights w
--     with w(a) + w(b) >= w(c) for every jump a over b into c, so the weighted
--     peg count never grows. A jump that takes it below the goal's weight
--     leads nowhere and is not even tried;
--   * a node budget. Past it the search stops and answers "unknown" rather
--     than freezing a slow e-reader; the caller says so honestly.
--
-- Positions are arrays of 0/1, one per hole (geometry.lua numbering).
-- ---------------------------------------------------------------------------

local Solver = {}
Solver.__index = Solver

-- Above this many proved-dead positions the memo starts over. A LuaJIT hash
-- node is 24 bytes and the table grows by powers of two: 2^19 nodes, about
-- 12 MB, at the cap. Smaller caps make the hardest proofs thrash.
Solver.MEMO_CAP = 500000

-- geo: from geometry.lua. goal: the hole the last peg must end in.
-- pagodas: optional list of weight arrays (one weight per hole); only the
-- valid ones that give the goal a positive weight are kept.
function Solver.new(geo, goal, pagodas)
    local self = setmetatable({ geo = geo, goal = goal }, Solver)
    local n, A, B, C = geo.n, geo.A, geo.B, geo.C

    -- Symmetries that keep the goal where it is: one weight table each, so a
    -- position's key under every symmetry can be kept up to date per jump.
    self.W = {}
    for _, perm in ipairs(geo.syms) do
        if perm[goal] == goal then
            local w = {}
            for i = 1, n do w[i] = 2 ^ (perm[i] - 1) end
            self.W[#self.W + 1] = w
        end
    end

    self.pagodas = {}
    for _, p in ipairs(pagodas or {}) do
        if #p == n and (p[goal] or 0) > 0 and Solver.isPagoda(geo, p) then
            self.pagodas[#self.pagodas + 1] = p
        end
    end

    -- Per jump: how it changes each key and each pagoda sum.
    self.DK, self.DP = {}, {}
    for m = 1, geo.nmoves do
        local a, b, c = A[m], B[m], C[m]
        local dk, dp = {}, {}
        for s, w in ipairs(self.W) do dk[s] = w[c] - w[a] - w[b] end
        for q, p in ipairs(self.pagodas) do dp[q] = p[c] - p[a] - p[b] end
        self.DK[m], self.DP[m] = dk, dp
    end

    -- Jump order: the jump that most reduces the sum of squared distances to
    -- the goal first. Outlying pegs come in early, as people solve these
    -- boards, and a solvable position's solution turns up far sooner than
    -- with board order.
    local gx, gy = geo.holes[goal].x, geo.holes[goal].y
    local function dist(i)
        local h = geo.holes[i]
        return (h.x - gx) ^ 2 + (h.y - gy) ^ 2
    end
    local score, order = {}, {}
    for m = 1, geo.nmoves do
        score[m] = dist(C[m]) - dist(A[m]) - dist(B[m])
        order[m] = m
    end
    table.sort(order, function(m1, m2)
        if score[m1] ~= score[m2] then return score[m1] < score[m2] end
        return m1 < m2
    end)
    self.order = order
    self.dead, self.ndead = {}, 0
    return self
end

function Solver.isPagoda(geo, p)
    for m = 1, geo.nmoves do
        if (p[geo.A[m]] or 0) + (p[geo.B[m]] or 0) < (p[geo.C[m]] or 0) then return false end
    end
    return true
end

-- Canonical key of a position (smallest of its symmetric images).
function Solver:key(pegs)
    local best
    for _, w in ipairs(self.W) do
        local k = 0
        for i = 1, #pegs do
            if pegs[i] == 1 then k = k + w[i] end
        end
        if not best or k < best then best = k end
    end
    return best
end

-- Was this position proved dead earlier, or cut by a pagoda?
function Solver:isKnownDead(pegs)
    if self.dead[self:key(pegs)] then return true end
    for _, p in ipairs(self.pagodas) do
        local v = 0
        for i = 1, #pegs do
            if pegs[i] == 1 then v = v + p[i] end
        end
        if v < p[self.goal] then return true end
    end
    return false
end

-- Searches from `pegs` (not modified). Returns
--   "yes", path   -- path: list of jump numbers that ends with one peg in goal
--   "no"          -- proved impossible
--   "unknown"     -- the budget ran out first
-- plus the number of nodes visited.
function Solver:solve(pegs, budget)
    local geo = self.geo
    local n, goal = geo.n, self.goal
    local A, B, C = geo.A, geo.B, geo.C
    local order, nm = self.order, geo.nmoves
    local S, NP = #self.W, #self.pagodas
    local DK, DP = self.DK, self.DP
    local dead = self.dead
    budget = budget or math.huge

    local P, count = {}, 0
    for i = 1, n do
        P[i] = pegs[i] == 1 and 1 or 0
        count = count + P[i]
    end
    if count == 0 then return "no", nil, 0 end
    if count == 1 then
        if P[goal] == 1 then return "yes", {}, 0 end
        return "no", nil, 0
    end
    if self:isKnownDead(P) then return "no", nil, 0 end

    -- Running keys (one per symmetry) and pagoda sums.
    local K = {}
    for s, w in ipairs(self.W) do
        local k = 0
        for i = 1, n do if P[i] == 1 then k = k + w[i] end end
        K[s] = k
    end
    local PS, PGOAL = {}, {}
    for q, p in ipairs(self.pagodas) do
        local v = 0
        for i = 1, n do if P[i] == 1 then v = v + p[i] end end
        PS[q], PGOAL[q] = v, p[goal]
    end

    local nodes, aborted = 0, false
    local path = {}
    local on_dead = self.on_dead

    local function dfs(depth, left)
        nodes = nodes + 1
        if left == 1 then return P[goal] == 1 end
        if nodes > budget then aborted = true return false end
        local ck = K[1]
        for s = 2, S do
            if K[s] < ck then ck = K[s] end
        end
        if dead[ck] then return false end
        for t = 1, nm do
            local m = order[t]
            local a, b, c = A[m], B[m], C[m]
            if P[a] == 1 and P[b] == 1 and P[c] == 0 then
                local dp, cut = DP[m], false
                for q = 1, NP do
                    if PS[q] + dp[q] < PGOAL[q] then cut = true break end
                end
                if not cut then
                    local dk = DK[m]
                    P[a], P[b], P[c] = 0, 0, 1
                    for s = 1, S do K[s] = K[s] + dk[s] end
                    for q = 1, NP do PS[q] = PS[q] + dp[q] end
                    path[depth] = m
                    if dfs(depth + 1, left - 1) then return true end
                    P[a], P[b], P[c] = 1, 1, 0
                    for s = 1, S do K[s] = K[s] - dk[s] end
                    for q = 1, NP do PS[q] = PS[q] - dp[q] end
                    if aborted then return false end
                end
            end
        end
        if self.ndead >= Solver.MEMO_CAP then
            dead = {}
            self.dead, self.ndead = dead, 0
        end
        dead[ck] = true
        self.ndead = self.ndead + 1
        if on_dead then on_dead(P, left) end
        return false
    end

    if dfs(1, count) then
        local res = {}
        for i = 1, count - 1 do res[i] = path[i] end
        return "yes", res, nodes
    end
    return aborted and "unknown" or "no", nil, nodes
end

-- Plays `path` on a copy of `pegs` and checks it really ends with one peg in
-- the goal hole. For the tools and the specs.
function Solver.check(geo, pegs, goal, path)
    local P = {}
    for i = 1, geo.n do P[i] = pegs[i] end
    for _, m in ipairs(path) do
        local a, b, c = geo.A[m], geo.B[m], geo.C[m]
        if not a or P[a] ~= 1 or P[b] ~= 1 or P[c] ~= 0 then return false end
        P[a], P[b], P[c] = 0, 0, 1
    end
    local count = 0
    for i = 1, geo.n do count = count + P[i] end
    return count == 1 and P[goal] == 1
end

return Solver
