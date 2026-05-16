//шо за бизнес сука
hook.Add("Org Think", "regenerationexpie", function(owner, org, timeValue)
	if not owner:IsPlayer() or not owner:Alive() then return end
	if owner.PlayerClassName != "expie" then return end
	if org.heartstop then return end

	org.blood = math.Approach(org.blood, 5000, timeValue * 30)

	for i, wound in pairs(org.wounds) do
		wound[1] = math.max(wound[1] - timeValue * 0.3,0)
	end
	
	for i, wound in pairs(org.arterialwounds) do
		wound[1] = math.max(wound[1] - timeValue * 0.3,0)
	end
	
	org.internalBleed = math.max(org.internalBleed - timeValue * 0.3, 0)

end)

hook.Add("PlayerDeath", "ExpieDeathSound", function(ply)
	if ply.PlayerClassName == "expie" then
		ply:EmitSound("expie/voice/death" .. math.random(1,4) .. ".wav")
	end
end)

hook.Add("HomigradDamage", "ExpieHit", function(ply, dmgInfo, hitgroup, ent)
	if ply.PlayerClassName == "expie" and !ply.otrub and math.random(1, 100) <=  75 and dmgInfo:GetDamage() > 3 then
		ply:EmitSound("expie/voice/pain" .. math.random(1, 14) .. ".wav")
		
		local weight = math.Rand(0.4, 0.65)
		local tid = "ExpiePain" .. ply:EntIndex()
		local step = 0
		local steps = 40
		
		timer.Remove(tid)
		timer.Create(tid, 0.03, steps, function()
			if not IsValid(ply) or not ply:Alive() then 
				timer.Remove(tid) 
				return 
			end

			local targetEnt = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
			if not IsValid(targetEnt) then 
				timer.Remove(tid) 
				return 
			end

			local flexREye = targetEnt:GetFlexIDByName("R_Eye_pain")
			local flexLEye = targetEnt:GetFlexIDByName("L_Eye_pain")
			local flexMouth = targetEnt:GetFlexIDByName("Mouth_open")

			step = step + 1

			local cweight = 0
			if step <= 5 then
				cweight = Lerp(step / 5, 0, weight)
			else
				cweight = Lerp((step - 5) / (steps - 5), weight, 0)
			end

			if flexREye and flexREye != -1 then targetEnt:SetFlexWeight(flexREye, cweight) end
			if flexLEye and flexLEye != -1 then targetEnt:SetFlexWeight(flexLEye, cweight) end
			if flexMouth and flexMouth != -1 then targetEnt:SetFlexWeight(flexMouth, cweight) end
		end)
	end
end)


local fur_pain = {
    "expie/voice/pain1.wav",
    "expie/voice/pain2.wav",
    "expie/voice/pain3.wav",
    "expie/voice/pain4.wav",
    "expie/voice/pain5.wav",
    "expie/voice/pain6.wav",
    "expie/voice/pain7.wav",
    "expie/voice/pain8.wav",
    "expie/voice/pain9.wav",
    "expie/voice/pain10.wav",
    "expie/voice/pain11.wav",
    "expie/voice/pain12.wav",
    "expie/voice/pain13.wav",
    "expie/voice/pain14.wav",
    "expie/voice/death1.wav",
    "expie/voice/death2.wav",
    "expie/voice/death3.wav",
    "expie/voice/death4.wav",
}

local uwuspeak_phrases = {
    "expie/voice/growl1.wav",
    "expie/voice/growl2.wav",
    "expie/voice/weh.wav",
    "expie/voice/yawn1.wav",
    "expie/voice/yawn2.wav",
    "expie/voice/death1.wav",
    "expie/voice/alert2.wav",
    "expie/voice/alert3.wav",
    "expie/voice/alert1.wav",
    "expie/voice/alert4.wav",
    "expie/voice/pain3.wav",
    "expie/voice/pain14.wav",
}

hook.Add("HG_ReplacePhrase", "ExpiePhrases", function(ply, phrase, muffed, pitch)
	if IsValid(ply) and ply.PlayerClassName == "expie" then
		local inpain = ply.organism.pain > 60
		local phr = (inpain and fur_pain[math.random(#fur_pain)] or uwuspeak_phrases[math.random(#uwuspeak_phrases)])

		return ply, phr, muffed, pitch
	end
end)

hook.Add("HG_ReplaceBurnPhrase", "ExpieBurnPhrases", function(ply, phrase)
	if ply.PlayerClassName == "expie" then
		return ply, fur_pain[math.random(#fur_pain)]
	end
end)
