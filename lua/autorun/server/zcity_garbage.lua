ab_MedicalGarbageTypes = {
	["bandage"] = {"models/plane_bandage_01.mdl","models/plane_bandage_02.mdl","models/plane_bandage_03.mdl","models/plane_bandage_04.mdl","models/plane_bandage_05.mdl","models/plane_bandage_06.mdl","models/plane_bandage_abdominal.mdl","models/plane_bandage_chest.mdl","models/plane_bandage_compres.mdl","models/plane_bandage_gauze.mdl"},
	["common"] = {"models/plane_glove_01.mdl","models/plane_glove_02.mdl","models/plane_glove_03.mdl","models/plane_glove_pack.mdl","models/plane_bandage_burn.mdl"},
}

--snd_jack_hmcd_bandage.ogg -- Bandage
--snds_jack_gmod/ez_medical/15.ogg -- Pain meds
--snd_jack_hmcd_needleprick.ogg - Needle

local sound_Table = {
	["snd_jack_hmcd_bandage.ogg"] = function(ent)
		ab_GarbageSpawn(ent:GetPos(), "bandage")

	end,
	["snds_jack_gmod/ez_medical/15."] = function(ent)
		ab_GarbageSpawn(ent:GetPos(), "bandage")

	end,
	["snd_jack_hmcd_needleprick.ogg"] = function(ent)
		ab_GarbageSpawn(ent:GetPos(), "bandage")
	end,
}

hook.Add( "EntityEmitSound", "TimeWarpSounds", function( t ) -- eL primo retardinio
	local snd = t.SoundName
	local ent = t.Entity
	
	if ent:IsPlayer() then 
		local f = sound_Table[snd] 
		if f then f(ent) end
	end
end)

function ab_GarbageSpawn(pos, type)
	local med = ents.Create("ent_medical_garbage")

	local offset = pos + Vector(math.random(-25,25),math.random(-25,25),0)

	local tr = util.TraceLine( {
		start = offset,
		endpos = offset - Vector(0,0,9000),
		collisiongroup = COLLISION_GROUP_WORLD,
	} )

	local ang = tr.HitNormal:Angle()
	ang:RotateAroundAxis(ang:Right(), -90)
	ang:RotateAroundAxis(ang:Up(), math.random(-180,180))

	med.Type = type 
	med:SetPos(tr.HitPos + Vector(0,0,0.25))
	med:SetAngles(ang)
	med:Spawn()

	timer.Simple(0.25, function()
		local chance = math.random(1,3)
		if chance == 3 then 
			for i = 1, 2 do 
				local offset = pos + Vector(math.random(-25,25),math.random(-25,25),0)
	
				local tr = util.TraceLine( {
					start = offset,
					endpos = offset - Vector(0,0,9000),
					collisiongroup = COLLISION_GROUP_WORLD,
				} )
	
				local ang = tr.HitNormal:Angle()
				ang:RotateAroundAxis(ang:Right(), -90)
				ang:RotateAroundAxis(ang:Up(), math.random(-180,180))

				local med = ents.Create("ent_medical_garbage")
				med.Type = "common" 
				med:SetPos(tr.HitPos + Vector(0,0,1))
				med:SetAngles(ang)
				med:Spawn()
			end
		end
	end)

end


concommand.Add("clear_med_garbage", function()
	for k,v in pairs(ents.GetAll()) do 
		if v:GetClass() == "ent_medical_garbage" then 
			v:Remove()
		end
	end
end)
