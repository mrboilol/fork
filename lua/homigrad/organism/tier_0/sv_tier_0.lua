hg.organism = hg.organism or {}
--local Organism = hg.organism
hg.organism.list = hg.organism.list or {}
local hook_Run = hook.Run
function hg.organism.Add(ent)
	ent.organism = {
		owner = ent
	}

	local org = ent.organism
	org.owner = ent
	hg.organism.list[ent] = org
	return org
end

function hg.organism.Clear(org)
	hook_Run("Org Clear", org)
	if not IsValid(org.owner) then return end
	
	local owner = org.owner
	if owner:IsPlayer() then
		local lastDeathTime = owner.lastDeathTime or 0
		if CurTime() - lastDeathTime < 2 then
			return
		end
	end
	
	owner.fullsend = true
	hg.send_organism(org)
end

function hg.organism.Remove(ent)
	local org = hg.organism.list[ent]
	if org then org.owner = nil end
	hg.organism.list[ent] = nil
end

hook.Add("PlayerInitialSpawn", "homigrad-organism", function(ply) hg.organism.Add(ply) end)
hook.Add("Player Spawn", "homigrad-organism", function(ply) hg.organism.Clear(ply.organism) end)
hook.Add("PlayerDisconnected", "homigrad-organism", function(ply) hg.organism.Remove(ply) end)
hook.Add("PostPlayerDeath", "homigrad-organism", function(ply)
	ply.lastDeathTime = CurTime()
	
	local entIdx = ply:EntIndex()
	if timer.GetTable then
		for k, v in pairs(timer.GetTable()) do
			if string.find(k, entIdx) then
				timer.Remove(k)
			end
		end
	end
	
	local ragdoll = ply:GetNWEntity("RagdollDeath")
	
	if not IsValid(ragdoll) then ragdoll = ply.FakeRagdoll end

	if IsValid(ragdoll) then
		local newOrg = hg.organism.Add(ragdoll)
		table.Merge(newOrg, ply.organism)

		hook.Run("RagdollDeath", ply, ragdoll)

		table.Merge(zb.net.list[ragdoll], zb.net.list[ply])

		newOrg.alive = false
		newOrg.owner = ragdoll
		ragdoll:CallOnRemove("organism", hg.organism.Remove, ragdoll)
		newOrg.owner.fullsend = true
		hg.send_bareinfo(newOrg)
	end

	hg.organism.Clear(ply.organism)

	hook.Run("PostPostPlayerDeath", ply, ragdoll)
end)

local tickrate = 1 / 10
local delay = 0
local time, mulTime, start
local CurTime = CurTime
local SysTime = SysTime
timer.Create("homigrad-organism", tickrate, 0, function()
	time = CurTime()
	local tickrate2 = tickrate// / math.max(game.GetTimeScale(), 0.01)
	//print(delay ,time + tickrate)
	if delay + tickrate2 > time then
		if HGPerf and perfStart then HGPerf:End("org.think.gate", perfStart) end
		return
	end

	delay = time

	if not start then
		start = SysTime()
		if HGPerf and perfStart then HGPerf:End("org.think.init", perfStart) end
		return
	end
	
	local sysTime = SysTime()
	mulTime = (sysTime - start) * game.GetTimeScale()

	start = sysTime
	for owner, org in pairs(hg.organism.list) do -- теперь ясно почему от трупов лагает...
		if not IsValid(owner) or org.owner ~= owner then hg.organism.list[owner] = nil continue end
		if org.godmode then continue end
		hook_Run("Org Think", owner, org, mulTime)
	end
	if HGPerf and perfStart then HGPerf:End("org.think.main", perfStart) end
end)

	local lastcall = SysTime()
hook.Add("Org Think Call", "homigrad-organism", function(owner, org)
	local sysTime = SysTime()
	if (sysTime - lastcall) < tickrate then return end
	lastcall = sysTime
	hook_Run("Org Think", owner, org, 0.00001)

end)


hook.Add("Fake", "organism", function(ply, ragdoll)
	ragdoll.organism = ply.organism
	--zb.net.list[ragdoll] = zb.net.list[ply]
end)
