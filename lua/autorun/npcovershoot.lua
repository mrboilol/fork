if SERVER then
	local enabled = CreateConVar("nos_enabled", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
	local maxOvershoot = CreateConVar("nos_max_overshoot_time", "2", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
	local overshootChance = CreateConVar("nos_overshoot_chance", "50", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
	local transparencyCheck = CreateConVar("nos_transparency_check", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
	local wallShootProficiency = CreateConVar("nos_overshoot_proficiency", "1", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})
	local doShootCorpse = CreateConVar("nos_do_shoot_corpse", "0", {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY})

	local shootIntervals = {
	    ["weapon_pistol"] = 0.5,
	    ["weapon_357"] = 0.3,
	    ["weapon_smg1"] = 0.15,
	    ["weapon_ar2"] = 0.15,
	    ["weapon_shotgun"] = 1,
	    ["weapon_crossbow"] = 1,
	    ["weapon_annabelle"] = 1,
	    ["weapon_rpg"] = 3.5,
	    ["weapon_frag"] = 3,
	}

	hook.Add("OnNPCKilled", "GetNPCRagdoll", function(npc, attacker, inflictor)
		if not doShootCorpse:GetBool() then return end
	    timer.Simple(0, function()
	        local nearby = ents.FindInSphere(npc:GetPos(), 50)
	        for _, ent in ipairs(nearby) do
	            if ent:GetClass() == "prop_ragdoll" and ent:GetModel() == npc:GetModel() then
	                npc.nos_rag = ent
	            end
	        end
	    end)
	end)
	hook.Add("PlayerDeath", "GetPlayerRagdoll", function(victim, inflictor, attacker)
		if not doShootCorpse:GetBool() then return end
	    timer.Simple(0, function()
	        local rag = ents.Create("prop_ragdoll")
	        rag:SetModel(victim:GetModel())
	        rag:SetPos(victim:GetPos())
	        rag:SetAngles(victim:GetAngles())
	        rag:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
	        rag:DrawShadow(false)
	        rag:SetNoDraw(true)
	        rag:SetParent(victim)
	        rag:Spawn()

	        rag:SetParent(nil)
			for i = 0, rag:GetPhysicsObjectCount() - 1 do
	            local phys = rag:GetPhysicsObjectNum(i)
	            if IsValid(phys) then
	                phys:SetVelocity(victim:GetVelocity())
	            end
	        end

	        if IsValid(rag) then
	            victim.nos_rag = rag
	        end
	    end)
	end)

	hook.Add("Think", "NPC Overshooting", function()
		if not enabled:GetBool() then
			return
		end

		local function GetCorpsePelvisPos(ragdoll)
		    if not IsValid(ragdoll) then return nil end

		    local boneID = ragdoll:LookupBone("ValveBiped.Bip01_Pelvis")
		    if not boneID then return ragdoll:GetPos() end

		    local pos, ang = ragdoll:GetBonePosition(boneID)
		    return pos
		end

		local function TrackCorpse(tracker, corpse)
			local id = "nos_corpse_" .. tracker:EntIndex()
			timer.Create(id, 0, 0, function()
				if not IsValid(corpse) or not IsValid(tracker) then
					timer.Remove(id)
					return
				end
				tracker:SetPos(GetCorpsePelvisPos(corpse))
			end)
		end

		for _, npc in ipairs(ents.FindByClass("npc_*")) do
			if IsValid(npc) and npc:IsNPC() then
				if npc.GetActiveWeapon == nil then continue end
				if not npc.GetActiveWeapon then continue end
				if not IsValid(npc:GetActiveWeapon()) then continue end

				local enemy = npc:GetEnemy()
				if IsValid(enemy) then
					if CAI and CAI.Enabled() and CAI.Manager.Get(npc) and not CAI.Util.IsTargetable(enemy) then
						if npc.didResetProficiency == false then npc:SetCurrentWeaponProficiency(npc.defaultProficiency) end
						npc.overshootTime = 0
						npc.didResetProficiency = true
						continue
					end
					local enemyVisible = npc:Visible(enemy)

					if transparencyCheck:GetBool() then
					    local tr = util.TraceLine({
					        start = npc:EyePos(),
					        endpos = enemy:EyePos(),
					        filter = npc,
					        mask = MASK_SHOT
					    })
					    if tr.Hit then
					    		enemyVisible = tr.Entity == enemy
					    end
					end

					if doShootCorpse:GetBool() and enemy:Health() <= 0 and IsValid(enemy.nos_rag) then
						local rag = enemy.nos_rag
						enemy.nos_rag = nil

						if math.random(1,100) < overshootChance:GetInt() then
							local ent = ents.Create("npc_bullseye")
							ent:SetHealth(99999)
							ent:SetPos(GetCorpsePelvisPos(rag))
	        				ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
							npc:AddEntityRelationship(ent, D_HT, 99)
							ent:Spawn()

							TrackCorpse(ent, rag)

							timer.Simple(math.Rand(0, math.max(0, maxOvershoot:GetFloat()) * 1.5), function()
								if IsValid(ent) then
									ent:Remove()
									if IsValid(rag) then rag:Remove() end
								end
							end)
						end
					end

					if enemyVisible then
						npc.overshootTime = CurTime() + math.Rand(0, math.max(0, maxOvershoot:GetFloat()))
						if math.random(1, 100) > overshootChance:GetInt() then npc.overshootTime = 0 end
						npc.defaultProficiency = npc:GetCurrentWeaponProficiency()
						npc.didResetProficiency = true
					else
						if npc.overshootTime == nil or npc.didResetProficiency == nil then continue end
						if npc.overshootTime <= CurTime() then
							if not npc.didResetProficiency then
								npc:SetCurrentWeaponProficiency(npc.defaultProficiency)
							end
							npc.didResetProficiency = true
							continue
						end
						npc.didResetProficiency = false
						if npc:HasCondition(COND.LOW_PRIMARY_AMMO) then
							npc.overshootTime = 0
							continue
						end
						if npc:GetCurrentWeaponProficiency() > wallShootProficiency:GetInt() then
							npc:SetCurrentWeaponProficiency(wallShootProficiency:GetInt())
						end
						local interval = shootIntervals[npc:GetActiveWeapon():GetClass()] or 0.2
						if npc.nos_nextShoot == nil or npc.nos_nextShoot < CurTime() then
							npc.nos_nextShoot = CurTime() + interval
							npc:SetActivity(ACT_RANGE_ATTACK1)
						end
					end
				elseif npc.didResetProficiency == false then
					npc:SetCurrentWeaponProficiency(npc.defaultProficiency)
					npc.didResetProficiency = true
					npc.overshootTime = 0
				end
			end
		end
	end)
end
