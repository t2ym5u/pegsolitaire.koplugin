-- lp.lua — a small dense two-phase simplex (Bland's rule), enough for pagoda
-- functions. Maximises c.x subject to rows A[i].x <= b[i] (b may be
-- negative) and x >= 0. Returns x, value; or nil plus a reason.

local LP = {}

local EPS = 1e-9

-- Pivots the tableau on (l, e).
local function pivot(T, z_rows, basis, l, e, W)
    local prow = T[l]
    local pv = prow[e]
    for j = 1, W + 1 do prow[j] = prow[j] / pv end
    for i = 1, #T do
        if i ~= l then
            local f = T[i][e]
            if f ~= 0 then
                local row = T[i]
                for j = 1, W + 1 do row[j] = row[j] - f * prow[j] end
            end
        end
    end
    for _, z in ipairs(z_rows) do
        local f = z[e]
        if f ~= 0 then
            for j = 1, W + 1 do z[j] = z[j] - f * prow[j] end
        end
    end
    basis[l] = e
end

-- Runs the simplex on objective row z (minimising z's reduced costs to >= 0),
-- allowing only columns with allowed[j]. Returns true, or nil on unbounded.
local function run(T, z, others, basis, W, allowed)
    local zs = { z }
    for _, o in ipairs(others) do zs[#zs + 1] = o end
    for _ = 1, 50000 do
        local e
        for j = 1, W do
            if allowed[j] and z[j] < -EPS then e = j break end
        end
        if not e then return true end
        local l, best
        for i = 1, #T do
            local a = T[i][e]
            if a > EPS then
                local r = T[i][W + 1] / a
                if not best or r < best - EPS or (math.abs(r - best) <= EPS and basis[i] < basis[l]) then
                    best, l = r, i
                end
            end
        end
        if not l then return nil end
        pivot(T, zs, basis, l, e, W)
    end
    return true
end

function LP.maximize(c, A, b)
    local m, n = #A, #c
    -- Columns: n variables, m slacks, then one artificial per negative row.
    local neg = {}
    for i = 1, m do if b[i] < 0 then neg[#neg + 1] = i end end
    local W = n + m + #neg
    local T, basis = {}, {}
    local art_of = {}
    for k, i in ipairs(neg) do art_of[i] = n + m + k end
    for i = 1, m do
        local row = {}
        for j = 1, W + 1 do row[j] = 0 end
        local s = b[i] < 0 and -1 or 1
        for j = 1, n do row[j] = s * (A[i][j] or 0) end
        row[n + i] = s
        row[W + 1] = s * b[i]
        if art_of[i] then
            row[art_of[i]] = 1
            basis[i] = art_of[i]
        else
            basis[i] = n + i
        end
        T[i] = row
    end
    -- Phase 2 objective (maximise c.x: reduced costs -c).
    local z = {}
    for j = 1, W + 1 do z[j] = 0 end
    for j = 1, n do z[j] = -c[j] end
    local allowed = {}
    for j = 1, W do allowed[j] = true end
    if #neg > 0 then
        -- Phase 1: minimise the sum of artificials (maximise its negative).
        local z1 = {}
        for j = 1, W + 1 do z1[j] = 0 end
        for _, i in ipairs(neg) do
            for j = 1, W + 1 do z1[j] = z1[j] - T[i][j] end
            z1[art_of[i]] = 0
        end
        if not run(T, z1, { z }, basis, W, allowed) then return nil, "phase1" end
        if z1[W + 1] < -1e-7 then return nil, "infeasible" end
        for _, i in ipairs(neg) do allowed[art_of[i]] = false end
        -- Drive artificials still basic (at zero) out where possible.
        for i = 1, m do
            if basis[i] > n + m then
                for j = 1, n + m do
                    if math.abs(T[i][j]) > EPS then
                        pivot(T, { z, z1 }, basis, i, j, W)
                        break
                    end
                end
            end
        end
    end
    if not run(T, z, {}, basis, W, allowed) then return nil, "unbounded" end
    local x = {}
    for j = 1, n do x[j] = 0 end
    for i = 1, m do
        if basis[i] <= n then x[basis[i]] = T[i][W + 1] end
    end
    return x, z[W + 1]
end

return LP
