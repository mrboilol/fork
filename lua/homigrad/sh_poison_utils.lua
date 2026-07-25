hg.poison = hg.poison or {}
hg.poison.registry = hg.poison.registry or {}

function hg.poison.Register(config)
	local key = config.key
	local notifyKey = key .. "notificate"
	local notifyDelay = config.notifyDelay or 20
	local notifyMsg = config.notifyMsg
	local notifyTag = config.notifyTag or key
	local killDelay = config.killDelay or 30
	local hookSuffix = config.hookSuffix or key

	hg.poison.registry[key] = config

	hook.Add("Org Clear", "RemovePoison_" .. hookSuffix, function(org)
		org[key] = nil
		org[notifyKey] = nil
	end)

	hook.Add("Org Think", "poison_" .. hookSuffix, function(owner, org, timeValue)
		if not owner:IsPlayer() or not owner:Alive() then return end
		if (not org[key]) or (not org.alive) then return end

		local curtime = CurTime()

		if config.earlyCheck then
			config.earlyCheck(owner, org, curtime)
		end

		if not org[notifyKey] and (org[key] + notifyDelay) < curtime then
			org[notifyKey] = true
			if notifyMsg then
				org.owner:Notify(notifyMsg, true, notifyTag, 3)
			end
			if config.notifySound then
				config.notifySound(org.owner)
			else
				org.owner:EmitSound(
					(ThatPlyIsFemale(org.owner) and "vo/npc/female01/moan0" .. math.random(5) .. ".wav")
					or "vo/npc/male01/moan0" .. math.random(5) .. ".wav"
				)
			end
		end

		if (org[key] + killDelay) < curtime then
			org.o2.regen = 0
		end
	end)
end
