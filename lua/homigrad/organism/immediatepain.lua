if SERVER then
    local painaddDrainRate = 16
    local adrenalinePainaddPassiveRate = 20
    local adrenalinePainaddPassiveCap = 2
    local adrenalinePainaddPassiveMin = 15

    local function applyPain(org)
        local adrenaline = math.Clamp(org.adrenaline or 0, 0, 5)
        local pain = (org.avgpain or 0) * math.max(1 - (org.analgesia or 0) - (org.painkiller or 0) * 0.3, 0)
            / math.max(org.painResistanceMul or 1, 1) * math.max(1 - adrenaline * 0.14, 0.3)
        if (org.zerlkers or 0) > 0 or (org.adrenaline or 0) >= 3 then
            pain = math.min(pain, 69.99)
        end
        org.pain = math.min(pain, 150)
    end

    hook.Add("Org Think", "ImmediatePainApply", function(owner, org, timeValue)
        if org.otrub then return end
        if not org.painadd or org.painadd <= 0 then
            if org.avgpain > 0 then
                local extraSub = timeValue * ( (org.painkiller or 0) * 2 + (org.analgesia or 0) * 4 ) * 2
                if org.naloxone and org.naloxone > 0 then
                    extraSub = extraSub * math.max(0, 1 - org.naloxone * 0.5)
                end
                org.avgpain = math.max(org.avgpain - extraSub, 0)
                applyPain(org)
            end
            return
        end
        local adrenaline = math.min(org.adrenaline or 0, adrenalinePainaddPassiveCap)
        local pacing = hg.organism.GetAdrenalinePainPacing and hg.organism.GetAdrenalinePainPacing(adrenaline) or 1
        local add = math.min(org.painadd, timeValue * painaddDrainRate * pacing)
        local passiveDrain = 0
        if adrenaline > adrenalinePainaddPassiveMin then
            passiveDrain = math.min(org.painadd - add, timeValue * adrenalinePainaddPassiveRate * adrenaline)
        end
        local isHero = IsValid(owner) and owner:IsPlayer() and owner.RealishIsHero
        if isHero then
            org.avgpain = 0
            org.painadd = 0
            org.pain = 0
            org.shock = 0
            return
        end
        org.avgpain = math.min(org.avgpain + add, 150)
        org.painadd = math.max(org.painadd - add - passiveDrain, 0)
		applyPain(org)

		if org.avgpain > 0 then
			local extraSub = timeValue * ( (org.painkiller or 0) * 2 + (org.analgesia or 0) * 4 ) * 2
            if org.naloxone and org.naloxone > 0 then
                extraSub = extraSub * math.max(0, 1 - org.naloxone * 0.5)
            end
            org.avgpain = math.max(org.avgpain - extraSub, 0)
			applyPain(org)
		end
	end, HOOK_MONITOR_HIGH)
end
