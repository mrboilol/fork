ZCityScopeZeroing = ZCityScopeZeroing or {}

local localPosCache = Vector(0, 0, 0)
local angAddHuyCache = Angle(0, 0, 0)
ZCityScopeZeroing.ColorRed = Color(255, 0, 0)

-- RT текстуры и материалы будут инициализированы внутри InitRender
ZCityScopeZeroing.RTMat = nil
ZCityScopeZeroing.RTView = nil
ZCityScopeZeroing.RTViewMat = nil
ZCityScopeZeroing.Initialized = false


--- Инициализирует Render Targets и внутренние материалы прицела, если они еще не были созданы.
function ZCityScopeZeroing.InitRender()
	if ZCityScopeZeroing.Initialized then return end
	
	local rtsize = ZCityScopeZeroing.RTSize
	-- Do not reuse homigrad_base's "huy-glass22" target.  The base creates it
	-- with GetRenderTargetEx/BGR888, while this code used GetRenderTarget with
	-- the same name.  Which version won depended on the client's load order and
	-- could leave the scope sampling a blank or alpha-faded target.
	local rtFlags = bit.bor(2, 256)
	ZCityScopeZeroing.RTMat = GetRenderTargetEx(
		"zcity_scope_zeroing_composite", rtsize, rtsize,
		RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_SHARED, rtFlags, 0, IMAGE_FORMAT_BGR888
	)
	ZCityScopeZeroing.RTView = GetRenderTargetEx(
		"zcity_scope_zeroing_view_rt", rtsize, rtsize,
		RT_SIZE_NO_CHANGE, MATERIAL_RT_DEPTH_SHARED, rtFlags, 0, IMAGE_FORMAT_BGR888
	)
	ZCityScopeZeroing.RTViewMat = CreateMaterial("zcity_scope_zeroing_view", "UnlitGeneric", {
		["$basetexture"] = ZCityScopeZeroing.RTView:GetName(),
		["$ignorez"] = 1,
		["$vertexcolor"] = 1
	})

	ZCityScopeZeroing.Initialized = true
end

ZCityScopeZeroing.CreatedMaterials = ZCityScopeZeroing.CreatedMaterials or {}
ZCityScopeZeroing.ResolvedMaterialsCache = ZCityScopeZeroing.ResolvedMaterialsCache or {}

--- Преобразует строковый путь в объект Material или возвращает материал напрямую.
--- Автоматически обходит некорректные VMT-прокси (например, ARC9), создавая чистый UnlitGeneric-материал
--- и копируя в него оригинальную текстуру напрямую из памяти.
--- @param value any
--- @return Material|nil
function ZCityScopeZeroing.ScopeMaterial(value)
	if not value or value == "" then return nil end

	local cached = ZCityScopeZeroing.ResolvedMaterialsCache[value]
	if cached ~= nil then return cached end

	local testMat = nil
	local path = nil

	if isstring(value) then
		testMat = Material(value)
		path = value
	elseif type(value) == "IMaterial" or (type(value) == "userdata" and value.GetName) then
		testMat = value
		path = value:GetName()
	end

	local resultMat = testMat

	if testMat and not testMat:IsError() and path and path ~= "" then
		local lowerPath = string.lower(path)
		local ext = string.sub(lowerPath, -4)
		
		-- Игнорируем стандартные vtf файлы
		if ext ~= ".vtf" then
			local cleanPath = path
			if ext == ".vmt" or ext == ".png" then
				cleanPath = string.sub(path, 1, -5)
			end
			
			local cacheKey = string.lower(cleanPath)
			if ZCityScopeZeroing.CreatedMaterials[cacheKey] then
				resultMat = ZCityScopeZeroing.CreatedMaterials[cacheKey]
			else
				-- Извлекаем оригинальную текстуру из базового материала
				local tex = testMat:GetTexture("$basetexture")
				if tex then
					-- Создаем уникальный чистый UnlitGeneric материал
					local uniqueName = "zcity_zeroing_reticle_" .. util.CRC(cacheKey)
					local customMat = CreateMaterial(uniqueName, "UnlitGeneric", {
						["$translucent"] = 1,
						["$vertexcolor"] = 1,
						["$vertexalpha"] = 1,
						["$ignorez"] = 1
					})
					
					if customMat and not customMat:IsError() then
						customMat:SetTexture("$basetexture", tex)
						ZCityScopeZeroing.CreatedMaterials[cacheKey] = customMat
						resultMat = customMat
					end
				end
			end
		end
	end

	resultMat = resultMat or testMat
	ZCityScopeZeroing.ResolvedMaterialsCache[value] = resultMat
	return resultMat
end

--- Проверяет, задано ли валидное значение материала (не nil и не пустая строка).
--- @param value any
--- @return boolean
function ZCityScopeZeroing.MaterialIsUsable(value)
	if value == nil then return false end
	if isstring(value) then
		return value ~= ""
	end
	return true
end


--- Находит нужный материал прицела, проверяя поочередно прицел (аттачмент) и оружие.
--- @param self Weapon
--- @param opticData table|nil
--- @param key string
--- @return Material|nil, string
function ZCityScopeZeroing.ResolveScopeMaterial(self, opticData, key)
	if opticData then
		local val = opticData[key]
		if ZCityScopeZeroing.MaterialIsUsable(val) then
			return ZCityScopeZeroing.ScopeMaterial(val), "att." .. key
		end
	end

	if IsValid(self) then
		local val = self[key]
		if ZCityScopeZeroing.MaterialIsUsable(val) then
			return ZCityScopeZeroing.ScopeMaterial(val), "wep." .. key
		end
	end

	return nil, "none"
end

--- Возвращает лимит расстояния эффекта айбокса (eyebox) на основе разрешения RT прицела.
--- @param scopeBlackout number
--- @return number
function ZCityScopeZeroing.GetScopeEyeBoxLimit(scopeBlackout)
	-- Возвращаем широкий предел для рендеринга (10000.0 при 512 RT), чтобы исключить резкое выключение
	-- 3D-сцены при быстром движении мыши (оригинальное поведение Z-City).
	return 10000.0 * (ZCityScopeZeroing.RTSize / 512)
end

--- Рисует текстурированный прямоугольник с поворотом и динамическим смещением (кастомный метод DrawTexturedRectRotatedHuy).
--- @param x number
--- @param y number
--- @param w number
--- @param h number
--- @param rotVal number
--- @param offsetX number
--- @param offsetY number
--- @param rotHuy number
function ZCityScopeZeroing.DrawTexturedRectRotatedHuy(x, y, w, h, rotVal, offsetX, offsetY, rotHuy)
	rotHuy = rotHuy or 0
	local newX = x + offsetX * math.sin(math.rad(rotVal))
	local newY = y + offsetX * math.cos(math.rad(rotVal))
	newX = newX + offsetY * math.cos(math.rad(rotVal))
	newY = newY - offsetY * math.sin(math.rad(rotVal))
	surface.DrawTexturedRectRotated(newX, newY, w, h, rotVal + rotHuy)
end
-- Экспортируем в таблицу surface для обратной совместимости с внешними скриптами
surface.DrawTexturedRectRotatedHuy = ZCityScopeZeroing.DrawTexturedRectRotatedHuy

--- Преобразует угловые миллирадианы (милы) прицела в пиксели относительно параметров RT прицела.
--- @param mil number
--- @param fov number
--- @return number
function ZCityScopeZeroing.ScopeMilToPixels(mil, fov)
	local halfFov = math.rad(math.max(fov or 0, 0.01)) * 0.5
	return math.tan(mil / 1000) / math.tan(halfFov) * (ZCityScopeZeroing.RTSize * 0.5)
end

--- Рассчитывает горизонтальное и вертикальное пиксельное смещение сетки на основе кликов горизонтальных и вертикальных поправок.
--- @param self Weapon
--- @param fov number
--- @param opticData table|nil
--- @return number, number
function ZCityScopeZeroing.GetScopeClickOffset(self, fov, opticData)
	local clickMil = math.max(0, ZCityScopeZeroing.ScopeValue(self, opticData, "scope_click_mil", ZCityScopeZeroing.ScopeClickMil))
	local clickPixels = ZCityScopeZeroing.ScopeMilToPixels(clickMil, fov)

	local clicksX = ZCityScopeZeroing.GetClicksX(self)
	local clicksY = ZCityScopeZeroing.GetClicksY(self)
	return -clicksX * clickPixels, clicksY * clickPixels
end

local hg_show_hitposmuzzle = ConVarExists("hg_show_hitposmuzzle") and GetConVar("hg_show_hitposmuzzle") or CreateClientConVar("hg_show_hitposmuzzle", "0", false, false, "shows weapons crosshair, work only ведьма admin rank or sv_cheats 1")

--- Кастомная настройка Render View для 3D picture-in-picture прицелов (DoRT).
--- @param self Weapon
function ZCityScopeZeroing.SWEP_DoRT(self)
	LOW_RENDER = nil
	local gun = self:GetWeaponEntity()
	local att = self:GetMuzzleAtt(gun, true)
	local owner = self:GetOwner()
	if not att then
		ZCityScopeZeroing.DebugPrint("DoRT stopped: no muzzle attachment for " .. tostring(self:GetClass()), 2)
		return
	end
	local foundatt = ZCityScopeZeroing.GetActiveOpticAttachment(self)
	local reticleBaseSize = tonumber(ZCityScopeZeroing.ScopeValue(self, foundatt, "sizeperekrestie"))
	if not reticleBaseSize or reticleBaseSize <= 0 then
		ZCityScopeZeroing.DebugPrint("DoRT stopped: no reticle size; wep.sizeperekrestie=" .. ZCityScopeZeroing.DebugValue(self.sizeperekrestie) .. " att.sizeperekrestie=" .. ZCityScopeZeroing.DebugValue(foundatt and foundatt.sizeperekrestie or nil), 2)
		return
	end
	self.isscoping = true
	local pos, ang = self:GetTrace(true, nil, nil, true)
	local optic = false
	if foundatt and self.modelAtt and IsValid(self.modelAtt.sight) then
		pos = self.modelAtt.sight:GetPos()
		optic = true
	end
	local localPos = localPosCache
	localPos:Set(ZCityScopeZeroing.ScopeValue(self, foundatt, "localScopePos", ZCityScopeZeroing.LocalScopePos))
	localPos:Rotate(ang)
	pos:Add(localPos)
	local view = render.GetViewSetup(true)
	local diff, point = util.DistanceToLine(view.origin, view.origin + ang:Forward() * 50, pos)
	local scope_pos = WorldToLocal(point, angle_zero, pos, view.angles)
	
	-- Убеждаемся, что RT инициализирован
	ZCityScopeZeroing.InitRender()
	
	-- The fallback lives under decals/.  Material("huy-glass") resolves to an
	-- error material on clients that do not have another addon providing it.
	local mat = self.mat or Material("decals/huy-glass")
	mat:SetTexture("$basetexture", ZCityScopeZeroing.RTMat)
	-- Scope lens materials are often shared with transparent glass.  Do not let
	-- their model alpha/tint wash out the render target while the player aims.
	mat:SetFloat("$alpha", 1)
	mat:SetVector("$color", Vector(1, 1, 1))
	mat:SetInt("$vertexcolor", 0)
	mat:SetInt("$vertexalpha", 0)
	
	if hg_show_hitposmuzzle:GetBool() then
		render.DrawLine(pos, point, Color(255, 255, 255))
	end

	local dist = pos:Distance(view.origin)
	local zoomFOV = math.max(self.ZoomFOV or ZCityScopeZeroing.FOVMax, 0.5)
	local scopeBlackout = math.max(1, tonumber(ZCityScopeZeroing.ScopeValue(self, foundatt, "scope_blackout", ZCityScopeZeroing.ScopeBlackout)) or ZCityScopeZeroing.ScopeBlackout)
	local rtsize = ZCityScopeZeroing.RTSize
	local reticleSize = (reticleBaseSize * rtsize / 512) / (ZCityScopeZeroing.ScopeValue(self, foundatt, "perekrestieSize") and 4 or zoomFOV / 3)
	local mul = 4 * zoomFOV / 7 * (ZCityScopeZeroing.ScopeValue(self, foundatt, "scopedef") and 400 / scopeBlackout or 1)
	
	local angaddhuy = angAddHuyCache
	angaddhuy[1] = scope_pos[3] * mul
	angaddhuy[2] = -scope_pos[2] * mul
	local ang2 = ang + angaddhuy
	local pos2 = pos
	local tr = util.QuickTrace(owner:EyePos(), (pos2 - owner:EyePos()) + (pos2 - owner:EyePos()):GetNormalized() * 5, {owner, owner.FakeRagdoll})

	local rt = {
		x = 0,
		y = 0,
		w = rtsize,
		h = rtsize,
		angles = ang2,
		origin = owner:InVehicle() and pos2 or tr.HitPos - (pos2 - owner:EyePos()):GetNormalized() * 5,
		drawviewmodel = false,
		fov = zoomFOV / dist * 12,
		znear = 1,
		bloomtone = false
	}
	local zeroingOffsetX, zeroingOffsetY = ZCityScopeZeroing.GetScopeClickOffset(self, rt.fov, foundatt)
	local scrw, scrh = ScrW(), ScrH()
	if scrw <= 0 or scrh <= 0 then
		ZCityScopeZeroing.DebugPrint("DoRT stopped: invalid screen size " .. tostring(scrw) .. "x" .. tostring(scrh), 2)
		return
	end
	local scr1 = pos:ToScreen()
	local scr2 = point:ToScreen()
	
	local diffaX = (scr1.x - scr2.x) * 2
	local diffaY = (scr1.y - scr2.y) * 2

	-- Нормализуем длину к базовому разрешению 1920x1080 для eyebox, чтобы он работал одинаково на высоких разрешениях (4K и т.д.)
	local normDiffaX = diffaX * (1920 / scrw)
	local normDiffaY = diffaY * (1080 / scrh)
	local diffaLenSqr = normDiffaX^2 + normDiffaY^2

	local eyeBoxLimit = ZCityScopeZeroing.GetScopeEyeBoxLimit(scopeBlackout)
	
	render.PushRenderTarget(ZCityScopeZeroing.RTMat, 0, 0, rtsize, rtsize)
	RENDERING_SCOPE = self
	render.Clear(1, 1, 1, 255)
	render.SetWriteDepthToDestAlpha(false)
	local old = DisableClipping(true)

	local renderedView = false
	if diffaLenSqr < eyeBoxLimit then
		render.PushRenderTarget(ZCityScopeZeroing.RTView, 0, 0, rtsize, rtsize)
			render.Clear(1, 1, 1, 255)
			render.ClearDepth()
			render.SetWriteDepthToDestAlpha(false)
			render.RenderView(rt)
		render.PopRenderTarget()
		renderedView = true

		render.Clear(0, 0, 0, 255)
		cam.Start3D()
			local aimWay = (ang:Forward()) * 10000000000
			local toscreen = aimWay:ToScreen()
			local x, y = toscreen.x, toscreen.y
			local hitPos
			if hg_show_hitposmuzzle:GetBool() then
				hitPos = self:GetTrace(true).HitPos:ToScreen()
			end
		cam.End3D()

		local distMul = math.min(15, 1.2 * 2.5 * (15 / zoomFOV))
		-- Нормализуем дистанцию к 1920x1080, чтобы ограничение отрисовки работало одинаково на высоких разрешениях (4K и т.д.)
		local dist_x = (x - scrw / 2) * (1920 / scrw)
		local dist_y = (y - scrh / 2) * (1080 / scrh)
		local distScreen = math.sqrt((dist_x * distMul)^2 + (dist_y * distMul)^2)
		local drawScopeImage = distScreen <= 2048

		if distScreen > 2048 then
			render.Clear(0, 0, 0, 255)
		end

		render.PushFilterMin(TEXFILTER.ANISOTROPIC)
		render.PushFilterMag(TEXFILTER.ANISOTROPIC)
		cam.Start2D()
			if drawScopeImage and renderedView then
				surface.SetDrawColor(255, 255, 255, 255)
				ZCityScopeZeroing.RTViewMat:SetTexture("$basetexture", ZCityScopeZeroing.RTView)
				surface.SetMaterial(ZCityScopeZeroing.RTViewMat)
				surface.DrawTexturedRect(zeroingOffsetX, zeroingOffsetY, rtsize, rtsize)
			end

			local scaleX = rtsize / scrw
			local scaleY = rtsize / scrh

			if hg_show_hitposmuzzle:GetBool() then
				draw.RoundedBox(0, hitPos.x * scaleX - 2, hitPos.y * scaleY - 2, 4, 4, ZCityScopeZeroing.ColorRed)
			end
			local blackout = ZCityScopeZeroing.ScopeValue(self, foundatt, "blackoutsize", ZCityScopeZeroing.BlackoutSize) * 0.75
			local scopeMaterial, scopeSource = ZCityScopeZeroing.ResolveScopeMaterial(self, foundatt, "scopemat")
			local reticleMaterial, reticleSource = ZCityScopeZeroing.ResolveScopeMaterial(self, foundatt, "perekrestie")
			local reticleRot = ZCityScopeZeroing.ScopeValue(self, foundatt, "rot", ZCityScopeZeroing.Rot)
			local reticleOffsetX = y * scaleY
			local reticleOffsetY = x * scaleX
			ZCityScopeZeroing.DebugPrint("DoRT draw: drawScopeImage=" .. tostring(drawScopeImage) .. " reticleSize=" .. tostring(reticleSize) .. " eyeBoxLimit=" .. tostring(eyeBoxLimit) .. " reticleOffsetX=" .. tostring(reticleOffsetX) .. " reticleOffsetY=" .. tostring(reticleOffsetY) .. " reticleSource=" .. tostring(reticleSource) .. " scopeSource=" .. tostring(scopeSource) .. " " .. ZCityScopeZeroing.DebugMaterialStatus("reticle", reticleMaterial) .. " " .. ZCityScopeZeroing.DebugMaterialStatus("scopeMask", scopeMaterial), 2)

			if reticleMaterial then
				surface.SetDrawColor(255, 255, 255, 255)
				surface.SetMaterial(reticleMaterial)
				surface.DrawTexturedRectRotatedHuy(0, 0, reticleSize, reticleSize, 0, reticleOffsetX, reticleOffsetY, reticleRot)
			end

			if scopeMaterial then
				surface.SetDrawColor(100, 100, 100)
				surface.SetMaterial(scopeMaterial)
				surface.DrawTexturedRectRotatedHuy(0, 0, blackout * rtsize / 512 * 2 + 512, blackout * rtsize / 512 * 2 + 512, 0, (rtsize / 2 - y * scaleY) * distMul + rtsize / 2, (rtsize / 2 - x * scaleX) * distMul + rtsize / 2)
				surface.SetDrawColor(0, 0, 0, 255)
				surface.SetMaterial(scopeMaterial)
				local x1 = x * math.atan(math.rad(math.cos(CurTime()) * 1))
				local y1 = y * math.atan(math.rad(math.sin(CurTime()) * 1))
				surface.DrawTexturedRectRotatedHuy(0, 0, blackout * 0.75 * rtsize / 512 + 512, blackout * rtsize / 512 * 0.75 + 512, 0, y1 * scaleY * distMul + rtsize / 2, x1 * scaleX * distMul + rtsize / 2)
				surface.DrawTexturedRectRotatedHuy(0, 0, blackout * 0.75 * rtsize / 512 + 512, blackout * rtsize / 512 * 0.75 + 512, 0, -diffaY * scaleY * 2 * distMul + rtsize / 2, -diffaX * scaleX * 2 * distMul + rtsize / 2)
			end

			if self.SightDrawFunc then self:SightDrawFunc() end
			if optic and foundatt.SightDrawFunc then foundatt.SightDrawFunc(self) end
		cam.End2D()
		render.PopFilterMin()
		render.PopFilterMag()
	else
		render.PushRenderTarget(ZCityScopeZeroing.RTView, 0, 0, rtsize, rtsize)
			render.Clear(0, 0, 0, 255)
		render.PopRenderTarget()
		ZCityScopeZeroing.DebugPrint("DoRT skipped: outside scope eye box; diffaLenSqr=" .. tostring(diffaLenSqr) .. " eyeBoxLimit=" .. tostring(eyeBoxLimit) .. " scopeBlackout=" .. tostring(scopeBlackout), 2)
	end
	DisableClipping(old)
	RENDERING_SCOPE = false
	render.PopRenderTarget()
end

--- Кастомная логика изменения FOV (приближения) на основе дельты прокрутки колесика мыши.
--- @param self Weapon
function ZCityScopeZeroing.SWEP_ChangeFOV(self)
	self.ZoomFOV = math.Clamp(self.ZoomFOV - (ZCityScopeZeroing.Delta / 10 or 0), self.FOVMin or ZCityScopeZeroing.FOVMin, self.FOVMax or ZCityScopeZeroing.FOVMax)
end

function ZCityScopeZeroing.ApplyOverrides()
	local base = weapons.GetStored("homigrad_base")
	if not base then
		print("[Scope Zeroing] WARNING: homigrad_base not found!")
		return
	end

	-- Сохраняем оригинальные функции для проверки в цикле, чтобы не перезаписывать
	-- кастомные реализации в дочерних оружиях
	local originalDoRT = base.DoRT
	local originalChangeFOV = base.ChangeFOV

	-- Инициализируем Render Targets
	ZCityScopeZeroing.InitRender()

	-- Применяем оверрайды к базовому классу
	base.DoRT = ZCityScopeZeroing.SWEP_DoRT
	base.ChangeFOV = ZCityScopeZeroing.SWEP_ChangeFOV
	base.localScopePos = ZCityScopeZeroing.LocalScopePos
	base.scope_blackout = ZCityScopeZeroing.ScopeBlackout
	base.rot = ZCityScopeZeroing.Rot
	base.FOVMin = ZCityScopeZeroing.FOVMin
	base.FOVMax = ZCityScopeZeroing.FOVMax
	base.blackoutsize = ZCityScopeZeroing.BlackoutSize
	base.scope_blackout_distmul_max = ZCityScopeZeroing.ScopeBlackoutDistMulMax
	base.scope_click_mil = ZCityScopeZeroing.ScopeClickMil
	base.scope_click_limit = ZCityScopeZeroing.ScopeClickLimit

	-- Также применяем оверрайды ко всем оружиям, которые наследуются от homigrad_base,
	-- но только если они используют стандартные функции базового класса.
	for classname, wepTable in pairs(weapons.GetList()) do
		if wepTable.Base == "homigrad_base" or classname == "homigrad_base" then
			if wepTable.DoRT == originalDoRT or wepTable.DoRT == nil then
				wepTable.DoRT = ZCityScopeZeroing.SWEP_DoRT
			end
			if wepTable.ChangeFOV == originalChangeFOV or wepTable.ChangeFOV == nil then
				wepTable.ChangeFOV = ZCityScopeZeroing.SWEP_ChangeFOV
			end
		end
	end

	print("[Scope Zeroing] Overrides applied successfully!")
end
