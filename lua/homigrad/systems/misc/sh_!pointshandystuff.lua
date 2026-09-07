if SERVER then
    CreateConVar("zb_dev", 0, FCVAR_ARCHIVE)
	CreateConVar("hg_indicator", 0, FCVAR_ARCHIVE)
end

if (CLIENT) then
    --sw и sh как глобальные переменные
    sw, sh = ScrW(), ScrH()

    hook.Add( "OnScreenSizeChanged", "sw_sh_globals", function()
        sw, sh = ScrW(), ScrH()
    end)

    --светящийся текст

    local old = surface.CreateFont
    local cache = {}

    local header = "glow_text_"
    surface.madefonts = surface.madefonts or {}
    local made = surface.madefonts


    function surface.CreateFont(name, info)
        made[name] = nil
        cache[name] = istable(info) and table.Copy(info) or nil

        old(name, info)
    end

    function ZB_GetFontTable(name)
        return cache[name]
    end

    function draw.GlowingText(text, font, x, y, col, colglow, colglow2, align, align2)
        if not isstring(font) or font == "" then return end

        align = align or TEXT_ALIGN_LEFT
        align2 = align2 or align or TEXT_ALIGN_CENTER

        local bfont1 = header .. font
        local bfont2 = header .. font .. "2"

        if !made[font] then
            local fontdata = ZB_GetFontTable(font)
            if not istable(fontdata) then
                fontdata = {
                    font = "VCR OSD Mono",
                    size = 16,
                    weight = 400,
                    antialias = true,
                    extended = true,
                }
            end

            local glowfont1 = table.Copy(fontdata)
            glowfont1.blursize = 4
            surface.CreateFont(bfont1, glowfont1)

            local glowfont2 = table.Copy(fontdata)
            glowfont2.blursize = 20
            surface.CreateFont(bfont2, glowfont2)
            made[font] = true
        end

        draw.SimpleText( text, bfont1, x, y, colglow or ColorAlpha(col,150), align, align2)
        draw.SimpleText( text, bfont2, x, y, colglow2 or colglow and ColorAlpha(colglow,50) or ColorAlpha(col, 50), align, align2)
        draw.SimpleText( text, font, x, y, col, align, align2)
    end
end

