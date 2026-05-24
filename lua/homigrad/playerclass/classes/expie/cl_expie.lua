if CLIENT then
	local expieModels = {
		["models/blop/expie/expie.mdl"] = true,
		["models/assassingecko/geckoexpie/geckoexpie.mdl"] = true,
		["models/assassingecko/geckoexpie/femgeckoexpie.mdl"] = true,
	}

	local function chekExpie(ent)
		if not IsValid(ent) then return false end
		return expieModels[ent:GetModel()] or ent.PlayerClassName == "expie" or ent.IsExpie or false
	end

	local function ScaleBoneAndChildren(ent, boneID, scale)
		ent:ManipulateBoneScale(boneID, scale)
		local children = ent:GetChildBones(boneID)
		for _, child in ipairs(children) do
			ScaleBoneAndChildren(ent, child, scale)
		end
	end

	-- Hide head and all child bones (eyes, mouth, etc.) only for the local player's own first-person view
	hook.Add("PrePlayerDraw", "ExpieHideHead", function(ply)
		if ply == LocalPlayer() and chekExpie(ply) then
			local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
			if headBone then
				ScaleBoneAndChildren(ply, headBone, Vector(0, 0, 0))
			end
		end
	end)

	hook.Add("PostPlayerDraw", "ExpieRestoreHead", function(ply)
		if ply == LocalPlayer() and chekExpie(ply) then
			local headBone = ply:LookupBone("ValveBiped.Bip01_Head1")
			if headBone then
				ScaleBoneAndChildren(ply, headBone, Vector(1, 1, 1))
			end
		end
	end)
end
