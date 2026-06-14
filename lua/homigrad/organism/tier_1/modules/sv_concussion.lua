hg.organism.module.concussion = {}
local module = hg.organism.module.concussion

module[1] = function(org)
    org.concussion = 0
    org.concussionTracker = 0
end

module[2] = function(ply, org, timeValue)
    if org.concussion > 0 then
        local prevConcussion = org.prevConcussion or 0
        org.prevConcussion = org.concussion

        -- Track concussion increases for disorientation (when it climbs, not decreases)
        if org.concussion > prevConcussion then
            org.concussionTracker = (org.concussionTracker or 0) + (org.concussion - prevConcussion)

            -- Chance to induce vomiting from severe concussion
            if org.isPly and org.concussion >= 3 and math.random() < (org.concussion - prevConcussion) * 0.25 then
                org.wantToVomit = (org.wantToVomit or 0) + math.Rand(0.2, 0.5)
                org.vomitTypeHeadTrauma = math.random(10) == 1
            end
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
        end
    end
end
