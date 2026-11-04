local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path

describe("Puzzle bank memory", function()
    it("loads the data on first use only, and release() drops it", function()
        local Puzzles = dofile(DIR .. "puzzles.lua")
        local bank, pagodas = Puzzles.isLoaded()
        assert.is_false(bank)
        assert.is_false(pagodas)
        local ids = {}
        for _, pz in ipairs(Puzzles.all()) do ids[#ids + 1] = pz.id end
        bank, pagodas = Puzzles.isLoaded()
        assert.is_true(bank)
        assert.is_false(pagodas)
        local pg = Puzzles.pagodas("english", 17)
        assert.is_true(#pg > 0)
        Puzzles.release()
        bank, pagodas = Puzzles.isLoaded()
        assert.is_false(bank)
        assert.is_false(pagodas)
        local again = {}
        for _, pz in ipairs(Puzzles.all()) do again[#again + 1] = pz.id end
        assert.are.same(ids, again)
        assert.are.same(pg, Puzzles.pagodas("english", 17))
    end)
end)
