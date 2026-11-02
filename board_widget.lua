local Blitbuffer     = require("ffi/blitbuffer")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local UIManager      = require("ui/uimanager")

local C_BG    = Blitbuffer.COLOR_WHITE
local C_FG    = Blitbuffer.COLOR_BLACK
local C_BOARD = Blitbuffer.COLOR_GRAY_E
local C_HOLE  = Blitbuffer.COLOR_GRAY_9
local C_GOAL  = Blitbuffer.COLOR_GRAY_5

-- ---------------------------------------------------------------------------
-- PegBoardWidget: the board (light grey), its holes (small dimples) and the
-- pegs (black marbles with a white glint). The goal hole wears a grey ring
-- that stays visible around a peg.
--
-- The selected peg turns white with a black rim; the holes it can jump into
-- get a black ring. A hint or the next solution jump shows the same way, with
-- only its one destination ringed.
--
-- Taps go to cellTapCallback(hole), hole numbers as in geometry.lua.
-- ---------------------------------------------------------------------------

local PegBoardWidget = InputContainer:extend{
    board           = nil,
    max_width       = 0,
    max_height      = 0,
    cellTapCallback = nil,
}

function PegBoardWidget:init()
    local geo = self.board.geo
    local cell = math.floor(math.min(self.max_width / geo.width, self.max_height / geo.height))
    self.cell = math.max(cell, 12)
    self.w = self.cell * geo.width
    self.h = math.ceil(self.cell * geo.height)
    self.dimen = Geom:new{ w = self.w, h = self.h }
    self.paint_rect = nil
    local range = function() return self.paint_rect end
    self.ges_events = {
        HoleTap = { GestureRange:new{ ges = "tap", range = range } },
    }
end

-- Centre of hole i relative to the widget's top-left corner.
function PegBoardWidget:_centre(i)
    local h = self.board.geo.holes[i]
    return math.floor((h.x + 0.5) * self.cell + 0.5), math.floor((h.y + 0.5) * self.cell + 0.5)
end

-- Screen centre of hole i, for tests driving the widget.
function PegBoardWidget:getHoleCenter(i)
    local rect = self.paint_rect or Geom:new{ x = 0, y = 0 }
    local x, y = self:_centre(i)
    return rect.x + x, rect.y + y
end

function PegBoardWidget:_holeAt(pos)
    if not self.paint_rect then return nil end
    local lx, ly = pos.x - self.paint_rect.x, pos.y - self.paint_rect.y
    local best, best_d
    for i = 1, self.board.geo.n do
        local x, y = self:_centre(i)
        local d = (x - lx) ^ 2 + (y - ly) ^ 2
        if not best_d or d < best_d then best, best_d = i, d end
    end
    if best and best_d <= (self.cell * 0.55) ^ 2 then return best end
    return nil
end

function PegBoardWidget:onHoleTap(_, ges)
    local i = self:_holeAt(ges.pos)
    if i and self.cellTapCallback then self.cellTapCallback(i) end
    return true
end

function PegBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

-- The peg shown as selected and the holes ringed as its destinations.
function PegBoardWidget:_marks()
    local board = self.board
    local geo = board.geo
    local m = board.nextSolutionMove and board:nextSolutionMove()
    if m then return geo.A[m], { [geo.C[m]] = true } end
    if board.hint_shown then
        return board.hint_shown.from, { [board.hint_shown.to] = true }
    end
    local sel = board.selected
    if not sel or board.pegs[sel] ~= 1 then return nil, {} end
    local dest = {}
    for _, mv in ipairs(board:movesFrom(sel)) do dest[mv.to] = true end
    return sel, dest
end

function PegBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local geo = board.geo
    local cell = self.cell
    bb:paintRect(x, y, self.w, self.h, C_BG)

    -- The board itself: one grey square per hole (square boards: the cross
    -- or octagon shape), one grey disc per hole on triangular boards.
    for i = 1, geo.n do
        local cx, cy = self:_centre(i)
        if geo.kind == "square" then
            local half = math.floor(cell / 2)
            bb:paintRect(x + cx - half, y + cy - half, cell, cell, C_BOARD)
        else
            bb:paintCircle(x + cx, y + cy, math.floor(cell * 0.56), C_BOARD)
        end
    end

    local sel, dest = self:_marks()
    local r_peg  = math.floor(cell * 0.36)
    local r_hole = math.max(3, math.floor(cell * 0.13))
    local r_goal = math.floor(cell * 0.45)
    local r_dest = math.floor(cell * 0.30)
    for i = 1, geo.n do
        local cx, cy = self:_centre(i)
        cx, cy = x + cx, y + cy
        if i == board.goal then
            bb:paintCircle(cx, cy, r_goal, C_GOAL, math.max(2, math.floor(cell * 0.035)))
        end
        if board.pegs[i] == 1 then
            if i == sel then
                bb:paintCircle(cx, cy, r_peg, C_FG)
                bb:paintCircle(cx, cy, r_peg - math.max(4, math.floor(cell * 0.1)), C_BG)
            else
                bb:paintCircle(cx, cy, r_peg, C_FG)
                local g = math.max(2, math.floor(cell * 0.07))
                local off = math.floor(r_peg * 0.4)
                bb:paintCircle(cx - off, cy - off, g, C_BG)
            end
        else
            bb:paintCircle(cx, cy, r_hole, C_HOLE)
            if dest[i] then
                bb:paintCircle(cx, cy, r_dest, C_FG, math.max(3, math.floor(cell * 0.07)))
            end
        end
    end
end

return PegBoardWidget
