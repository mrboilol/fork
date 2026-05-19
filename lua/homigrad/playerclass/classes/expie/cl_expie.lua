if CLIENT then
	local function chekExpie(ent)
		return IsValid(ent) and (ent:GetModel() == "models/blop/expie/expie.mdl" or ent.PlayerClassName == "expie" or ent.IsExpie) or false
	end

	hook.Add("PrePlayerDraw", "ExpieHideHead", function(ply)
		if chekExpie(ply) then
			local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
			if headBone then
				ply:ManipulateBoneScale(headBone, Vector(0, 0, 0))
			end
		end
	end)

	hook.Add("PostPlayerDraw", "ExpieRestoreHead", function(ply)
		if chekExpie(ply) then
			local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
			if headBone then
				ply:ManipulateBoneScale(headBone, Vector(1, 1, 1))
			end
		end
	end)
end
