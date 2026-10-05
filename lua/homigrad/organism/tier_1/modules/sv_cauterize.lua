local cauterizeThoughts = {
	"IT BURNS IT BURNS IT BURNS... but the bleeding stopped.",
	"God, that hurt worse than the wound. At least it's sealed.",
	"The smell of my own flesh... I'll never forget it.",
	"Burned shut. Ugly, painful, alive.",
	"I can't believe I just did that to myself.",
}

local cauterizeThoughtsOther = {
	"The wound is sealed. They won't forget that scream.",
	"I burned them shut. It had to be done.",
}

local woundReach = 12

local function woundWorldPos(ent, wound)
	if not isvector(wound[2]) or not isstring(wound[4]) then return end
	local boneIndex = ent:LookupBone(wound[4])
	if not boneIndex then return end
	local bonePos, boneAng = ent:GetBonePosition(boneIndex)
	if not bonePos then return end
	return LocalToWorld(wound[2], wound[3] or angle_zero, bonePos, boneAng)
end

local function closeWounds(org, ent, hitPos, includeAll)
	local closed = 0

	for _, list in ipairs({org.wounds or {}, org.arterialwounds or {}}) do
		for index = #list, 1, -1 do
			local wound = list[index]
			if (tonumber(wound[1]) or 0) > 0 then
				local inReach = includeAll
				if not inReach then
					local pos = IsValid(ent) and woundWorldPos(ent, wound)
					inReach = pos and pos:DistToSqr(hitPos) <= woundReach * woundReach
				end

				if inReach then
					wound[1] = 0
					table.remove(list, index)
					closed = closed + 1
				end
			end
		end
	end

	return closed
end

function hg.organism.Cauterize(org, ent, hitPos, includeAll, applier)
	if not org or not org.owner then return 0 end
	local owner = org.owner
	if hitPos == nil and not includeAll then return 0 end

	local closed = closeWounds(org, ent, hitPos, includeAll)
	if closed <= 0 then return 0 end

	if hg.organism.AddInstantPain then hg.organism.AddInstantPain(org, math.min(closed * 40, 120)) end
	if hg.organism.AddPain then hg.organism.AddPain(org, math.min(closed * 25, 100)) end
	org.shock = math.min((org.shock or 0) + closed * 12, 95)
	org.fearadd = (org.fearadd or 0) + 0.5

	if IsValid(ent) then
		ent:EmitSound("player/general/flesh_burn.wav", 70, math.random(90, 105))
		timer.Simple(1.5, function()
			if IsValid(ent) then ent:StopSound("player/general/flesh_burn.wav") end
		end)
	end

	if hg.QueuePainScream then hg.QueuePainScream(owner, 2) end

	if owner:IsPlayer() and owner:Alive() then
		owner:Thought(cauterizeThoughts[math.random(#cauterizeThoughts)], 8, "cauterized", 1, Color(255, 120, 60, 255))
	end

	if IsValid(applier) and applier ~= owner and applier:IsPlayer() then
		applier:Thought(cauterizeThoughtsOther[math.random(#cauterizeThoughtsOther)], 8, "cauterized_other", 1, Color(255, 170, 90, 255))
	end

	return closed
end

function hg.organism.CauterizeFlame(applier, target, hitPos, reach)
	if not IsValid(target) or not isvector(hitPos) then return 0 end
	local ply = target:IsPlayer() and target or hg.RagdollOwner(target)
	if not IsValid(ply) or not ply:Alive() or not ply.organism then return 0 end

	local char = hg.GetCurrentCharacter(ply)
	if not IsValid(char) then return 0 end

	woundReach = reach or 12
	local closed = hg.organism.Cauterize(ply.organism, char, hitPos, false, applier)
	woundReach = 12
	return closed
end

function hg.organism.CauterizeSelf(ply)
	if not IsValid(ply) or not ply:Alive() or not ply.organism then return 0 end
	local char = hg.GetCurrentCharacter(ply)
	if not IsValid(char) then return 0 end

	local handBone = char:LookupBone("ValveBiped.Bip01_R_Hand")
	local handPos = handBone and char:GetBonePosition(handBone)
	if not handPos then return 0 end

	return hg.organism.CauterizeFlame(ply, char, handPos, 22)
end

hook.Add("Org Think", "homigrad_burn_cauterize", function(owner, org)
	if not owner:IsPlayer() or not owner:Alive() or org.otrub then return end
	if CurTime() < (org.nextCauterize or 0) then return end

	local char = hg.GetCurrentCharacter(owner)
	if not IsValid(char) or not char:IsOnFire() then return end

	local hasOpen = false
	for _, list in ipairs({org.wounds or {}, org.arterialwounds or {}}) do
		for _, wound in ipairs(list) do
			if (tonumber(wound[1]) or 0) > 0 then hasOpen = true break end
		end
		if hasOpen then break end
	end
	if not hasOpen then return end

	org.nextCauterize = CurTime() + 3
	hg.organism.Cauterize(org, char, nil, true)
end)
