local cooldown = 0.5

concommand.Add("fake", function(ply)
	if not ply:Alive() then return end
	if ply.fakecd and ply.fakecd > CurTime() then return end
	if ply:IsFlagSet( FL_FROZEN ) then return end
	--ply.fakecd = CurTime() + cooldown
	ply._godFakeBypass = true
	if not IsValid(ply.FakeRagdoll) then
		hg.Fake(ply)
	else
		hg.FakeUp(ply)
	end
	ply._godFakeBypass = nil
end)

hook.Add("PlayerInitialSpawn", "PlayerColideCallback", function(ply) ply:AddCallback("PhysicsCollide", function(phys, data) hook.Run("PlayerCollide", ply, data.HitEntity, data) end) end)
hook.Add("PlayerCollide", "Fake", function(ply, ent, data)
	if (not ent:IsPlayerHolding()) and data.Speed > math.max(700 - ent:GetPhysicsObject():GetMass(), 200) and ent:GetPhysicsObject():GetMass() > 20 and ent:GetClass() ~= "prop_ragdoll" and ent:GetPhysicsObject():GetVelocity():Length() > 50 then		--[[local d = DamageInfo()
		d:SetDamageType(DMG_CRUSH)
		d:SetAttacker(data.HitEntity)
		d:SetDamage(data.Speed / 40)
		ply:TakeDamageInfo(d)]]
		--
		timer.Simple(0,function()
			hg.LightStunPlayer(ply, 2)
		end)
		
		-- Inflict fear from fast moving objects
		if ply.organism then
			local fearAmount = math.Clamp(data.Speed / 500, 0.2, 1.5)
			ply.organism.fearadd = (ply.organism.fearadd or 0) + fearAmount
		end
	end
end)

hook.Add("OnPlayerHitGround","fallStun",function(ply,inwater,onfloater,speed)
	if IsValid(ply.FakeRagdoll) then return true end
	local tr = {}
	tr.start = ply:GetPos()
	tr.endpos = ply:GetPos() - vector_up * 2
	tr.filter = ply
	local bottom, top = ply:GetHull()
	bottom[3] = bottom[3] - 5
	tr.mins = bottom
	tr.maxs = top

	tr = util.TraceHull(tr)

	if ply:IsBerserk() then
		return
	end

	if ply.GetPlayerClass and ply:GetPlayerClass() and ply:GetPlayerClass().FallDmgFunc then
		ply:PlayerClassEvent("FallDmgFunc", speed, tr)

		return
	end

	if (ply.PlayerClassName == "furry" and speed > 350 or speed > 250) and tr.Entity:IsPlayer() then
		hg.drop(tr.Entity)
		hg.LightStunPlayer(tr.Entity,2)
		--tr.Entity:TakeDamage(speed / 5,ply,ply)
	end

	if speed > 600 then
		hg.LightStunPlayer(ply,2)
	end
	
	-- Accidental weapon discharge on impact
	if speed > 300 then
		local wep = ply:GetActiveWeapon()
		if IsValid(wep) and wep:IsWeapon() then
			-- Check if weapon has ammo/clip
			local clip1 = wep:Clip1()
			local clip2 = wep:Clip2()
			local hasAmmo = clip1 > 0 or clip2 > 0
			
			if hasAmmo then
				-- Chance based on impact speed: higher speed = higher chance
				-- Speed 300 = 1% chance, Speed 1000 = 10% chance
				local dischargeChance = math.Clamp((speed - 300) / 7000, 0.01, 0.10)
				
				if math.random() < dischargeChance then
					-- Fire the weapon
					wep:PrimaryAttack()
				end
			end
		end
	end
end)

concommand.Add("force_fake", function(ply, cmd, args)
	if IsValid(ply) and not ply:IsAdmin() then return end
	ply = Player(tonumber(args[1]))
	if not IsValid(ply.FakeRagdoll) then
		hg.Fake(ply)
	else
		hg.FakeUp(ply)
	end
end)