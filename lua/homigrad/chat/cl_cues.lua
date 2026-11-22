local math_Clamp = math.Clamp

local MEMORY_TIME = 180
local MEMORY_FADE_START = 0.6
local MEMORY_MIN_ALPHA = 0.35
local OBSERVE_INTERVAL = 0.25
local OBSERVE_MAX_DIST = 1800
local VIEW_DOT = 0.7
local LOS_INTERVAL = 0.2
local LOS_MIN_FRACTION = 0.97

local TAG_DIST = 3000
local ZOOM_DIST = 6000
local ZOOM_RADIUS = 0.2
local NAME_MIN_ALPHA = 0.6
local ITEM_LIMIT = 64
local ITEM_NAME_LIMIT = 8
local ITEM_REFRESH = 0.5
local VIGNETTE_ALPHA = 215
local VIGNETTE_SPEED = 6
local VIGNETTE_BANDS = 32

local CUE_MAX = 6
local CUE_STEP = 22
local NAME_OFFSET = 30
local OUTLINE_WIDTH = 2
local IS_GAP = 10

local tagFont = "HomigradFontLarge"
local cueFont = "HomigradFontMedium"

local propClasses = {prop_physics = true, prop_physics_multiplayer = true}

local tagColor = Color(255, 255, 255)
local tagOutline = Color(0, 0, 0)
local cueColor = Color(255, 255, 255)
local haloColor = Color(255, 220, 90)

local seen = setmetatable({}, {__mode = "k"})
local losCache = setmetatable({}, {__mode = "k"})
local itemCache, itemCacheAt = {}, 0
local vignetteAmount = 0

local function o2Of(org)
	return istable(org.o2) and org.o2 or {}
end

local cueDefs = {
	{key = "motionless", text = "motionless", sev = 1, dist = 1800, corpse = true, test = function(org) return org.alive == false end},
	{key = "dull", text = "dull", sev = 1, dist = 900, test = function(org) return org.alive ~= false and org.heartstop and org.otrub end},
	{key = "unconscious", text = "unconscious", sev = 0.85, dist = 1500, test = function(org) return org.alive ~= false and org.otrub end},
	{key = "notbreathing", text = "not breathing", sev = 0.95, dist = 450, test = function(org)
		return org.alive ~= false and (org.respiratoryArrest or (org.otrub and o2Of(org).curregen == 0))
	end},
	{key = "seizing", text = "seizing", sev = 0.85, dist = 1200, test = function(org) return org.alive ~= false and org.seizureActive end},
	{key = "critical", text = "barely hanging on", sev = 0.9, dist = 700, test = function(org) return org.alive ~= false and (org.critical or org.incapacitated) end},
	{key = "gasping", text = "gasping for air", sev = 0.8, dist = 500, test = function(org)
		return org.alive ~= false and not org.otrub and (tonumber(o2Of(org)[1]) or 30) < 15
	end},
	{key = "bleedheavy", text = "bleeding heavily", sev = 0.85, dist = 1000, corpse = true, test = function(org)
		return ((tonumber(org.arterialBleed) or 0) > 0.5 or (tonumber(org.bleed) or 0) > 10)
	end},
	{key = "bleed", text = "bleeding", sev = 0.55, dist = 550, corpse = true, test = function(org)
		return (tonumber(org.bleed) or 0) > 2 and (tonumber(org.arterialBleed) or 0) <= 0.5 and (tonumber(org.bleed) or 0) <= 10
	end},
	{key = "verypale", text = "very pale", sev = 0.75, dist = 350, corpse = true, test = function(org) return (tonumber(org.blood) or 5000) < 2500 end},
	{key = "pale", text = "pale", sev = 0.45, dist = 250, corpse = true, test = function(org)
		local blood = tonumber(org.blood) or 5000

		return blood >= 2500 and blood < 3500
	end},
	{key = "agony", text = "in agony", sev = 0.7, dist = 750, test = function(org) return org.alive ~= false and (tonumber(org.pain) or 0) > 70 end},
	{key = "wince", text = "wincing in pain", sev = 0.4, dist = 350, test = function(org)
		local pain = tonumber(org.pain) or 0

		return org.alive ~= false and not org.otrub and pain > 30 and pain <= 70
	end},
	{key = "shock", text = "in shock", sev = 0.6, dist = 320, test = function(org) return org.alive ~= false and (tonumber(org.shock) or 0) > 35 end},
	{key = "dazed", text = "dazed", sev = 0.5, dist = 300, test = function(org)
		return org.alive ~= false and not org.otrub and (tonumber(org.consciousness) or 1) < 0.6
	end},
	{key = "joint", text = "hurt, with a joint out of place", sev = 0.45, dist = 260, corpse = true, test = function(org)
		return org.llegdislocation or org.rlegdislocation or org.larmdislocation or org.rarmdislocation or org.jawdislocation
	end},
	{key = "nohead", text = "missing their head", sev = 1, dist = 1300, corpse = true, test = function(org) return org.headamputated end},
	{key = "noarm", text = "missing an arm", sev = 0.8, dist = 1300, corpse = true, test = function(org)
		return org.larmamputated or org.rarmamputated or org.larmupamputated or org.rarmupamputated
	end},
	{key = "noleg", text = "missing a leg", sev = 0.8, dist = 1300, corpse = true, test = function(org)
		return org.llegamputated or org.rlegamputated or org.llegupamputated or org.rlegupamputated
	end},
	{key = "nopulse", text = "without a pulse", sev = 0.95, check = true, test = function(org)
		return org.alive ~= false and (org.heartstop or (tonumber(org.pulse) or 0) <= 0)
	end},
	{key = "weakpulse", text = "showing a weak pulse", sev = 0.6, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.pulse) or 0) > 0 and ((tonumber(org.hypotension) or 0) > 0.74 or (tonumber(org.perfusion) or 1) < 0.35)
	end},
	{key = "fastpulse", text = "showing a fast pulse", sev = 0.4, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.pulse) or 0) >= 105
	end},
	{key = "fixedpupils", text = "showing fixed, dilated pupils", sev = 0.8, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.brain) or 0) >= 0.6
	end},
	{key = "pinpoint", text = "showing pinpoint pupils", sev = 0.35, check = true, test = function(org)
		return org.alive ~= false and (tonumber(org.analgesia) or 0) > 1
	end},
}

local function PlayerName(ply)
	local name = hg.ChatLog and hg.ChatLog.Name and hg.ChatLog.Name(ply) or ply:GetPlayerName()

	return isstring(name) and name or "Someone"
end

local function Announce(ply, def)
	if not (IsValid(hg.chat) and hg.chat.AddLine) then return end

	local base = hg.ChatLog and hg.ChatLog.COLOR_AROUND or color_white
	local pcol = ply.GetPlayerColor and ply:GetPlayerColor()

	hg.chat:AddLine({base, "You notice ", pcol and pcol:ToColor() or base, PlayerName(ply), base, " is " .. def.text .. "."})
end

local losTrace = {mask = MASK_VISIBLE}
local losFilter = {}

local function HasLOS(ply, character, pos, eye)
	local now = CurTime()
	local cache = losCache[ply]

	if not cache or cache.at < now then
		local lply = LocalPlayer()
		losFilter[1] = lply
		losFilter[2] = hg.GetCurrentCharacter(lply)
		losFilter[3] = ply
		losFilter[4] = character
		losTrace.start = eye
		losTrace.endpos = pos
		losTrace.filter = losFilter

		cache = {at = now + LOS_INTERVAL, visible = util.TraceLine(losTrace).Fraction >= LOS_MIN_FRACTION}
		losCache[ply] = cache
	end

	return cache.visible
end

local function Observe()
	local lply = LocalPlayer()
	if not IsValid(lply) or not lply:Alive() then return end

	local now = CurTime()
	local eye, forward = EyePos(), EyeAngles():Forward()
	local checking = lply:GetNWString("hg_ia_mode", "") == "check" and lply:GetNWEntity("hg_ia_target") or nil
	local players = player.GetAll()

	for i = 1, #players do
		local ply = players[i]
		local org = ply.organism
		local character = ply ~= lply and not ply:IsDormant() and hg.GetCurrentCharacter(ply)
		if not org or not IsValid(character) then continue end

		local pos = character:WorldSpaceCenter()
		local delta = pos - eye
		local dist = delta:Length()
		local examined = checking == ply
		local visible = dist <= OBSERVE_MAX_DIST and delta:Dot(forward) >= dist * VIEW_DOT and HasLOS(ply, character, pos, eye)
		if not visible and not examined then continue end

		local record = seen[ply]
		if not record then
			record = {}
			seen[ply] = record
		end

		for j = 1, #cueDefs do
			local def = cueDefs[j]
			local canSee = examined or (visible and not def.check and dist <= def.dist)
			if not canSee then continue end

			local entry = record[def.key]

			if def.test(org) then
				if entry then
					entry.at = now
				else
					record[def.key] = {def = def, at = now}
					Announce(ply, def)
				end
			elseif entry then
				record[def.key] = nil
			end
		end
	end

	for ply, record in pairs(seen) do
		if not IsValid(ply) then
			seen[ply] = nil
			continue
		end

		for key, entry in pairs(record) do
			if now - entry.at > MEMORY_TIME then record[key] = nil end
		end
	end
end

timer.Create("HGCueObserve", OBSERVE_INTERVAL, 0, Observe)

local function KnownCues(ply)
	local record = seen[ply]
	if not record then return end

	local list = {}
	for _, entry in pairs(record) do list[#list + 1] = entry end
	if #list == 0 then return end

	table.sort(list, function(a, b) return a.def.sev > b.def.sev end)

	return list
end

local INJURY_SEV = 0.65
local CORPSE_CUE_MAX = 14

local function CorpseCues(org)
	local list = {}
	local now = CurTime()

	for i = 1, #cueDefs do
		local def = cueDefs[i]
		if def.corpse and def.test(org) then list[#list + 1] = {def = def, at = now} end
	end

	local injuries = hg.ChatLog and hg.ChatLog.Injuries
	if injuries then
		for i = 1, #injuries do
			local injury = injuries[i]
			if injury.check(org) then
				injury.cueDef = injury.cueDef or {text = "their " .. injury.text, sev = INJURY_SEV}
				list[#list + 1] = {def = injury.cueDef, at = now}
			end
		end
	end

	if #list == 0 then return end

	table.sort(list, function(a, b) return a.def.sev > b.def.sev end)

	return list
end

local function Suppressed(lply)
	if IsValid(MENUPANELHUYHUY) then return true end
	if lply:GetNWString("hg_ia_mode", "") ~= "" then return true end
	if lply.organism and lply.organism.otrub then return true end

	local wep = lply:GetActiveWeapon()

	return IsValid(wep) and wep.GetCheckingAfflictions and wep:GetCheckingAfflictions() or false
end

local function AltHeld()
	return input.IsKeyDown(KEY_LALT) or input.IsKeyDown(KEY_RALT)
end

local function ScanActive(lply)
	return IsValid(lply) and lply:Alive() and AltHeld() and zooming == true and not Suppressed(lply)
end

local function PlayerTagColor(ent)
	local pcol = ent.GetPlayerColor and ent:GetPlayerColor()
	local col = pcol and pcol:ToColor() or color_white
	tagColor.r, tagColor.g, tagColor.b = col.r, col.g, col.b

	local v = (col.r < 50 and col.g < 50 and col.b < 50) and 100 or 0
	tagOutline.r, tagOutline.g, tagOutline.b = v, v, v
end

local function DrawPerson(ent, name, cues, offer, screen, alpha, cueMax)
	PlayerTagColor(ent)
	tagColor.a = alpha
	tagOutline.a = alpha

	surface.SetFont(tagFont)
	local nameW, nameH = surface.GetTextSize(name)
	local y = screen.y + NAME_OFFSET

	draw.SimpleTextOutlined(name, tagFont, screen.x, y, tagColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, OUTLINE_WIDTH, tagOutline)

	tagOutline.r, tagOutline.g, tagOutline.b = 0, 0, 0

	local count = cues and math.min(#cues, cueMax or CUE_MAX) or 0
	if count > 0 then
		cueColor.r, cueColor.g, cueColor.b, cueColor.a = 255, 255, 255, alpha
		draw.SimpleTextOutlined("is", cueFont, screen.x + nameW / 2 + IS_GAP, y + nameH * 0.5, cueColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, OUTLINE_WIDTH, tagOutline)
	end

	local lineY = y + nameH + 2
	local now = CurTime()

	for i = 1, count do
		local entry = cues[i]
		local sev = math_Clamp(entry.def.sev, 0, 1)
		local age = (now - entry.at) / MEMORY_TIME
		local fade = Lerp(math_Clamp((age - MEMORY_FADE_START) / (1 - MEMORY_FADE_START), 0, 1), 1, MEMORY_MIN_ALPHA)

		cueColor.r, cueColor.g, cueColor.b = 255, 255 * (1 - sev), 255 * (1 - sev)
		cueColor.a = alpha * fade
		tagOutline.a = alpha * fade

		draw.SimpleTextOutlined(entry.def.text, cueFont, screen.x, lineY, cueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, OUTLINE_WIDTH, tagOutline)
		lineY = lineY + CUE_STEP
	end

	if offer then
		cueColor.r, cueColor.g, cueColor.b, cueColor.a = 255, 255, 255, alpha
		tagOutline.a = alpha

		draw.SimpleTextOutlined("offers you " .. offer .. " (Q)", cueFont, screen.x, lineY, cueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, OUTLINE_WIDTH, tagOutline)
	end
end

local function CenterDistance(screen, cx, cy)
	local dx, dy = screen.x - cx, screen.y - cy

	return math.sqrt(dx * dx + dy * dy)
end

local function TagBlocked(lply)
	if AltHeld() then return false end

	local wep = lply:GetActiveWeapon()
	if not IsValid(wep) then return false end
	if wep.GetCarrying and IsValid(wep:GetCarrying()) then return true end

	local hands = hg.PlayerInteract and hg.PlayerInteract.HandsClasses[wep:GetClass()]

	return not hands and lply:KeyDown(IN_ATTACK2)
end

local function DrawFacing(lply, dist)
	local trace = hg.eyeTrace(lply, dist)
	if not trace or not trace.Hit then return end

	local ent = trace.Entity
	if not IsValid(ent) or not (ent:IsRagdoll() or ent:IsPlayer()) then return end
	if ent.PlayerClassName == "sc_infiltrator" or ent:GetNetVar("disappearance", nil) then return end

	local owner = ent:IsRagdoll() and hg.RagdollOwner(ent) or ent
	local corpse = ent:IsRagdoll() and not IsValid(owner) and istable(ent.organism) and ent.organism or nil

	local name = ent:GetPlayerName()
	if not isstring(name) or name == "" then
		local ply = ent:IsRagdoll() and ent:GetNWEntity("ply")
		name = IsValid(ply) and ply:IsPlayer() and PlayerName(ply) or nil
	end
	if not isstring(name) or name == "" then return end

	local hitDist = EyePos():Distance(trace.HitPos)
	local alpha = Lerp(math_Clamp(hitDist / dist, 0, 1), 1, NAME_MIN_ALPHA) * 255
	local cues
	if AltHeld() then
		if corpse then
			cues = CorpseCues(corpse)
		elseif IsValid(owner) then
			cues = KnownCues(owner)
		end
	end
	local offer = IsValid(owner) and owner:GetNWString("hg_ia_mode", "") == "offer" and owner:GetNWEntity("hg_ia_target") == lply and owner:GetNWString("hg_ia_item", "something") or nil

	DrawPerson(ent, name, cues, offer, trace.HitPos:ToScreen(), alpha, corpse and CORPSE_CUE_MAX)
end

local function IsMovable(ent)
	if not (propClasses[ent:GetClass()] or (ent:IsWeapon() and not IsValid(ent:GetOwner()))) then return false end
	if ent:GetMoveType() ~= MOVETYPE_VPHYSICS or ent:GetNoDraw() then return false end

	local phys = ent:GetPhysicsObject()

	return IsValid(phys) and phys:IsMotionEnabled()
end

local function MovableItems(eye)
	local now = CurTime()
	if itemCacheAt > now then return itemCache end
	itemCacheAt = now + ITEM_REFRESH

	local list = {}
	local limit = ZOOM_DIST * ZOOM_DIST
	local all = ents.GetAll()

	for i = 1, #all do
		local ent = all[i]
		if IsValid(ent) and not ent:IsDormant() and IsMovable(ent) then
			local d = eye:DistToSqr(ent:GetPos())
			if d <= limit then list[#list + 1] = {ent = ent, d = d} end
		end
	end

	table.sort(list, function(a, b) return a.d < b.d end)

	for i = #list, ITEM_LIMIT + 1, -1 do list[i] = nil end
	itemCache = list

	return list
end

local function ItemName(ent)
	if ent:IsWeapon() and ent.GetPrintName then
		local name = ent:GetPrintName()
		if isstring(name) and name ~= "" then return name end
	end

	if isstring(ent.PrintName) and ent.PrintName ~= "" then return ent.PrintName end

	local model = string.StripExtension(string.GetFileFromFilename(ent:GetModel() or ""))

	return (string.gsub(model, "_", " "))
end

local function DrawItemNames(radius)
	local cx, cy = ScrW() / 2, ScrH() / 2
	local picks = {}

	for _, item in ipairs(itemCache) do
		local ent = item.ent
		if IsValid(ent) then
			local screen = ent:WorldSpaceCenter():ToScreen()
			local d = screen.visible and CenterDistance(screen, cx, cy)
			if d and d <= radius then picks[#picks + 1] = {ent = ent, screen = screen, d = d} end
		end
	end

	table.sort(picks, function(a, b) return a.d < b.d end)

	cueColor.r, cueColor.g, cueColor.b, cueColor.a = haloColor.r, haloColor.g, haloColor.b, 255
	tagOutline.r, tagOutline.g, tagOutline.b, tagOutline.a = 0, 0, 0, 255

	for i = 1, math.min(#picks, ITEM_NAME_LIMIT) do
		local pick = picks[i]
		draw.SimpleTextOutlined(ItemName(pick.ent), cueFont, pick.screen.x, pick.screen.y, cueColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, OUTLINE_WIDTH, tagOutline)
	end
end

local function DrawVignette(amount)
	local w, h = ScrW(), ScrH()
	local bandW, bandH = w * 0.5 / VIGNETTE_BANDS, h * 0.5 / VIGNETTE_BANDS

	for i = 0, VIGNETTE_BANDS - 1 do
		local fall = 1 - i / VIGNETTE_BANDS
		surface.SetDrawColor(0, 0, 0, VIGNETTE_ALPHA * amount * fall * fall)
		surface.DrawRect(i * bandW, 0, bandW + 1, h)
		surface.DrawRect(w - (i + 1) * bandW, 0, bandW + 1, h)
		surface.DrawRect(0, i * bandH, w, bandH + 1)
		surface.DrawRect(0, h - (i + 1) * bandH, w, bandH + 1)
	end
end

hook.Add("HUDPaint", "HGCueScan", function()
	local lply = LocalPlayer()
	local usable = IsValid(lply) and lply:Alive() and not Suppressed(lply)
	local zoomScan = usable and AltHeld() and zooming == true

	vignetteAmount = Lerp(math_Clamp(FrameTime() * VIGNETTE_SPEED, 0, 1), vignetteAmount, zoomScan and 1 or 0)
	if vignetteAmount > 0.01 then DrawVignette(vignetteAmount) end

	if not usable or lply:GetNetVar("disappearance", nil) or TagBlocked(lply) then return end

	DrawFacing(lply, zoomScan and ZOOM_DIST or TAG_DIST)

	if zoomScan then
		MovableItems(EyePos())
		DrawItemNames(ScrH() * ZOOM_RADIUS)
	end
end)

hook.Add("PreDrawHalos", "HGCueScanHalos", function()
	local lply = LocalPlayer()
	if not ScanActive(lply) then return end

	local highlighted = {}

	for _, item in ipairs(MovableItems(EyePos())) do
		if IsValid(item.ent) then highlighted[#highlighted + 1] = item.ent end
	end

	if #highlighted > 0 then halo.Add(highlighted, haloColor, 2, 2, 1, true, true) end
end)
