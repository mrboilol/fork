hg.organism.module.concussion = {}
local module = hg.organism.module.concussion

module[1] = function(org)
    org.concussion = 0
    org.concussionTracker = 0
    org.concussionSpikeTracker = 0
end

module[2] = function(ply, org, timeValue)
    if org.concussion > 0 then
        local prevConcussion = org.prevConcussion or 0
        org.prevConcussion = org.concussion

        -- Track concussion increases for disorientation (when it climbs, not decreases)
        if org.concussion > prevConcussion then
            local concussionGain = org.concussion - prevConcussion
            org.concussionTracker = (org.concussionTracker or 0) + concussionGain
            org.concussionSpikeTracker = (org.concussionSpikeTracker or 0) + concussionGain

            -- Every two concussion gained is a major neurological hit.
            -- Keep any remainder so repeated smaller head injuries still add up.
            while org.concussionSpikeTracker >= 2 do
                org.consciousness = math.max((org.consciousness or 1) - 0.3, 0)
                org.concussionSpikeTracker = org.concussionSpikeTracker - 2
            end

            -- Chance to induce vomiting from severe concussion
            if org.isPly and org.concussion >= 3 and math.random() < (org.concussion - prevConcussion) * 0.25 then
                org.wantToVomit = (org.wantToVomit or 0) + math.Rand(0.2, 0.5)
                org.vomitTypeHeadTrauma = math.random(10) == 1
            end
        end

        -- Apply 2 points of disorientation when concussion climbs 2.5 points
        while (org.concussionTracker or 0) >= 2.5 do
            org.disorientation = (org.disorientation or 0) + 2
            org.brain = math.min((org.brain or 0) + 0.01, 1.0)
            org.concussionTracker = org.concussionTracker - 2.5
        end

        org.concussion = math.max(org.concussion - timeValue, 0)

        -- Heavy consciousness drain that scales with concussion (much heavier above 4)
        if org.consciousness then
            local baseDrain = org.concussion * 0.05
            local heavyDrain = org.concussion > 4 and (org.concussion - 4) * 0.1 or 0
            org.consciousness = math.max(org.consciousness - (baseDrain + heavyDrain) * timeValue, 0)
        end

        local traumaResistance = hg.organism.GetTraumaRagdollResistance and hg.organism.GetTraumaRagdollResistance(org) or 0
        if org.concussion > 3 + traumaResistance * 1.5 then
             org.needfake = true
        end
    end
end
