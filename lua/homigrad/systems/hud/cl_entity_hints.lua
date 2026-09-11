local hint
local hg_hints = ConVarExists("hg_hints") and GetConVar("hg_hints") or CreateClientConVar("hg_hints", "1", true, false, "Toggle UI hints")

local HintBackgroundColor = Color( 0, 0, 0, 200 )

hook.Add("HUDPaint","EntHints",function()
	if not hg_hints:GetBool() then return end 
	if HGSuppressEntityHints then return end
	if lply.organism and lply.organism.otrub then return end
	if !lply:Alive() then return end
	
	local trace = hg.eyeTrace(lply)

	if not trace then return end

	HintBackgroundColor.a = LerpFT(0.1, HintBackgroundColor.a, (IsValid(trace.Entity) and trace.Entity.HudHintMarkup) and 200 or 0)

	hg.BasicHudHint(trace.Entity, trace, hint)
end)

function hg.BasicHudHint(ent, trace)
	hint = (IsValid(ent) and ent.HudHintMarkup) or hint

	if not hint then return end

	local screen = trace.HitPos:ToScreen()
	local scale = hg.UIScale and hg.UIScale() or math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.65, 1.5)
	local padding = 5 * scale
	local x = math.Clamp(screen.x, hint:GetWidth() * 0.5 + padding, ScrW() - hint:GetWidth() * 0.5 - padding)
	local y = math.Clamp(screen.y + 100 * scale, padding, ScrH() - hint:GetHeight() - padding)

	draw.RoundedBox(math.max(1, math.floor(2 * scale)), x - hint:GetWidth() / 2 - padding * 0.5, y - padding * 0.5, hint:GetWidth() + padding, hint:GetHeight() + padding, HintBackgroundColor)
	
	hint:Draw(x, y, TEXT_ALIGN_CENTER, nil, 175 * (HintBackgroundColor.a / 200), TEXT_ALIGN_CENTER)

	if ent.AdditionalInfoFunc then
		local str = ent.AdditionalInfoFunc()

		surface.SetFont("ZCity_Tiny")
		local w, h = surface.GetTextSize(str)
		surface.SetTextColor(color_white)
		surface.SetTextPos(x - w * 0.5, y + hint:GetHeight() + h)
		surface.DrawText(str)
	end
end
