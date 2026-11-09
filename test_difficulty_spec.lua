local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

package.preload["gettext"] = function()
    return setmetatable({}, { __call = function(_, s) return s end })
end
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

-- Difficulty guarantees of the puzzle bank: a puzzle's level is its
-- starting peg count (Easy <= EASY_MAX < Medium <= MEDIUM_MAX < Hard), every
-- level is populated, and each board lists its puzzles easiest first.
-- (Solvability of every stored puzzle is checked in test_pegsolitaire_spec.lua.)
local function lrequire(name)
    local key = DIR .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(DIR .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Geometry = lrequire("geometry")
local Puzzles  = lrequire("puzzles")

local LEVELS = { "easy", "medium", "hard" }

describe("Peg solitaire difficulty", function()
    it("the peg-count bands are ordered", function()
        assert.are.equal(12, Puzzles.EASY_MAX)
        assert.are.equal(24, Puzzles.MEDIUM_MAX)
        assert.is_true(Puzzles.EASY_MAX < Puzzles.MEDIUM_MAX)
    end)

    it("groups by peg count", function()
        for _, pz in ipairs(Puzzles.all()) do
            if pz.count <= 12 then assert.are.equal("easy", pz.difficulty)
            elseif pz.count <= 24 then assert.are.equal("medium", pz.difficulty)
            else assert.are.equal("hard", pz.difficulty) end
        end
    end)

    it("every level holds puzzles, and the levels grow on average", function()
        local n, sum = {}, {}
        for _, d in ipairs(LEVELS) do n[d], sum[d] = 0, 0 end
        for _, pz in ipairs(Puzzles.all()) do
            n[pz.difficulty] = n[pz.difficulty] + 1
            sum[pz.difficulty] = sum[pz.difficulty] + pz.count
        end
        local prev = 0
        for _, d in ipairs(LEVELS) do
            assert.is_true(n[d] >= 3, d .. " has " .. n[d])
            assert.is_true(sum[d] / n[d] > prev, d)
            prev = sum[d] / n[d]
        end
    end)

    it("each board lists its puzzles easiest first", function()
        local rank = { easy = 1, medium = 2, hard = 3 }
        for _, b in ipairs(Geometry.BOARDS) do
            local list = Puzzles.forBoard(b)
            for i = 2, #list do
                assert.is_true(list[i - 1].count <= list[i].count, b)
                assert.is_true(rank[list[i - 1].difficulty] <= rank[list[i].difficulty], b)
            end
        end
    end)
end)
