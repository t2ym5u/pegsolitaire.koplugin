-- ---------------------------------------------------------------------------
-- geometry.lua — the boards: where the holes are, which jumps exist, and the
-- board's symmetries. Pure Lua, no UI; shared by the game, the on-device
-- solver and the offline tools.
--
-- Holes are numbered 1..n row by row. A jump is a triple (a, b, c): the peg
-- in a jumps over the peg in b into the empty hole c. Square boards jump
-- along rows and columns; triangular boards also along the third axis, so
-- six directions.
-- ---------------------------------------------------------------------------

local Geometry = {}

-- "o" a hole, anything else nothing. Triangular boards list row r with r+1
-- holes, left-aligned.
local LAYOUTS = {
    english = { kind = "square", rows = {
        "..ooo..",
        "..ooo..",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        "..ooo..",
        "..ooo..",
    } },
    french = { kind = "square", rows = {
        "..ooo..",
        ".ooooo.",
        "ooooooo",
        "ooooooo",
        "ooooooo",
        ".ooooo.",
        "..ooo..",
    } },
    square5 = { kind = "square", rows = {
        "ooooo",
        "ooooo",
        "ooooo",
        "ooooo",
        "ooooo",
    } },
    triangle = { kind = "tri", size = 5 },
    triangle6 = { kind = "tri", size = 6 },
}

Geometry.BOARDS = { "english", "french", "triangle", "triangle6", "square5" }
Geometry.DEFAULT = "english"

local SQUARE_DIRS = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }
local TRI_DIRS    = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 }, { 1, 1 }, { -1, -1 } }

local cache = {}

local function build(id)
    local lay = LAYOUTS[id]
    if not lay then return nil end
    local geo = { id = id, kind = lay.kind, holes = {}, index = {} }
    local holes, index = geo.holes, geo.index
    local function add(r, c, x, y)
        holes[#holes + 1] = { r = r, c = c, x = x, y = y }
        index[r * 64 + c] = #holes
    end
    local nrows, ncols
    if lay.kind == "square" then
        nrows, ncols = #lay.rows, #lay.rows[1]
        for r = 0, nrows - 1 do
            local row = lay.rows[r + 1]
            for c = 0, ncols - 1 do
                if row:sub(c + 1, c + 1) == "o" then add(r, c, c, r) end
            end
        end
        geo.width, geo.height = ncols, nrows
    else
        local n = lay.size
        nrows, ncols = n, n
        local h = math.sqrt(3) / 2
        for r = 0, n - 1 do
            for c = 0, r do add(r, c, c - r / 2 + (n - 1) / 2, r * h) end
        end
        geo.size = n
        geo.width, geo.height = n, (n - 1) * h + 1
    end
    geo.n = #holes

    -- Jumps.
    local A, B, C = {}, {}, {}
    local dirs = lay.kind == "square" and SQUARE_DIRS or TRI_DIRS
    for i, hole in ipairs(holes) do
        for _, d in ipairs(dirs) do
            local b = index[(hole.r + d[1]) * 64 + hole.c + d[2]]
            local c = index[(hole.r + 2 * d[1]) * 64 + hole.c + 2 * d[2]]
            if b and c then
                A[#A + 1], B[#B + 1], C[#C + 1] = i, b, c
            end
        end
    end
    geo.A, geo.B, geo.C = A, B, C
    geo.nmoves = #A

    -- Symmetries: every candidate transform that maps the holes onto
    -- themselves, as a permutation of hole numbers.
    local transforms = {}
    if lay.kind == "square" then
        local R, Cn = nrows - 1, ncols - 1
        transforms = {
            function(r, c) return r, c end,
            function(r, c) return r, Cn - c end,
            function(r, c) return R - r, c end,
            function(r, c) return R - r, Cn - c end,
        }
        if nrows == ncols then
            transforms[#transforms + 1] = function(r, c) return c, r end
            transforms[#transforms + 1] = function(r, c) return Cn - c, R - r end
            transforms[#transforms + 1] = function(r, c) return c, R - r end
            transforms[#transforms + 1] = function(r, c) return Cn - c, r end
        end
    else
        -- Barycentric (r - c, c, n-1-r): any permutation of the three.
        local n1 = geo.size - 1
        local function back(u, v, w) return n1 - w, v end  -- (r, c) from (r-c, c, n-1-r)
        transforms = {
            function(r, c) return back(r - c, c, n1 - r) end,
            function(r, c) return back(c, r - c, n1 - r) end,
            function(r, c) return back(r - c, n1 - r, c) end,
            function(r, c) return back(n1 - r, c, r - c) end,
            function(r, c) return back(c, n1 - r, r - c) end,
            function(r, c) return back(n1 - r, r - c, c) end,
        }
    end
    geo.syms = {}
    for _, f in ipairs(transforms) do
        local perm, ok = {}, true
        for i, hole in ipairs(holes) do
            local r2, c2 = f(hole.r, hole.c)
            local j = index[r2 * 64 + c2]
            if not j then ok = false break end
            perm[i] = j
        end
        if ok then geo.syms[#geo.syms + 1] = perm end
    end

    -- The centre hole, when there is one (fixed by every symmetry).
    for i = 1, geo.n do
        local fixed = true
        for _, p in ipairs(geo.syms) do
            if p[i] ~= i then fixed = false break end
        end
        if fixed and #geo.syms > 1 then geo.center = i break end
    end
    return geo
end

function Geometry.get(id)
    if not cache[id] then cache[id] = build(id) end
    return cache[id]
end

function Geometry.isBoard(id)
    return LAYOUTS[id] ~= nil
end

-- Hole number at (r, c), 0-based, or nil.
function Geometry.holeAt(geo, r, c)
    return geo.index[r * 64 + c]
end

-- A position as a "0"/"1" string, one character per hole, and back.
function Geometry.encode(pegs)
    local t = {}
    for i = 1, #pegs do t[i] = pegs[i] == 1 and "1" or "0" end
    return table.concat(t)
end

function Geometry.decode(geo, s)
    if type(s) ~= "string" or #s ~= geo.n or s:find("[^01]") then return nil end
    local pegs = {}
    for i = 1, geo.n do pegs[i] = s:byte(i) == 49 and 1 or 0 end
    return pegs
end

-- Position class: a jump changes the parity of the peg count on each of the
-- three colours of a 3-colouring whose colours alternate along every line, so
-- these parities never change. Two positions with different classes can never
-- reach each other (the reason the French board's centre start has no
-- one-peg finish in its centre). Square boards have two such colourings
-- ((r+c) mod 3 and (r-c) mod 3), triangular ones one ((r+c) mod 3).
function Geometry.positionClass(geo, pegs)
    local n1, n2 = { 0, 0, 0 }, { 0, 0, 0 }
    for i, h in ipairs(geo.holes) do
        if pegs[i] == 1 then
            local k1 = (h.r + h.c) % 3 + 1
            n1[k1] = n1[k1] + 1
            if geo.kind == "square" then
                local k2 = (h.r - h.c) % 3 + 1
                n2[k2] = n2[k2] + 1
            end
        end
    end
    return string.format("%d%d%d%d", (n1[1] + n1[2]) % 2, (n1[2] + n1[3]) % 2,
        (n2[1] + n2[2]) % 2, (n2[2] + n2[3]) % 2)
end

-- Can `pegs` possibly end with one peg in `goal`? (Necessary, not enough.)
function Geometry.goalInClass(geo, pegs, goal)
    local one = {}
    for i = 1, geo.n do one[i] = (i == goal) and 1 or 0 end
    return Geometry.positionClass(geo, pegs) == Geometry.positionClass(geo, one)
end

-- The jump number taking a peg from `from` to `to`, or nil.
function Geometry.findMove(geo, from, to)
    for m = 1, geo.nmoves do
        if geo.A[m] == from and geo.C[m] == to then return m end
    end
    return nil
end

return Geometry
