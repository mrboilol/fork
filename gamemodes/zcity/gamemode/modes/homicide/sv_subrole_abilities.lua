local MODE = MODE

util.AddNetworkString("HMCD_BeingVictimOfNeckBreak")	--; А тут я значит рещил без скобок да крутой кодинг стиль вопросы?
util.AddNetworkString("HMCD_BreakingOtherNeck")
util.AddNetworkString("HMCD_BeingVictimOfDisarmament")
util.AddNetworkString("HMCD_DisarmingOther")
util.AddNetworkString("HMCD_UpdateChemicalResistance")
util.AddNetworkString("HMCD_BeingVictimOfChoke")
util.AddNetworkString("HMCD_ChokingOther")
util.AddNetworkString("HMCD_ChokeProgress")

--\\Brawler: melee-only enforcement + fragile from behind
hook.Add("PlayerCanPickupWeapon", "Brawler_MeleeOnly", function(ply, wep)
	if(ply.SubRole ~= "traitor_brawler")then return end
	local class = wep:GetClass()
	if(class == "weapon_hands_sh" or class == "weapon_hg_coolhands")then return end

	local ammo = wep:GetPrimaryAmmoType()
	if(ammo and ammo ~= 0 and ammo ~= "" and ammo ~= "none")then
		wep:SetClip1(0)
		if(wep.SetClip2)then wep:SetClip2(0) end
		ply:SetAmmo(0, ammo)
	end
end)

hook.Add("PlayerSwitchWeapon", "Brawler_MeleeOnly", function(ply, oldw, neww)
	if(ply.BeingVictimOfChoke)then
		return true
	end
end)

hook.Add("EntityTakeDamage", "Brawler_BackKnockdown", function(ent, dmginfo)
	if(not IsValid(ent) or not ent:IsPlayer() or not ent:Alive())then return end
	if(ent.SubRole ~= "traitor_brawler")then return end
	local att = dmginfo:GetAttacker()
	if(not IsValid(att) or not att:IsPlayer() or att == ent)then return end
	local toAtt = (att:GetPos() - ent:GetPos()):GetNormalized()
	if(ent:GetForward():Dot(toAtt) > 0.2)then return end
	if((ent.BrawlerKnockCD or 0) > CurTime())then return end
	ent.BrawlerKnockCD = CurTime() + 2
	hg.LightStunPlayer(ent, 1.2)
end)
--//

local function canUseShadowCamouflageOnEntity(ent, tr)
	if not tr.Hit or tr.HitSky then
		return false
	end

	if tr.HitWorld then
		return true
	end

	if not IsValid(ent) then
		return false
	end

	if ent:IsPlayer() or ent:IsNPC() or ent:IsWeapon() or ent:IsRagdoll() then
		return false
	end

	if hgIsDoor and hgIsDoor(ent) then
		return true
	end

	local moveType = ent:GetMoveType()
	local isTrigger = ent.IsTrigger and ent:IsTrigger() or false

	return ent:GetSolid() ~= SOLID_NONE and not isTrigger and (moveType == MOVETYPE_NONE or moveType == MOVETYPE_PUSH)
end

function MODE.IsPlayerNearWallForShadowCamouflage(ply)
	local origin = ply:WorldSpaceCenter()
	origin.z = ply:GetPos().z + math.max(ply:OBBMaxs().z * 0.4, 35)

	for yaw = 0, 330, 30 do
		local dir = Angle(0, yaw, 0):Forward()
		local tr = util.TraceLine({
			start = origin,
			endpos = origin + dir * MODE.ShadowCamouflageWallDistance,
			filter = ply,
			mask = MASK_PLAYERSOLID,
		})

		if canUseShadowCamouflageOnEntity(tr.Entity, tr) then
			return true, tr
		end
	end

	return false
end

function MODE.SetShadowCamouflageActive(ply, state)
	if ply.Ability_ShadowCamouflage_Active == state then
		return
	end

	if state then
		ply.Ability_ShadowCamouflage_OriginalColor = ply.Ability_ShadowCamouflage_OriginalColor or ply:GetColor()
		ply.Ability_ShadowCamouflage_OriginalRenderMode = ply.Ability_ShadowCamouflage_OriginalRenderMode or ply:GetRenderMode()

		ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
		local tint = MODE.ShadowCamouflageTint or Color(255, 255, 255, MODE.ShadowCamouflageAlpha)
		ply:SetColor(Color(255, 255, 255, tint.a))
		ply:DrawShadow(false)
	else
		local clr = ply.Ability_ShadowCamouflage_OriginalColor or color_white

		ply:SetRenderMode(ply.Ability_ShadowCamouflage_OriginalRenderMode or RENDERMODE_NORMAL)
		ply:SetColor(Color(clr.r, clr.g, clr.b, clr.a))
		ply:DrawShadow(true)
	end

	ply.Ability_ShadowCamouflage_Active = state
	ply:SetNWBool("HMCD_ShadowCamouflageActive", state)
end

function MODE.ResetShadowCamouflage(ply)
	ply.Ability_ShadowCamouflage_ChargeStart = nil
	ply.Ability_ShadowCamouflage_LastNearWall = nil
	ply:SetNWFloat("HMCD_ShadowCamouflageChargeStart", 0)
	ply:SetNWFloat("HMCD_ShadowCamouflageReadyAt", 0)

	MODE.SetShadowCamouflageActive(ply, false)
end

--\\Chemical resistance
	function MODE.NetworkChemicalResistanceOfPlayer(ply)
		ply.PassiveAbility_ChemicalAccumulation = ply.PassiveAbility_ChemicalAccumulation or {}
		
		net.Start("HMCD_UpdateChemicalResistance")
		
		for chemical_name, amt in pairs(ply.PassiveAbility_ChemicalAccumulation) do
			net.WriteString(chemical_name)
			net.WriteUInt(math.Round(amt), MODE.NetSize_ChemicalResistanceBits)
		end
		
		net.WriteString("")
		net.Send(ply)
	end
--//

hook.Add("PlayerPostThink", "HMCD_SubRoles_Abilities", function(ply)
	if(MODE.RoleChooseRoundTypes[MODE.Type])then
		local subRole = ply.SubRole
		local neck_break_allow = subRole == "traitor_infiltrator" or subRole == "traitor_infiltrator_soe" or subRole == "traitor_martial_artist"
		local neck_break_down = ply:KeyDown(subRole == "traitor_martial_artist" and IN_RELOAD or IN_USE)
		local neck_break_prev = ply.Ability_NeckBreak_KeyDownPrev
		local can_break_neck = neck_break_allow
		local can_disarm = subRole == "traitor_assasin" or subRole == "traitor_assasin_soe" or subRole == "traitor_martial_artist"
		if(ply:Alive() and ply.organism and not ply.organism.otrub)then
			if(MODE.IsShadowRole(ply.SubRole))then
				local current_char = hg.GetCurrentCharacter(ply)
				local is_upright = current_char == ply and not IsValid(ply.FakeRagdoll)
				local is_still = ply:IsOnGround() and ply:GetVelocity():Length2DSqr() <= (MODE.ShadowCamouflageMoveSpeed * MODE.ShadowCamouflageMoveSpeed)
				local near_wall = is_upright and is_still and not ply:InVehicle() and MODE.IsPlayerNearWallForShadowCamouflage(ply)
				local now = CurTime()

				if(near_wall)then
					ply.Ability_ShadowCamouflage_LastNearWall = now
				end

				local grace_active = ply.Ability_ShadowCamouflage_LastNearWall and (now - ply.Ability_ShadowCamouflage_LastNearWall) <= MODE.ShadowCamouflageGraceTime

				if(near_wall or grace_active)then
					local charge_start = ply.Ability_ShadowCamouflage_ChargeStart

					if(not charge_start)then
						charge_start = now
						ply.Ability_ShadowCamouflage_ChargeStart = charge_start

						ply:SetNWFloat("HMCD_ShadowCamouflageChargeStart", charge_start)
						ply:SetNWFloat("HMCD_ShadowCamouflageReadyAt", charge_start + MODE.ShadowCamouflageChargeTime)
					elseif(not ply.Ability_ShadowCamouflage_Active and charge_start + MODE.ShadowCamouflageChargeTime <= now)then
						MODE.SetShadowCamouflageActive(ply, true)
					end
				elseif(ply.Ability_ShadowCamouflage_ChargeStart or ply.Ability_ShadowCamouflage_Active)then
					MODE.ResetShadowCamouflage(ply)
				end
			elseif(ply.Ability_ShadowCamouflage_ChargeStart or ply.Ability_ShadowCamouflage_Active)then
				MODE.ResetShadowCamouflage(ply)
			end

			if(ply.SubRole == "traitor_infiltrator" or ply.SubRole == "traitor_infiltrator_soe")then
				if(ply:KeyDown(IN_WALK))then
					if(ply:KeyPressed(IN_RELOAD))then
						local aim_ent, other_ply = hg.eyeTrace(ply,85).Entity
						other_ply = hg.RagdollOwner(aim_ent) or aim_ent
						
						if(IsValid(aim_ent) and aim_ent:IsRagdoll())then	--; REDO
							local other_appearance = aim_ent.CurAppearance
							local your_appearance = ply.CurAppearance

							local aMdl1,aMdl2 = your_appearance.AModel,other_appearance.AModel
							
							other_appearance.AModel = aMdl1
							your_appearance.AModel = aMdl2

							local aFace1,aFace2 = your_appearance.AFacemaps,other_appearance.AFacemaps

							other_appearance.AFacemaps = aFace1
							your_appearance.AFacemaps = aFace2

							hg.Appearance.ForceApplyAppearance(ply, other_appearance, true)
							local char = hg.GetCurrentCharacter(ply)
							if char:IsRagdoll() then
								hg.Appearance.ForceApplyAppearance(char, other_appearance, true)
							end
							ply:EmitSound("snd_jack_hmcd_disguise.ogg",35,math.random(90,110),0.5)

							--local duplicator_data = duplicator.CopyEntTable(ply)
							--duplicator.DoGeneric(aim_ent, duplicator_data)
							aim_ent.CurAppearance = your_appearance

							hg.Appearance.ForceApplyAppearance(aim_ent, your_appearance, true)
							
							if other_ply:IsPlayer() and other_ply:Alive() then
								hg.Appearance.ForceApplyAppearance(other_ply, your_appearance, true)
							end
						end
					end
					
					if(ply:KeyPressed(IN_USE))then
						if(WWE and WWE.RunMove)then WWE.RunMove(ply, "dl_back") end
					end
				else
					MODE.StopBreakingOtherNeck(ply)
				end
			end

			ply.Ability_NeckBreak_KeyDownPrev = neck_break_allow and neck_break_down or false
			
			if(can_disarm)then
				if(ply:KeyDown(IN_WALK))then
					if(ply:KeyPressed(IN_USE) and not ply.Ability_DisarmNeedRelease and not ply.Ability_Disarm)then
						local aim_ent, other_ply, trace = MODE.GetPlayerTraceToOther(ply, nil, MODE.DisarmReach)
						
						if(IsValid(aim_ent))then
							if(other_ply and MODE.CanPlayerDisarmOther(ply, aim_ent, MODE.DisarmReach) and MODE.CanPlayerDisarmOtherPly(ply, other_ply, MODE.DisarmReach))then
								MODE.StartDisarmingOther(ply, other_ply)
							end
						end
					elseif(ply:KeyDown(IN_USE))then
						if(ply.Ability_Disarm)then
							MODE.ContinueDisarmingOther(ply)
						end
					end
					
					if(ply:KeyReleased(IN_USE))then
						MODE.StopDisarmingOther(ply)
						ply.Ability_DisarmNeedRelease = nil
					end
				else
					MODE.StopDisarmingOther(ply)
				end
			end
			
			if(ply.SubRole == "traitor_brawler")then
				local w = ply:GetActiveWeapon()
				local cls = IsValid(w) and w:GetClass() or ""
				local hasHands = (cls == "weapon_hands_sh" or cls == "weapon_hg_coolhands")
				local wstore = IsValid(w) and weapons.GetStored(cls)
				local hasMelee = IsValid(w) and not hasHands and (cls == "weapon_hg_fists" or (wstore and wstore.Category == "Weapons - Melee"))

				if(IsValid(w) and cls ~= "weapon_matches")then
					local ammo = wstore and wstore.Primary and wstore.Primary.Ammo or "none"
					if(ammo ~= "none")then
						local clip = w:Clip1()
						if(ply._brawlerLastWep ~= cls)then
							ply._brawlerLastClip = clip
							ply._brawlerLastWep = cls
						end
						local reserve = ply:GetAmmoCount(w:GetPrimaryAmmoType())
						local prev = ply._brawlerLastClip or 0
						if(prev > 0 and clip == 0 and reserve == 0)then
							ply:DropWeapon(w)
							ply._brawlerLastClip = nil
							ply._brawlerLastWep = nil
						end
					else
						ply._brawlerLastClip = nil
						ply._brawlerLastWep = nil
					end
				else
					ply._brawlerLastClip = nil
					ply._brawlerLastWep = nil
				end

				if(ply:KeyDown(IN_WALK))then
					if(hasHands)then
						if(ply:KeyPressed(IN_USE))then
							local aim_ent, other_ply = MODE.GetPlayerTraceToOther(ply, nil, 100)

							if(IsValid(aim_ent) and other_ply and MODE.CanPlayerChokeOther(ply, aim_ent))then
								MODE.StartChokingOther(ply, other_ply)
							end
						elseif(ply:KeyDown(IN_USE))then
							if(ply.Ability_Choke)then
								MODE.ContinueChokingOther(ply)
							end
						end

						if(ply:KeyReleased(IN_USE))then
							MODE.StopChokingOther(ply)
						end
					elseif(hasMelee)then
					if(ply:KeyPressed(IN_USE))then
						local aim_ent, other_ply = MODE.GetPlayerTraceToOther(ply, nil, 160)

						if(IsValid(other_ply) and other_ply:IsPlayer() and other_ply:Alive()
							and not (IsValid(other_ply.FakeRagdoll) or IsValid(other_ply:GetNWEntity("FakeRagdoll"))))then

							local behindVec = ply:GetPos() - other_ply:GetPos()
							behindVec.z = 0
							local isBehind = behindVec:LengthSqr() > 1 and behindVec:GetNormalized():Dot(Angle(0, other_ply:EyeAngles().yaw, 0):Forward()) <= -0.4

							if(isBehind)then
								local name = (MH and MH.PickKill) and MH.PickKill(ply) or nil

								if(name)then
									local ok, err = MH.Play(ply, other_ply, name)

									if(not ok and IsValid(ply))then
										ply:ChatPrint("[Manhunt] " .. tostring(err or "execution failed"))
									end
								end
							end
						end
					end
					end
				else
					MODE.StopChokingOther(ply)
				end
			end

			if(ply.SubRole == "traitor_martialartist")then
				if(ply:KeyDown(IN_WALK) and ply:KeyPressed(IN_USE))then
					if(ply.Ability_Choke)then return end

					-- aimed at a ragdoll lying on the floor? pick it up with a giantswing
					if(WWE and WWE.moves and WWE.moves.mw_giantswing)then
						if(WWE.RunMove(ply, "mw_giantswing"))then return end
					end

					-- pick a move suited to our position relative to the target (front / back)
					local wantDir = "back"
					local action_ent, action_ply = MODE.GetPlayerTraceToOther(ply, nil, 160)
					if(IsValid(action_ply) and action_ply:IsPlayer() and action_ply:Alive())then
						local behindVec = ply:GetPos() - action_ply:GetPos()
						behindVec.z = 0
						local isBehind = behindVec:LengthSqr() > 1 and behindVec:GetNormalized():Dot(Angle(0, action_ply:EyeAngles().yaw, 0):Forward()) <= -0.4
						wantDir = isBehind and "back" or "front"
					end

					local moves = {}
					for _, m in ipairs(MODE.MAMoves and MODE.MAMoves or {}) do
						if(m.dir == wantDir)then moves[#moves + 1] = m.id end
					end
					if(#moves == 0)then return end

					local moveId = moves[math.random(#moves)]
					if(WWE and WWE.RunMove)then WWE.RunMove(ply, moveId) end
				end
			end

			if(ply.SubRole == "traitor_zombie")then
				if(ply:KeyDown(IN_WALK))then
					
				end
			end

			if(ply.SubRole == "traitor_chemist")then
				MODE.DegradeChemicalsOfPlayer(ply)
				
				if(!ply.PassiveAbility_ChemicalAccumulation_NextNetworkTime or ply.PassiveAbility_ChemicalAccumulation_NextNetworkTime <= CurTime())then
					MODE.NetworkChemicalResistanceOfPlayer(ply)

					ply.PassiveAbility_ChemicalAccumulation_NextNetworkTime = CurTime() + 1
				end
			end
		elseif(ply.Ability_ShadowCamouflage_ChargeStart or ply.Ability_ShadowCamouflage_Active)then
			MODE.ResetShadowCamouflage(ply)
		end
	end
end)

hook.Add("PlayerSpawn", "HMCD_SubRoles_ShadowCamouflage", function(ply)
	MODE.ResetShadowCamouflage(ply)
end)

hook.Add("PlayerDeath", "HMCD_SubRoles_ShadowCamouflage", function(ply)
	MODE.ResetShadowCamouflage(ply)
end)
