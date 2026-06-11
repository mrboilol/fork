local max, min, Round, Lerp, halfValue2 = math.max, math.min, math.Round, Lerp, util.halfValue2
--local Organism = hg.organism
hg.organism.module.lungs = {}
local module = hg.organism.module.lungs
module[1] = function(org)
	org.lungsL = {
		0, --состояние,пневмотаракс
		0
	}

	org.lungsR = {0, 0}
	org.trachea = 0
	org.pneumothorax = 0
	org.needle = 0
	org.tracheaPath = nil -- "trachea" or "pneumothorax" determined when first > 0.5
	org.nextCough = nil
	org.o2 = {
		range = 30,
		regen = 4,
		k = 0.5,
	}

	

			org.lungsfunction = true

	org.o2.curregen = org.o2.regen
	
	org.o2[1] = org.o2.range
	org.CO = 0
	org.COregen = 0
	org.lastCOBreathe = nil

	org.mannitol = 0
end

function hg.organism.OxygenateBlood(org)
	return (math.max(((1 - org.lungsL[1]) + (1 - org.lungsR[1])) / 2, 0.5) * (1 - org.trachea * 0.8)) * org.o2.regen / 4 * (org.owner:WaterLevel() < 3 and 1 or 0)// * (1 - org.pneumothorax)
end

function hg.organism.CanBreath(org)
	return org.o2 and org.o2.curregen >= org.losing_oxy
end

local function insta_send_holdingbreath(org)
	net.Start("organism_send") // отправляем только дизориентацию (чтобы не нагружать нет), и сразу
	
	local tbl = {}
	tbl.holdingbreath = org.holdingbreath
	tbl.owner = org.owner

	net.WriteTable(tbl)
	net.WriteBool(true)
	net.WriteBool(false)
	net.WriteBool(false)
	net.WriteBool(true) // вот эта шняга отвечает за то чтобы оно просто мерджнуло и всё
	net.Send(org.owner)
end

local function togglebreath(ply, toggle)
	local org = ply.organism
	
	if isbool(toggle) then
		if toggle then
			if not ply.organism.holdingbreath then
				ply.organism.holdingbreath = true
				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)	
				insta_send_holdingbreath(ply.organism)
			end
		else
			if ply.organism.holdingbreath then
				ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".wav" or "breathing/exhale/male/exhale_0"..math.random(5)..".wav",65)
				ply.organism.holdingbreath = false
				ply.releasebreathe = nil
				insta_send_holdingbreath(ply.organism)
			end
		end
	else
		if ply.organism.holdingbreath then
			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/exhale/female/exhale_0"..math.random(5)..".wav" or "breathing/exhale/male/exhale_0"..math.random(5)..".wav",65)
			ply.organism.holdingbreath = false
			ply.releasebreathe = nil
			insta_send_holdingbreath(ply.organism)
		else
			ply.organism.holdingbreath = true
			ply:EmitSound(ThatPlyIsFemale(ply) and "breathing/inhale/female/inhale_0"..math.random(5)..".wav" or "breathing/inhale/male/inhale_0"..math.random(4)..".wav",65)	
			insta_send_holdingbreath(ply.organism)
		end
	end

	local ent = hg.GetCurrentCharacter(ply)
	ent:StopSound(ply.lastPhr or "")
	ply.phrCld = 0
end

concommand.Add("hmcd_holdbreath",function(ply)
	if not ply.organism then return end
	if not ply:Alive() then return end
	if ply.organism.stamina[1] < 90 then return end
	if ply.organism.o2.curregen == 0 then return end

	if (ply.cooldownbreathe or 0) > CurTime() then return end
	ply.cooldownbreathe = CurTime() + 0.5

	togglebreath(ply)
end)

concommand.Add("+hmcd_holdbreath",function(ply)
	if not ply.organism then return end
	if not ply:Alive() then return end
	if ply.organism.stamina[1] < 90 then return end
	if ply.organism.o2.curregen == 0 then return end

	if (ply.cooldownbreathe or 0) > CurTime() then return end
	ply.cooldownbreathe = CurTime() + 0.5

	togglebreath(ply,true)
end)

concommand.Add("-hmcd_holdbreath",function(ply)
	if not ply.organism then return end
	if ply.organism.stamina[1] < 90 then return end
	if ply.organism.o2.curregen == 0 then return end

	if (ply.cooldownbreathe or 0) > CurTime() then ply.releasebreathe = ply.cooldownbreathe return end

	togglebreath(ply,false)
end)

local lowoxy = {
	"IM GONNA FAINT, I REALLY NEED SOME AIR",
	"DARK- EVERYTHING IS GOING DARK...",
	"I CANT BREATHE- WHY CANT I BREATHE...",
	"MY CHEST HURTS SO MUCH, I NEED AIR...",
	"THERES NOT ENOUGH OXYGEN, I NEED TO BREATHE...",
	"son im cooked 😭✌️"
}

local not_enough_intake = {
	//"I have to breathe...",
	//"I gotta take a break...",
	//"Need a break from this... to breathe...",
	//"Resting sounds like a nice idea.",
	"Im breathing very shallowly...",
	"I cant breathe properly...",
	"Its hard to breathe...",
	"I have less air than usual...",
	"Breathing is a unusual struggle...",
	"Im winded...",
	
}

local barely_breathing = {
	"I can barely breathe...",
	"Every breath is a struggle...",
	"Theres barely enough air for me to survive.",
	"I'm struggling to breathe.",
	"It's too hard to get air...",
}

local low_stamina = {
	"Im tired, im really tired...",
	"I can barely keep moving...",
	"I need to rest...",
	"I am REALLY, REALLY TIRED.",
	"I need to stop and rest...",
}

local drop_mask = {
	"I can't breathe in this mask... I need to take it off.",
	"Drop the mask, it's not worth it...",
	"It's fucking disgusting... and I surely can't breathe in this...",
	"Fucking stinks... Gotta take this mask off...",
}

local drugged = {
	"Ohhh hohoohoooo Ie-like it.....",
	"Fukkenh awesomee..... ffffeeelin gooooood..",
	"That's theh sStuffff DUDeeee",
	"I reallly like whatEvER I'm feeling right now....",
	"Oh yeahhhh this feels gooood!",
	"I want to feel likhe this for theRRRREST of my life",
	"Why am I here even?.. wWhatever whuhhh heh",
	"Whoa re you? Gett outtaheree...",
	"Don't want anything else... this is pERRRfect!..",
}

local bit_band,util_PointContents = bit.band,util.PointContents

local color_white, color_red, color_red2, color_red3 = Color(255, 255, 255), Color(255, 0, 0), Color(200, 55, 55), Color(255, 100, 100)
module[2] = function(owner, org, timeValue)
	local o2 = org.o2
	local losing_oxy = timeValue * 1 * math.Clamp(org.o2[1] / 30, 0.25, 1)
	org.losing_oxy = losing_oxy
	o2[1] = max(o2[1] - losing_oxy, 0)
	local ent = hg.GetCurrentCharacter(owner)
	local bone = ent:LookupBone("ValveBiped.Bip01_Head1")

	if (not bone) or (bone < 0) then bone = 6 end

	local head = ent:GetBonePosition(bone)
	
	if not head then
		head = ent:GetBonePosition(0)
	end

	if org.o2.curregen == 0 and org.holdingbreath then
		togglebreath(owner, false)
	end

	if org.holdingbreath then
		//org.stamina[1] = max(org.stamina[1] - timeValue * 15,0)
		if org.stamina[1] < 90 or org.o2[1] <= 10 then
			togglebreath(owner, false)
		end
		
		if owner.releasebreathe and owner.releasebreathe < CurTime() then
			togglebreath(owner, false)
			owner.releasebreathe = nil
		end
	end

	if not head then head = owner:GetPos() end
	
	local inwater = bit_band(util_PointContents(head),CONTENTS_WATER) == CONTENTS_WATER
	
	local success = owner:IsBerserk() or (not org.heartstop and org.alive and not (org.brain >= 0.4 and math.random(10 - (org.brain * 10)) < 4) and org.lungsfunction)
	if success and owner:IsPlayer() and inwater then success = false end
	if success and org.choking then org.needfake = true success = false end
	if success and org.vomitInThroat then success = false end
	org.choking = false
	local pneumothorax = (org.lungsR[2] == 1 or org.lungsL[2] == 1) and org.needle == 0
	
	org.needle = math.Approach(org.needle, 0, timeValue / 1200)

	if org.needle > 0 then
		org.hemothorax = false
	end

	if not org.hemothorax then
		org.pneumothorax = pneumothorax and min(org.pneumothorax + timeValue / 180 * (org.lungsL[2] + org.lungsR[2]), (org.lungsL[2] + org.lungsR[2]) / 2) or max(org.pneumothorax - timeValue / 10, 0)
	else
		org.pneumothorax = min(org.pneumothorax + timeValue / 120, 1) -- A bit faster than a single punctured lung
	end

		if org.lastCOBreathe and org.lastCOBreathe + 1 > CurTime() then
		org.COregen = math.Approach(org.COregen, 30, timeValue * 1)
	else
		org.COregen = math.Approach(org.COregen, 0, timeValue * 0.5)
	end
	
	if o2[1] < 15 then
        org.CO = math.min(org.CO + timeValue * 0.5, 30)
    end

	org.CO = max(org.CO - timeValue, 0)
	if success then
		local oxygenate = hg.organism.OxygenateBlood(org) * 0.5
		local lerp = min(max(org.pulse - 20, 0) / 20, 1)
		local regen = Lerp(lerp, 0, o2.regen * oxygenate * math.Rand(0.95, 1.05))

		org.CO = min(org.CO + (org.COregen > 0 and timeValue * 1.5 or 0), 30)

		org.consciousness = math.min(org.consciousness, (30 - org.CO) / 30)

		local mask_blevota = owner:GetNetVar("zableval_masku", false)

		local sprayed = org.is_sprayed_at
		org.is_sprayed_at = nil

        local blood_pressure_k = 1
        if org.bloodpressure < 70 then
            blood_pressure_k = math.Remap(org.bloodpressure, 0, 70, 0.1, 1)
        elseif org.bloodpressure > 115 then -- from sv_pulse
            blood_pressure_k = math.Remap(org.bloodpressure, 115, 190, 1, 0.75)
        end
        blood_pressure_k = math.Clamp(blood_pressure_k, 0.2, 1)

		local pulseMultiplier = math.Clamp((org.heartbeat or 70) / 70, 0.8, 1.5)
		local regenerate = regen * timeValue * 4 * (org.stamina[1] / org.stamina.max) * pulseMultiplier * (mask_blevota and 0 or 1) * ((org.temperature > 38) and math.Clamp(math.Remap(org.temperature, 38, 41, 1, 0.1), 0.1, 1) or 1) * blood_pressure_k * (1 - (org.CO / 30))
		if org.oxygen_deprivation and org.oxygen_deprivation > 0 then
			local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
			local hasStabilizer = totalAdrenaline > 0.5 or (org.thiamine or 0) > 0 or (org.tranexamic_acid or 0) > 0
			regenerate = regenerate * (hasStabilizer and 0.4 or 0.1) -- drugs reduce penalty from 90% to 60%
			org.oxygen_deprivation = math.max(org.oxygen_deprivation - timeValue * (hasStabilizer and 2 or 1), 0) -- drugs clear O2 deprivation faster
		end
		o2[1] = min(o2[1] + regenerate * math.Clamp(org.o2[1] / 30, 0.25, 1) * (org.holdingbreath and 0 or 1) * (sprayed and 0 or 1) * min((10 / max(org.CO,1)),1), o2.range * math.max(1 - org.pneumothorax * org.pneumothorax, 0.1) * math.min(org.blood / 3750, 1) * math.max(1 - (org.lungsL[1] + org.lungsR[1]) / 2, 0.5))

		-- Below 2500 blood, keep dropping O2
		-- Adrenaline, thiamine and tranexamic acid partially resist this to help kickstart recovery
		if org.blood < 2500 then
			local o2DropRate = (2500 - org.blood) / 2500 -- 0 to 1 based on how far below 2500
			local totalAdrenaline = (org.adrenaline or 0) + (org.noradrenaline or 0)
			local hasStabilizer = totalAdrenaline > 0.5 or (org.thiamine or 0) > 0 or (org.tranexamic_acid or 0) > 0
			o2[1] = max(o2[1] - timeValue * o2DropRate * (hasStabilizer and 0.6 or 2), 0)
		end

		-- Low blood pressure slowly lowers O2 to 0 if very low
		if org.bloodpressure and org.bloodpressure < 40 then
			local bp_o2DropRate = (40 - org.bloodpressure) / 40
			o2[1] = max(o2[1] - timeValue * bp_o2DropRate * 1.5, 0)
		end

		-- Trachea damage from breathing - damages trachea when breathing, more breathing = more damage
		-- Needle prevents trachea damage, only triggers when trachea > 0.5
		if org.trachea > 0.5 and org.trachea < 1.0 and org.needle <= 0 then
			local breatheAmount = regenerate * 0.01
			if breatheAmount > 0.01 then
				org.trachea = min(org.trachea + breatheAmount, 1)
			end
		end

		-- O2 impairment when trachea is damaged
		if org.trachea > 0 and org.trachea <= 0.5 then
			local impairment = org.trachea * 0.5 -- up to 25% O2 reduction at 0.5
			regenerate = regenerate * (1 - impairment)
		elseif org.trachea > 0.5 then
			-- Much worse impairment above 0.5 (50% to 100% reduction)
			local impairment = 0.5 + (org.trachea - 0.5) * 1.0 -- 50% at 0.5, up to 100% at 1.0
			regenerate = regenerate * (1 - impairment)
		end

		-- O2 drain when trachea is damaged (> 0.5)
		if org.trachea > 0.5 then
			local tracheaDrain = (org.trachea - 0.5) * 2 -- 0 at 0.5, up to 1 at 1.0
			o2[1] = max(o2[1] - timeValue * tracheaDrain, 0)
		end

		-- Gradual O2 drain for arteria wounds (direct pathway to brain)
		if org.arteriaO2Drain and org.arterialwounds then
			local arteriaOpen = false
			for _, wound in pairs(org.arterialwounds) do
				if wound[7] == "arteria" and wound[1] > 0 then
					arteriaOpen = true
					break
				end
			end
			if not arteriaOpen then
				org.arteriaO2Drain = false
			else
				local pulseMultiplier = math.Clamp((org.pulse or 70) / 70, 0.8, 1.5)
				local arteriaDrain = timeValue * 0.15 * pulseMultiplier
				o2[1] = max(o2[1] - arteriaDrain, 0)
			end
		end

		-- Trachea > 0.5: determine path once, then stick with it
		-- Needle prevents both
		if org.trachea > 0.5 and org.trachea < 1.0 and org.needle <= 0 and regenerate > 0 then
			-- First time above 0.5: choose path
			if not org.tracheaPath then
				org.tracheaPath = math.random() < 0.5 and "trachea" or "pneumothorax"
			end

			local damageSeverity = (org.trachea - 0.5) * 2
			local drainRate = regenerate * 0.005 * damageSeverity

			if org.tracheaPath == "trachea" then
				org.trachea = min(org.trachea + drainRate, 1)
			else
				org.pneumothorax = min(org.pneumothorax + drainRate * 0.5, 1)
			end
		end

		o2.curregen = regenerate

		o2[1] = max(o2[1] - (org.CO > 0 and o2.curregen * 1.1 * (org.CO / 30) or 0),0)

		//org.owner:ResetNotification("oxygen_cantbreathe")
		//org.owner:ResetNotification("oxygen_cantbreathe2")
	else
		o2.curregen = 0
	end

	if owner:IsBerserk() then
		o2[1] = math.max(5, o2[1])
	end
	
	if org.isPly and not org.otrub and o2.curregen < losing_oxy and org.analgesia <= 1.5 and !org.heartstop then
		if mask_blevota then
			if o2[1] < 15 then
				org.owner:Notify("DROP THE FUCKING MASK", 25, "take_gasmask2", 0, nil, color_red2)
			else
				org.owner:Notify(drop_mask[math.random(#drop_mask)], 15, "take_gasmask", 0)
			end
		else
			if o2[1] < 25 and o2[1] > 12 then
				org.owner:Notify(not_enough_intake[math.random(#not_enough_intake)], 61, "oxygen_lowintake", 3)
			end
		end

		if o2[1] < 12 then


			org.owner:Notify(lowoxy[math.random(#lowoxy)], 30, "lowoxy", 0, nil, color_red3)
	
			if o2[1] < 6 then
				org.owner:Notify("Oxygen... please...", 30, "lowoxy2", 0, nil, color_red)
			end
		end
	end

	-- Barely breathing (low curregen but just enough) - 2nd priority, bypassed if choking
	if org.isPly and not org.otrub and not org.choking and o2.curregen >= losing_oxy and o2.curregen < losing_oxy * 1.3 and org.analgesia <= 1.5 and !org.heartstop then
		org.owner:Notify(barely_breathing[math.random(#barely_breathing)], 45, "barely_breathing", 2)
	end

	-- Low stamina - 3rd priority, bypassed if choking
	if org.isPly and not org.otrub and not org.choking and org.stamina[1] < 30 and org.stamina[1] > 10 and org.analgesia <= 1.5 and !org.heartstop then
		org.owner:Notify(low_stamina[math.random(#low_stamina)], 50, "low_stamina", 3)
	end

	if org.analgesia > 1.5 then
		org.owner:Notify(drugged[math.random(#drugged)], 30, "drugged", 0, nil, color_white)
	end

	if org.analgesia > 1.5 or org.painkiller > 2.4 then
		if math.Rand(0, 500) < (org.analgesia + org.painkiller) then
			//org.lungsfunction = false
		end
	end
	if o2[1] == 0 then
		if math.random(50) == 1 then
			org.lungsfunction = false
		end
	else
			org.lungsfunction = true
	end

	if (org.lungsL[1] == 1 and org.lungsR[1] == 1) or org.heartstop then
		org.lungsfunction = false
	end

	if org.trachea >= 1.0 then
		org.lungsfunction = false
	end

	-- Spine3 (neck) damage affects breathing capability
	if org.spine3 and org.spine3 > 0.5 then
		local fake3 = hg.organism and hg.organism.fake_spine3 or 0.75
		local spine3BreathingPenalty = (org.spine3 - 0.5) / (fake3 - 0.5)
		if math.random() < spine3BreathingPenalty * 0.1 then
			org.lungsfunction = false
		end
	end

	--[[if (pneumothorax or org.trachea >= 0.6 or org.lungsR[1] >= 0.6 or org.lungsL[1] >= 0.6) and org.alive and o2[1] > 0 then
		local timeSub = org.pneumothorax + org.trachea + org.lungsR[1] + org.lungsL[1]
		org.nextCough = org.nextCough and org.nextCough or (CurTime() + 5)
		
		if org.nextCough < CurTime() then
			org.nextCough = CurTime() + math.random(15,30 - timeSub + math.max(10 - o2[1],0))
			owner:EmitSound("homigrad/player/male/male_cough"..math.random(5)..".wav",50 + Round(timeSub * 2.5))
		end
	end--]]

	if org.isPly then
		if org.pneumothorax > 0 then
			org.owner:Notify("I can feel something filling my lungs.", true, "pneumothorax1",10) // delay of 10 seconds before typing that
		else
			org.owner:ResetNotification("pneumothorax1")
		end

		if org.pneumothorax > 0.3 then
			org.owner:Notify("It's getting harder to breathe.", true, "pneumothorax2", 5)
		else
			org.owner:ResetNotification("pneumothorax2")
		end

		if org.pneumothorax > 0.5 then
			org.owner:Notify("I'm really struggling to breathe.", true, "pneumothorax3", 5)
		else
			org.owner:ResetNotification("pneumothorax3")
		end

		-- Trachea damage notifications
		if org.trachea > 0.3 and org.trachea <= 0.5 then
			org.owner:Notify("My throat feels like it has a hole in it.", true, "trachea1", 15)
		else
			org.owner:ResetNotification("trachea1")
		end

		if org.trachea > 0.5 and org.trachea < 1.0 then
			org.owner:Notify("I can't get any air through my trachea...", true, "trachea2", 5)
		else
			org.owner:ResetNotification("trachea2")
		end

		if org.trachea >= 1.0 then
			org.owner:Notify("MY TRACHEA IS COMPLETELY DESTROYED!", true, "trachea_critical", 0, nil, color_red)
		else
			org.owner:ResetNotification("trachea_critical")
		end
	end

	local k = halfValue2(o2[1], o2.range, o2.k)
	
	if o2[1] < 10 then
		if org.isPly then
			hg.StunPlayer(owner, 3)
		end
	end

	if o2[1] < 12 then
		org.needfake = true

		if org.isPly then
			hg.LightStunPlayer(owner, 3)
		end
	end

	local o2Cap = 4
	if o2[1] < o2Cap then
		local o2Severity = math.Clamp((o2Cap - o2[1]) / o2Cap, 0.1, 1)
		org.consciousness = math.max((org.consciousness or 1) - timeValue * o2Severity * 1.2, 0)
	end

	if org.lungsR[1] < 0.5 then
		//org.lungsR[1] = max(org.lungsR[1] - timeValue / 240, 0)
	end

	if org.lungsL[1] < 0.5 then
		//org.lungsL[1] = max(org.lungsL[1] - timeValue / 240, 0)
	end

	if owner:IsBerserk() then
		org.brain = math.min(0.5, org.brain)
	end

	if org.skull >= 0.6 then k = 0 end
	if org.brain >= 0.6 then k = 0 end

	if org.skull < 1 and org.skull >= 0.5 and org.bandagedskull then
		org.skull = math.Approach(org.skull, 0, timeValue / 600)
	end

	if org.brain >= 0.3 then
		if org.brain >= 0.5 then
			if math.random(60) == 1 then
				org.heartstop = true
			end
		end

		if org.brain > 0.35 and !org.heartstop then
			if math.random(60) == 1 then
				org.lungsfunction = true
			end
		end

		local brainCap = 0.35
		local brainSeverity = math.Clamp((org.brain - brainCap) / (1 - brainCap), 0.1, 1)
		org.consciousness = math.max((org.consciousness or 1) - timeValue * brainSeverity * 0.6, 0)
	end

	local death_from_braindamage = false
	if org.brain >= 0.7 and org.alive then
		death_from_braindamage = true
		org.alive = false
	end

	if org.skull == 1 then org.brain = min(org.brain + timeValue / 1000, 1) end

	if org.isPly then
		if org.brain > 0.1 and org.brain < 0.3 then
			org.owner:Notify(math.random(2) == 1 and "My head hurts..." or "Where am I?", true, "brain", 5)
		else
			org.owner:ResetNotification("brain") 
		end
	end

	org.brain = max(org.brain - timeValue / 400 * ((org.mannitol > 0 and org.brain < 0.6) and 1 or (org.brain > 0.1 and 0.1 or 0)), 0)
	org.mannitol = math.Approach(org.mannitol, 0, timeValue / 200)
	
	if k < 0.25 then
		if not org.alive and owner:IsPlayer() and death_from_braindamage and org.o2[1] == 0 then
			hg.achievements.AddPlayerAchievement(owner,"brain",1)
			if org.analgesia > 1 then
				hg.achievements.AddPlayerAchievement(owner,"drugs",1)
			end
		end
		
		local hypoxiaResistance = not org.otrub and 0.3 or 1
		org.brain = min(org.brain + timeValue / (org.brain < 0.3 and 300 or 120) * math.min(((org.o2[1] < 0.25 and 1 or 0) + org.skull), 1) * hypoxiaResistance, 1)
	end --~120 seconds to fully die (0.3 of 300 and 0.4 of 60 seconds after)
end