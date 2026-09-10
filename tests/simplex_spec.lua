require("tests.gmod_mock")

-- Load the simplex module
local simplex_module = dofile("gamemodes/zcity/gamemode/libraries/sh_simplex.lua")

describe("simplex noise library", function()

    describe("Noise2D", function()
        it("returns a number", function()
            local val = simplex.Noise2D(0, 0)
            assert.is_number(val)
        end)

        it("returns values in [-1, 1]", function()
            for x = -10, 10 do
                for y = -10, 10 do
                    local val = simplex.Noise2D(x, y)
                    assert.is_true(val >= -1 and val <= 1,
                        string.format("Noise2D(%d,%d) = %f out of range", x, y, val))
                end
            end
        end)

        it("is deterministic for the same inputs", function()
            local a = simplex.Noise2D(1.5, 2.7)
            local b = simplex.Noise2D(1.5, 2.7)
            assert.are.equal(a, b)
        end)

        it("produces different values for different inputs", function()
            local a = simplex.Noise2D(0, 0)
            local b = simplex.Noise2D(10, 10)
            -- Not mathematically guaranteed, but extremely likely
            assert.are_not.equal(a, b)
        end)

        it("handles fractional coordinates", function()
            local val = simplex.Noise2D(0.123, 0.456)
            assert.is_number(val)
            assert.is_true(val >= -1 and val <= 1)
        end)

        it("handles large coordinates", function()
            local val = simplex.Noise2D(1000, 2000)
            assert.is_number(val)
            assert.is_true(val >= -1 and val <= 1)
        end)

        it("handles negative coordinates", function()
            local val = simplex.Noise2D(-5.5, -3.2)
            assert.is_number(val)
            assert.is_true(val >= -1 and val <= 1)
        end)
    end)

    describe("Noise3D", function()
        it("returns a number", function()
            local val = simplex.Noise3D(0, 0, 0)
            assert.is_number(val)
        end)

        it("returns values in [-1, 1]", function()
            for x = -5, 5 do
                for y = -5, 5 do
                    local val = simplex.Noise3D(x, y, 0)
                    assert.is_true(val >= -1 and val <= 1,
                        string.format("Noise3D(%d,%d,0) = %f out of range", x, y, val))
                end
            end
        end)

        it("is deterministic", function()
            local a = simplex.Noise3D(1.1, 2.2, 3.3)
            local b = simplex.Noise3D(1.1, 2.2, 3.3)
            assert.are.equal(a, b)
        end)

        it("handles fractional coordinates", function()
            local val = simplex.Noise3D(0.1, 0.2, 0.3)
            assert.is_number(val)
            assert.is_true(val >= -1 and val <= 1)
        end)
    end)

    describe("Noise4D", function()
        it("returns a number", function()
            local val = simplex.Noise4D(0, 0, 0, 0)
            assert.is_number(val)
        end)

        it("returns values in [-1, 1]", function()
            for x = -3, 3 do
                for y = -3, 3 do
                    local val = simplex.Noise4D(x, y, 0, 0)
                    assert.is_true(val >= -1 and val <= 1,
                        string.format("Noise4D(%d,%d,0,0) = %f out of range", x, y, val))
                end
            end
        end)

        it("is deterministic", function()
            local a = simplex.Noise4D(1, 2, 3, 4)
            local b = simplex.Noise4D(1, 2, 3, 4)
            assert.are.equal(a, b)
        end)
    end)

    describe("GBlur2D", function()
        it("returns a positive number", function()
            local val = simplex.GBlur2D(0, 0, 1)
            assert.is_number(val)
            assert.is_true(val > 0)
        end)

        it("peaks at the origin", function()
            local center = simplex.GBlur2D(0, 0, 1)
            local off = simplex.GBlur2D(1, 1, 1)
            assert.is_true(center > off)
        end)

        it("decreases with distance", function()
            local a = simplex.GBlur2D(0, 0, 1)
            local b = simplex.GBlur2D(1, 0, 1)
            local c = simplex.GBlur2D(2, 0, 1)
            assert.is_true(a > b)
            assert.is_true(b > c)
        end)

        it("wider stddev produces lower peak", function()
            local narrow = simplex.GBlur2D(0, 0, 0.5)
            local wide = simplex.GBlur2D(0, 0, 2)
            assert.is_true(narrow > wide)
        end)

        it("is symmetric", function()
            local pos = simplex.GBlur2D(1, 0, 1)
            local neg = simplex.GBlur2D(-1, 0, 1)
            assert.are.equal(pos, neg)
        end)
    end)

    describe("GBlur1D", function()
        it("returns a positive number", function()
            local val = simplex.GBlur1D(0, 1)
            assert.is_number(val)
            assert.is_true(val > 0)
        end)

        it("peaks at zero", function()
            local center = simplex.GBlur1D(0, 1)
            local off = simplex.GBlur1D(1, 1)
            assert.is_true(center > off)
        end)

        it("is symmetric", function()
            local pos = simplex.GBlur1D(1, 1)
            local neg = simplex.GBlur1D(-1, 1)
            assert.are.equal(pos, neg)
        end)
    end)

    describe("caching", function()
        it("returns same results with caching enabled", function()
            simplex.internalCache = false
            local uncached = simplex.Noise2D(5.5, 3.3)
            simplex.internalCache = true
            local cached1 = simplex.Noise2D(5.5, 3.3)
            local cached2 = simplex.Noise2D(5.5, 3.3)
            simplex.internalCache = false

            assert.are.equal(uncached, cached1)
            assert.are.equal(cached1, cached2)
        end)

        it("caches 3D noise correctly", function()
            simplex.internalCache = true
            local a = simplex.Noise3D(1, 2, 3)
            local b = simplex.Noise3D(1, 2, 3)
            simplex.internalCache = false
            assert.are.equal(a, b)
        end)

        it("caches 4D noise correctly", function()
            simplex.internalCache = true
            local a = simplex.Noise4D(1, 2, 3, 4)
            local b = simplex.Noise4D(1, 2, 3, 4)
            simplex.internalCache = false
            assert.are.equal(a, b)
        end)

        it("caches GBlur2D correctly", function()
            simplex.internalCache = true
            local a = simplex.GBlur2D(1, 2, 1)
            local b = simplex.GBlur2D(1, 2, 1)
            simplex.internalCache = false
            assert.are.equal(a, b)
        end)

        it("caches GBlur1D correctly", function()
            simplex.internalCache = true
            local a = simplex.GBlur1D(1, 1)
            local b = simplex.GBlur1D(1, 1)
            simplex.internalCache = false
            assert.are.equal(a, b)
        end)
    end)

    describe("FractalSum", function()
        it("returns a number", function()
            local val = simplex.FractalSum(simplex.Noise2D, 2, 1, 1)
            assert.is_number(val)
        end)
    end)

    describe("FractalSumAbs", function()
        it("returns a non-negative number", function()
            local val = simplex.FractalSumAbs(simplex.Noise2D, 2, 1, 1)
            assert.is_number(val)
            assert.is_true(val >= 0)
        end)
    end)
end)
