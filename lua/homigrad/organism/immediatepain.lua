if SERVER then
    local painaddDrainRate = 16
    local adrenalinePainaddPassiveCap = 2

    hook.Add("Org Think", "ImmediatePainApply", function(owner, org, timeValue)
        if not org.painadd or org.painadd <= 0 then return end
        local adrenaline = math.min(org.adrenaline or 0, adrenalinePainaddPassiveCap)
        local painPacing = hg.organism.GetAdrenalinePainPacing and hg.organism.GetAdrenalinePainPacing(adrenaline) or 1
        painPacing = Lerp(math.Clamp(org.zerlkers or 0, 0, 1), painPacing, 0.025)
        local add = math.min(org.painadd, timeValue * painaddDrainRate * painPacing)
        org.avgpain = math.min(org.avgpain + add, 150)
        -- Stimulants pace this queue; they never discard it. Any pain still
        -- waiting here is allowed to arrive once the stimulant wears off.
        org.painadd = math.max(org.painadd - add, 0)
        org.pain = org.avgpain * math.max(1 - ((org.analgesia or 0) + (org.painkiller or 0) * 0.3), 0)
        org.pain = math.min(org.pain, 150)
    end, HOOK_MONITOR_HIGH)
    hook.Add("Org Think", "ImmediatePainDrainBoost", function(owner, org, timeValue)
        if org.avgpain <= 0 then return end
        local extraSub = timeValue * ( ((org.painkiller or 0) * 0.3 + (org.analgesia or 0)) * 4 ) * 2
        if org.naloxone and org.naloxone > 0 then
            extraSub = extraSub * math.max(0, 1 - org.naloxone * 0.5)
        end
        org.avgpain = math.max(org.avgpain - extraSub, 0)
        org.pain = org.avgpain * math.max(1 - ((org.analgesia or 0) + (org.painkiller or 0) * 0.3), 0)
        org.pain = math.min(org.pain, 150)
    end, HOOK_MONITOR_LOW)
end
