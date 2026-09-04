if SERVER then
    local painaddDrainRate = 16
    local adrenalinePainaddPassiveRate = 20
    local adrenalinePainaddPassiveCap = 2
    local adrenalinePainaddPassiveMin = 15

    local function applyPain(org)
        local angerPainMul = 1 - math.Clamp(org.anger or 0, 0, 1) * 0.16
        local pain = (org.avgpain or 0) * math.max(1 - (org.adrenaline or 0) / 4, 0.75) * math.max(1 - (org.analgesia or 0), 0) * angerPainMul
        if (org.zerlkers or 0) > 0 or (org.adrenaline or 0) >= 3 then
            pain = math.min(pain, 69.99)
        end
        org.pain = math.min(pain, 150)
    end

    hook.Add("Org Think", "ImmediatePainApply", function(owner, org, timeValue)
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
        local add = math.min(org.painadd, timeValue * painaddDrainRate)
        local passiveDrain = 0
        if adrenaline > adrenalinePainaddPassiveMin then
            passiveDrain = math.min(org.painadd - add, timeValue * adrenalinePainaddPassiveRate * adrenaline)
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
