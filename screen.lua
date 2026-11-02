local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local ConfirmBox      = require("ui/widget/confirmbox")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Menu            = require("ui/widget/menu")
local MultiConfirmBox = require("ui/widget/multiconfirmbox")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local ScreenBase  = require("screen_base")
local DailySeed   = require("daily_seed")
local MenuHelper  = require("menu_helper")
local Geometry    = lrequire("geometry")
local PegBoard    = lrequire("board")
local BoardWidget = lrequire("board_widget")
local Puzzles     = lrequire("puzzles")

local DeviceScreen = Device.screen

local GAME_RULES_EN = [[
Peg Solitaire — Rules

Jump a peg over a neighbouring peg into the empty hole just behind it; the peg jumped over is taken off the board. Jumps go along the lines of holes: across and up or down on square boards, and also along the third direction on triangular boards. There are no diagonal jumps on square boards.

Each puzzle starts with some pegs on the board and a goal hole, marked with a grey ring. Remove all the pegs but one, and finish with that last peg in the goal hole.

When no jump is left, the pegs remaining give the traditional rating:
• one peg, in the goal hole: Genius
• one peg elsewhere: Excellent
• two pegs: Very good
• three pegs: Good
• four pegs: Fair
• five or more: Beginner

Controls:
• Tap a peg to pick it up: the holes it can jump into get a black ring. Tap one of them to jump. Tap the peg again, or anywhere else, to put it down.
• Undo and Redo go back and forth through your jumps; Restart goes back to the start (Redo replays your jumps).
• Hint, first tap: marks the peg to move and rings where it goes; second tap: plays that jump. A hint always keeps the puzzle solvable from where you are. If your position can no longer be solved, Hint says so and offers to take you back to the last position that can.
• The solver is quick but not unlimited: on a big board with many pegs it may not decide in time. It says so instead of guessing, and offers to think longer or to take you back to the last position known to be solvable.
• Warn if unsolvable (menu): after each jump, a short check; the status line warns you when the position can no longer be solved.
• Show solution (menu) gives up the puzzle and steps through a solution from the start.

Boards: English (33 holes), French (37 holes: its centre-hole start cannot be finished, its full-board puzzles start from a hole that can), triangles of 15 and 21 holes (six jump directions) and a 5×5 square. Puzzles are grouped by their number of pegs: Easy up to 12, Medium up to 24, Hard beyond. "New game" opens the next puzzle you haven't solved on the current board; "Puzzle" lets you pick any. The Daily Challenge is the same puzzle for everyone today.
]]

local GAME_RULES_FR = [[
Solitaire à billes — Règles

Faites sauter une bille par-dessus une bille voisine dans le trou vide juste derrière ; la bille sautée est retirée du plateau. Les sauts suivent les lignes de trous : en largeur et en hauteur sur les plateaux carrés, et aussi selon la troisième direction sur les plateaux triangulaires. Pas de saut en diagonale sur les plateaux carrés.

Chaque problème commence avec des billes sur le plateau et un trou d'arrivée, marqué d'un cercle gris. Retirez toutes les billes sauf une, et finissez avec cette dernière bille dans le trou d'arrivée.

Quand plus aucun saut n'est possible, les billes restantes donnent le classement traditionnel :
• une bille, dans le trou d'arrivée : Génie
• une bille ailleurs : Excellent
• deux billes : Très bien
• trois billes : Bien
• quatre billes : Assez bien
• cinq ou plus : Débutant

Commandes :
• Touchez une bille pour la prendre : les trous où elle peut sauter sont cerclés de noir. Touchez l'un d'eux pour sauter. Touchez à nouveau la bille, ou ailleurs, pour la reposer.
• Annuler et Rejouer parcourent vos sauts dans les deux sens ; Recommencer revient au départ (Rejouer refait vos sauts).
• Astuce, premier appui : marque la bille à déplacer et cercle sa destination ; second appui : joue ce saut. Une astuce garde toujours le problème soluble depuis votre position. Si votre position n'a plus de solution, l'astuce le dit et propose de revenir à la dernière position soluble.
• Le solveur est rapide mais pas illimité : sur un grand plateau encore bien rempli, il peut ne pas trancher à temps. Il le dit au lieu de deviner, et propose de chercher encore ou de revenir à la dernière position dont on sait qu'elle est soluble.
• Avertir si insoluble (menu) : après chaque saut, une vérification rapide ; la ligne d'état prévient quand la position n'a plus de solution.
• Voir la solution (menu) abandonne le problème et déroule une solution depuis le départ.

Plateaux : anglais (33 trous), français (37 trous : son départ trou central ne peut pas être fini, ses problèmes plateau complet partent d'un trou qui le peut), triangles de 15 et 21 trous (six directions de saut) et un carré de 5×5. Les problèmes sont classés par nombre de billes : Facile jusqu'à 12, Moyen jusqu'à 24, Difficile au-delà. « Nouvelle partie » ouvre le prochain problème non résolu du plateau choisi ; « Problème » permet de choisir n'importe lequel. Le Défi du jour est le même problème pour tout le monde aujourd'hui.
]]

local BOARD_LABELS = {
    english   = _("English (33 holes)"),
    french    = _("French (37 holes)"),
    triangle  = _("Triangle (15 holes)"),
    triangle6 = _("Triangle (21 holes)"),
    square5   = _("Square (25 holes)"),
}

local DIFFICULTY_LABELS = {
    easy   = _("Easy"),
    medium = _("Medium"),
    hard   = _("Hard"),
}

local RATING_LABELS = {
    genius    = _("Genius"),
    excellent = _("Excellent"),
    very_good = _("Very good"),
    good      = _("Good"),
    fair      = _("Fair"),
    beginner  = _("Beginner"),
}

-- Puzzle names are i18n keys; listed here so the extractor sees them.
local PUZZLE_NAMES = {
    _("Cross"), _("Plus"), _("Fireplace"), _("Up arrow"), _("Pyramid"), _("Diamond"),
    _("Double cross"), _("Long cross"), _("Triangle"), _("Lamp"), _("House"),
    _("Half board"), _("Heart"), _("Star"), _("Belt"), _("Frame"), _("Full board"),
    _("Corner start"), _("Side start"), _("Off-centre start"), _("Crown"),
    _("Four corners"), _("Big square"), _("Full board A"), _("Full board B"),
    _("Inner start"), _("Second row start"),
}
local _unused = PUZZLE_NAMES  -- luacheck: ignore

local DEFAULT_PUZZLE = "en_classic"

local PegSolitaireScreen = ScreenBase:extend{}

function PegSolitaireScreen:init()
    self.board = PegBoard:new()
    if not self.board:load(self.plugin:loadState()) then
        -- First game: the classic, English board with the centre hole empty.
        local first = Puzzles.get(DEFAULT_PUZZLE)
        if not first or first.board ~= self:_getBoardId() then
            first = self:_nextUnsolved(self:_getBoardId())
        end
        self:_startPuzzle(first)
    elseif self:_warnOn() then
        -- A restored game gets its warning back at once.
        self.board:warnCheck()
    end
    ScreenBase.init(self)
end

function PegSolitaireScreen:serializeState()
    return self.board:serialize()
end

function PegSolitaireScreen:_save()
    self.plugin:saveState(self.board:serialize())
end

-- ---------------------------------------------------------------------------
-- Settings, puzzles and progress
-- ---------------------------------------------------------------------------

function PegSolitaireScreen:_getBoardId()
    local b = self.plugin:getSetting("board", Geometry.DEFAULT)
    return Geometry.isBoard(b) and #Puzzles.forBoard(b) > 0 and b or Geometry.DEFAULT
end

function PegSolitaireScreen:_warnOn()
    return self.plugin:getSetting("warn_unsolvable", true) ~= false
end

function PegSolitaireScreen:_table(key)
    local t = self.plugin:getSetting(key, nil)
    return type(t) == "table" and t or {}
end

function PegSolitaireScreen:isSolved(id)
    return self:_table("solved")[id] == true
end

-- Fewest pegs left at the end of a game of puzzle `id`, or nil.
function PegSolitaireScreen:bestLeft(id)
    return tonumber(self:_table("best")[id])
end

function PegSolitaireScreen:solvedCount(board)
    local n = 0
    for _i, pz in ipairs(Puzzles.forBoard(board)) do
        if self:isSolved(pz.id) then n = n + 1 end
    end
    return n
end

-- Records a finished game: best result, and solved on a win.
function PegSolitaireScreen:_recordEnd()
    local b = self.board
    if not b.puzzle or not b:isOver() or b:isShowingSolution() then return end
    local id = b.puzzle.id
    local best = self:_table("best")
    local left = b:pegCount()
    if not best[id] or left < best[id] then
        best[id] = left
        self.plugin:saveSetting("best", best)
    end
    if b:isWon() and not self:isSolved(id) then
        local solved = self:_table("solved")
        solved[id] = true
        self.plugin:saveSetting("solved", solved)
    end
end

-- The first puzzle of the board (easiest first) not solved yet, other than
-- the one in play; the one after the current puzzle once all are solved.
function PegSolitaireScreen:_nextUnsolved(board)
    local list = Puzzles.forBoard(board)
    local cur = self.board.puzzle and self.board.puzzle.id
    for _i, pz in ipairs(list) do
        if pz.id ~= cur and not self:isSolved(pz.id) then return pz end
    end
    for i, pz in ipairs(list) do
        if pz.id == cur then return list[i % #list + 1] end
    end
    return list[1]
end

function PegSolitaireScreen:_startPuzzle(pz, daily)
    if not pz or not self.board:setPuzzle(pz, daily) then return false end
    self.hint_cell = nil
    self:_save()
    return true
end

function PegSolitaireScreen:_puzzleName(pz)
    return pz and _(pz.name) or "–"
end

-- ---------------------------------------------------------------------------
-- Layout
-- ---------------------------------------------------------------------------

function PegSolitaireScreen:buildLayout()
    local is_landscape = self:isLandscape()

    local title_bar = self:buildTitleBar(_("Peg Solitaire"), function()
        local items = {
            { text = _("New game"), callback = function() self:onNewGame() end },
            self:makeDailyButtonConfig(),
            { text = T(_("Board: %1"), BOARD_LABELS[self:_getBoardId()]),
              callback = function() self:openBoardMenu() end },
            { text = T(_("Puzzle: %1"), self:_puzzleName(self.board.puzzle)),
              callback = function() self:openPuzzleMenu() end },
            { text = T(_("Warn if unsolvable: %1"), self:_warnOn() and _("On") or _("Off")),
              callback = function() self:onToggleWarn() end },
        }
        if not self.board:isShowingSolution() and not self.board:isWon() then
            items[#items + 1] = { text = _("Show solution"), callback = function() self:onShowSolution() end }
        end
        items[#items + 1] = self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR)
        return items
    end)

    self.status_text:setMaxWidth(self:getControlsWidth())
    local undo    = { id = "undo_btn",    text = _("Undo"),    callback = function() self:onUndo() end }
    local redo    = { id = "redo_btn",    text = _("Redo"),    callback = function() self:onRedo() end }
    local restart = { id = "restart_btn", text = _("Restart"), callback = function() self:onRestart() end }
    local hint    = { text = _("Hint"), callback = function() self:onHint() end }
    -- The landscape side panel is too narrow for four labels on one row.
    local action_bar = self:buildActionBar(is_landscape
        and { { undo, redo }, { restart, hint } }
        or  { undo, redo, restart, hint })
    self.undo_btn    = action_bar:getButtonById("undo_btn")
    self.redo_btn    = action_bar:getButtonById("redo_btn")
    self.restart_btn = action_bar:getButtonById("restart_btn")
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        action_bar,
    }

    -- The widget paints its own board shape, so the frame only pads.
    local frame_pad = Size.padding.large
    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    self.board_widget = BoardWidget:new{
        board           = self.board,
        max_width       = math.max(budget_w - 2 * frame_pad, 84),
        max_height      = math.max(budget_h - 2 * frame_pad, 72),
        cellTapCallback = function(i) self:onHoleTap(i) end,
    }
    local board_frame = FrameContainer:new{
        padding    = frame_pad,
        margin     = 0,
        bordersize = 0,
        self.board_widget,
    }
    self:_updateButtons()

    if is_landscape then
        self:buildLandscapeLayout(title_bar, HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        })
    else
        self:buildPortraitLayout(title_bar, board_frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self:updateStatus()
end

function PegSolitaireScreen:_rebuild()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

-- ---------------------------------------------------------------------------
-- Interaction
-- ---------------------------------------------------------------------------

-- Shows `msg` at once (before a search that may take a moment).
function PegSolitaireScreen:_flash(msg)
    ScreenBase.updateStatus(self, msg)
    if UIManager.forceRePaint then pcall(UIManager.forceRePaint, UIManager) end
end

-- After anything that changed the pegs: the quick solvability check, the
-- save, the end-of-game record and one repaint.
function PegSolitaireScreen:_afterMove(msg)
    local b = self.board
    self.hint_cell = nil
    if self:_warnOn() and not b:isOver() and not b:isShowingSolution() then
        b:warnCheck()
    end
    self:_recordEnd()
    self:_save()
    self:_updateButtons()
    self:updateStatus(msg)
end

function PegSolitaireScreen:onHoleTap(i)
    local b = self.board
    if b:isOver() or b:isShowingSolution() then return end
    if b:hasPeg(i) then
        if b.selected == i then
            b:select(nil)
            self:updateStatus()
        elseif #b:movesFrom(i) > 0 then
            b:select(i)
            self:updateStatus()
        else
            b:select(nil)
            self:updateStatus(_("That peg has no jump."))
        end
        self.hint_cell = nil
        self.board_widget:refresh()
        return
    end
    local sel = b.selected
    if sel and b:jumpTo(sel, i) then
        self:_afterMove()
    elseif sel then
        b:select(nil)
        self.hint_cell = nil
        self.board_widget:refresh()
        self:updateStatus()
    end
end

function PegSolitaireScreen:onUndo()
    if self.board:undo() then self:_afterMove() end
end

function PegSolitaireScreen:onRedo()
    if self.board:redo() then self:_afterMove() end
end

function PegSolitaireScreen:onRestart()
    if self.board:restart() then self:_afterMove() end
end

function PegSolitaireScreen:onToggleWarn()
    self.plugin:saveSetting("warn_unsolvable", not self:_warnOn())
    if self:_warnOn() then
        self:_afterMove()
    else
        self.board.warn_state = nil
        self:updateStatus()
    end
end

function PegSolitaireScreen:describeHintStep(_step, level)
    if level == 1 then
        return _("Jump the marked peg to the ringed hole.")
    end
    return _("Hint played.")
end

-- A hint is a jump that keeps the puzzle solvable. When there is none, or
-- the solver can't tell in time, it says so and offers to go back to the last
-- position known to be solvable (and, when it couldn't tell, to think longer).
function PegSolitaireScreen:onHint()
    local b = self.board
    if b:isShowingSolution() or b:isOver() then
        return ScreenBase.onHint(self)
    end
    if not b:knownState() then self:_flash(_("Thinking…")) end
    self:_onAnalysis(b:analyze())
end

-- The second half of onHint, once the solver has answered `st`.
function PegSolitaireScreen:_onAnalysis(st)
    local b = self.board
    if st == "yes" then
        ScreenBase.onHint(self)
        if not self.hint_cell then
            -- Second tap: the jump was played (and is on a known solution,
            -- so no warning check is needed).
            self:_recordEnd()
            self:_save()
            if b:isOver() then self:updateStatus() end
        end
        self:_updateButtons()
        self:refreshActionBar()
        return
    end
    self.hint_cell = nil
    local depth = b:lastGoodDepth()
    local back = #b.history - depth
    local function goBack()
        b:rewindTo(depth)
        b:noteHintUsed()
        self:_afterMove(T(_("Back %1 jump(s): solvable again."), back))
    end
    if st == "no" then
        self:updateStatus(_("No solution from here any more."))
        UIManager:show(ConfirmBox:new{
            text        = T(_("This position can no longer be solved.\n\nGo back %1 jump(s), to the last position that can?"), back),
            ok_text     = _("Go back"),
            cancel_text = _("Keep playing"),
            ok_callback = goBack,
        })
    else
        self:updateStatus(_("Can't tell quickly."))
        UIManager:show(MultiConfirmBox:new{
            text = T(_("The solver can't tell quickly whether this position can still be solved.\n\nThe last position known to be solvable is %1 jump(s) back."), back),
            choice1_text     = _("Think longer"),
            choice1_callback = function() self:onThinkLonger() end,
            choice2_text     = _("Go back"),
            choice2_callback = goBack,
            cancel_text      = _("Keep playing"),
        })
    end
end

-- A longer search on the current position; the memo keeps what the first
-- one proved, so this goes further rather than starting over.
function PegSolitaireScreen:onThinkLonger()
    self:_flash(_("Thinking…"))
    self:_onAnalysis(self.board:analyze(PegBoard.HINT_BUDGET * 4))
end

function PegSolitaireScreen:onShowSolution()
    if not self.board:showSolution() then
        self:updateStatus(_("No hint is available here."))
        return
    end
    self.hint_cell = nil
    self:_save()
    self:_updateButtons()
    self:updateStatus()
end

function PegSolitaireScreen:onSolutionStep(dir)
    if self.board:solutionStep(dir) then
        self:_save()
        self:updateStatus()
    end
end

function PegSolitaireScreen:onNewGame()
    self:_startPuzzle(self:_nextUnsolved(self:_getBoardId()))
    self:_rebuild()
end

-- Today's puzzle: picked from the whole bank by the daily seed (the small
-- warm-up figures left out), the same for everyone today.
function PegSolitaireScreen:onDailyGame()
    local pool = {}
    for _i, pz in ipairs(Puzzles.all()) do
        if pz.count > Puzzles.EASY_MAX then pool[#pool + 1] = pz end
    end
    if #pool == 0 then return end
    local plugin = self.plugin
    local key = plugin.getPluginId and plugin:getPluginId() or plugin.name
    local pick
    DailySeed.run(key, function() pick = pool[math.random(#pool)] end)
    self:_startPuzzle(pick, os.date("%Y-%m-%d"))
    self:_rebuild()
end

function PegSolitaireScreen:openBoardMenu()
    local items = {}
    for _i, id in ipairs(Puzzles.boards()) do
        items[#items + 1] = {
            id   = id,
            text = BOARD_LABELS[id] .. " · " .. T(_("Solved: %1/%2"), self:solvedCount(id), #Puzzles.forBoard(id)),
        }
    end
    MenuHelper.openPickerMenu{
        title       = _("Board"),
        items       = items,
        current_id  = self:_getBoardId(),
        parent      = self,
        width_ratio = 0.9,
        on_select   = function(id)
            self.plugin:saveSetting("board", id)
            self:onNewGame()
        end,
    }
end

-- Every puzzle of the current board, easiest first, with its peg count and
-- difficulty; solved ones carry a check mark, others the best result so far.
function PegSolitaireScreen:openPuzzleMenu()
    local board = self:_getBoardId()
    local list = Puzzles.forBoard(board)
    if #list == 0 then return end
    local cur_id = (self.board.puzzle and not self.board.daily) and self.board.puzzle.id or nil
    local menu, cur
    local item_table = {}
    for i, pz in ipairs(list) do
        if pz.id == cur_id then cur = i end
        local best = self:bestLeft(pz.id)
        item_table[i] = {
            text      = T("%1 · %2 · %3", _(pz.name), T(_("Pegs: %1"), pz.count), DIFFICULTY_LABELS[pz.difficulty]),
            mandatory = self:isSolved(pz.id) and "✓" or (best and T(_("Best: %1"), best)) or nil,
            checked   = pz.id == cur_id,
            callback  = function()
                UIManager:close(menu)
                self:_startPuzzle(pz)
                self:_rebuild()
            end,
        }
    end
    menu = Menu:new{
        title                  = BOARD_LABELS[board],
        item_table             = item_table,
        width                  = math.floor(DeviceScreen:getWidth() * 0.9),
        height                 = math.floor(DeviceScreen:getHeight() * 0.9),
        disable_footer_padding = true,
        show_parent            = self,
    }
    if cur then menu:switchItemTable(nil, item_table, cur) end
    UIManager:show(menu)
    return menu
end

-- ---------------------------------------------------------------------------
-- Round over: no jump left (won or stuck), or the solution on show.
-- ---------------------------------------------------------------------------

function PegSolitaireScreen:isRoundOver()
    return self.board:isOver() or self.board:isShowingSolution()
end

function PegSolitaireScreen:getRoundOverButtons()
    local b = self.board
    local new_game = { text = _("New game"), callback = function() self:onNewGame() end }
    if b:isShowingSolution() then
        local back = { text = _("Step back"),    callback = function() self:onSolutionStep(-1) end }
        local fwd  = { text = _("Step forward"), callback = function() self:onSolutionStep(1) end }
        if self:isLandscape() then
            return { { back, fwd }, { new_game } }
        end
        return { { back, fwd, new_game } }
    end
    if not b:isWon() then
        -- Stuck: backing out of the dead end is the likely next step.
        return { { { text = _("Undo"), callback = function() self:onUndo() end }, new_game } }
    end
    return { new_game }
end

-- ---------------------------------------------------------------------------
-- Status
-- ---------------------------------------------------------------------------

function PegSolitaireScreen:updateStatus(msg)
    local b = self.board
    local status
    if msg then
        status = msg
    elseif not b.puzzle then
        status = ""
    elseif b:isShowingSolution() then
        status = T(_("Solution: jump %1/%2"), b.sol_step, #b.solution)
    elseif b:isWon() then
        status = T(_("Solved: %1! Time: %2"), RATING_LABELS.genius, b.timer:format())
    elseif b:isOver() then
        local n = b:pegCount()
        if n == 1 then
            status = T(_("One peg left, not in the goal hole. %1."), RATING_LABELS[b:rating()])
        else
            status = T(_("No jump left: %1 pegs remain. %2."), n, RATING_LABELS[b:rating()])
        end
    elseif b.warn_state == "no" then
        status = _("No solution from here any more.")
    else
        -- The Daily Challenge takes the difficulty's place: one line in portrait.
        status = self:joinStatus(
            b.daily and _("Daily Challenge") or nil,
            self:_puzzleName(b.puzzle),
            not b.daily and DIFFICULTY_LABELS[b.puzzle.difficulty] or nil,
            T(_("Pegs: %1"), b:pegCount()))
    end
    ScreenBase.updateStatus(self, status)
    -- Every jump, hint, undo and reveal ends here, so the bar follows the board.
    self:refreshActionBar()
end

function PegSolitaireScreen:_updateButtons()
    if self.undo_btn then self.undo_btn:enableDisable(self.board:canUndo()) end
    if self.redo_btn then self.redo_btn:enableDisable(self.board:canRedo()) end
    if self.restart_btn then self.restart_btn:enableDisable(self.board:canUndo()) end
end

return PegSolitaireScreen
