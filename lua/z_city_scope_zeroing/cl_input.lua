ZCityScopeZeroing = ZCityScopeZeroing or {}

ZCityScopeZeroing.Delta = 0
ZCityScopeZeroing.NextClick = 0

-- Хук ввода/зума
hook.Add("HG.InputMouseApply", "ChangeZoomZeroing", function(tbl)
	local ply = LocalPlayer()
	ZCityScopeZeroing.Delta = Lerp(FrameTime() * 5, ZCityScopeZeroing.Delta, 0)
	if IsAiming(ply) then
		if input.WasMousePressed(MOUSE_WHEEL_UP) then
			ZCityScopeZeroing.Delta = ZCityScopeZeroing.Delta + (FrameTime() / engine.TickInterval())
		elseif input.WasMousePressed(MOUSE_WHEEL_DOWN) then
			ZCityScopeZeroing.Delta = ZCityScopeZeroing.Delta - (FrameTime() / engine.TickInterval())
		end
		if ply:KeyDown(IN_WALK) then
			ZCityScopeZeroing.Delta = ZCityScopeZeroing.Delta - tbl.y / 24
			tbl.y = 0
		end
	end
end)

--- Изменяет количество кликов пристрелки оружия и ограничивает его в допустимых пределах.
--- @param wep Weapon
--- @param field string
--- @param amount number
--- @param opticData table|nil
--- @return boolean
function ZCityScopeZeroing.AddScopeClick(wep, field, amount, opticData)
	if not IsValid(wep) then return false end

	-- Инициализируем из сети, если еще не задано локально
	if wep[field] == nil then
		local nwKey = (field == "ReticleClicksX") and "ZCityScopeClicksX" or "ZCityScopeClicksY"
		wep[field] = wep:GetNWInt(nwKey, 0)
	end

	local limit = ZCityScopeZeroing.GetScopeClickLimit(wep, opticData)
	local oldValue = ZCityScopeZeroing.ClampClickCount(wep[field], limit)
	local newValue = ZCityScopeZeroing.ClampClickCount(oldValue + amount, limit)

	wep[field] = newValue

	return newValue ~= oldValue
end

--- Отправляет текущее состояние пристрелки оружия на сервер через сеть.
--- @param wep Weapon
function ZCityScopeZeroing.SendScopeZeroingState(wep)
	if not IsValid(wep) then return end

	local clicksX = wep.ReticleClicksX or 0
	local clicksY = wep.ReticleClicksY or 0
	if wep._ZCityScopeZeroingSentX == clicksX and wep._ZCityScopeZeroingSentY == clicksY then return end

	wep._ZCityScopeZeroingSentX = clicksX
	wep._ZCityScopeZeroingSentY = clicksY

	net.Start(ZCityScopeZeroing.NetMessage)
		net.WriteEntity(wep)
		net.WriteInt(clicksX, 16)
		net.WriteInt(clicksY, 16)
	net.SendToServer()
end

-- Хук Think для отслеживания кнопок регулировки пристрелки (клавиши со стрелками)
hook.Add("Think", "HG_ScopeZeroingGlobal", function()
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
		
		if CurTime() > ZCityScopeZeroing.NextClick then
			local clicked = false
			if input.IsKeyDown(KEY_UP) then
				clicked = ZCityScopeZeroing.AddScopeClick(wep, "ReticleClicksY", 1, foundatt)
			elseif input.IsKeyDown(KEY_DOWN) then
				clicked = ZCityScopeZeroing.AddScopeClick(wep, "ReticleClicksY", -1, foundatt)
			elseif input.IsKeyDown(KEY_LEFT) then
				clicked = ZCityScopeZeroing.AddScopeClick(wep, "ReticleClicksX", -1, foundatt)
			elseif input.IsKeyDown(KEY_RIGHT) then
				clicked = ZCityScopeZeroing.AddScopeClick(wep, "ReticleClicksX", 1, foundatt)
			end
			
			if clicked then
				ZCityScopeZeroing.SendScopeZeroingState(wep)
				wep:EmitSound("buttons/lightswitch2.ogg", 35, 150, 0.4, CHAN_ITEM)
				wep.LastZeroingAdjustTime = CurTime()
				ZCityScopeZeroing.NextClick = CurTime() + 0.15
			end
		end
	end
end)
