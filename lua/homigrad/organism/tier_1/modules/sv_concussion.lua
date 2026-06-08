hg.organism.module.concussion = {}
local module = hg.organism.module.concussion

module[1] = function(org)
    org.concussion = 0
end

module[2] = function(ply, org, timeValue)
    if org.concussion > 0 then
        org.concussion = math.max(org.concussion - timeValue, 0)
        
        -- Drain consciousness (0.05 * concussion per second)
		if org.consciousness then
			org.consciousness = math.max(org.consciousness - (org.concussion * 0.032) * timeValue, 0)
		end

        if org.concussion > 2.5 then
             org.needfake = true
             -- Apply disorientation (set to 2)
             org.disorientation = math.max(org.disorientation or 0, 2)

             -- Trigger brain bleed for severe concussion
             if org.concussion >= 2.5 and (org.brainBleed or 0) < 0.3 then
                 org.brainBleed = math.min((org.brainBleed or 0) + 0.4, 1.0)
                 org.brain = math.min((org.brain or 0) + 0.05, 1.0)
             end
        end
    end
end
