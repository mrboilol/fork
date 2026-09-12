local hg_font_default = "Lora"

if CLIENT then
	local hg_font = ConVarExists("hg_font") and GetConVar("hg_font") or CreateClientConVar("hg_font", hg_font_default, true, false, "Change UI text font")

	if hg_font:GetString() != hg_font_default then
		RunConsoleCommand("hg_font", hg_font_default)
	end

	local font = function()
		return hg_font_default
	end

	local registerFont = hg.RegisterUIFont or function(name, definition)
		definition = table.Copy(definition)
		definition.size = math.max(1, math.floor((definition.referenceSize or definition.size) * math.Clamp(math.min(ScrW() / 1920, ScrH() / 1080), 0.65, 1.5) + 0.5))
		definition.referenceSize = nil
		surface.CreateFont(name, definition)
	end

	registerFont("HomigradFont", {
		font = font(),
		referenceSize = 23,
		weight = 1100,
		outline = false
	})

	registerFont("ScoreboardPlayer", {
		font = font(),
		referenceSize = 16,
		weight = 1100,
		outline = false
	})

	registerFont("HomigradFontBig", {
		font = font(),
		referenceSize = 27,
		weight = 1100,
		outline = false,
		shadow = true
	})

	registerFont("HomigradFontMedium", {
		font = font(),
		referenceSize = 18,
		weight = 1100,
		outline = false,
	})

	registerFont("HomigradFontRadialOld", {
		font = font(),
		referenceSize = 25,
		weight = 1100,
		outline = false,
	})

	registerFont("HomigradFontRadialCenter", {
		font = font(),
		referenceSize = 32,
		weight = 1100,
		outline = false,
	})

	registerFont("HomigradFontLarge", {
		font = font(),
		referenceSize = 34,
		weight = 1100,
		outline = false
	})

	registerFont("HomigradFontGigantoNormous", {
		font = font(),
		referenceSize = 56,
		weight = 1100,
		outline = false,
		shadow = false
	})

	registerFont("HomigradFontSmall", {
		font = font(),
		referenceSize = 17,
		weight = 1100,
		outline = false
	})

	registerFont("HomigradFontVSmall", {
		font = font(),
		referenceSize = 12,
		weight = 400,
		outline = false
	})

	registerFont("ZCity_Veteran", {
		font = "x14y24pxHeadUpDaisy",
		referenceSize = 23,
		weight = 500,
		outline = false
	})

	registerFont("HG_font", {
		font = "Arial",
		extended = false,
		referenceSize = 50,
		weight = 500,
		outline = true
	})
end
