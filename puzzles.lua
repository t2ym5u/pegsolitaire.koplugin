-- ---------------------------------------------------------------------------
-- puzzles.lua — the puzzle bank (puzzles_data.lua) and the pagoda functions
-- (pagodas_data.lua), both built offline by tools/ and loaded on first use.
-- ---------------------------------------------------------------------------

local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

local Geometry = (function()
    local key = _dir .. "geometry"
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. "geometry.lua"))()
    end
    return package.loaded[key]
end)()

local Puzzles = {}

-- Difficulty by starting peg count.
Puzzles.EASY_MAX, Puzzles.MEDIUM_MAX = 12, 24

local bank, by_id, pagodas

local function loadData(name)
    local chunk = loadfile(_dir .. name)
    if not chunk then return {} end
    local ok, t = pcall(chunk)
    return (ok and type(t) == "table") and t or {}
end

local function load()
    if bank then return bank end
    bank, by_id = {}, {}
    for _, pz in ipairs(loadData("puzzles_data.lua")) do
        local geo = Geometry.get(pz.board)
        local pegs = geo and Geometry.decode(geo, pz.pegs)
        if pegs and pz.goal and pz.goal >= 1 and pz.goal <= geo.n then
            local count = 0
            for i = 1, geo.n do count = count + pegs[i] end
            pz.count = count
            pz.difficulty = (count <= Puzzles.EASY_MAX and "easy")
                or (count <= Puzzles.MEDIUM_MAX and "medium") or "hard"
            bank[#bank + 1] = pz
            by_id[pz.id] = pz
        end
    end
    return bank
end

function Puzzles.all()
    return load()
end

function Puzzles.get(id)
    load()
    return by_id[id]
end

-- The puzzles of one board, easiest (fewest pegs) first.
function Puzzles.forBoard(board)
    local list = {}
    for _, pz in ipairs(load()) do
        if pz.board == board then list[#list + 1] = pz end
    end
    table.sort(list, function(a, b)
        if a.count ~= b.count then return a.count < b.count end
        return a.id < b.id
    end)
    return list
end

-- Boards that have at least one puzzle, in Geometry.BOARDS order.
function Puzzles.boards()
    local have = {}
    for _, pz in ipairs(load()) do have[pz.board] = true end
    local list = {}
    for _, b in ipairs(Geometry.BOARDS) do
        if have[b] then list[#list + 1] = b end
    end
    return list
end

-- Pagoda functions for a board and goal hole (may be empty).
function Puzzles.pagodas(board, goal)
    if not pagodas then pagodas = loadData("pagodas_data.lua") end
    return pagodas[board .. ":" .. goal] or {}
end

return Puzzles
