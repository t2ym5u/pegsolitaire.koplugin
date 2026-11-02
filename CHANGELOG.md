# Changelog

All notable changes to this project will be documented in this file.

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
