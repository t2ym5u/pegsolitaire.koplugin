-- puzzles_src.lua — the puzzles, as pictures. Read by build_puzzles.lua,
-- which checks every one is solvable and stores a solution.
--
-- Pictures list the board row by row, one character per grid square:
--   o  a peg          .  an empty hole        (space)  no hole
--   *  a peg in the goal hole                 +  the goal hole, empty
-- Triangular boards: row r has r+1 characters, no indentation.
-- A puzzle without a goal mark (full boards: `vacancy` instead of a picture)
-- gets `goal` = { row, col } (0-based), or "same" for the vacancy itself.
-- `name` is the English name (an i18n key in the game).

return {
    -- ---------------------------------------------------------------- English
    { id = "en_cross", board = "english", name = "Cross", pic = {
        "  ...  ",
        "  .o.  ",
        "..ooo..",
        "...*...",
        "...o...",
        "  ...  ",
        "  ...  " } },
    { id = "en_plus", board = "english", name = "Plus", pic = {
        "  ...  ",
        "  .o.  ",
        "...o...",
        ".oo*oo.",
        "...o...",
        "  .o.  ",
        "  ...  " } },
    { id = "en_fireplace", board = "english", name = "Fireplace", pic = {
        "  ooo  ",
        "  ooo  ",
        "..ooo..",
        "..o+o..",
        ".......",
        "  ...  ",
        "  ...  " } },
    { id = "en_uparrow", board = "english", name = "Up arrow", pic = {
        "  .o.  ",
        "  ooo  ",
        ".ooooo.",
        "...*...",
        "...o...",
        "  ooo  ",
        "  ooo  " } },
    { id = "en_pyramid", board = "english", name = "Pyramid", pic = {
        "  ...  ",
        "  .o.  ",
        "..ooo..",
        ".oo*oo.",
        "ooooooo",
        "  ...  ",
        "  ...  " } },
    { id = "en_diamond", board = "english", name = "Diamond", pic = {
        "  .o.  ",
        "  ooo  ",
        ".ooooo.",
        "ooo+ooo",
        ".ooooo.",
        "  ooo  ",
        "  .o.  " } },
    { id = "en_doublecross", board = "english", name = "Double cross", pic = {
        "  .o.  ",
        "  .o.  ",
        "..ooo..",
        "...*...",
        "..ooo..",
        "  .o.  ",
        "  ...  " } },
    { id = "en_longcross", board = "english", name = "Long cross", pic = {
        "  .o.  ",
        "  ooo  ",
        "..ooo..",
        "...*...",
        "...o...",
        "  .o.  ",
        "  ...  " } },
    { id = "en_triangle", board = "english", name = "Triangle", pic = {
        "  ...  ",
        "  ...  ",
        "...o...",
        "..o*o..",
        ".ooooo.",
        "  ...  ",
        "  ...  " } },
    { id = "en_lamp", board = "english", name = "Lamp", pic = {
        "  .o.  ",
        "  ooo  ",
        "..o*o..",
        "..ooo..",
        "...o...",
        "  ooo  ",
        "  ...  " } },
    { id = "en_house", board = "english", name = "House", pic = {
        "  ...  ",
        "  .o.  ",
        "..o*o..",
        ".ooooo.",
        "..ooo..",
        "  ooo  ",
        "  ...  " } },
    { id = "en_halfboard", board = "english", name = "Half board", pic = {
        "  ooo  ",
        "  ooo  ",
        "ooo*ooo",
        "ooo.ooo",
        ".......",
        "  ...  ",
        "  ...  " } },
    { id = "en_heart", board = "english", name = "Heart", pic = {
        "  ...  ",
        "  ...  ",
        ".oo.oo.",
        "ooooooo",
        ".oo*oo.",
        "  ooo  ",
        "  .o.  " } },
    { id = "en_star", board = "english", name = "Star", pic = {
        "  .o.  ",
        "  .o.  ",
        "..ooo..",
        "ooo+ooo",
        "..ooo..",
        "  .o.  ",
        "  .o.  " } },
    { id = "en_belt", board = "english", name = "Belt", pic = {
        "  ...  ",
        "  ...  ",
        "ooooooo",
        "ooo+ooo",
        "ooooooo",
        "  ...  ",
        "  ...  " } },
    { id = "en_frame", board = "english", name = "Frame", pic = {
        "  ooo  ",
        "  ooo  ",
        "oo...oo",
        "ooo+ooo",
        "oo...oo",
        "  ooo  ",
        "  ooo  " } },
    { id = "en_classic", board = "english", name = "Full board", vacancy = { 3, 3 }, goal = "same" },
    { id = "en_corner", board = "english", name = "Corner start", vacancy = { 0, 2 }, goal = "same" },
    { id = "en_side", board = "english", name = "Side start", vacancy = { 0, 3 }, goal = "same" },
    { id = "en_offcentre", board = "english", name = "Off-centre start", vacancy = { 2, 3 }, goal = "same" },

    -- ----------------------------------------------------------------- French
    { id = "fr_cross", board = "french", name = "Cross", pic = {
        "  ...  ",
        " ..o.. ",
        "..ooo..",
        "...o...",
        "...o...",
        " ..... ",
        "  ...  " } },
    { id = "fr_crown", board = "french", name = "Crown", pic = {
        "  ...  ",
        " o.o.o ",
        "ooooooo",
        "..ooo..",
        ".......",
        " ..... ",
        "  ...  " } },
    { id = "fr_corners", board = "french", name = "Four corners", pic = {
        "  ...  ",
        " oo.oo ",
        ".oo.oo.",
        "...*...",
        ".oo.oo.",
        " oo.oo ",
        "  ...  " } },
    { id = "fr_diamond", board = "french", name = "Diamond", pic = {
        "  .o.  ",
        " .ooo. ",
        ".ooooo.",
        "ooo.ooo",
        ".ooooo.",
        " .ooo. ",
        "  .o.  " } },
    { id = "fr_bigsquare", board = "french", name = "Big square", pic = {
        "  ...  ",
        " ooooo ",
        ".ooooo.",
        ".oo*oo.",
        ".ooooo.",
        " ooooo ",
        "  ...  " } },
    { id = "fr_full_a", board = "french", name = "Full board A", vacancy = { 0, 2 }, goal = "search" },
    { id = "fr_full_b", board = "french", name = "Full board B", vacancy = { 1, 3 }, goal = "search" },

    -- --------------------------------------------------------------- Triangle
    { id = "tri_corner", board = "triangle", name = "Corner start", vacancy = { 0, 0 }, goal = "same" },
    { id = "tri_edge", board = "triangle", name = "Side start", vacancy = { 2, 0 }, goal = "search" },
    { id = "tri_inner", board = "triangle", name = "Inner start", vacancy = { 2, 1 }, goal = "search" },
    { id = "tri_second", board = "triangle", name = "Second row start", vacancy = { 1, 0 }, goal = "search" },
    { id = "tri6_corner", board = "triangle6", name = "Corner start", vacancy = { 0, 0 }, goal = "search" },
    { id = "tri6_inner", board = "triangle6", name = "Inner start", vacancy = { 2, 1 }, goal = "search" },

    -- ----------------------------------------------------------------- Square
    { id = "sq5_side", board = "square5", name = "Side start", vacancy = { 0, 2 }, goal = "search" },
    { id = "sq5_inner", board = "square5", name = "Inner start", vacancy = { 1, 2 }, goal = "search" },
}
