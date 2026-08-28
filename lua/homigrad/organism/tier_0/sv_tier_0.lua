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

function hg.organism.Clear(org, suppressNetwork)
	hook_Run("Org Clear", org)//.owner.organism_internal)
	if IsValid(org.owner) then org.owner.fullsend = true end
	if not suppressNetwork then hg.send_organism(org) end
end

function hg.organism.Remove(ent)
	local org = hg.organism.list[ent]
	if org then org.owner = nil end
	hg.organism.list[ent] = nil
end

hook.Add("PlayerInitialSpawn", "homigrad-organism", function(ply) hg.organism.Add(ply) end)
hook.Add("Player Spawn", "homigrad-organism", function(ply) hg.organism.Clear(ply.organism) end)
hook.Add("PlayerDisconnected", "homigrad-organism", function(ply) hg.organism.Remove(ply) end)

local function stopVitalSigns(org)
	if not org then return end

	org.alive = false
	org.heartstop = true
	org.heartbeat = 0
	org.pulse = 0
	org.bloodPressure = 0
	org.systolic = 0
	org.diastolic = 0
	org.cardiacOutput = 0
	org.strokeVolume = 0
	org.mechanicalPulseCapture = 0
	org.pulseDeficit = 0
	org.ecgState = "asystole"
	org.perfusion = 0
	org.peripheralperfusion = 0
	org.cerebralPerfusion = 0
	org.myocardialOxygen = 0
	org.bodyoxygen = 0
	org.brainoxygen = 0
	org.brainoxygenTarget = 0
	if org.o2 then org.o2[1] = 0 end
end

hook.Add("PostPlayerDeath", "homigrad-organism", function(ply)
	local ragdoll = ply:GetNWEntity("RagdollDeath")
	
	if not IsValid(ragdoll) then ragdoll = ply.FakeRagdoll end

	if IsValid(ragdoll) then
		stopVitalSigns(ply.organism)
		local newOrg = hg.organism.Add(ragdoll)
		table.Merge(newOrg, ply.organism)
		newOrg.woundNetGeneration = (newOrg.woundNetGeneration or 0) + 1
		newOrg.woundNetFlushPending = nil
		newOrg.woundsNetDirty = nil
		newOrg.arterialWoundsNetDirty = nil
		newOrg.mirrorWoundsToDeathRagdoll = nil

		hook.Run("RagdollDeath", ply, ragdoll)

		table.Merge(zb.net.list[ragdoll], zb.net.list[ply])

		newOrg.alive = false
		newOrg.owner = ragdoll
		ragdoll:CallOnRemove("organism", hg.organism.Remove, ragdoll)
		newOrg.owner.fullsend = true
		hg.organism.FlushWoundsNet(newOrg, true, true)
		hg.organism.FlushArterialWoundsNet(newOrg, true)
		hg.send_bareinfo(newOrg, true, true)
	end

	hg.organism.Clear(ply.organism, true)

	hook.Run("PostPostPlayerDeath", ply, ragdoll)
end)

local tickrate = 1 / 10
local delay = 0
local time, mulTime, start
local CurTime = CurTime
local SysTime = SysTime
hook.Add("Think", "homigrad-organism", function()
	time = CurTime()
	local tickrate2 = tickrate// / math.max(game.GetTimeScale(), 0.01)
	//print(delay ,time + tickrate)
	if delay + tickrate2 > time then return end

	delay = time

	if not start then
		start = SysTime()
		return
	end
	
	mulTime = (SysTime() - start) * game.GetTimeScale()

	start = SysTime()
	for owner, org in pairs(hg.organism.list) do
		if not IsValid(owner) or not org or org.owner ~= owner then
			hg.organism.list[owner] = nil
			continue
		end
		if org.alive == false then
			if owner:IsRagdoll() then hook_Run("Org PostMortem Think", owner, org, mulTime) end
			continue
		end
		if owner:IsPlayer() and not owner:Alive() then continue end
		if org.godmode then continue end
		hook_Run("Org Think", owner, org, mulTime)
	end
end)

local lastcall = SysTime()
hook.Add("Org Think Call", "homigrad-organism", function(owner, org)
	if (SysTime() - lastcall) < tickrate then return end
	if not IsValid(owner) or not org or org.alive == false or (owner:IsPlayer() and not owner:Alive()) then return end
	lastcall = SysTime()
	hook_Run("Org Think", owner, org, 0.00001)
end)


hook.Add("Fake", "organism", function(ply, ragdoll)
	ragdoll.organism = ply.organism
	--zb.net.list[ragdoll] = zb.net.list[ply]
end)
