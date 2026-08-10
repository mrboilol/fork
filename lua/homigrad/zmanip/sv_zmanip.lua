util.AddNetworkString("RunZManipAnim")

function hg.RunZManipAnim(ply, anim, revers, timeOveride, additionalTbl)
	net.Start("RunZManipAnim")
		net.WritePlayer(ply)
		net.WriteString(anim or "")
		net.WriteBool(revers or false)
		net.WriteFloat(timeOveride or 0)
		net.WriteTable(additionalTbl or {})
	net.SendPVS(ply:GetPos())
end

hook.Add("PlayerUse", "ZManipUseAnim", function(ply, ent)
	--print(ent,ent.Use)
	local org = ply.organism
	if org and org.larmamputated then
		if IsValid(ply:GetNetVar("carryent")) or IsValid(ply:GetNetVar("carryent2")) then
			return false
		end
	end

	if IsValid(ent) and !ent:IsRagdoll() and ent.Use and (!ply.ZManipInteractCD or ply.ZManipInteractCD < CurTime()) and !hgIsDoor(ent) then
		if string.find(ent:GetClass(), "prop") or string.find(ent:GetClass(), "breakable") or string.find(ent:GetClass(), "ladder") then return end
		
		local chosenArm, isRight, isBroken = hg.GetPrioritizedArm(ply)
		ply.ZManipInteractCD = CurTime() + 0.95
		ply.ZManipOldUse = ply:KeyDown(IN_USE)
		local anim = (ent:IsWeapon() or ent.IsZPickup) and "interact" or "use"

		-- Add pain if using broken arm to interact/pickup (only for the arm being used)
		if org and isBroken then
			local armVal = org.larm or 0
			local disloc = org.larmdislocation
			-- This may be charged alongside PlayerUse's generic arm-use check.
			local painAmount = armVal * 3 + (disloc and 2 or 0)
			org.painadd = (org.painadd or 0) + painAmount
		end

		--if ent:IsWeapon() then hg.RunZManipAnim(ply, anim) return end
		timer.Simple(0,function()
			--print(anim)w
			hg.RunZManipAnim(ply, anim, nil, nil, {ent})
		end)
	end
end)

hook.Add("Player Think", "ZManipSwimAnim", function(ply, time, dtime)
	if ply:WaterLevel() > 0 and !ply:IsOnGround() and ply:GetVelocity():LengthSqr() > 3000 and (!ply.ZManipSwimCD or ply.ZManipSwimCD < CurTime()) then
		ply.ZManipSwimCD = CurTime() + 0.95
		if not (ply:WaterLevel() > 2) then
			local snd = math.random(1,11)
			ply:EmitSound("zcitysnd/player/footsteps/wade" .. ( snd ) .. ".ogg")
		end
		if IsValid(ply:GetActiveWeapon()) and ishgweapon(ply:GetActiveWeapon()) then
			if ply:KeyDown(IN_FORWARD) or ply:KeyDown(IN_MOVERIGHT) then
				hg.RunZManipAnim(ply, "swimforward")
			else
				hg.RunZManipAnim(ply, "swimleft")
			end
		end
	end
end)

local gestures = {
	["fuckyou"]     = {"fuckyou", false},
	["thumb_up"]    = {"thump_up", false},
	["point"]       = {"point", false},
	["acknowledge"] = {"acknowledge", false},
	["wait"]        = {"wait", false},
	["danger"]      = {"danger", false},
	["thanks"]      = {"thanks", false},
	["omw"]         = {"omw", false},
	["regroup"]     = {"regroup", false},
	["help"]        = {"help", false},
	["hello"]       = {"hello", false},
	["point_of"]    = {"point_of", false},
	--["door_open_back"] = {"door_open_back", false},
	--["door_open_forward"] = {"door_open_forward", false},
	--["usedoor"] = "usedoor",
	--["visordown"] = "visordown"
}

concommand.Add("hg_hand_gesture",function( ply, cmd, args )
	ply.handGestureCD = ply.handGestureCD or 0
	if ply.handGestureCD > CurTime() then return end

	if args[1] and gestures[args[1]] then
		hg.RunZManipAnim( ply, gestures[args[1]][1], gestures[args[1]][2] )
	elseif not args[1] then
		local gestur = table.Random(gestures)
		hg.RunZManipAnim( ply, gestur[1], gestur[2] )
	end

	ply.handGestureCD = CurTime() + 2
end)
