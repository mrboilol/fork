ZCityScopeZeroing = ZCityScopeZeroing or {}

ZCityScopeZeroing.DebugCvar = CreateClientConVar("zcity_scope_zeroing_debug", "0", false, false, "Prints scope zeroing render debug info.")

ZCityScopeZeroing.DebugState = ZCityScopeZeroing.DebugState or {
	lastMessage = "",
	lastPrint = 0,
	lastStatus = "waiting for scope render",
	lastDump = "not dumped yet"
}

--- Проверяет, включен ли вывод отладочной информации через CVar клиента.
--- @return boolean
function ZCityScopeZeroing.DebugEnabled()
	return ZCityScopeZeroing.DebugCvar and ZCityScopeZeroing.DebugCvar:GetBool()
end

--- Безопасно форматирует любое значение в строковое представление для вывода дампа.
--- @param value any
--- @return string
function ZCityScopeZeroing.DebugValue(value)
	if value == nil then return "nil" end
	if isbool(value) then return tostring(value) end
	if isnumber(value) or isstring(value) then return tostring(value) end
	if isvector and isvector(value) then return tostring(value) end
	if isangle and isangle(value) then return tostring(value) end
	if value.IsError then
		local okName, name = pcall(function() return value:GetName() end)
		local okError, isError = pcall(function() return value:IsError() end)

		return string.format("%s IsError=%s", okName and name or tostring(value), okError and tostring(isError) or "unknown")
	end

	return tostring(value)
end

--- Безопасно обрабатывает результат pcall для печати.
--- @param ok boolean
--- @param value any
--- @return string
function ZCityScopeZeroing.DebugCallValue(ok, value)
	if not ok then return "error: " .. tostring(value) end
	return tostring(value)
end

--- Находит и форматирует статус материала (существует ли, ошибка ли).
--- @param label string
--- @param materialValue any
--- @return string
function ZCityScopeZeroing.DebugMaterialStatus(label, materialValue)
	if materialValue == nil then return label .. "=nil" end

	local mat = materialValue
	if isstring(materialValue) then mat = Material(materialValue) end
	if not mat or not mat.IsError then return label .. "=" .. ZCityScopeZeroing.DebugValue(materialValue) end

	local okName, name = pcall(function() return mat:GetName() end)
	local okError, isError = pcall(function() return mat:IsError() end)

	return string.format("%s=%s IsError=%s", label, okName and name or tostring(materialValue), okError and tostring(isError) or "unknown")
end

--- Выводит сообщение в консоль, если отладка активна, соблюдая заданный интервал задержки вывода.
--- @param message string
--- @param interval number|nil
function ZCityScopeZeroing.DebugPrint(message, interval)
	if not ZCityScopeZeroing.DebugEnabled() then return end

	-- Всегда обновляем текущий статус для отображения на экране в реальном времени
	ZCityScopeZeroing.DebugState.lastStatus = message

	local now = CurTime()
	interval = interval or 1
	
	-- Ограничиваем частоту
	if now < ZCityScopeZeroing.DebugState.lastPrint + interval then return end

	ZCityScopeZeroing.DebugState.lastMessage = message
	ZCityScopeZeroing.DebugState.lastPrint = now
	print("[Scope Zeroing Debug] " .. message)
end

--- Выполняет полный дамп состояния параметров пристрелки оружия в консоль.
function ZCityScopeZeroing.DebugDump()
	local ply = LocalPlayer()
	local wep = IsValid(ply) and ply:GetActiveWeapon() or NULL
	local foundatt = IsValid(wep) and ZCityScopeZeroing.GetActiveOpticAttachment(wep) or nil
	local reticleMaterial, reticleSource = ZCityScopeZeroing.ResolveScopeMaterial(wep, foundatt, "perekrestie")
	local scopeMaterial, scopeSource = ZCityScopeZeroing.ResolveScopeMaterial(wep, foundatt, "scopemat")
	
	local okHg, hgValue = false, nil
	local okAim, aimValue = false, nil
	local okAttack2, attack2Value = false, nil
	local okCanUse, canUseValue = false, nil

	if IsValid(wep) then
		okHg, hgValue = pcall(function() return ishgweapon(wep) end)
		okAim, aimValue = pcall(function() return IsAiming(ply) end)
		okAttack2, attack2Value = pcall(function() return hg.KeyDown(ply, IN_ATTACK2) end)
		okCanUse, canUseValue = pcall(function() return wep:CanUse() end)
	end

	local lines = {
		"===== Scope Zeroing Debug Dump =====",
		"addon build=" .. tostring(ZCityScopeZeroing.Build or "unknown"),
		"playerValid=" .. tostring(IsValid(ply)) .. " alive=" .. tostring(IsValid(ply) and ply:Alive()),
		"weaponValid=" .. tostring(IsValid(wep)) .. " class=" .. (IsValid(wep) and wep:GetClass() or "nil") .. " base=" .. tostring(IsValid(wep) and wep.Base or nil),
		"ishgweapon=" .. ZCityScopeZeroing.DebugCallValue(okHg, hgValue) .. " attack2=" .. ZCityScopeZeroing.DebugCallValue(okAttack2, attack2Value) .. " canUse=" .. ZCityScopeZeroing.DebugCallValue(okCanUse, canUseValue) .. " IsAiming=" .. ZCityScopeZeroing.DebugCallValue(okAim, aimValue),
		"hasOpticAttachment=" .. tostring(foundatt ~= nil),
		"wep.sizeperekrestie=" .. ZCityScopeZeroing.DebugValue(IsValid(wep) and wep.sizeperekrestie or nil) .. " att.sizeperekrestie=" .. ZCityScopeZeroing.DebugValue(foundatt and foundatt.sizeperekrestie or nil),
		"wep.perekrestie=" .. ZCityScopeZeroing.DebugValue(IsValid(wep) and wep.perekrestie or nil) .. " att.perekrestie=" .. ZCityScopeZeroing.DebugValue(foundatt and foundatt.perekrestie or nil),
		"wep.scopemat=" .. ZCityScopeZeroing.DebugValue(IsValid(wep) and wep.scopemat or nil) .. " att.scopemat=" .. ZCityScopeZeroing.DebugValue(foundatt and foundatt.scopemat or nil),
		ZCityScopeZeroing.DebugMaterialStatus("resolvedReticle", reticleMaterial) .. " source=" .. tostring(reticleSource),
		ZCityScopeZeroing.DebugMaterialStatus("resolvedScopeMask", scopeMaterial) .. " source=" .. tostring(scopeSource),
		ZCityScopeZeroing.DebugMaterialStatus("zeroingHud", "optic.png"),
		"ZoomFOV=" .. ZCityScopeZeroing.DebugValue(IsValid(wep) and wep.ZoomFOV or nil) .. " clicksX=" .. ZCityScopeZeroing.DebugValue(IsValid(wep) and wep.ReticleClicksX or nil) .. " clicksY=" .. ZCityScopeZeroing.DebugValue(IsValid(wep) and wep.ReticleClicksY or nil),
		"lastRenderStatus=" .. tostring(ZCityScopeZeroing.DebugState.lastStatus),
		"===================================="
	}

	for _, line in ipairs(lines) do
		print("[Scope Zeroing Debug] " .. line)
	end

	ZCityScopeZeroing.DebugState.lastDump = table.concat(lines, " | ")
end

concommand.Add("zcity_scope_zeroing_debug_dump", ZCityScopeZeroing.DebugDump)

concommand.Add("zcity_scope_zeroing_debug_dump_delay", function(_, _, args)
	local delay = math.Clamp(tonumber(args and args[1]) or 3, 1, 10)
	print("[Scope Zeroing Debug] Dump scheduled in " .. delay .. " seconds. Close the console and hold aim through the scope.")
	timer.Simple(delay, ZCityScopeZeroing.DebugDump)
end)

-- Отображение худа
hook.Add("HUDPaint", "HG_ScopeZeroingDebugHUD", function()
	if not ZCityScopeZeroing.DebugEnabled() then return end

	draw.SimpleText("[Scope Zeroing Debug] " .. tostring(ZCityScopeZeroing.DebugState.lastStatus), "DermaDefault", 12, 12, Color(255, 220, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
	draw.SimpleText("Console: zcity_scope_zeroing_debug_dump_delay 3", "DermaDefault", 12, 28, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end)
