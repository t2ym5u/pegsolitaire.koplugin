# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-11-04

### Changed
- A hint never searches for more than about 2.5 s on an e-reader (it could
  take 5 s on a Kobo), and shows a progress bar when it takes a moment. In
  the rare position it can't settle in that time, it says "Can't tell
  quickly" and offers "Think longer" (up to 6 s, with a progress bar).
- The "Warn if unsolvable" check after each jump is capped at about 1 s,
  and when a saved game is reopened it runs once the board is on screen
  instead of delaying the opening.
- Finding the last solvable position to go back to is capped at 1.5 s.

## [1.0.3] - 2026-11-03

### Changed
- Picks up game-common 1.11.0: the shared on-screen keyboard (where used)
  gives every key the same letter size, and the no-repeat history helper.

## [1.0.2] - 2026-11-02

### Changed
- Picks up game-common 1.10.0: the shared Tools → Games menu also lists
  the games' new "· multiplayer" entries under Party & quiz.

## [1.0.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.0.0] - 2026-11-02

### Added
- First release: the classic peg solitaire. Jump a peg over a neighbour into
  the empty hole behind it, the jumped peg comes off; finish with one peg in
  the goal hole.
- Five boards: English (33 holes), French (37), triangles of 15 and 21 holes
  (six jump directions) and a 5×5 square.
- 35 puzzles: the full boards from their solvable starting holes (the French
  board's centre start has no one-peg finish, so its full-board puzzles start
  elsewhere) and classic figures — Cross, Plus, Fireplace, Pyramid, Up arrow,
  Diamond, Double cross, Heart, Star… Every puzzle is checked solvable by the
  offline solver and ships with a solution. Grouped by peg count: Easy (up to
  12), Medium (up to 24), Hard.
- Tap a peg, then one of the ringed holes it can jump into. Undo, Redo,
  Restart, pegs counter, timer and auto-save.
- End of game with the traditional rating (Genius, Excellent, Very good,
  Good, Fair, Beginner).
- Hint (two taps: mark the peg and its destination, then play it): always a
  jump that keeps the puzzle solvable from the current position, worked out
  by an on-device solver with a strict budget. When the position can no
  longer be solved, or the solver can't tell in time, it says so and offers
  to go back to the last position known to be solvable (or to think longer).
- "Warn if unsolvable" option: a quick check after each jump.
- Show solution: step through a solution from the start, forwards and back.
- "New game" opens the next unsolved puzzle of the board; a puzzle picker
  with solved marks and best results; a Daily Challenge.
