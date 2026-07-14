ZCityScopeZeroing = ZCityScopeZeroing or {}

ZCityScopeZeroing.Build = "2026-06-12"
ZCityScopeZeroing.NetMessage = "ZCity_ScopeZeroing_Update"

-- Значения конфигурации по умолчанию
ZCityScopeZeroing.DefaultClickLimit = 120
ZCityScopeZeroing.DefaultClickMil = 0.1
ZCityScopeZeroing.ScopeClickLimit = 120
ZCityScopeZeroing.ScopeClickMil = 0.1
ZCityScopeZeroing.RTSize = 512

ZCityScopeZeroing.VecZero = Vector(0, 0, 0)
ZCityScopeZeroing.LocalScopePos = Vector(-21, 3.95, -0.2)
ZCityScopeZeroing.ScopeBlackout = 400
ZCityScopeZeroing.Rot = 37
ZCityScopeZeroing.FOVMin = 3.5
ZCityScopeZeroing.FOVMax = 10
ZCityScopeZeroing.BlackoutSize = 2500
ZCityScopeZeroing.ScopeBlackoutDistMulMax = 6

--- Возвращает таблицу активного оптического прицела, если она есть у оружия.
--- @param wep Weapon
--- @return table|nil
function ZCityScopeZeroing.GetActiveOpticAttachment(wep)
	if not IsValid(wep) or not wep.HasAttachment then return nil end
	local _, foundatt = wep:HasAttachment("sight", "optic")
	return foundatt
end

--- Безопасно получает значение настройки, проверяя сначала прицел, затем таблицу оружия, затем значение по умолчанию.
--- @param wep Weapon
--- @param opticData table|nil
--- @param key string
--- @param default any
--- @return any
function ZCityScopeZeroing.ScopeValue(wep, opticData, key, default)
	if opticData and opticData[key] ~= nil then return opticData[key] end
	if IsValid(wep) and wep[key] ~= nil then return wep[key] end
	return default
end

--- Определяет, задан ли у оружия корректный размер прицельной сетки.
--- @param wep Weapon
--- @param opticData table|nil
--- @return boolean
function ZCityScopeZeroing.HasScopeReticle(wep, opticData)
	if not opticData then
		opticData = ZCityScopeZeroing.GetActiveOpticAttachment(wep)
	end
	return IsValid(wep) and (wep.sizeperekrestie or not not (opticData and opticData.sizeperekrestie))
end

--- Возвращает лимит кликов для регулировки пристрелки данного оружия/прицела.
--- @param wep Weapon
--- @param opticData table|nil
--- @return number
function ZCityScopeZeroing.GetScopeClickLimit(wep, opticData)
	local defaultLimit = ZCityScopeZeroing.DefaultClickLimit
	return math.max(0, math.Round(tonumber(ZCityScopeZeroing.ScopeValue(wep, opticData, "scope_click_limit", defaultLimit)) or defaultLimit))
end

--- Ограничивает количество кликов в пределах допустимого лимита (положительного и отрицательного).
--- @param value number
--- @param limit number
--- @return number
function ZCityScopeZeroing.ClampClickCount(value, limit)
	value = math.Round(tonumber(value) or 0)
	return math.Clamp(value, -limit, limit)
end

--- Получает текущие клики по оси X с поддержкой сетевой синхронизации и предсказания.
--- @param wep Weapon
--- @return number
function ZCityScopeZeroing.GetClicksX(wep)
	if not IsValid(wep) then return 0 end
	if wep.ReticleClicksX == nil then
		wep.ReticleClicksX = wep:GetNWInt("ZCityScopeClicksX", 0)
	end
	return wep.ReticleClicksX
end

--- Получает текущие клики по оси Y с поддержкой сетевой синхронизации и предсказания.
--- @param wep Weapon
--- @return number
function ZCityScopeZeroing.GetClicksY(wep)
	if not IsValid(wep) then return 0 end
	if wep.ReticleClicksY == nil then
		wep.ReticleClicksY = wep:GetNWInt("ZCityScopeClicksY", 0)
	end
	return wep.ReticleClicksY
end

-- Вспомогательные функции для обнаружения прицеливания на стороне клиента
if CLIENT then
	--- Проверяет, целится ли игрок из оружия (не обязательно через оптический прицел).
	--- @param ply Player
	--- @return boolean
	function ZCityScopeZeroing.IsAimingNoScope(ply)
		local wep = ply:GetActiveWeapon()
		return IsValid(wep) and ishgweapon(wep) and hg.KeyDown(ply, IN_ATTACK2) and wep:CanUse()
	end
	IsAimingNoScope = ZCityScopeZeroing.IsAimingNoScope

	--- Проверяет, целится ли игрок активно через оптический прицел (с валидной сеткой).
	--- @param ply Player
	--- @return boolean
	function ZCityScopeZeroing.IsAiming(ply)
		local wep = ply:GetActiveWeapon()
		if not IsValid(wep) or not ishgweapon(wep) then return false end
		if not hg.KeyDown(ply, IN_ATTACK2) or not wep:CanUse() then return false end
		
		-- Должен быть задан размер прицельной сетки, чтобы оружие считалось оптическим прицелом
		if not ZCityScopeZeroing.HasScopeReticle(wep) then return false end
		
		return true
	end
	IsAiming = ZCityScopeZeroing.IsAiming
end
