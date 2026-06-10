hg.organism.module.concussion = {}
local module = hg.organism.module.concussion

module[1] = function(org)
    org.concussion = 0
    org.concussionTracker = 0
    org.brainBleedTriggered = false
end

module[2] = function(ply, org, timeValue)
    if org.concussion > 0 then
        local prevConcussion = org.prevConcussion or 0
        org.prevConcussion = org.concussion

        -- Track concussion increases for disorientation (when it climbs, not decreases)
        if org.concussion > prevConcussion then
            org.concussionTracker = (org.concussionTracker or 0) + (org.concussion - prevConcussion)
        end

        -- Apply 2 points of disorientation when concussion climbs 2.5 points
        if (org.concussionTracker or 0) >= 2.5 then
            org.disorientation = (org.disorientation or 0) + 2
            org.brain = math.min((org.brain or 0) + 0.01, 1.0)
            org.concussionTracker = 0
        end

        org.concussion = math.max(org.concussion - timeValue, 0)

        -- Drain consciousness (0.05 * concussion per second)
		if org.consciousness then
			org.consciousness = math.max(org.consciousness - (org.concussion * 0.032) * timeValue, 0)
		end

        if org.concussion > 3 then
             org.needfake = true

             -- Trigger brain bleed for severe concussion (one-time per event)
             if org.concussion >= 3 and not org.brainBleedTriggered then
                 org.brainBleed = math.min((org.brainBleed or 0) + 0.4, 1.0)
                 org.brain = math.min((org.brain or 0) + 0.025, 1.0)
                 org.brainBleedTriggered = true
             end
        else
             -- Reset trigger when concussion drops below 3
             org.brainBleedTriggered = false
        end
    end
end
