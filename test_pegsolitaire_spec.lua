local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

local unpack = unpack or table.unpack

-- Modules are loaded the way the plugin loads them (by file path), so the
-- board, the screen and the specs share one copy.
local function lrequire(name)
    local key = DIR .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(DIR .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Geometry = lrequire("geometry")
local Solver   = lrequire("solver")
local Puzzles  = lrequire("puzzles")
local PegBoard = lrequire("board")

-- A position from a picture (rows of "o" peg, "." hole, " " none).
local function pic(geo, rows)
    local P = {}
    for i = 1, geo.n do P[i] = 0 end
    for r, row in ipairs(rows) do
        for c = 1, #row do
            if row:sub(c, c) == "o" then P[assert(Geometry.holeAt(geo, r - 1, c - 1))] = 1 end
        end
    end
    return P
end

local function hole(geo, r, c) return assert(Geometry.holeAt(geo, r, c)) end

describe("Geometry", function()
    it("builds the boards", function()
        local en = Geometry.get("english")
        assert.are.equal(33, en.n)
        assert.are.equal(76, en.nmoves)
        assert.are.equal(8, #en.syms)
        assert.are.equal(hole(en, 3, 3), en.center)
        local fr = Geometry.get("french")
        assert.are.equal(37, fr.n)
        assert.are.equal(8, #fr.syms)
        local tri = Geometry.get("triangle")
        assert.are.equal(15, tri.n)
        assert.are.equal(36, tri.nmoves)
        assert.are.equal(6, #tri.syms)
        assert.are.equal(21, Geometry.get("triangle6").n)
        assert.are.equal(25, Geometry.get("square5").n)
        assert.is_nil(Geometry.get("nope"))
    end)

    it("lists every jump once per direction, between holes in a line", function()
        for _, id in ipairs(Geometry.BOARDS) do
            local g = Geometry.get(id)
            local seen = {}
            for m = 1, g.nmoves do
                local a, b, c = g.holes[g.A[m]], g.holes[g.B[m]], g.holes[g.C[m]]
                assert.are.equal(b.r - a.r, c.r - b.r)
                assert.are.equal(b.c - a.c, c.c - b.c)
                local key = g.A[m] .. ":" .. g.C[m]
                assert.is_nil(seen[key])
                seen[key] = true
            end
        end
    end)

    it("knows the French centre start has no centre finish", function()
        local fr = Geometry.get("french")
        local P = {}
        for i = 1, fr.n do P[i] = 1 end
        P[fr.center] = 0
        assert.is_false(Geometry.goalInClass(fr, P, fr.center))
        local en = Geometry.get("english")
        for i = 1, en.n do P[i] = 1 end
        P[en.center] = 0
        assert.is_true(Geometry.goalInClass(en, P, en.center))
    end)

    it("encodes and decodes positions", function()
        local en = Geometry.get("english")
        local P = pic(en, { "  ...  ", "  .o.  ", "..ooo..", "...o...", "...o...", "  ...  ", "  ...  " })
        local s = Geometry.encode(P)
        assert.are.same(P, Geometry.decode(en, s))
        assert.is_nil(Geometry.decode(en, "0101"))
        assert.is_nil(Geometry.decode(en, s:sub(2) .. "2"))
    end)
end)

describe("Solver", function()
    local en = Geometry.get("english")

    it("solves small positions and proves dead ones", function()
        local s = Solver.new(en, en.center)
        -- Two pegs, one jump from the centre.
        local P = pic(en, { "  ...  ", "  .o.  ", "...o...", ".......", ".......", "  ...  ", "  ...  " })
        local st, path = s:solve(P)
        assert.are.equal("yes", st)
        assert.is_true(Solver.check(en, P, en.center, path))
        -- Two pegs far apart: no jump at all.
        P = pic(en, { "  o..  ", "  ...  ", ".......", ".......", ".......", "  ...  ", "  ..o  " })
        assert.are.equal("no", (s:solve(P)))
        -- One peg, not in the goal.
        P = pic(en, { "  o..  ", "  ...  ", ".......", ".......", ".......", "  ...  ", "  ...  " })
        assert.are.equal("no", (s:solve(P)))
    end)

    it("solves the classic full board", function()
        local P = {}
        for i = 1, en.n do P[i] = 1 end
        P[en.center] = 0
        local st, path = Solver.new(en, en.center, Puzzles.pagodas("english", en.center)):solve(P, 2e6)
        assert.are.equal("yes", st)
        assert.are.equal(31, #path)
        assert.is_true(Solver.check(en, P, en.center, path))
    end)

    it("stops at the budget and says it doesn't know", function()
        -- Deviated early position, no pagodas, tiny budget.
        local P = Geometry.decode(en, "111101111011111111111110101001110")
        local s = Solver.new(en, en.center)
        local st, _, nodes = s:solve(P, 1000)
        assert.are.equal("unknown", st)
        assert.is_true(nodes <= 1001)
    end)

    it("rejects a bad pagoda and keeps good ones", function()
        local bad = {}
        for i = 1, en.n do bad[i] = 0 end
        bad[en.center] = 5
        assert.is_false(Solver.isPagoda(en, bad))
        assert.are.equal(0, #Solver.new(en, en.center, { bad }).pagodas)
    end)

    it("ships only valid pagodas, for real boards", function()
        local data = dofile(DIR .. "pagodas_data.lua")
        for key, list in pairs(data) do
            local board, goal = key:match("^(%w+):(%d+)$")
            local geo = assert(Geometry.get(board), key)
            assert.is_true(tonumber(goal) >= 1 and tonumber(goal) <= geo.n)
            for _, p in ipairs(list) do
                assert.are.equal(geo.n, #p)
                assert.is_true(Solver.isPagoda(geo, p), key)
            end
        end
    end)
end)

describe("Puzzles", function()
    it("loads the bank, every board has puzzles", function()
        local all = Puzzles.all()
        assert.is_true(#all >= 30)
        for _, b in ipairs(Geometry.BOARDS) do
            assert.is_true(#Puzzles.forBoard(b) >= 2, b)
        end
        assert.are.equal("en_classic", Puzzles.get("en_classic").id)
    end)

    it("ships only solvable puzzles: every stored solution replays", function()
        local ids = {}
        for _, pz in ipairs(Puzzles.all()) do
            assert.is_nil(ids[pz.id], pz.id)
            ids[pz.id] = true
            local geo = Geometry.get(pz.board)
            local pegs = Geometry.decode(geo, pz.pegs)
            local path = {}
            for k = 1, #pz.sol, 2 do
                path[#path + 1] = assert(Geometry.findMove(geo, pz.sol[k], pz.sol[k + 1]), pz.id)
            end
            assert.are.equal(pz.count - 1, #path)
            assert.is_true(Solver.check(geo, pegs, pz.goal, path), pz.id)
            assert.is_true(Geometry.goalInClass(geo, pegs, pz.goal), pz.id)
        end
    end)
end)

describe("PegBoard", function()
    local function newBoard(id)
        local b = PegBoard:new()
        assert.is_true(b:setPuzzle(Puzzles.get(id)))
        return b
    end

    it("plays, undoes, redoes and restarts", function()
        local b = newBoard("en_classic")
        local g = b.geo
        assert.are.equal(32, b:pegCount())
        -- From the centre start, exactly four jumps, all into the centre.
        local n = 0
        for m = 1, g.nmoves do
            if b:isLegal(m) then
                n = n + 1
                assert.are.equal(g.center, g.C[m])
            end
        end
        assert.are.equal(4, n)
        local from = hole(g, 1, 3)
        assert.are.same({ { m = Geometry.findMove(g, from, g.center), to = g.center } }, b:movesFrom(from))
        assert.is_false(b:jumpTo(hole(g, 0, 3), g.center))  -- not a jump
        assert.is_true(b:jumpTo(from, g.center))
        assert.are.equal(31, b:pegCount())
        assert.is_false(b:hasPeg(from))
        assert.is_false(b:hasPeg(hole(g, 2, 3)))
        assert.is_true(b:undo())
        assert.are.equal(32, b:pegCount())
        assert.is_true(b:canRedo())
        assert.is_true(b:redo())
        assert.are.equal(31, b:pegCount())
        assert.is_false(b:canRedo())
        assert.is_true(b:restart())
        assert.are.equal(32, b:pegCount())
        assert.are.equal(1, #b.redo_stack)
        assert.is_false(b:undo())
    end)

    it("wins by following the stored solution, with the top rating", function()
        local b = newBoard("en_cross")
        for _, m in ipairs(b.stored_solution) do assert.is_true(b:jump(m)) end
        assert.is_true(b:isWon())
        assert.is_true(b:isOver())
        assert.are.equal("genius", b:rating())
    end)

    it("rates a stuck game by the pegs left", function()
        local b = newBoard("en_classic")
        while not b:isOver() do
            local last
            for m = 1, b.geo.nmoves do if b:isLegal(m) then last = m end end
            b:jump(last)
        end
        assert.is_false(b:isWon())
        local n = b:pegCount()
        local expect = ({ "excellent", "very_good", "good", "fair" })[n] or "beginner"
        assert.are.equal(expect, b:rating())
    end)

    it("knows the stored solution's positions without searching", function()
        local b = newBoard("en_offcentre")
        assert.are.equal("yes", b:knownState())
        b:jump(b.stored_solution[1])
        assert.are.equal("yes", b:knownState())
        local step = assert(b:findHint())
        assert.are.equal(b.stored_solution[2], step.m)
    end)

    it("hints a jump that keeps a deviated position solvable", function()
        local b = newBoard("en_classic")
        -- Leave the stored solution at once.
        local g = b.geo
        local first = b.stored_solution[1]
        for m = 1, g.nmoves do
            if b:isLegal(m) and m ~= first then b:jump(m) break end
        end
        for _ = 1, 5 do
            local step = assert(b:findHint())
            b:setSelection(step.r, step.c)
            assert.are.equal(step.r, b.selected)
            assert.is_true(b:applyHint(step))
            local check = Solver.new(g, b.goal, Puzzles.pagodas("english", b.goal))
            assert.are.equal("yes", (check:solve(b.pegs)))
        end
    end)

    it("spots an unsolvable position and finds the way back", function()
        local b = newBoard("en_cross")
        local g = b.geo
        -- Try the first jumps until one leaves the cross unsolvable.
        local legal = {}
        for k = 1, g.nmoves do if b:isLegal(k) then legal[#legal + 1] = k end end
        local bad
        for _, k in ipairs(legal) do
            b:jump(k)
            if b:analyze() == "no" then bad = k break end
            b:undo()
        end
        assert.is_not_nil(bad, "some first jump of the cross is a mistake")
        assert.are.equal("no", b:warnCheck())
        local step, why = b:findHint()
        assert.is_nil(step)
        assert.are.equal("no", why)
        assert.are.equal(0, b:lastGoodDepth())
        assert.is_true(b:rewindTo(0))
        assert.are.equal(0, b:getMoves())
        assert.are.equal("yes", b:knownState())
    end)

    it("stops a search at its time cap and answers unknown", function()
        -- A deadline already past stops the search at its first clock check
        -- (every 1024 nodes); the full classic board needs far more nodes.
        local b = newBoard("en_classic")
        local st, path, nodes = b:getSolver():solve(b.start, math.huge, os.clock() - 1)
        assert.are.equal("unknown", st)
        assert.is_nil(path)
        assert.are.equal(1024, nodes)
        -- With time, the same solver (memo intact) still proves it solvable.
        local st2, path2 = b:getSolver():solve(b.start, math.huge)
        assert.are.equal("yes", st2)
        assert.is_true(Solver.check(b.geo, b.start, b.goal, path2))
    end)

    it("keeps hints within the Kobo time cap (simulated)", function()
        local keep = PegBoard.time_scale
        PegBoard.time_scale = 0.04         -- a Kobo is ~25x slower
        local worst = 0
        for _, pz in ipairs(Puzzles.all()) do
            for s = 1, 3 do
                math.randomseed(s * 31)
                local b = PegBoard:new()
                b:setPuzzle(pz)
                for _ = 1, s + 1 do
                    local legal = {}
                    for m = 1, b.geo.nmoves do if b:isLegal(m) then legal[#legal + 1] = m end end
                    if #legal == 0 then break end
                    b:jump(legal[math.random(#legal)])
                end
                local t0 = os.clock()
                b:analyze()
                worst = math.max(worst, os.clock() - t0)
            end
        end
        PegBoard.time_scale = keep
        -- 2.5 s x 0.04 = 100 ms, with a margin for a loaded machine.
        assert.is_true(worst < 0.3)
    end)

    it("falls back to a known position when the solver can't tell", function()
        local b = newBoard("en_classic")
        local keep = PegBoard.REWIND_BUDGET
        PegBoard.REWIND_BUDGET = 1
        b:jump(b.stored_solution[1])
        b:jump(b.stored_solution[2])
        -- Then a few more jumps, first legal one each time.
        for _ = 1, 4 do
            for m = 1, b.geo.nmoves do
                if b:isLegal(m) then
                    b:jump(m)
                    break
                end
            end
        end
        local d = b:lastGoodDepth()
        PegBoard.REWIND_BUDGET = keep
        assert.is_true(d >= 2 and d < 6)
        b:rewindTo(d)
        assert.are.equal("yes", b:knownState())
    end)

    it("steps through the solution, one way", function()
        local b = newBoard("tri_corner")
        b:jump(b.stored_solution[1])
        assert.is_true(b:showSolution())
        assert.are.equal(14, b:pegCount())
        assert.is_false(b:canUndo())
        assert.is_true(b:solutionStep(1))
        assert.are.equal(13, b:pegCount())
        assert.are.equal(b.stored_solution[2], b:nextSolutionMove())
        assert.is_false(b:solutionStep(-2))
        assert.is_false(b:jump(b:nextSolutionMove()))
    end)

    it("saves and restores a game", function()
        local b = newBoard("fr_diamond")
        for k = 1, 5 do b:jump(b.stored_solution[k]) end
        b:undo()
        local data = b:serialize()
        local c = PegBoard:new()
        assert.is_true(c:load(data))
        assert.are.equal("fr_diamond", c.puzzle.id)
        assert.are.same(b.pegs, c.pegs)
        assert.are.same(b.history, c.history)
        assert.is_true(c:redo())
        -- A history that doesn't replay is refused, the board untouched.
        local bad = { puzzle = "fr_diamond", history = { 1, 1, 1 } }
        assert.is_false(c:load(bad))
        assert.are.equal(5, c:getMoves())
        assert.is_false(c:load({ puzzle = "nope" }))
        assert.is_false(c:load(nil))
    end)

    it("restores a game on show with its solution step", function()
        local b = newBoard("tri_edge")
        b:showSolution()
        b:solutionStep(1)
        b:solutionStep(1)
        local c = PegBoard:new()
        assert.is_true(c:load(b:serialize()))
        assert.is_true(c:isShowingSolution())
        assert.are.equal(2, c.sol_step)
        assert.are.same(b.pegs, c.pegs)
    end)

    it("copies positions instead of sharing them", function()
        local b = newBoard("en_plus")
        local start = { unpack(b.start) }
        b:jump(b.stored_solution[1])
        assert.are.same(start, b.start)
    end)
end)
