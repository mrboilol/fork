require("tests.gmod_mock")

describe("math utility functions (GMod extensions)", function()

    describe("math.Clamp", function()
        it("returns low when value is below low", function()
            assert.are.equal(0, math.Clamp(-5, 0, 10))
        end)

        it("returns high when value is above high", function()
            assert.are.equal(10, math.Clamp(15, 0, 10))
        end)

        it("returns value when in range", function()
            assert.are.equal(5, math.Clamp(5, 0, 10))
        end)

        it("returns low when equal to low", function()
            assert.are.equal(0, math.Clamp(0, 0, 10))
        end)

        it("returns high when equal to high", function()
            assert.are.equal(10, math.Clamp(10, 0, 10))
        end)

        it("works with negative ranges", function()
            assert.are.equal(-5, math.Clamp(-10, -5, 5))
        end)

        it("works with float values", function()
            assert.are.equal(0.5, math.Clamp(0.5, 0, 1))
        end)
    end)

    describe("math.Approach", function()
        it("approaches target from below", function()
            assert.are.equal(5, math.Approach(0, 10, 5))
        end)

        it("approaches target from above", function()
            assert.are.equal(5, math.Approach(10, 0, 5))
        end)

        it("does not overshoot target from below", function()
            assert.are.equal(10, math.Approach(8, 10, 5))
        end)

        it("does not overshoot target from above", function()
            assert.are.equal(0, math.Approach(2, 0, 5))
        end)

        it("returns target when already at target", function()
            assert.are.equal(5, math.Approach(5, 5, 1))
        end)

        it("handles zero increment", function()
            assert.are.equal(3, math.Approach(3, 10, 0))
        end)

        it("handles negative increment (takes absolute value)", function()
            assert.are.equal(5, math.Approach(0, 10, -5))
        end)
    end)

    describe("math.Remap", function()
        it("remaps midpoint correctly", function()
            assert.are.equal(50, math.Remap(5, 0, 10, 0, 100))
        end)

        it("remaps minimum to output minimum", function()
            assert.are.equal(0, math.Remap(0, 0, 10, 0, 100))
        end)

        it("remaps maximum to output maximum", function()
            assert.are.equal(100, math.Remap(10, 0, 10, 0, 100))
        end)

        it("extrapolates beyond range", function()
            assert.are.equal(150, math.Remap(15, 0, 10, 0, 100))
        end)

        it("remaps negative ranges", function()
            local result = math.Remap(0, -10, 10, 0, 1)
            assert.is_true(math.abs(result - 0.5) < 0.001)
        end)

        it("remaps inverted output range", function()
            assert.are.equal(50, math.Remap(5, 0, 10, 100, 0))
        end)
    end)

    describe("math.Rand", function()
        it("returns values in range", function()
            for _ = 1, 100 do
                local val = math.Rand(0, 10)
                assert.is_true(val >= 0 and val <= 10)
            end
        end)

        it("works with negative range", function()
            for _ = 1, 50 do
                local val = math.Rand(-10, -5)
                assert.is_true(val >= -10 and val <= -5)
            end
        end)
    end)

    describe("Lerp", function()
        it("returns a at t=0", function()
            assert.are.equal(10, Lerp(0, 10, 20))
        end)

        it("returns b at t=1", function()
            assert.are.equal(20, Lerp(1, 10, 20))
        end)

        it("returns midpoint at t=0.5", function()
            assert.are.equal(15, Lerp(0.5, 10, 20))
        end)

        it("extrapolates beyond t=1", function()
            assert.are.equal(30, Lerp(2, 10, 20))
        end)
    end)

    describe("Round", function()
        it("rounds to integer by default", function()
            assert.are.equal(3, Round(2.7))
            assert.are.equal(3, Round(3.2))
        end)

        it("rounds to specified decimals", function()
            assert.are.equal(2.5, Round(2.456, 1))
            assert.are.equal(2.46, Round(2.456, 2))
        end)

        it("rounds .5 up", function()
            assert.are.equal(3, Round(2.5))
        end)

        it("handles negative numbers", function()
            assert.are.equal(-3, Round(-2.7))
        end)
    end)

    describe("bit.band", function()
        it("performs bitwise AND", function()
            assert.are.equal(0, bit.band(0, 255))
            assert.are.equal(255, bit.band(255, 255))
            assert.are.equal(1, bit.band(1, 255))
            assert.are.equal(0, bit.band(256, 255))
        end)

        it("masks correctly for simplex perm table", function()
            -- Simplex uses bit.band(i, 255) to wrap indices
            assert.are.equal(0, bit.band(256, 255))
            assert.are.equal(1, bit.band(257, 255))
            assert.are.equal(255, bit.band(511, 255))
        end)
    end)

    describe("table extensions", function()
        describe("table.GetKeys", function()
            it("returns all keys", function()
                local t = {a = 1, b = 2, c = 3}
                local keys = table.GetKeys(t)
                assert.are.equal(3, #keys)
                table.sort(keys)
                assert.are.same({"a", "b", "c"}, keys)
            end)

            it("returns empty for empty table", function()
                assert.are.same({}, table.GetKeys({}))
            end)
        end)

        describe("table.IsEmpty", function()
            it("returns true for empty table", function()
                assert.is_true(table.IsEmpty({}))
            end)

            it("returns false for non-empty table", function()
                assert.is_false(table.IsEmpty({1}))
                assert.is_false(table.IsEmpty({a = 1}))
            end)
        end)

        describe("table.HasValue", function()
            it("finds existing value", function()
                assert.is_true(table.HasValue({1, 2, 3}, 2))
            end)

            it("returns false for missing value", function()
                assert.is_false(table.HasValue({1, 2, 3}, 4))
            end)

            it("works with string values", function()
                assert.is_true(table.HasValue({"a", "b"}, "a"))
                assert.is_false(table.HasValue({"a", "b"}, "c"))
            end)
        end)
    end)

    describe("type checking globals", function()
        it("isstring works", function()
            assert.is_true(isstring("hello"))
            assert.is_false(isstring(42))
            assert.is_false(isstring(nil))
            assert.is_false(isstring({}))
        end)

        it("isnumber works", function()
            assert.is_true(isnumber(42))
            assert.is_true(isnumber(3.14))
            assert.is_false(isnumber("42"))
            assert.is_false(isnumber(nil))
        end)

        it("istable works", function()
            assert.is_true(istable({}))
            assert.is_true(istable({1, 2}))
            assert.is_false(istable("hello"))
            assert.is_false(istable(42))
        end)

        it("isbool works", function()
            assert.is_true(isbool(true))
            assert.is_true(isbool(false))
            assert.is_false(isbool(1))
            assert.is_false(isbool(nil))
        end)
    end)

    describe("Vector", function()
        it("creates with components", function()
            local v = Vector(1, 2, 3)
            assert.are.equal(1, v[1])
            assert.are.equal(2, v[2])
            assert.are.equal(3, v[3])
        end)

        it("defaults to zero", function()
            local v = Vector()
            assert.are.equal(0, v[1])
            assert.are.equal(0, v[2])
            assert.are.equal(0, v[3])
        end)

        it("computes length", function()
            local v = Vector(3, 4, 0)
            assert.are.equal(5, v:Length())
        end)

        it("computes distance", function()
            local a = Vector(0, 0, 0)
            local b = Vector(3, 4, 0)
            assert.are.equal(5, a:Distance(b))
        end)

        it("supports addition", function()
            local a = Vector(1, 2, 3)
            local b = Vector(4, 5, 6)
            local c = a + b
            assert.are.equal(5, c[1])
            assert.are.equal(7, c[2])
            assert.are.equal(9, c[3])
        end)

        it("supports subtraction", function()
            local a = Vector(5, 5, 5)
            local b = Vector(1, 2, 3)
            local c = a - b
            assert.are.equal(4, c[1])
            assert.are.equal(3, c[2])
            assert.are.equal(2, c[3])
        end)

        it("supports scalar multiplication", function()
            local v = Vector(1, 2, 3) * 2
            assert.are.equal(2, v[1])
            assert.are.equal(4, v[2])
            assert.are.equal(6, v[3])
        end)

        it("computes dot product", function()
            local a = Vector(1, 0, 0)
            local b = Vector(0, 1, 0)
            assert.are.equal(0, a:Dot(b))

            local c = Vector(1, 2, 3)
            local d = Vector(4, 5, 6)
            assert.are.equal(32, c:Dot(d))
        end)
    end)
end)
