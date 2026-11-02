local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local unpack = unpack or table.unpack  -- luacheck: ignore (Lua 5.2+ in the specs)

local Timer    = require("timer")
local Geometry = lrequire("geometry")
local Solver   = lrequire("solver")
local Puzzles  = lrequire("puzzles")

-- ---------------------------------------------------------------------------
-- PegBoard — one puzzle in play: the pegs, the jumps made (undo/redo), the
-- clock, hints, the "can this still be solved?" bookkeeping and the
-- step-through solution. Pure Lua, no UI.
--
-- Solvability answers are remembered per position: "no", or the rest of a
-- solution from there (every position along a solution found is solvable
-- too). The puzzle's stored solution seeds it, so the start and every
-- position on that line are known without searching.
-- ---------------------------------------------------------------------------

local PegBoard = {}
PegBoard.__index = PegBoard

-- Node budgets for the on-device solver (about 0.1 s per 100 000 nodes on a
-- desktop, roughly ten times that on a 2013 e-reader). The memo is kept, so a
-- second question about the same position goes further than the first.
PegBoard.HINT_BUDGET   = 250000
PegBoard.WARN_BUDGET   = 60000
PegBoard.REWIND_BUDGET = 60000

function PegBoard:new()
    return setmetatable({
        timer      = Timer:new(),
        history    = {},
        redo_stack = {},
        hints_used = 0,
    }, self)
end

-- Starts puzzle `pz` (a Puzzles record) from scratch.
function PegBoard:setPuzzle(pz, daily)
    local geo = pz and Geometry.get(pz.board)
    local pegs = geo and Geometry.decode(geo, pz.pegs)
    if not pegs then return false end
    self.geo        = geo
    self.puzzle     = pz
    self.goal       = pz.goal
    self.daily      = daily or nil
    self.start      = pegs
    self.pegs       = { unpack(pegs) }
    self.history    = {}
    self.redo_stack = {}
    self.selected   = nil
    self.hint_shown = nil
    self.solution   = nil
    self.sol_step   = nil
    self.hints_used = 0
    self.warn_state = nil
    self.solver     = nil
    self.known      = {}
    -- The stored solution, as jump numbers; it seeds the known positions.
    local sol = {}
    for k = 1, #(pz.sol or {}), 2 do
        local m = Geometry.findMove(geo, pz.sol[k], pz.sol[k + 1])
        if not m then sol = nil break end
        sol[#sol + 1] = m
    end
    self.stored_solution = sol
    if sol then self:_learnPath(self.start, sol) end
    self.timer:reset()
    self.timer:start()
    return true
end

-- ---------------------------------------------------------------------------
-- Queries
-- ---------------------------------------------------------------------------

function PegBoard:pegCount(pegs)
    pegs = pegs or self.pegs
    local n = 0
    for i = 1, #pegs do n = n + pegs[i] end
    return n
end

function PegBoard:hasPeg(i)
    return self.pegs[i] == 1
end

function PegBoard:isLegal(m, pegs)
    pegs = pegs or self.pegs
    local g = self.geo
    return m ~= nil and g.A[m] ~= nil and pegs[g.A[m]] == 1 and pegs[g.B[m]] == 1 and pegs[g.C[m]] == 0
end

-- Jumps the peg in hole `from` can make: list of { m = jump, to = hole }.
function PegBoard:movesFrom(from)
    local g, t = self.geo, {}
    if not from or self.pegs[from] ~= 1 then return t end
    for m = 1, g.nmoves do
        if g.A[m] == from and self:isLegal(m) then t[#t + 1] = { m = m, to = g.C[m] } end
    end
    return t
end

function PegBoard:hasMoves(pegs)
    for m = 1, self.geo.nmoves do
        if self:isLegal(m, pegs) then return true end
    end
    return false
end

function PegBoard:isWon()
    return self:pegCount() == 1 and self.pegs[self.goal] == 1
end

-- No jump left (won or stuck).
function PegBoard:isOver()
    return not self:hasMoves()
end

function PegBoard:isShowingSolution()
    return self.solution ~= nil
end

function PegBoard:getMoves()
    return #self.history
end

function PegBoard:canUndo()
    return #self.history > 0 and not self.solution
end

function PegBoard:canRedo()
    return #self.redo_stack > 0 and not self.solution
end

-- The traditional scale, from the pegs left once no jump remains.
function PegBoard:rating()
    local n = self:pegCount()
    if self:isWon() then return "genius" end
    if n == 1 then return "excellent" end
    if n == 2 then return "very_good" end
    if n == 3 then return "good" end
    if n == 4 then return "fair" end
    return "beginner"
end

-- ---------------------------------------------------------------------------
-- Moves
-- ---------------------------------------------------------------------------

function PegBoard:_apply(m, pegs)
    local g = self.geo
    pegs[g.A[m]], pegs[g.B[m]], pegs[g.C[m]] = 0, 0, 1
end

function PegBoard:_revert(m, pegs)
    local g = self.geo
    pegs[g.A[m]], pegs[g.B[m]], pegs[g.C[m]] = 1, 1, 0
end

-- Plays jump m. `keep_redo`: called by redo, which must not clear its stack.
function PegBoard:jump(m, keep_redo)
    if self.solution or not self:isLegal(m) then return false end
    self:_apply(m, self.pegs)
    self.history[#self.history + 1] = m
    if not keep_redo then self.redo_stack = {} end
    self.selected = nil
    self.hint_shown = nil
    self.warn_state = nil
    if self:isOver() then self.timer:stop() end
    return true
end

-- Jumps the peg in `from` into `to`, if that is a legal jump.
function PegBoard:jumpTo(from, to)
    local m = Geometry.findMove(self.geo, from, to)
    return m ~= nil and self:jump(m)
end

function PegBoard:undo()
    if not self:canUndo() then return false end
    local m = table.remove(self.history)
    self:_revert(m, self.pegs)
    self.redo_stack[#self.redo_stack + 1] = m
    self.selected = nil
    self.hint_shown = nil
    self.warn_state = nil
    self.timer:start()
    return true
end

function PegBoard:redo()
    if not self:canRedo() then return false end
    local m = self.redo_stack[#self.redo_stack]
    if not self:isLegal(m) then
        self.redo_stack = {}
        return false
    end
    table.remove(self.redo_stack)
    return self:jump(m, true)
end

-- Back to the start; the jumps stay on the redo stack. The clock runs on.
function PegBoard:restart()
    if not self:canUndo() then return false end
    while #self.history > 0 do self:undo() end
    return true
end

function PegBoard:select(i)
    self.selected = i
    self.hint_shown = nil
end

-- ---------------------------------------------------------------------------
-- Solvability
-- ---------------------------------------------------------------------------

function PegBoard:getSolver()
    if not self.solver then
        self.solver = Solver.new(self.geo, self.goal, Puzzles.pagodas(self.puzzle.board, self.goal))
    end
    return self.solver
end

-- Remembers that `pegs` and every position along `path` from it are solvable.
function PegBoard:_learnPath(pegs, path)
    local P = { unpack(pegs) }
    for k = 1, #path + 1 do
        self.known[Geometry.encode(P)] = { path = path, from = k }
        if path[k] then self:_apply(path[k], P) end
    end
end

-- "yes" plus the rest of a solution, "no", or "unknown" for position `pegs`.
function PegBoard:analyzeAt(pegs, budget)
    local key = Geometry.encode(pegs)
    local k = self.known[key]
    if k == "no" then return "no" end
    if type(k) == "table" then
        local rest = {}
        for i = k.from, #k.path do rest[#rest + 1] = k.path[i] end
        return "yes", rest
    end
    if self:pegCount(pegs) == 1 then
        return pegs[self.goal] == 1 and "yes" or "no", {}
    end
    if not self:hasMoves(pegs) then
        self.known[key] = "no"
        return "no"
    end
    local st, path = self:getSolver():solve(pegs, budget)
    if st == "yes" then
        self:_learnPath(pegs, path)
    elseif st == "no" then
        self.known[key] = "no"
    end
    return st, path
end

function PegBoard:analyze(budget)
    return self:analyzeAt(self.pegs, budget or PegBoard.HINT_BUDGET)
end

-- What is known about the current position without searching.
function PegBoard:knownState()
    local k = self.known[Geometry.encode(self.pegs)]
    if k == "no" then return "no" end
    if k then return "yes" end
    return nil
end

-- The quick check behind "Warn if unsolvable": "yes", "no" or "unknown".
function PegBoard:warnCheck()
    if self.solution or self:isOver() then
        self.warn_state = nil
        return nil
    end
    self.warn_state = self:analyze(PegBoard.WARN_BUDGET)
    return self.warn_state
end

-- The most recent earlier position (number of jumps from the start) that is
-- known, or found within budget, to be solvable. The start always is. Only
-- the REWIND_SEARCHES most recent unknown positions are searched; further
-- back, only what is already known counts, so this stays bounded.
PegBoard.REWIND_SEARCHES = 4

function PegBoard:lastGoodDepth()
    local P = { unpack(self.pegs) }
    local searches = 0
    for d = #self.history - 1, 0, -1 do
        self:_revert(self.history[d + 1], P)
        local k = self.known[Geometry.encode(P)]
        if type(k) == "table" then return d end
        if k == nil and searches < PegBoard.REWIND_SEARCHES then
            searches = searches + 1
            if self:analyzeAt(P, PegBoard.REWIND_BUDGET) == "yes" then return d end
        end
    end
    return 0
end

-- Undoes jumps until `depth` are left (they go on the redo stack).
function PegBoard:rewindTo(depth)
    local moved = false
    while #self.history > depth and self:undo() do moved = true end
    return moved
end

-- ---------------------------------------------------------------------------
-- Hints (game-common's two-tap convention, see ScreenBase:onHint)
-- ---------------------------------------------------------------------------

-- A step names the peg to move (r) and the hole it lands in (c); both are
-- hole numbers here, not rows and columns. Fails with "complete", "no" or
-- "unknown".
function PegBoard:findHint()
    if self:isWon() then return nil, "complete" end
    if self:isOver() then return nil, "no" end
    local st, path = self:analyze(PegBoard.HINT_BUDGET)
    if st ~= "yes" or not path[1] then return nil, st end
    local m = path[1]
    return { kind = "fill", r = self.geo.A[m], c = self.geo.C[m], m = m }
end

function PegBoard:setSelection(from, to)
    self.selected = from
    self.hint_shown = { from = from, to = to }
end

function PegBoard:applyHint(step)
    return step ~= nil and self:jump(step.m)
end

function PegBoard:getHintsUsed()
    return self.hints_used or 0
end

function PegBoard:noteHintUsed()
    self.hints_used = (self.hints_used or 0) + 1
end

-- ---------------------------------------------------------------------------
-- Show solution: one-way, the stored solution from the start, step by step.
-- ---------------------------------------------------------------------------

function PegBoard:showSolution()
    if self.solution then return true end
    if not self.stored_solution then return false end
    self.solution = self.stored_solution
    self.sol_step = 0
    self.pegs = { unpack(self.start) }
    self.selected = nil
    self.hint_shown = nil
    self.timer:stop()
    return true
end

-- The jump about to be played in the solution (for the widget), or nil.
function PegBoard:nextSolutionMove()
    if not self.solution then return nil end
    return self.solution[self.sol_step + 1]
end

function PegBoard:solutionStep(dir)
    if not self.solution then return false end
    local s = self.sol_step + dir
    if s < 0 or s > #self.solution then return false end
    self.pegs = { unpack(self.start) }
    for k = 1, s do self:_apply(self.solution[k], self.pegs) end
    self.sol_step = s
    return true
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function PegBoard:serialize()
    if not self.puzzle then return nil end
    return {
        puzzle     = self.puzzle.id,
        daily      = self.daily,
        history    = { unpack(self.history) },
        redo       = { unpack(self.redo_stack) },
        hints_used = self.hints_used,
        timer      = self.timer:serialize(),
        sol_step   = self.solution and self.sol_step or nil,
    }
end

-- Restores a saved game. Returns false (board untouched) if the save does not
-- replay on the puzzle it names.
function PegBoard:load(data)
    if type(data) ~= "table" or type(data.puzzle) ~= "string" then return false end
    local pz = Puzzles.get(data.puzzle)
    if not pz then return false end
    local probe = PegBoard:new()
    if not probe:setPuzzle(pz) then return false end
    for _, m in ipairs(type(data.history) == "table" and data.history or {}) do
        if not probe:jump(tonumber(m)) then return false end
    end
    self:setPuzzle(pz, data.daily)
    for _, m in ipairs(probe.history) do self:jump(m) end
    if type(data.redo) == "table" then
        for _, m in ipairs(data.redo) do
            if tonumber(m) then self.redo_stack[#self.redo_stack + 1] = tonumber(m) end
        end
    end
    self.hints_used = tonumber(data.hints_used) or 0
    self.timer:load(data.timer)
    local s = tonumber(data.sol_step)
    if s and self:showSolution() then
        self:solutionStep(math.max(0, math.min(s, #self.solution)))
    end
    if self.solution or self:isOver() then self.timer:stop() else self.timer:start() end
    return true
end

return PegBoard
