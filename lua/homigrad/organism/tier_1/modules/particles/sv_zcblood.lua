local sendEvery = 0.25
local smoothing = 0.5
local nextSend = 0

local function internalLoss(org)
	return (org.internalBleed or 0) / 14 * 10 * (org.pulse or 70) / 70
end

local function sendBleed(ent, org, dt)
	local rate = 0

	if org and org.alive ~= false and org.blood then
		local last = ent.zcbLastBlood
		if last and last > org.blood then
			rate = math.max((last - org.blood) / dt - internalLoss(org), 0)
		end
		ent.zcbLastBlood = org.blood
	else
		ent.zcbLastBlood = nil
	end

	ent.zcbRate = Lerp(smoothing, ent.zcbRate or 0, rate)
	if ent.zcbRate < 0.05 then ent.zcbRate = 0 end

	if math.abs(ent:GetNW2Float("zcbBleed", 0) - ent.zcbRate) > 0.05 then
		ent:SetNW2Float("zcbBleed", ent.zcbRate)
	end
end

hook.Add("Think", "zcblood_bleed", function()
	if nextSend > CurTime() then return end
	nextSend = CurTime() + sendEvery

	for _, ply in player.Iterator() do
		sendBleed(ply, ply:Alive() and ply.organism, sendEvery)
	end

	for _, rag in ipairs(ents.FindByClass("prop_ragdoll")) do
		if rag.organism then sendBleed(rag, rag.organism, sendEvery) end
	end
end)
