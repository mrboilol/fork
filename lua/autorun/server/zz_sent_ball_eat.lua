hg = hg or {}

local BALL_HEAL = 25
local SATIETY_PER_POINT = 1
local EPSILON = 0.001
local TISSUE_KINDS = {"brute", "burn"}

local function healWorstTissue(org, amount, heal)
	local healed = 0

	while amount - healed > EPSILON do
		local limb = hg.SoftTissue.GetWorstLimb(org, TISSUE_KINDS)
		if not limb then break end

		local got = heal(org, "brute", limb, amount - healed)
		if got <= EPSILON then got = heal(org, "burn", limb, amount - healed) end
		if got <= EPSILON then break end

		healed = healed + got
	end

	return healed
end

local function healSimpleTissue(org, kind, limb, amount)
	return hg.SimpleHealth.Heal(org, kind, amount, limb)
end

local function healNormalTissue(org, kind, limb, amount)
	return hg.SoftTissue.Heal(org, kind, limb, amount)
end

local function eatBall(ply)
	local owner = hg.GetCurrentCharacter(ply) or ply
	local org = owner.organism
	if not org then return end

	local state = hg.SimpleHealth.GetState(org)
	if state then
		local remaining = BALL_HEAL - healWorstTissue(org, BALL_HEAL, healSimpleTissue)
		local oxyHealed = hg.SimpleHealth.Heal(org, "oxy", remaining)
		hg.SimpleHealth.Heal(org, "toxin", remaining - oxyHealed)
		return
	end

	local remaining = BALL_HEAL - healWorstTissue(org, BALL_HEAL, healNormalTissue)
	if remaining > EPSILON and org.satiety then
		org.satiety = math.min((org.satiety or 0) + remaining * SATIETY_PER_POINT, 100)
	end
end

hook.Add("PlayerUse", "HG_SentBallEat", function(ply, ent)
	if not IsValid(ent) or ent:GetClass() ~= "sent_ball" then return end

	ent:Remove()
	if ply:IsPlayer() and ply:Alive() then
		eatBall(ply)
		ply:SendLua("achievements.EatBall()")
	end

	return false
end)
