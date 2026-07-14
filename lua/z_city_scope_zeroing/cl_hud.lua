ZCityScopeZeroing = ZCityScopeZeroing or {}

ZCityScopeZeroing.MatOptic = nil

-- Создание кастомного шрифта для HUD отображения прицела
surface.CreateFont("ZCity_OpticHUD", {
	font = "Roboto",
	size = 17,
	weight = 800,
	extended = true,
	antialias = true,
})

-- Хук отрисовки оверлея пристрелки прицела
hook.Add("HUDPaint", "HG_ScopeZeroingHUDGlobal", function()
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	local wep = ply:GetActiveWeapon()
	if not IsValid(wep) or not ishgweapon(wep) then return end
	
	if IsAiming(ply) then
		local foundatt = ZCityScopeZeroing.GetActiveOpticAttachment(wep)
		local clickLimit = ZCityScopeZeroing.GetScopeClickLimit(wep, foundatt)
		local clicksX = ZCityScopeZeroing.GetClicksX(wep)
		local clicksY = ZCityScopeZeroing.GetClicksY(wep)
		wep.ReticleClicksX = ZCityScopeZeroing.ClampClickCount(clicksX, clickLimit)
		wep.ReticleClicksY = ZCityScopeZeroing.ClampClickCount(clicksY, clickLimit)
		wep.LastZeroingAdjustTime = wep.LastZeroingAdjustTime or 0
		
		local diff = CurTime() - wep.LastZeroingAdjustTime
		if diff < 2 then
			if not ZCityScopeZeroing.MatOptic or (ZCityScopeZeroing.MatOptic.IsError and ZCityScopeZeroing.MatOptic:IsError()) then
				ZCityScopeZeroing.MatOptic = Material("optic.png")
			end
			
			local alpha = math.Clamp((2 - diff) * 2, 0, 1)
			local hudW, hudH = 251, 242
			local x = ScrW() / 2 - hudW / 2
			local y = 20
			
			if ZCityScopeZeroing.MatOptic and not ZCityScopeZeroing.MatOptic:IsError() then
				surface.SetMaterial(ZCityScopeZeroing.MatOptic)
				surface.SetDrawColor(255, 255, 255, 255 * alpha)
				surface.DrawTexturedRect(x, y, hudW, hudH)
			end
			
			local elevation = wep.ReticleClicksY
			local windageVal = wep.ReticleClicksX
			local windageText = ""
			if windageVal > 0 then
				windageText = windageVal .. "R"
			elseif windageVal < 0 then
				windageText = math.abs(windageVal) .. "L"
			else
				windageText = "0"
			end
			
			draw.SimpleText(tostring(elevation), "ZCity_OpticHUD", x + 82, y + 62, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			draw.SimpleText(windageText, "ZCity_OpticHUD", x + 185, y + 161, Color(255, 255, 255, 255 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end)
