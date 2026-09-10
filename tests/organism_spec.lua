require("tests.gmod_mock")

-- The production organism modules use GMod-specific Lua syntax (// comments, != operator)
-- which standard Lua 5.1 cannot parse directly.
-- We test the pure logic by replicating key functions and data structures.

describe("organism system", function()

    describe("paincheck", function()
        -- Replicated from sv_pain.lua:51-61
        local function paincheck(org)
            local analgesiaMul = (org.analgesia * 4 + 1)
            local adrenalineMul = math.min(math.max(1 + org.adrenaline, 1), 1.2)
            return (org.shock > org.shock_turn * 4 * analgesiaMul)
        end

        it("returns false when shock is 0", function()
            local org = { shock = 0, shock_turn = 10, analgesia = 0, adrenaline = 0 }
            assert.is_falsy(paincheck(org))
        end)

        it("returns true when shock exceeds threshold", function()
            local org = { shock = 50, shock_turn = 10, analgesia = 0, adrenaline = 0 }
            -- threshold = 10 * 4 * (0*4+1) = 40
            assert.is_truthy(paincheck(org))
        end)

        it("analgesia raises the threshold", function()
            local org = { shock = 50, shock_turn = 10, analgesia = 2, adrenaline = 0 }
            -- threshold = 10 * 4 * (2*4+1) = 10 * 4 * 9 = 360
            assert.is_falsy(paincheck(org))
        end)

        it("high analgesia makes threshold very high", function()
            local org = { shock = 100, shock_turn = 10, analgesia = 5, adrenaline = 0 }
            -- threshold = 10 * 4 * (5*4+1) = 10 * 4 * 21 = 840
            assert.is_falsy(paincheck(org))
        end)

        it("returns true only when shock exactly crosses threshold", function()
            local org = { shock = 40, shock_turn = 10, analgesia = 0, adrenaline = 0 }
            -- threshold = 10 * 4 * 1 = 40, shock == 40 so NOT greater
            assert.is_falsy(paincheck(org))

            org.shock = 41
            assert.is_truthy(paincheck(org))
        end)
    end)

    describe("should_gain_fear", function()
        -- Replicated from sv_pulse.lua:22-23
        local function should_gain_fear(org)
            return ((org.pain > 30) or (org.blood < 4000) or (org.bleed > 1))
        end

        it("returns truthy when pain > 30", function()
            assert.is_truthy(should_gain_fear({ pain = 50, blood = 5000, bleed = 0 }))
        end)

        it("returns truthy when blood < 4000", function()
            assert.is_truthy(should_gain_fear({ pain = 0, blood = 3500, bleed = 0 }))
        end)

        it("returns truthy when bleed > 1", function()
            assert.is_truthy(should_gain_fear({ pain = 0, blood = 5000, bleed = 2 }))
        end)

        it("returns falsy when healthy", function()
            assert.is_falsy(should_gain_fear({ pain = 10, blood = 5000, bleed = 0 }))
        end)

        it("returns falsy at exact thresholds", function()
            -- pain == 30 is NOT > 30
            assert.is_falsy(should_gain_fear({ pain = 30, blood = 4000, bleed = 1 }))
        end)

        it("returns truthy when multiple conditions met", function()
            assert.is_truthy(should_gain_fear({ pain = 50, blood = 3000, bleed = 2 }))
        end)
    end)

    describe("AddNaturalAdrenaline", function()
        -- Replicated from sv_stamina.lua:248-264
        local function AddNaturalAdrenaline(org, fAmount)
            if org.adrenalineStorage == 0 then return end
            if fAmount < 0 then return end
            local amt = math.min(org.adrenalineStorage, fAmount)
            org.adrenaline = math.min(org.adrenaline + amt, 5)
            org.adrenalineStorage = org.adrenalineStorage - amt
            org.nextAdrenalineRegen = CurTime() + 30
        end

        it("adds adrenaline from storage", function()
            local org = { adrenaline = 0, adrenalineStorage = 5 }
            _SetCurTime(100)
            AddNaturalAdrenaline(org, 2)
            assert.are.equal(2, org.adrenaline)
            assert.are.equal(3, org.adrenalineStorage)
        end)

        it("caps adrenaline at 5", function()
            local org = { adrenaline = 4, adrenalineStorage = 5 }
            _SetCurTime(100)
            AddNaturalAdrenaline(org, 3)
            assert.are.equal(5, org.adrenaline)
        end)

        it("does not add if storage is 0", function()
            local org = { adrenaline = 1, adrenalineStorage = 0 }
            AddNaturalAdrenaline(org, 2)
            assert.are.equal(1, org.adrenaline)
        end)

        it("does not add negative amounts", function()
            local org = { adrenaline = 1, adrenalineStorage = 5 }
            AddNaturalAdrenaline(org, -1)
            assert.are.equal(1, org.adrenaline)
            assert.are.equal(5, org.adrenalineStorage)
        end)

        it("uses only available storage", function()
            local org = { adrenaline = 0, adrenalineStorage = 1 }
            _SetCurTime(100)
            AddNaturalAdrenaline(org, 3)
            assert.are.equal(1, org.adrenaline)
            assert.are.equal(0, org.adrenalineStorage)
        end)

        it("sets a regen cooldown of 30 seconds", function()
            local org = { adrenaline = 0, adrenalineStorage = 5 }
            _SetCurTime(100)
            AddNaturalAdrenaline(org, 1)
            assert.are.equal(130, org.nextAdrenalineRegen)
        end)

        it("drains storage by exactly the used amount", function()
            local org = { adrenaline = 3, adrenalineStorage = 5 }
            _SetCurTime(100)
            AddNaturalAdrenaline(org, 2)
            -- Cap at 5, so only 2 used
            assert.are.equal(5, org.adrenaline)
            assert.are.equal(3, org.adrenalineStorage)
        end)
    end)

    describe("OxygenateBlood", function()
        -- Replicated from sv_lungs.lua:73-76
        local function OxygenateBlood(org)
            return (math.max(((1 - org.lungsL_1) + (1 - org.lungsR_1)) / 2, 0.5) * (1 - org.trachea * 0.8)) * org.o2_regen / 4 * (org.waterLevel < 3 and 1 or 0)
        end

        it("returns 1.0 for healthy lungs on land", function()
            local org = { lungsL_1 = 0, lungsR_1 = 0, trachea = 0, o2_regen = 4, waterLevel = 0 }
            assert.are.equal(1, OxygenateBlood(org))
        end)

        it("returns 0 when underwater", function()
            local org = { lungsL_1 = 0, lungsR_1 = 0, trachea = 0, o2_regen = 4, waterLevel = 3 }
            assert.are.equal(0, OxygenateBlood(org))
        end)

        it("decreases with left lung damage", function()
            local healthy = OxygenateBlood({ lungsL_1 = 0, lungsR_1 = 0, trachea = 0, o2_regen = 4, waterLevel = 0 })
            local damaged = OxygenateBlood({ lungsL_1 = 0.5, lungsR_1 = 0, trachea = 0, o2_regen = 4, waterLevel = 0 })
            assert.is_true(damaged < healthy)
        end)

        it("decreases with right lung damage", function()
            local healthy = OxygenateBlood({ lungsL_1 = 0, lungsR_1 = 0, trachea = 0, o2_regen = 4, waterLevel = 0 })
            local damaged = OxygenateBlood({ lungsL_1 = 0, lungsR_1 = 0.5, trachea = 0, o2_regen = 4, waterLevel = 0 })
            assert.is_true(damaged < healthy)
        end)

        it("decreases with trachea damage", function()
            local healthy = OxygenateBlood({ lungsL_1 = 0, lungsR_1 = 0, trachea = 0, o2_regen = 4, waterLevel = 0 })
            local damaged = OxygenateBlood({ lungsL_1 = 0, lungsR_1 = 0, trachea = 0.5, o2_regen = 4, waterLevel = 0 })
            assert.is_true(damaged < healthy)
        end)

        it("floors at 0.5 when both lungs fully destroyed", function()
            local val = OxygenateBlood({ lungsL_1 = 1, lungsR_1 = 1, trachea = 0, o2_regen = 4, waterLevel = 0 })
            assert.are.equal(0.5, val)
        end)

        it("reaches 0.1 when trachea fully destroyed (80% reduction on 0.5 floor)", function()
            local val = OxygenateBlood({ lungsL_1 = 1, lungsR_1 = 1, trachea = 1, o2_regen = 4, waterLevel = 0 })
            -- 0.5 * (1 - 1 * 0.8) = 0.5 * 0.2 = 0.1
            assert.is_true(math.abs(val - 0.1) < 0.001)
        end)
    end)

    describe("heartstop conditions", function()
        -- From sv_pulse.lua:292-293
        it("triggers at pulse < 10", function()
            local pulse = 9
            local brain = 0
            local bloodpressure = 93
            local temperature = 36.7
            local heartstop = pulse < 10 or brain >= 0.85 or bloodpressure < 25
            assert.is_true(heartstop)
        end)

        it("triggers at brain >= 0.85", function()
            local pulse = 70
            local brain = 0.85
            local bloodpressure = 93
            local heartstop = pulse < 10 or brain >= 0.85 or bloodpressure < 25
            assert.is_true(heartstop)
        end)

        it("triggers at blood pressure < 25", function()
            local pulse = 70
            local brain = 0
            local bloodpressure = 20
            local heartstop = pulse < 10 or brain >= 0.85 or bloodpressure < 25
            assert.is_true(heartstop)
        end)

        it("triggers at temperature < 28", function()
            local temp = 27
            local heartstop = temp < 28 or temp > 42
            assert.is_true(heartstop)
        end)

        it("triggers at temperature > 42", function()
            local temp = 43
            local heartstop = temp < 28 or temp > 42
            assert.is_true(heartstop)
        end)

        it("does not trigger at normal vitals", function()
            local pulse = 70
            local brain = 0
            local bloodpressure = 93
            local temperature = 36.7
            local heartstop = pulse < 10 or brain >= 0.85 or bloodpressure < 25
            heartstop = heartstop or temperature < 28 or temperature > 42
            assert.is_false(heartstop)
        end)
    end)

    describe("blood pressure calculation", function()
        it("MAP is 93 at normal pulse", function()
            local pulse_factor = 70 / 70
            local map = 93 * pulse_factor
            assert.are.equal(93, map)
        end)

        it("MAP scales with pulse", function()
            local map_normal = 93 * (70 / 70)
            local map_high = 93 * (140 / 70)
            assert.is_true(map_high > map_normal)
            assert.are.equal(186, map_high)
        end)

        it("MAP is 0 when dead", function()
            local alive = false
            local map = alive and 93 or 0
            assert.are.equal(0, map)
        end)

        it("MAP is 0 during heartstop", function()
            local heartstop = true
            local map = 93
            if heartstop then map = 0 end
            assert.are.equal(0, map)
        end)
    end)

    describe("consciousness tracking for brain damage", function()
        -- From sv_organism.lua:595-606
        it("does not accumulate below threshold", function()
            local consciousnessTracker = 0
            local brain = 0
            local prevConsciousness = 0.5
            local consciousness = 0.6

            if consciousness > prevConsciousness then
                consciousnessTracker = consciousnessTracker + (consciousness - prevConsciousness)
            end
            -- 0.1 < 2.5 threshold, no brain damage
            assert.is_true(consciousnessTracker < 2.5)
            assert.are.equal(0, brain)
        end)

        it("applies brain damage at 2.5 threshold", function()
            local consciousnessTracker = 2.4
            local brain = 0
            local prevConsciousness = 0.5
            local consciousness = 0.7

            if consciousness > prevConsciousness then
                consciousnessTracker = consciousnessTracker + (consciousness - prevConsciousness)
            end

            if consciousnessTracker >= 2.5 then
                brain = math.min(brain + 0.015, 1.0)
                consciousnessTracker = 0
            end

            assert.are.equal(0.015, brain)
            assert.are.equal(0, consciousnessTracker)
        end)
    end)

    describe("metabolism hunger rate", function()
        -- From sv_metabolism.lua:37-51
        local function get_hunger_rate(satiety, timeSinceClimbed, timeValue)
            local hungerRate = 0
            if satiety > 60 and timeSinceClimbed < 45 then
                hungerRate = -timeValue * 0.1
            elseif satiety > 30 then
                hungerRate = -timeValue * 0.05
            elseif satiety > 0 then
                hungerRate = timeValue * 0.045
            else
                hungerRate = timeValue * 0.075
            end
            return hungerRate
        end

        it("reduces hunger when well-fed and recently eaten", function()
            local rate = get_hunger_rate(80, 10, 1)
            assert.is_true(rate < 0)
            assert.are.equal(-0.1, rate)
        end)

        it("slowly reduces hunger at moderate satiety", function()
            local rate = get_hunger_rate(50, 100, 1)
            assert.is_true(rate < 0)
            assert.are.equal(-0.05, rate)
        end)

        it("increases hunger at low satiety", function()
            local rate = get_hunger_rate(15, 100, 1)
            assert.is_true(rate > 0)
            assert.are.equal(0.045, rate)
        end)

        it("increases hunger faster at zero satiety", function()
            local rate = get_hunger_rate(0, 100, 1)
            assert.is_true(rate > 0)
            assert.are.equal(0.075, rate)
        end)

        it("hunger rate scales with timeValue", function()
            local rate1 = get_hunger_rate(0, 100, 1)
            local rate2 = get_hunger_rate(0, 100, 2)
            assert.are.equal(rate1 * 2, rate2)
        end)
    end)

    describe("pain mitigation from healthy left hand", function()
        -- From sv_pain.lua:81-109
        local function get_pain_mitigation(org)
            local leftHandHealthy = not org.larmamputated
                and not (org.larm and org.larm >= 1)
                and not (org.larmdislocation or org.larmdislocated)
            local rightHandDamaged = (org.rarm and org.rarm >= 1)
                or (org.rarmdislocation or org.rarmdislocated)
                or org.rarmamputated
            local isOneHanding = org.isOneHanding

            if leftHandHealthy and rightHandDamaged and not isOneHanding then
                return 0.5
            end
            return 1
        end

        it("returns 1 when both hands healthy", function()
            local org = {
                larmamputated = false, larm = 0, larmdislocation = false,
                rarmamputated = false, rarm = 0, rarmdislocation = false,
                isOneHanding = false,
            }
            assert.are.equal(1, get_pain_mitigation(org))
        end)

        it("returns 0.5 when right arm damaged and left healthy", function()
            local org = {
                larmamputated = false, larm = 0, larmdislocation = false,
                rarmamputated = false, rarm = 1, rarmdislocation = false,
                isOneHanding = false,
            }
            assert.are.equal(0.5, get_pain_mitigation(org))
        end)

        it("returns 1 when one-handing despite conditions met", function()
            local org = {
                larmamputated = false, larm = 0, larmdislocation = false,
                rarmamputated = false, rarm = 1, rarmdislocation = false,
                isOneHanding = true,
            }
            assert.are.equal(1, get_pain_mitigation(org))
        end)

        it("returns 1 when left arm also damaged", function()
            local org = {
                larmamputated = false, larm = 1, larmdislocation = false,
                rarmamputated = false, rarm = 1, rarmdislocation = false,
                isOneHanding = false,
            }
            assert.are.equal(1, get_pain_mitigation(org))
        end)

        it("returns 0.5 when right arm amputated", function()
            local org = {
                larmamputated = false, larm = 0, larmdislocation = false,
                rarmamputated = true, rarm = 0, rarmdislocation = false,
                isOneHanding = false,
            }
            assert.are.equal(0.5, get_pain_mitigation(org))
        end)

        it("returns 0.5 when right arm dislocated", function()
            local org = {
                larmamputated = false, larm = 0, larmdislocation = false,
                rarmamputated = false, rarm = 0, rarmdislocation = true,
                isOneHanding = false,
            }
            assert.are.equal(0.5, get_pain_mitigation(org))
        end)
    end)

    describe("brain damage from consciousness tracking", function()
        -- From sv_pain.lua:237-246
        local function brain_consciousness_drain(brain, timeValue)
            if brain > 0.325 then
                local brainSeverity = (brain - 0.325) / 0.675
                local drain = (0.17 + brainSeverity * 0.06) * timeValue
                return drain
            end
            return 0
        end

        it("no drain below 0.325 brain damage", function()
            assert.are.equal(0, brain_consciousness_drain(0.3, 1))
            assert.are.equal(0, brain_consciousness_drain(0, 1))
        end)

        it("drains at minimum rate at 0.325 threshold", function()
            local drain = brain_consciousness_drain(0.326, 1)
            assert.is_true(drain > 0)
            -- Should be close to 0.17
            assert.is_true(math.abs(drain - 0.17) < 0.01)
        end)

        it("drains at maximum rate at full brain damage", function()
            local drain = brain_consciousness_drain(1.0, 1)
            -- At brain=1: severity=1, drain = 0.17 + 0.06 = 0.23
            assert.is_true(math.abs(drain - 0.23) < 0.001)
        end)

        it("scales with timeValue", function()
            local drain1 = brain_consciousness_drain(0.5, 1)
            local drain2 = brain_consciousness_drain(0.5, 2)
            assert.is_true(math.abs(drain2 - drain1 * 2) < 0.001)
        end)
    end)

    describe("caliber weight calculation", function()
        -- From sv_organism.lua:476
        local function calc_caliber_weight(force, mass, diameter)
            return (force / 200) + (mass / 20) + (diameter / 15)
        end

        it("returns 0 for zero stats", function()
            assert.are.equal(0, calc_caliber_weight(0, 0, 0))
        end)

        it("classifies light caliber below 1.0", function()
            -- Light pistol: force=40, mass=3, diameter=3
            local w = calc_caliber_weight(40, 3, 3)
            assert.is_true(w < 1.0)
        end)

        it("classifies heavy caliber above 0.8", function()
            -- Heavy rifle: force=300, mass=25, diameter=12
            local w = calc_caliber_weight(300, 25, 12)
            assert.is_true(w > 0.8)
        end)

        it("scales linearly with force", function()
            local w1 = calc_caliber_weight(100, 0, 0)
            local w2 = calc_caliber_weight(200, 0, 0)
            assert.are.equal(w1 * 2, w2)
        end)
    end)
end)
