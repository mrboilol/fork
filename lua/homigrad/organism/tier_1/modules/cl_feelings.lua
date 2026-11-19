local Clamp = math.Clamp

local angerTunnel = 0

hook.Add("Player_Death", "hg_psyche_sound_stop", function(ply)
	if ply == LocalPlayer() then
		angerTunnel = 0
	end
end)

local angerTier = 0
hook.Add("Think", "hg_psyche_anger_sound", function()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() or not lply.organism then angerTier = 0 return end
	local org = lply.organism
	local anger = Clamp(org.psycheAnger or 0, 0, 1)
	local tier = (org.otrub or org.incapacitated) and 0 or (anger >= 0.75 and 2 or anger >= 0.5 and 1 or 0)
	if tier > angerTier then
		surface.PlaySound(tier == 2 and "FURIOUS.mp3" or "angry.mp3")
	end
	if tier < angerTier and anger < (angerTier == 2 and 0.65 or 0.4) then
		angerTier = tier
	elseif tier > angerTier then
		angerTier = tier
	end
end)

local angerMat = Material("effects/shaders/zb_grain2")

local psyche_color_tab = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}
hook.Add("RenderScreenspaceEffects", "hg_psyche_color", function()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() or not lply.organism then return end
	local org = lply.organism
	local anger = Clamp(org.psycheAnger or 0, 0, 1)
	local angerFrac = Clamp((anger - 0.5) / 0.5, 0, 1)

	psyche_color_tab["$pp_colour_addr"] = 0.07 * angerFrac
	if angerFrac > 0 then DrawColorModify(psyche_color_tab) end

	local K = hg.PsycheCombat
	local angerTarget = K and Clamp((anger - K.angerTunnelStart) / (K.angerTunnelFull - K.angerTunnelStart), 0, 1) or 0
	if org.otrub or org.incapacitated then angerTarget = 0 end
	angerTunnel = Lerp(math.min(FrameTime() * 2.5, 1), angerTunnel, angerTarget)
	if angerTunnel < 0.005 then return end

	local pulse = angerTunnel
	render.UpdateScreenEffectTexture()
	render.UpdateFullScreenDepthTexture()
	angerMat:SetFloat("$c0_x", 0)
	angerMat:SetFloat("$c0_y", -1)
	angerMat:SetFloat("$c0_z", 4096)
	angerMat:SetFloat("$c1_x", pulse * 7)
	angerMat:SetFloat("$c1_y", pulse * 0.45)
	angerMat:SetFloat("$c1_z", 0)
	angerMat:SetFloat("$c2_x", pulse * 0.2)
	angerMat:SetFloat("$c2_y", 0)
	angerMat:SetFloat("$c2_z", 0)
	angerMat:SetFloat("$c3_x", 0)
	render.SetMaterial(angerMat)
	render.DrawScreenQuad()
end)
