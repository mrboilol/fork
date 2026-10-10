local function hasModel(ent)
	if not IsValid(ent) then return false end
	local model = ent:GetModel()

	return model ~= nil and model ~= ""
end

hook.Add("Think", "HGHideOrphanHands", function()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	local hands = ply:GetHands()
	if not IsValid(hands) then return end

	local orphaned = not hasModel(hands:GetParent())
	if hands:GetNoDraw() ~= orphaned then hands:SetNoDraw(orphaned) end
end)
