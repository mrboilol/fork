local hint
local hg_hints = ConVarExists("hg_hints") and GetConVar("hg_hints") or CreateClientConVar("hg_hints", "1", true, false, "Toggle UI hints")

local HintBackgroundColor = Color( 0, 0, 0, 200 )
local PromptBackgroundColor = Color( 0, 0, 0, 200 )

local function hintScale()
	return hg.UIScale and hg.UIScale() or math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.65, 1.5)
end

local function drawHintBox(markup, screenX, screenY, backgroundColor, alphaMul)
	local scale = hintScale()
	local padding = 5 * scale
	local width, height = markup:GetWidth(), markup:GetHeight()
	local x = math.Clamp(screenX, width * 0.5 + padding, ScrW() - width * 0.5 - padding)
	local y = math.Clamp(screenY, padding, ScrH() - height - padding)

	draw.RoundedBox(math.max(1, math.floor(2 * scale)), x - width / 2 - padding * 0.5, y - padding * 0.5, width + padding, height + padding, backgroundColor)

	markup:Draw(x, y, TEXT_ALIGN_CENTER, nil, 175 * alphaMul, TEXT_ALIGN_CENTER)

	return x, y
end

local function drawObjectPrompt(ent, alphaMul)
	if not IsValid(ent) or not ent.HudHintMarkup then return end

	local scale = hintScale()
	local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
	local bottom = ent:WorldSpaceCenter() - Vector(0, 0, (maxs.z - mins.z) * 0.5)
	local screen = bottom:ToScreen()
	if not screen.visible then return end

	PromptBackgroundColor.a = 200 * alphaMul
	drawHintBox(ent.HudHintMarkup, screen.x, screen.y + 14 * scale, PromptBackgroundColor, alphaMul)
end

hook.Add("HUDPaint","EntHints",function()
	if not hg_hints:GetBool() then return end
	if HGSuppressEntityHints then return end
	if lply.organism and lply.organism.otrub then return end
	if !lply:Alive() then return end

	local trace = hg.eyeTrace(lply)

	if not trace then return end

	local traceEnt = trace.Entity
	local traceHasHint = IsValid(traceEnt) and traceEnt.HudHintMarkup

	HintBackgroundColor.a = LerpFT(0.1, HintBackgroundColor.a, traceHasHint and 200 or 0)

	hg.BasicHudHint(traceEnt, trace)

	if not hg.GetPickupPromptEntities then return end

	local prompts, selected = hg.GetPickupPromptEntities(lply, traceEnt)
	for _, ent in ipairs(prompts) do
		if ent == traceEnt and traceHasHint then continue end
		drawObjectPrompt(ent, ent == selected and 1 or 0.6)
	end
end)

function hg.BasicHudHint(ent, trace)
	hint = (IsValid(ent) and ent.HudHintMarkup) or hint

	if not hint then return end

	local screen = trace.HitPos:ToScreen()
	local x, y = drawHintBox(hint, screen.x, screen.y + 100 * hintScale(), HintBackgroundColor, HintBackgroundColor.a / 200)

	if IsValid(ent) and ent.AdditionalInfoFunc then
		local str = ent.AdditionalInfoFunc()

		surface.SetFont("ZCity_Tiny")
		local w, h = surface.GetTextSize(str)
		surface.SetTextColor(color_white)
		surface.SetTextPos(x - w * 0.5, y + hint:GetHeight() + h)
		surface.DrawText(str)
	end
end
