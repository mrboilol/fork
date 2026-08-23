local function DrawSunEffect()
	local sun = util.GetSunInfo()
	if not sun then return end
	if not sun.direction then return end
	if sun.obstruction == 0 then return end
	local sunpos = EyePos() + sun.direction * 1024 * 4
	local scrpos = sunpos:ToScreen()
	local dot = (sun.direction:Dot(EyeVector()) - 0.8) * 5
	if dot <= 0 then return end
	DrawSunbeams(0.1, 0.15 * dot * sun.obstruction, 0.1, scrpos.x / ScrW(), scrpos.y / ScrH())
end

surface.CreateFont("ZCity_Suicide_Text", {
	font = "Mx437 IBM PS/55 re.",
	size = ScreenScaleH(20),
	weight = 700,
	antialias = true
})
hg.postprocess = hg.postprocess or {}
local postprs = hg.postprocess
postprs.addtiveLayer = {
	bloom_darken = 0,
	bloom_mul = 0,
	bloom_sizex = 0,
	bloom_sizey = 0,
	bloom_passes = 0,
	bloom_colormul = 0,
	bloom_colorr = 0,
	bloom_colorg = 0,
	bloom_colorb = 0,
	blur_addalpha = 0,
	blur_drawalpha = 0,
	blur_delay = 0,
	toytown = 0,
	toytown_h = 0,
	brightness = 0,
	sharpen = 0,
	sharpen_dist = 0
}

postprs.layers = postprs.layers or {}
local layers = postprs.layers
local layers_name = {}
function postprs.LayerAdd(name, tab)
	tab.weight = 0
	layers_name[#layers_name+1] = name
	layers[name] = tab
end

function postprs.LayerWeight(name, lerp, value)
	layers[name].weight = LerpFT(lerp, layers[name].weight, value)
end

function postprs.LayerSetWeight(name, value)
	layers[name].weight = value
end

local addtiveLayer = postprs.addtiveLayer
local tab = {
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

--local potatopc = GetConVar("hg_potatopc") or CreateClientConVar("hg_potatopc", "0", true, false, "enable this if you are noob", 0, 1)
local function getServerSoundMode(name, fallback)
	local convar = GetConVar(name)
	return convar and convar:GetInt() or fallback
end
local otrubSoundPaths = {
	[1] = "sound/altotrub.mp3",
	[2] = "sound/sleepy.mp3",
	[3] = "sound/itssoover.mp3",
	[4] = "sound/ngaimcooked.mp3",
	[5] = "sound/rem_dying1.mp3"
}
local OtrubModeStation
local activeOtrubMode
local ConsciousnessSleepyStation
local AltRemDyingStation
local ItsHopelessStation
local ITS_HOPELESS_LOOP_START = 5
local ITS_HOPELESS_LOOP_END_TRIM = 12
local hg_dyingpulse = CreateClientConVar("hg_dyingpulse", "1", true, false, "Detect peaks for screen shake when dying", 0, 1)
local hg_laivlik = CreateClientConVar("hg_laivlik", "1", true, false, "Show black square on skull destruction: 0=off, 1=on", 0, 1)
local hg_damage_corner_distortion = CreateClientConVar("hg_damage_corner_distortion", "1", true, false, "Distort screen corners from pain and head trauma", 0, 1)
local snd_musicvolume = GetConVar("snd_musicvolume")
local hook_Run = hook.Run
local drawFinalVitalsVignettes
hook.Add("RenderScreenspaceEffects", "homigrad", function()
	tab["$pp_colour_brightness"] = 0
	tab["$pp_colour_contrast"] = 1
	tab["$pp_colour_colour"] = 1
	tab["$pp_colour_addr"] = 0
	tab["$pp_colour_addg"] = 0
	tab["$pp_colour_addb"] = 0
	tab["$pp_colour_mulr"] = 0
	tab["$pp_colour_mulg"] = 0
	tab["$pp_colour_mulb"] = 0
	--//if potatopc:GetInt() >= 1 then return end
	hook_Run("Post Processing")
	--//DrawSunEffect()
	for _, layer in ipairs(layers_name) do
		layer = layers[layer]
		local weight = layer.weight
		--for k, v in pairs(layer) do
			--if k == "weight" then continue end
		addtiveLayer["brightness"] = Lerp(weight, 0, layer["brightness"] or 0)
		--end
	end

	--//DrawBloom(addtiveLayer.bloom_darken, addtiveLayer.bloom_mul, addtiveLayer.bloom_sizex, addtiveLayer.bloom_sizey, addtiveLayer.bloom_passes, addtiveLayer.bloom_colormul, addtiveLayer.bloom_colorr, addtiveLayer.bloom_colorg, addtiveLayer.bloom_colorb)
	--//DrawSharpen(addtiveLayer.sharpen, addtiveLayer.sharpen_dist)
	--//if not brain_motionblur then DrawMotionBlur(addtiveLayer.blur_addalpha, addtiveLayer.blur_drawalpha, addtiveLayer.blur_delay) end
	--//DrawToyTown(addtiveLayer.toytown, addtiveLayer.toytown_h * ScrH())
	tab["$pp_colour_brightness"] = addtiveLayer.brightness
	if math.abs(addtiveLayer.brightness) > 0.001 then DrawColorModify(tab) end

	hook_Run("Post Pre Post Processing")

	hook_Run("Post Post Processing")

	hook_Run("Post Post Pre Post Processing")

	-- Keep the vital-state borders above every motion-blur pass, including the
	-- organism effects dispatched by the hook immediately above.
	if drawFinalVitalsVignettes then drawFinalVitalsVignettes() end
end)

local postprs = hg.postprocess
postprs.LayerAdd("main", {
	bloom_darken = 0.64,
	bloom_mul = 0.5,
	bloom_sizex = 4,
	bloom_sizey = 4,
	bloom_passes = 2,
	bloom_colormul = 1,
	bloom_colorr = 1,
	bloom_colorg = 1,
	bloom_colorb = 1
})

postprs.LayerAdd("water", {
	bloom_darken = 0.15,
	bloom_mul = 1,
	bloom_sizex = 30,
	bloom_sizey = 30,
	bloom_passes = 2,
	bloom_colormul = 1,
	bloom_colorr = 0.05,
	bloom_colorg = 0.5,
	bloom_colorb = 1,
	blur_addalpha = 0.1,
	blur_drawalpha = 0.5,
	blur_delay = 0.01
})

postprs.LayerAdd("water2", {
	toytown = 6,
	toytown_h = 4
})

postprs.LayerAdd("water3", {
	brightness = -0.5
})

local oldWaterLevel, lastWater = 0, 0
local LayerWeight = postprs.LayerWeight
local LayerSetWeight = postprs.LayerSetWeight
local CurTime = CurTime
local timecheck = CurTime()
hook.Add("Post Processing", "Main", function()
	//if potatopc:GetInt() >= 1 then return end
	//if !lply:Alive() then return end
	local ply = lply:Alive() and lply or lply:GetNWEntity("spect")
	if !IsValid(ply) then return end
	local waterLevel = oldWaterLevel
	if timecheck < CurTime() then
		local pos = hg.eye(lply)
		
		if !pos then return end

		waterLevel = (ply:WaterLevel() == 3) or ((ply:WaterLevel() > 1) and bit.band(util.PointContents(pos), CONTENTS_WATER) == CONTENTS_WATER)//lply:WaterLevel()

		timecheck = CurTime() + 0.1
	end

	local time = CurTime()

	if oldWaterLevel ~= waterLevel and waterLevel then
		lastWater = time + 2
	end

	local animpos = lastWater - time
	if animpos > 0 then
		LayerSetWeight("water3", animpos)
	else
		LayerSetWeight("water3", 0)
	end

	if waterLevel then
		LayerWeight("main", 0.1, 0)
		LayerWeight("water", 0.1, 1)
		LayerWeight("water2", 0.1, 1)
	else
		LayerWeight("main", 0.5, 1)
		LayerWeight("water", 0.5, 0)
		LayerWeight("water2", 0.01, 0)
	end

	oldWaterLevel = waterLevel

	DrawSunEffect()
end)

local pickupHaloRadius = 72
local haloents = {
	["attachment_base"] = true,
	["ammo_base"] = true,
	["armor_base"] = true,
	["hg_flashlight"] = true,
	["homigrad_base"] = true,
	["weapon_melee"] = true,
	["weapon_bandage_sh"] = true,
	["hg_sling"] = true,
	["hg_brassknuckles"] = true,
	["weapon_m4super"] = true,
	["weapon_revolver2"] = true,
	["weapon_hg_f1_tpik"] = true
}

local pickupHaloClasses = {
	["ent_hg_bugbait"] = true,
	["ent_hg_emptymag"] = true,
	["ent_hg_grenade"] = true,
	["ent_hg_jam"] = true,
	["ent_hg_magazine"] = true,
	["ent_hg_molotov"] = true,
	["ent_hg_slam"] = true,
	["ent_hg_smokenade"] = true,
	["ent_hg_snowball"] = true,
	["ent_throwable"] = true
}

local pickupHaloLevels = setmetatable({}, {__mode = "k"})
local pickupHaloSeen = setmetatable({}, {__mode = "k"})
local function CanPickupHalo(ent)
	if not IsValid(ent) then return false end
	if ent:IsNPC() or ent:IsPlayer() or ent:IsWorld() then return false end
	if ent:GetNoDraw() then return false end
	if ent:IsWeapon() then return not IsValid(ent:GetOwner()) end
	if ent.IsZPickup then return true end
	if ent.Throwable then return true end
	if haloents[ent.Base] or haloents[ent:GetClass()] then return true end
	if pickupHaloClasses[ent.Base] or pickupHaloClasses[ent:GetClass()] then return true end
	return false
end

hook.Add( "PreDrawHalos", "AddPropHalos", function()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return end

	table.Empty(pickupHaloSeen)

	local frameLerp = math.min(FrameTime() * 8, 1)
	local plyPos = ply:GetPos()

	for _, ent in ipairs(ents.FindInSphere(plyPos, pickupHaloRadius)) do
		if CanPickupHalo(ent) then
			pickupHaloSeen[ent] = true

			local dist = plyPos:Distance(ent:GetPos())
			local target = math.Clamp(1 - dist / pickupHaloRadius, 0, 1)

			local level = Lerp(frameLerp, pickupHaloLevels[ent] or 0, target)
			pickupHaloLevels[ent] = level

			if level > 0.01 then
				local brightness = math.floor(255 * level)
				halo.Add({ent}, Color(brightness, brightness, brightness, 255), 1, 1, 1)
			end
		end
	end

	for ent, level in pairs(pickupHaloLevels) do
		if not pickupHaloSeen[ent] then
			level = Lerp(frameLerp, level, 0)
			pickupHaloLevels[ent] = level > 0.01 and level or nil
		end
	end
end )

-- funny :)

--that one furry game


painMat = Material("effects/shaders/zb_grain")
noiseMat = Material("effects/shaders/zb_grainwhite")
vignetteMat = Material("effects/shaders/zb_vignette")
assimilationMat = Material("effects/shaders/zb_assimilation")
coldMat = Material("effects/shaders/zb_colda")
grainMat = Material("effects/shaders/zb_grain2")
heatMat = Material("effects/shaders/zb_heat")
chromaticMat = Material("effects/shaders/merc_chromaticaberration")
blindMat = Material("effects/shaders/zb_blind")
zombMat = grainMat -- Material("effects/shaders/zb_zomb")
hurtoverlay = Material("zcity/neurotrauma/damageOverlay.png")

local PainLerp = 0
local painThresholdIntensityLerp = 1
local PanicAttackLerp = 0
local PanicStationVolume = 0
local O2Lerp = 0
local dyingAudioFade = 0
local ischemicVignetteLerp = 0
local assimilatedLerp = 0
local tempLerp = 36.6
local brainFrontalLerp = 0
local brainParietalLerp = 0
local brainTemporalLerp = 0
local brainOccipitalLerp = 0
local brainHemorrhageLerp = 0
local CardioLerp = 0
local brainFrontalColor = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}

PainLerp = 0
PanicAttackLerp = 0
O2Lerp = 0
dyingAudioFade = 0
ischemicVignetteLerp = 0
AnalgesiaLerp = 0
assimilatedLerp = 0
tempLerp = 36.6
headtraumaSaturation = 0
suicideLerp = 0
suicideViewAng = Angle()
addtime = CurTime()
show_image_time = 0
show_some_images_time = 0
lobotomy_index = 0
disorientationFxLerp = 0
adrenalineVisualLerp = 0
lastDisorientationFx = 0
lastConcussionFx = 0
nextNeuroTinnitus = 0
nextPanicAttackShake = 0
lobotomy_mats = {
	[1] = Material("overlays/photopsiaoverlay1.png"),
	[2] = Material("overlays/photopsiaoverlay2.png"),
	[3] = Material("overlays/photopsiaoverlay3.png"),
	[4] = Material("overlays/photopsiaoverlay4.png"),
	[5] = Material("overlays/peripheralorboverlay.png"),
	[6] = Material("overlays/tallflash1.png"),
	[7] = Material("overlays/tallflash2.png"),
	[8] = Material("overlays/tallflash3.png")
}

local consciousnessTypeBeatVolume = 0.18
local dying2Volume = 0.4
local alternateDyingForegroundVolume = 0.6
-- sonimcooked is the solo foreground track for hg_dyingsound 7. Its source
-- file is quieter than the other dying tracks, so give it a higher ceiling.
local sonimCookedForegroundVolume = 1
local alternateDyingBackgroundVolume = 0.34
local alternateDyingBackgroundMul = 0.42
local painBeatOverlayPath = "sound/rem_pain.mp3"
local panicattackOverlayPath = "sound/rem_panicattack.mp3"
local panicattackFadeStart = 0
local panicattackThreshold = 0.55
local panicattackVolumeMul = 1
local panicattackVisualExponent = 1.75
local panicattackPulseFloor = 0.78
local panicattackPulseIntensity = 0.2
local panicattackShakeIntervalMin = 0.45
local panicattackShakeIntervalMax = 1.4
local panicattackShakeMul = 0.85
local function getPanicAttackFx(org)
	local panicConVar = GetConVar("hg_panic")
	if panicConVar and not panicConVar:GetBool() then return 0 end
	local panic = math.Clamp(tonumber(org.panicattack) or 0, 0, 1)
	local intensity = math.Clamp(math.Remap(panic, panicattackFadeStart, panicattackThreshold, 0, panicattackVolumeMul), 0, 1)
	if org.otrub or org.incapacitated then return intensity * 0.22 end
	return intensity
end
local painBeatOverlayVolumeMul = 1.25
local painThresholdMax = 120
local painAgonyThreshold = 60
local painExcruciatingThreshold = 85
local painAgonyVolumeMul = 1.15
local painExcruciatingVolumeMul = 0.85
local painLayerFadeLerp = 0.06
local painPitchMax = 150
local painEffectIntensity = 0.8
local unconsciousPainEffectIntensity = 1.55
local painPulseIntensity = 0.25
local painRapidShakeThreshold = 95
hg.screeneffects_config = {
	consciousnessTypeBeatVolume = consciousnessTypeBeatVolume,
	dying2Volume = dying2Volume,
	alternateDyingForegroundVolume = alternateDyingForegroundVolume,
	sonimCookedForegroundVolume = sonimCookedForegroundVolume,
	alternateDyingBackgroundVolume = alternateDyingBackgroundVolume,
	alternateDyingBackgroundMul = alternateDyingBackgroundMul,
	painBeatOverlayPath = painBeatOverlayPath,
	panicattackOverlayPath = panicattackOverlayPath,
	panicattackVisualExponent = panicattackVisualExponent,
	panicattackPulseFloor = panicattackPulseFloor,
	panicattackPulseIntensity = panicattackPulseIntensity,
	panicattackShakeIntervalMin = panicattackShakeIntervalMin,
	panicattackShakeIntervalMax = panicattackShakeIntervalMax,
	panicattackShakeMul = panicattackShakeMul,
	painBeatOverlayVolumeMul = painBeatOverlayVolumeMul,
	painThresholdMax = painThresholdMax,
	painAgonyThreshold = painAgonyThreshold,
	painExcruciatingThreshold = painExcruciatingThreshold,
	painAgonyVolumeMul = painAgonyVolumeMul,
	painExcruciatingVolumeMul = painExcruciatingVolumeMul,
	painPitchMax = painPitchMax,
	itsHopelessLoopStart = ITS_HOPELESS_LOOP_START,
	itsHopelessLoopEndTrim = ITS_HOPELESS_LOOP_END_TRIM,
}
local hiddenPainFlickerSeverity = 0
local hiddenPainFlickerStart = 0
local hiddenPainFlickerAttackEnd = 0
local hiddenPainFlickerEnd = 0
local hiddenPainFlickerPeak = 0
local hiddenPainNextFlicker = 0
local function getPainLayerBlend(pain, threshold)
	if pain < threshold then return 0 end
	return math.Clamp(math.Remap(pain, threshold, painThresholdMax, 0.2, 1), 0, 1)
end
local hiddenPainColor = {
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}
local PainStationLoading = false
local PanicStationLoading = false
local PainStationOverlayLoading = false
local RemAgonyStationLoading = false
local RemExcruciatingPainStationLoading = false
local AssimilationStationLoading = false
local BrainTraumaStationLoading = false
local TinnitusLoading = false
local NoiseStationLoading = false
local NoiseStation2Loading = false
local NoiseStation2DyingLoading = false

local function isRapidPainShakeActive(org)
	return not org.otrub and (org.pain or 0) > painRapidShakeThreshold
end

local function getPainPulse(org)
	if isRapidPainShakeActive(org) then return 0 end

	return math.ease.InOutSine(math.abs(math.cos(CurTime() * 2))) * PainLerp * (org.otrub and 0.5 or painPulseIntensity)
end

local seizureSoundPath = "sound/rem_seizure.mp3"
local seizureIntroDuration = 3
local seizureFlashDelayMin = 0.12
local seizureFlashDelayMax = 0.55
local seizureFlashDurationMin = 0.35
local seizureFlashDurationMax = 1.1
local seizureFlashSizeMin = 9000
local seizureFlashSizeMax = 18000
local seizureFinalFlashLead = 2
local seizureFinalFlashDuration = 5
local seizureFinalFlashSize = 90000
local seizureSoundVolume = 1
local seizureIntroTab = {
	["$pp_colour_addr"] = 0,
	["$pp_colour_addg"] = 0,
	["$pp_colour_addb"] = 0,
	["$pp_colour_brightness"] = 0,
	["$pp_colour_contrast"] = 1,
	["$pp_colour_colour"] = 1,
	["$pp_colour_mulr"] = 0,
	["$pp_colour_mulg"] = 0,
	["$pp_colour_mulb"] = 0
}
local seizureChromatic = Material("effects/shaders/merc_chromaticaberration")
local SeizureStationLoading = false
local seizureAudioGeneration = 0
local seizureClientActive = false
local seizureClientStart = 0
local seizureClientEnd = 0
local nextSeizureFlash = 0
local nextSeizureCamShake = 0
local seizureFinalFlashFired = false
local seizureMidazolamFadeEnd = 0
local seizureMidazolamFadeDuration = 15

function REM_MidazolamSeizureFade(time)
	seizureMidazolamFadeDuration = time or 15
	seizureMidazolamFadeEnd = CurTime() + seizureMidazolamFadeDuration
end

local function stopSeizureEffects()
	if not seizureClientActive and not IsValid(SeizureStation) then return end

	seizureClientActive = false
	seizureClientStart = 0
	seizureClientEnd = 0
	nextSeizureFlash = 0
	nextSeizureCamShake = 0
	seizureFinalFlashFired = false

	if IsValid(SeizureStation) then
		SeizureStation:Stop()
		SeizureStation = nil
	end
end

local function addSeizureFlash(isFinal)
	if not hg.AddFlash then return end

	local view = render.GetViewSetup(true)
	local pos = view.origin + view.angles:Forward() * math.Rand(isFinal and 140 or 120, isFinal and 220 or 210) + view.angles:Right() * math.Rand(isFinal and -45 or -110, isFinal and 45 or 110) + view.angles:Up() * math.Rand(isFinal and -45 or -80, isFinal and 45 or 80)
	local time = isFinal and seizureFinalFlashDuration or math.Rand(seizureFlashDurationMin, seizureFlashDurationMax)
	local size = isFinal and seizureFinalFlashSize or math.Rand(seizureFlashSizeMin, seizureFlashSizeMax)

	hg.AddFlash(view.origin, 1, pos, time, size)
end

local function updateSeizureEffects(org)
	-- Unconscious players should not receive the seizure's flashing, camera
	-- punches, or audio. Stop an already-playing station immediately as otrub
	-- can begin after the seizure effect has started.
	if org.otrub then
		stopSeizureEffects()
		return
	end

	if org.seizureActive and (org.seizureStart or 0) > 0 and (org.seizureEnd or 0) > CurTime() then
		if not seizureClientActive or seizureClientStart != org.seizureStart or seizureClientEnd != org.seizureEnd then
			seizureClientActive = true
			seizureClientStart = org.seizureStart
			seizureClientEnd = org.seizureEnd
			nextSeizureFlash = math.max(seizureClientStart + seizureIntroDuration, CurTime() + seizureIntroDuration)
			nextSeizureCamShake = CurTime()
			seizureFinalFlashFired = false
		end

		if canRetrySound("SeizureStation", SeizureStation) then
			local seizureDuration = math.max(seizureClientEnd - seizureClientStart, 0.001)
			local seizureTimeline = math.Clamp((CurTime() - seizureClientStart) / seizureDuration, 0, 1)
			sound.PlayFile(seizureSoundPath, "noblock noplay", function(station)
				if IsValid(station) then
					local currentPlayer = LocalPlayer()
					if not seizureClientActive or (IsValid(currentPlayer) and currentPlayer.organism and currentPlayer.organism.otrub) then
						station:Stop()
						return
					end

					station:SetVolume(0)
					station:Play()
					station:SetTime(seizureTimeline * station:GetLength())
					station:EnableLooping(true)
					SeizureStation = station
				end
			end)
		end

		if IsValid(SeizureStation) then
			local midazolamFade = seizureMidazolamFadeEnd > CurTime() and math.Clamp((seizureMidazolamFadeEnd - CurTime()) / seizureMidazolamFadeDuration, 0, 1) or 1
			SeizureStation:SetVolume((org.otrub and seizureSoundOtrubVolume or seizureSoundVolume) * midazolamFade)
			SeizureStation:SetPlaybackRate(org.otrub and seizureSoundOtrubPlaybackRate or 1)
		end

		local seizureElapsed = math.max(CurTime() - seizureClientStart, 0)
		if seizureElapsed < seizureIntroDuration then
			local intensity = math.min(seizureElapsed, seizureIntroDuration)
			seizureIntroTab["$pp_colour_contrast"] = intensity / 2
			seizureIntroTab["$pp_colour_addr"] = intensity / 10
			seizureIntroTab["$pp_colour_brightness"] = intensity / 10
			DrawColorModify(seizureIntroTab)
			DrawBloom(0.65, intensity * 4, 9, 9, 1, 1, intensity / 16, 0.2, 0.2)

			render.UpdateScreenEffectTexture()
			chromaticMat:SetFloat("$c0_x", 3.5 - intensity)
			chromaticMat:SetInt("$c0_y", 1)
			render.SetMaterial(chromaticMat)
			render.DrawScreenQuad()
		end

		if seizureElapsed >= seizureIntroDuration and CurTime() >= nextSeizureFlash then
			addSeizureFlash(false)
			nextSeizureFlash = CurTime() + math.Rand(seizureFlashDelayMin, seizureFlashDelayMax)
		end

		if CurTime() >= nextSeizureCamShake then
			ViewPunch(Angle(math.Rand(-1.25, 1.25), math.Rand(-1.4, 1.4), math.Rand(-0.45, 0.45)))
			ViewPunch2(Angle(math.Rand(-0.55, 0.55), math.Rand(-0.8, 0.8), math.Rand(-0.7, 0.7)))
			nextSeizureCamShake = CurTime() + math.Rand(0.025, 0.06)
		end

		if not seizureFinalFlashFired and CurTime() >= seizureClientEnd - seizureFinalFlashLead then
			addSeizureFlash(true)
			seizureFinalFlashFired = true
		end
	else
		stopSeizureEffects()
	end
end

local function stopthings()
	PainLerp = 0
	painThresholdIntensityLerp = 1
	PanicAttackLerp = 0
	PanicStationVolume = 0
	O2Lerp = 0
	AnalgesiaLerp = 0
	shockLerp = 0
	assimilatedLerp = 0
	tempLerp = 36.6
	headtraumaSaturation = 0
	consciousnessLerp = 1
	brainFrontalLerp = 0
	brainParietalLerp = 0
	brainTemporalLerp = 0
	brainOccipitalLerp = 0
	brainHemorrhageLerp = 0
	CardioLerp = 0

	lply.tinnitus = 0
	nextPanicAttackShake = 0
	stopSeizureEffects()
	
	if IsValid(PainStation) then
		PainStation:Stop()
		PainStation = nil
	end

	if IsValid(PainStationOverlay) then
		PainStationOverlay:Stop()
		PainStationOverlay = nil
	end

	if IsValid(NoiseStation) then
		NoiseStation:Stop()
		NoiseStation = nil
	end

	if IsValid(NoiseStation2) then
		NoiseStation2:Stop()
		NoiseStation2 = nil
	end

	if IsValid(NoiseStation2Dying) then
		NoiseStation2Dying:Stop()
		NoiseStation2Dying = nil
	end

	if IsValid(PainStationOverlay) then
		PainStationOverlay:Stop()
		PainStationOverlay = nil
	end

	if IsValid(BrainTraumaStation) then
		BrainTraumaStation:Stop()
		BrainTraumaStation = nil
	end

	if IsValid(BrainTraumaStation2) then
		BrainTraumaStation2:Stop()
		BrainTraumaStation2 = nil
	end

	if IsValid(BrainTraumaStation3) then
		BrainTraumaStation3:Stop()
		BrainTraumaStation3 = nil
	end

	if IsValid(BrainTraumaStation4) then
		BrainTraumaStation4:Stop()
		BrainTraumaStation4 = nil
	end

	if IsValid(BrainTraumaStation5) then
		BrainTraumaStation5:Stop()
		BrainTraumaStation5 = nil
	end

	if IsValid(Tinnitus) then
		Tinnitus:Stop()
		Tinnitus = nil
	end

	if IsValid(AssimilationStation) then
		AssimilationStation:Stop()
		AssimilationStation = nil
	end

	if IsValid(RealityStation) then
		RealityStation:Stop()
		RealityStation = nil
	end

	if IsValid(AgonyStation) then
		AgonyStation:Stop()
		AgonyStation = nil
	end

	if IsValid(AltpainStation) then
		AltpainStation:Stop()
		AltpainStation = nil
	end

	if IsValid(RemAgonyStation) then
		RemAgonyStation:Stop()
		RemAgonyStation = nil
	end

	if IsValid(RemExcruciatingPainStation) then
		RemExcruciatingPainStation:Stop()
		RemExcruciatingPainStation = nil
	end

	if IsValid(SillypainStation) then
		SillypainStation:Stop()
		SillypainStation = nil
	end

	if IsValid(DyingStation) then
		DyingStation:Stop()
		DyingStation = nil
	end

	if IsValid(RemDying1Station) then
		RemDying1Station:Stop()
		RemDying1Station = nil
	end
	if IsValid(AltRemDyingStation) then
		AltRemDyingStation:Stop()
		AltRemDyingStation = nil
	end
	if IsValid(ItsHopelessStation) then
		ItsHopelessStation:Stop()
		ItsHopelessStation = nil
	end

	if IsValid(SillydyingStation) then
		SillydyingStation:Stop()
		SillydyingStation = nil
	end

	if IsValid(PanicStation) then
		PanicStation:Stop()
		PanicStation = nil
	end

	if IsValid(ItssooverStation) then
		ItssooverStation:Stop()
		ItssooverStation = nil
	end

	if IsValid(SonimCookedStation) then
		SonimCookedStation:Stop()
		SonimCookedStation = nil
	end

	if IsValid(OtrubModeStation) then
		OtrubModeStation:Stop()
		OtrubModeStation = nil
	end
	activeOtrubMode = nil

	if IsValid(NoisesStation) then
		NoisesStation:Stop()
		NoisesStation = nil
	end

	if IsValid(ConsciousnessSleepyStation) then
		ConsciousnessSleepyStation:Stop()
		ConsciousnessSleepyStation = nil
	end

	if IsValid(EndStation) then
		EndStation:Stop()
		EndStation = nil
	end
	if IsValid(Alto2Station) then
		Alto2Station:Stop()
		Alto2Station = nil
	end

	suicideLerp = 0

end

local stations = {
	0.06,
	0.1,
	0.15,
	0.22,
	0.27,
}

local choosera = 1
local tempolerp = 0
local grayscaleLerp = 0
local soundRetry = {}

drawFinalVitalsVignettes = function()
	if not IsValid(lply) or not lply:Alive() then return end
	if IsValid(lply:GetNWEntity("spect")) then return end

	local org = lply.new_organism or lply.organism
	if not org or not org.brain or not org.o2 or not isnumber(org.o2[1]) or not org.analgesia then return end
	local excruciatingBlend = getServerSoundMode("hg_painsound", 6) == 6
		and getPainLayerBlend(org.pain or 0, painExcruciatingThreshold)
		or 0
	painThresholdIntensityLerp = LerpFT(painLayerFadeLerp, painThresholdIntensityLerp or 1, 1 + excruciatingBlend * painEffectIntensity)

	if (PainLerp > 0.001 or shockLerp > 5) or org.otrub then
		local strobe = getPainPulse(org)
		local pain = (PainLerp + strobe) * painThresholdIntensityLerp
		local shock = shockLerp

		render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", org.otrub and 1 or (pain / 40 + math.max(shock - 5, 0) / 6))
		vignetteMat:SetFloat("$c1_y", org.otrub and 5 or (pain / 40 + math.max(shock - 5, 0) / 6))
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()
		painMat:SetFloat("$c2_x", CurTime() + 10000)
		painMat:SetFloat("$c0_y", 0.3)
		painMat:SetFloat("$c0_z", 1)
		painMat:SetFloat("$c1_x", math.Clamp(pain / 90, 0, 0.75))
		painMat:SetFloat("$c1_y", math.Clamp(pain / 90, 0, 0.75))
		render.SetMaterial(painMat)
		render.DrawScreenQuad()
	end

	if O2Lerp > 1 then
		local o2 = O2Lerp

		render.UpdateScreenEffectTexture()
		noiseMat:SetFloat("$c0_y", 1 - o2 / 200)
		noiseMat:SetFloat("$c0_z", 1)
		noiseMat:SetFloat("$c1_x", math.Clamp(o2 / 200, 0, 2))
		noiseMat:SetFloat("$c1_y", o2 * (not org.otrub and 0.05 or 1))
		noiseMat:SetFloat("$c2_x", CurTime() + 10000)
		render.SetMaterial(noiseMat)
		render.DrawScreenQuad()
	end
end

function canRetrySound(key, station)
	if IsValid(station) and station:GetState() == GMOD_CHANNEL_PLAYING then return false end
	local nextTry = soundRetry[key] or 0
	if CurTime() < nextTry then return false end
	soundRetry[key] = CurTime() + 2.5
	return true
end
hook.Add("Post Post Processing", "ItHurts", function()
	if not IsValid(lply) then return end
	if IsValid(lply:GetNWEntity("spect")) then
		stopthings()
		tab["$pp_colour_brightness"] = 0
		tab["$pp_colour_contrast"] = 1
		tab["$pp_colour_colour"] = 1
		return
	end
	if not lply:Alive() then
		stopthings()
		tab["$pp_colour_brightness"] = 0
		tab["$pp_colour_contrast"] = 1
		tab["$pp_colour_colour"] = 1
		return
	end

	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	local painVolume = 0
	local normalizedPain = 0
	
	if IsValid(PainStation) then
		PainStation:SetVolume(0)
	end
	if IsValid(PainStationOverlay) then
		PainStationOverlay:SetVolume(0)
	end
	if IsValid(RealityStation) then
		RealityStation:SetVolume(0)
	end
	if IsValid(AgonyStation) then
		AgonyStation:SetVolume(0)
	end
	if IsValid(AltpainStation) then
		AltpainStation:SetVolume(0)
	end
	if IsValid(RemAgonyStation) then
		RemAgonyStation:SetVolume(0)
	end
	if IsValid(RemExcruciatingPainStation) then
		RemExcruciatingPainStation:SetVolume(0)
	end
	if IsValid(SillypainStation) then
		SillypainStation:SetVolume(0)
	end
	
	if !lply:Alive() and !IsValid(spect) then stopthings() return end
	if !lply:Alive() and viewmode != 1 then stopthings() return end
	local organism = lply:Alive() and (lply.new_organism or lply.organism) or (IsValid(spect) and (spect.new_organism or spect.organism))
	if not organism then stopthings() return end
	if not organism.brain then stopthings() return end
	local org = organism
	local deathStateEnd = tonumber(org.deathStateEnd)
	local incapacitated = org.otrub and org.incapacitated and deathStateEnd and deathStateEnd > CurTime()
	local incapacitationProgress = incapacitated and math.Clamp((25 - (deathStateEnd - CurTime())) / 25, 0, 1) or 0
	local sensoryActive = not org.otrub or incapacitated
	local sensoryMix = incapacitated and Lerp(incapacitationProgress, 1, 0.35) or 1

    -- Concussion and low blood blur
    local blurAmount = 0
    if sensoryActive and org.concussion and org.concussion > 2 then
        blurAmount = math.min((org.concussion - 2) / 8, 1) * 4 * sensoryMix
    end

    if sensoryActive and org.blood and org.blood < 4000 then
        blurAmount = math.max(blurAmount, math.min((4000 - org.blood) / 3500, 1) * 5 * sensoryMix)
    end

    local adrenaline = org.adrenaline or 0
    local adrenalineIntensity = math.Clamp((adrenaline - 1) / 1.5, 0, 1)
    if adrenalineIntensity > 0 and sensoryActive then
		-- A sustained surge should feel increasingly disorienting instead of
		-- jumping straight to its final visual strength.
		adrenalineVisualLerp = math.Approach(adrenalineVisualLerp, 1, FrameTime() * (0.08 + adrenalineIntensity * 0.22))
		local adrenalineShock = adrenalineIntensity * (0.35 + adrenalineVisualLerp * 2.65) * sensoryMix
		blurAmount = math.max(blurAmount, adrenalineShock * 1.5)

		if not (lply:IsBerserk() or lply:IsStimulated()) then
            render.UpdateScreenEffectTexture()
            heatMat:SetFloat("$c0_x", -CurTime() * 0.18)
            heatMat:SetFloat("$c0_y", adrenalineShock * 0.01)
            heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.75) - 1.5) * (adrenalineShock * 0.1))
            render.SetMaterial(heatMat)
            render.DrawScreenQuad()
		end
		render.UpdateScreenEffectTexture()
		chromaticMat:SetFloat("$c0_x", adrenalineShock * (0.18 + math.abs(math.sin(CurTime() * 5)) * 0.08))
		chromaticMat:SetInt("$c0_y", 1)
		render.SetMaterial(chromaticMat)
		render.DrawScreenQuad()
		render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", adrenalineShock * 0.6)
		vignetteMat:SetFloat("$c1_y", adrenalineShock * 0.8)
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()
	else
		adrenalineVisualLerp = math.Approach(adrenalineVisualLerp, 0, FrameTime() * 0.45)
    end

    if blurAmount > 0 then
        DrawToyTown(blurAmount, ScrH() / 2)
    end

	local blindness = org.blindness
	if blindness ~= nil or amtflashed >= 0.8 then
		local eyesmode = amtflashed >= 0.8 and 0 or (blindness ~= nil and math.Round(blindness) or 0)

		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()

		blindMat:SetFloat("$c0_x", 5)
		blindMat:SetFloat("$c0_y", CurTime())
		blindMat:SetFloat("$c0_z", eyesmode)

		render.SetMaterial(blindMat)
		render.DrawScreenQuad()
	end

	if (org.consciousness < 0.7) then
		-- Reach full black only at the server's standard OTRUB consciousness threshold.
		lerpblood = LerpFT(0.01, lerpblood or 0, math.Clamp(math.Remap(org.consciousness, 0.7, 0.3, 0, 1), 0, 1) * 255)
		local lowblood = (3600 - (org.blood or 5000)) / 600

		addtime = addtime + FrameTime() / 6
		local amt = (math.cos(addtime) + math.sin(addtime * 3) + math.sin(addtime * 2)) / 90
		local amt2 = (math.sin(addtime) + math.cos(addtime * 5) + math.sin(addtime * 6)) / 90
		local mat = Matrix({
			{1 - amt, amt, 0, -amt2 / 2},
			{amt2, 1 - amt2, 0, -amt / 2},
			{0, 0, 1, 0},
			{0, 0, 0, 1},
		})
		hurtoverlay:SetMatrix("$basetexturetransform", mat)
		surface.SetMaterial(hurtoverlay)
		surface.SetDrawColor(0, 0, 0, lerpblood)
		surface.DrawRect(0, 0, ScrW(), ScrH())
		//ViewPunch(Angle(-amt * 1, amt2 * 1,0))
		//ViewPunch2(Angle(-amt * 1, amt2 * 1,0))
	end
	
	local painMode = getServerSoundMode("hg_painsound", 6)

	if not PainStationLoading and canRetrySound("PainStation", PainStation) then
		PainStationLoading = true
		sound.PlayFile("sound/zbattle/pain_beat.mp3", "noblock noplay", function(station)
			PainStationLoading = false
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				PainStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if painMode == 6 and not PainStationOverlayLoading and canRetrySound("PainStationOverlay", PainStationOverlay) then
		PainStationOverlayLoading = true
		sound.PlayFile(hg.screeneffects_config.painBeatOverlayPath, "noblock noplay", function(station)
			PainStationOverlayLoading = false
			if IsValid(station) then
				if getServerSoundMode("hg_painsound", 6) != 6 then
					station:Stop()
					return
				end
				station:SetVolume(0)
				station:Play()
				station:SetTime(IsValid(PainStation) and PainStation:GetTime() or 0)
				PainStationOverlay = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("RealityStation", RealityStation) then
		sound.PlayFile("sound/reality.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				RealityStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("AgonyStation", AgonyStation) then
		sound.PlayFile("sound/agony.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				AgonyStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("AltpainStation", AltpainStation) then
		sound.PlayFile("sound/altpain.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				AltpainStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if painMode == 6 and not RemAgonyStationLoading and canRetrySound("RemAgonyStation", RemAgonyStation) then
		RemAgonyStationLoading = true
		sound.PlayFile("sound/rem_agony.mp3", "noblock noplay", function(station)
			RemAgonyStationLoading = false
			if IsValid(station) then
				if getServerSoundMode("hg_painsound", 6) != 6 then
					station:Stop()
					return
				end
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				RemAgonyStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if painMode == 6 and not RemExcruciatingPainStationLoading and canRetrySound("RemExcruciatingPainStation", RemExcruciatingPainStation) then
		RemExcruciatingPainStationLoading = true
		sound.PlayFile("sound/rem_excruciatingpain.mp3", "noblock noplay", function(station)
			RemExcruciatingPainStationLoading = false
			if IsValid(station) then
				if getServerSoundMode("hg_painsound", 6) != 6 then
					station:Stop()
					return
				end
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				RemExcruciatingPainStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("SillypainStation", SillypainStation) then
		sound.PlayFile("sound/sillypain.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				SillypainStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("DyingStation", DyingStation) then
		sound.PlayFile("sound/dying.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				DyingStation = station
				station:EnableLooping(true)
			end
		end)
	end

	local selectedDyingMode = getServerSoundMode("hg_dyingsound", 2)
	if selectedDyingMode == 8 and canRetrySound("RemDying1Station", RemDying1Station) then
		sound.PlayFile("sound/rem_dying1.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				RemDying1Station = station
				station:EnableLooping(true)
			end
		end)
	end

	if selectedDyingMode == 9 and canRetrySound("AltRemDyingStation", AltRemDyingStation) then
		sound.PlayFile("sound/itssofuckingover.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 119))
				AltRemDyingStation = station
				station:EnableLooping(true)
			end
		end)
	end

	-- Shared by dying mode 10 and OTRUB mode 7. Keep this channel alive at zero
	-- volume between states so losing consciousness does not restart the track.
	if canRetrySound("ItsHopelessStation", ItsHopelessStation) then
		sound.PlayFile("sound/itshopeless.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(hg.screeneffects_config.itsHopelessLoopStart)
				ItsHopelessStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if IsValid(ItsHopelessStation) then
		local trackLength = ItsHopelessStation:GetLength()
		local loopEnd = trackLength - hg.screeneffects_config.itsHopelessLoopEndTrim
		local playbackTime = ItsHopelessStation:GetTime()
		if loopEnd > hg.screeneffects_config.itsHopelessLoopStart and (playbackTime < hg.screeneffects_config.itsHopelessLoopStart or playbackTime >= loopEnd) then
			ItsHopelessStation:SetTime(hg.screeneffects_config.itsHopelessLoopStart)
		end
	end

	if canRetrySound("SillydyingStation", SillydyingStation) then
		sound.PlayFile("sound/sillydying.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				SillydyingStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("ItssooverStation", ItssooverStation) then
		sound.PlayFile("sound/fuck.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				ItssooverStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("SonimCookedStation", SonimCookedStation) then
		sound.PlayFile("sound/sonimcooked.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				SonimCookedStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("Alto2Station", Alto2Station) then
		sound.PlayFile("sound/alto2.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				Alto2Station = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("ConsciousnessSleepyStation", ConsciousnessSleepyStation) then
		sound.PlayFile("sound/sleepy.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				ConsciousnessSleepyStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("NoisesStation", NoisesStation) then
		sound.PlayFile("sound/noises.mp3", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				NoisesStation = station
				station:EnableLooping(true)
			end
		end)
	end

	local LerpFT = LerpFT or Lerp

	if !org or !org.o2 or !isnumber(org.o2[1]) or !org.analgesia then stopthings() return end

	brainFrontalLerp = LerpFT(0.025, brainFrontalLerp, org.brainFrontal or 0)
	brainParietalLerp = LerpFT(0.025, brainParietalLerp, org.brainParietal or 0)
	brainTemporalLerp = LerpFT(0.025, brainTemporalLerp, org.brainTemporal or 0)
	brainOccipitalLerp = LerpFT(0.025, brainOccipitalLerp, org.brainOccipital or 0)
	brainHemorrhageLerp = LerpFT(0.02, brainHemorrhageLerp, org.brainHemorrhage or 0)
	CardioLerp = LerpFT(0.025, CardioLerp, math.max(org.hypotension or 0, (1 - (org.myocardialOxygen or 1)) * 0.9, (org.arrhythmia or 0) * 0.35, org.fibrillation and 0.85 or 0))

	local o2 = org.o2[1] or 0
	o2 = o2 + (org.CO or 0)
	local brain = org.brain or 0
	O2Lerp = LerpFT(0.01, O2Lerp, (30 - o2) * (org.otrub and 2 or 10) + (brain * 100) * (org.otrub and 1 or 5))
	updateSeizureEffects(org)

	local panicBaseTarget = getPanicAttackFx(org)
	PanicAttackLerp = LerpFT(0.03, PanicAttackLerp, panicBaseTarget ^ hg.screeneffects_config.panicattackVisualExponent)
	local panicDying = org.otrub or org.incapacitated
	if PanicAttackLerp > 0.001 then
		local panicBase = PanicAttackLerp
		local panicPulse = panicDying and 0 or panicBase * (hg.screeneffects_config.panicattackPulseFloor + math.ease.InOutSine(math.abs(math.cos(CurTime() * 2))) * hg.screeneffects_config.panicattackPulseIntensity)

		render.UpdateScreenEffectTexture()
		heatMat:SetFloat("$c0_x", -CurTime() * 0.1)
		heatMat:SetFloat("$c0_y", panicBase * 0.014 + panicPulse * 0.055)
		heatMat:SetFloat("$c2_x", panicBase * 0.28 + panicPulse * 1.7)
		render.SetMaterial(heatMat)
		render.DrawScreenQuad()

		if not panicDying then
			render.UpdateScreenEffectTexture()
			render.UpdateFullScreenDepthTexture()
			grainMat:SetFloat("$c0_x", CurTime())
			grainMat:SetFloat("$c0_y", -1)
			grainMat:SetFloat("$c0_z", 1 + panicBase * 1.4)
			grainMat:SetFloat("$c1_x", panicBase * 3.2 + panicPulse * 5.8)
			grainMat:SetFloat("$c1_y", panicBase * 0.08 + panicPulse * 0.22)
			grainMat:SetFloat("$c1_z", panicBase * 0.08 + panicPulse * 0.24)
			grainMat:SetFloat("$c2_x", panicBase * 0.04 + panicPulse * 0.12)
			grainMat:SetFloat("$c2_y", 0.075 * panicBase)
			grainMat:SetFloat("$c2_z", 0)
			grainMat:SetFloat("$c3_x", 0)
			render.SetMaterial(grainMat)
			render.DrawScreenQuad()
		end

		if not panicDying and CurTime() >= nextPanicAttackShake then
			local shakeMul = (0.25 + panicBase * 0.9) * hg.screeneffects_config.panicattackShakeMul
			ViewPunch(Angle(math.Rand(-0.8, 0.6), math.Rand(-1, 1), math.Rand(-0.2, 0.2)) * shakeMul)
			ViewPunch2(Angle(math.Rand(-0.25, 0.35), math.Rand(-0.55, 0.55), math.Rand(-0.4, 0.4)) * shakeMul)
			nextPanicAttackShake = CurTime() + math.Rand(hg.screeneffects_config.panicattackShakeIntervalMin, hg.screeneffects_config.panicattackShakeIntervalMax)
		end

		if not panicDying and canRetrySound("PanicStation", PanicStation) then
			sound.PlayFile(hg.screeneffects_config.panicattackOverlayPath, "noblock noplay", function(station)
				if IsValid(station) then
					station:SetVolume(0)
					station:EnableLooping(true)
					station:Play()
					PanicStation = station
				end
			end)
		end
		if IsValid(PanicStation) then
			PanicStationVolume = math.Approach(PanicStationVolume, panicDying and 0 or math.Clamp(PanicAttackLerp, 0, 1), FrameTime() * 1.8)
			PanicStation:SetVolume(PanicStationVolume)
			if PanicStationVolume <= 0.001 then
				PanicStation:Stop()
				PanicStation = nil
			end
		end
	else
		nextPanicAttackShake = 0
		if IsValid(PanicStation) then
			PanicStationVolume = math.Approach(PanicStationVolume, 0, FrameTime() * 1.8)
			PanicStation:SetVolume(PanicStationVolume)
			if PanicStationVolume <= 0.001 then
				PanicStation:Stop()
				PanicStation = nil
			end
		else
			PanicStationVolume = 0
		end
	end

	local analgesia = org.analgesia or 0
	-- Keep therapeutic analgesia visually clear. Sedation and overdose physiology
	-- are handled server-side; only the drug-screen effects wait for a full dose.
	AnalgesiaLerp = LerpFT(0.04, AnalgesiaLerp, math.Clamp((analgesia - 1) / 1.75, 0, 1))
	local rainbowFx = math.Clamp((analgesia - 1) / 1.25, 0, 1) * math.max(AnalgesiaLerp, 0.35)

	tempLerp = LerpFT(0.01, tempLerp, org.temperature)

	if AnalgesiaLerp > 0.005 and not org.otrub then
		local pulse = (math.sin(CurTime() * 1.35) + 1) * 0.5
		local drugFx = AnalgesiaLerp * (0.75 + pulse * 0.25)
		local lsdFx = math.max(math.Clamp((analgesia - 1) / 1.5, 0, 1) * drugFx, rainbowFx)

		DrawMaterialOverlay("particle/warp4_warp_noz", -drugFx * 0.045)

		if not (lply:IsBerserk() or lply:IsStimulated()) then
			render.UpdateScreenEffectTexture()
			heatMat:SetFloat("$c0_x", -CurTime() * 0.08)
			heatMat:SetFloat("$c0_y", drugFx * (0.008 + lsdFx * 0.025))
			heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.5) - 1.5) * drugFx * (0.08 + lsdFx * 0.12))
			render.SetMaterial(heatMat)
			render.DrawScreenQuad()

			render.UpdateScreenEffectTexture()
			chromaticMat:SetFloat("$c0_x", drugFx * (0.018 + lsdFx * 0.045))
			chromaticMat:SetInt("$c0_y", 1)
			render.SetMaterial(chromaticMat)
			render.DrawScreenQuad()
		end

		tab["$pp_colour_colour"] = math.max(tab["$pp_colour_colour"] or 1, 1 + drugFx * 0.45)
		tab["$pp_colour_brightness"] = (tab["$pp_colour_brightness"] or 0) + drugFx * 0.025
		tab["$pp_colour_contrast"] = math.max(tab["$pp_colour_contrast"] or 1, 1 + drugFx * 0.04)
		if lsdFx > 0.001 then
			local time = CurTime() * 1.8
			tab["$pp_colour_mulr"] = (tab["$pp_colour_mulr"] or 0) + (0.18 + math.sin(time) * 0.12) * lsdFx
			tab["$pp_colour_mulg"] = (tab["$pp_colour_mulg"] or 0) + (0.18 + math.sin(time + 2.094) * 0.12) * lsdFx
			tab["$pp_colour_mulb"] = (tab["$pp_colour_mulb"] or 0) + (0.18 + math.sin(time + 4.188) * 0.12) * lsdFx
			tab["$pp_colour_addr"] = (tab["$pp_colour_addr"] or 0) + math.max(math.sin(time), 0) * 0.035 * lsdFx
			tab["$pp_colour_addg"] = (tab["$pp_colour_addg"] or 0) + math.max(math.sin(time + 2.094), 0) * 0.035 * lsdFx
			tab["$pp_colour_addb"] = (tab["$pp_colour_addb"] or 0) + math.max(math.sin(time + 4.188), 0) * 0.035 * lsdFx
			tab["$pp_colour_brightness"] = (tab["$pp_colour_brightness"] or 0) + lsdFx * 0.03
			tab["$pp_colour_contrast"] = math.max(tab["$pp_colour_contrast"] or 1, 1 + lsdFx * 0.12)
		end
	end

	if lply.PlayerClassName == "headcrabzombie" and not org.otrub then
		render.UpdateScreenEffectTexture()

		heatMat:SetFloat("$c0_x", -CurTime() * 0.1) //time
		heatMat:SetFloat("$c0_y", 0.1) //intensity (strict)
		heatMat:SetFloat("$c2_x", 2)

		render.SetMaterial(heatMat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()
		
		zombMat:SetFloat("$c0_x", CurTime()) -- time
		zombMat:SetFloat("$c0_y", -1) -- gate
		zombMat:SetFloat("$c0_z", 1) -- Pixelize
		zombMat:SetFloat("$c1_x", 12) -- lerp
		zombMat:SetFloat("$c1_y", 0.2) -- vignette intensity
		zombMat:SetFloat("$c1_z", 0.3) -- BlurIntensity
		zombMat:SetFloat("$c2_x", 0.3) -- r
		zombMat:SetFloat("$c2_y", 0.05) -- g
		zombMat:SetFloat("$c2_z", 0) -- b
		zombMat:SetFloat("$c3_x", 0) -- ImageIntensity
	
		render.SetMaterial(zombMat)
		render.DrawScreenQuad()
	end

	if tempLerp > 38 then
		local heat = tempLerp - 38

		render.UpdateScreenEffectTexture()

		heatMat:SetFloat("$c0_x", -CurTime() * 0.25)//math.sin(CurTime() * 0.1) * CurTime() * 0.01) //time
		heatMat:SetFloat("$c0_y", 0.06 * heat)//(math.sin(CurTime()) + 1) * 2) //intensity (strict)
		heatMat:SetFloat("$c2_x", (math.sin(CurTime()) - 2) * heat)

		render.SetMaterial(heatMat)
		render.DrawScreenQuad()
	end

	local rawPain = math.max(org.pain or 0, 0)
	local pain = math.max(rawPain - 15, 0)
	local shock = (org.shock or 0) * 1 + (1 - org.consciousness) * 40
	shockLerp = LerpFT(0.01, shockLerp or 0, shock)
	consciousnessLerp = LerpFT(org.consciousness < (consciousnessLerp or 1) and 1 or 0.01, consciousnessLerp or 1, org.consciousness)
	-- local immobilization = org.immobilization
	PainLerp = LerpFT(0.05, PainLerp, math.max(pain * (org.otrub and 0.2 or 1), 0))
	assimilatedLerp = LerpFT(0.01, assimilatedLerp, (org.assimilated or 0))

	if assimilatedLerp > 0.001 then
		render.UpdateScreenEffectTexture()

		assimilationMat:SetFloat("$c0_x", -CurTime())//math.sin(CurTime() * 0.1) * CurTime() * 0.01) //time
		assimilationMat:SetFloat("$c0_y", assimilatedLerp * 3)//(math.sin(CurTime()) + 1) * 2) //intensity (strict)
		local ctime = CurTime() * 2
		local val = math.Clamp(3 - 1 / 3 * (math.sin(ctime * 2.8862) + math.cos(ctime * 1.115) - math.sin(ctime * 0.6215) + 3), 0, 5)
		local val2 = math.Clamp(1 - 1 / 6 * (math.sin(ctime * 1.1862) + math.cos(ctime * 2.315) - math.sin(ctime * 0.9215) + 3), 0, 1)
		assimilationMat:SetFloat("$c1_y", val)
		assimilationMat:SetFloat("$c1_x", val2 - 0.5)

		if canRetrySound("AssimilationStation", AssimilationStation) then
			sound.PlayFile("sound/zbattle/furry/conversion/assimilation_noise3.mp3", "noblock noplay", function(station, err)
				AssimilationStationLoading = false
				if IsValid(station) then
					station:SetVolume(0)
					station:Play()
					AssimilationStation = station
					station:EnableLooping(true)
				end
			end)
		elseif IsValid(AssimilationStation) then
			AssimilationStation:SetVolume(assimilatedLerp * 2)
			//AssimilationStation:SetPlaybackRate(assimilatedLerp * 1)
		end

		render.SetMaterial(assimilationMat)
		render.DrawScreenQuad()
	else
		if IsValid(AssimilationStation) then
			AssimilationStation:Stop()
			AssimilationStation = nil
		end
	end

	if not org.otrub and (org.consciousness or 0) < 1 then
		local consciousness = 1 - consciousnessLerp
		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()

		grainMat:SetFloat("$c0_x", CurTime()) -- time
		grainMat:SetFloat("$c0_y", 0.5) -- gate
		grainMat:SetFloat("$c0_z", consciousness * 0.4) -- Pixelize
		grainMat:SetFloat("$c1_x", consciousness * 0.3) -- lerp
		grainMat:SetFloat("$c1_y", consciousness * 2) -- vignette intensity
		grainMat:SetFloat("$c1_z", consciousness * 0.3) -- BlurIntensity
		grainMat:SetFloat("$c2_x", 0) -- r
		grainMat:SetFloat("$c2_y", 0) -- g
		grainMat:SetFloat("$c2_z", 0) -- b
		grainMat:SetFloat("$c3_x", 0) -- ImageIntensity

		render.SetMaterial(grainMat)
		render.DrawScreenQuad()
	end

	-- The sleepy OTRUB track fades in while consciousness falls, then hands off to
	-- the configured OTRUB audio once the player is unconscious.
	if not org.otrub and (org.consciousness or 1) < 0.95 then
		local consciousnessVol = math.Remap(org.consciousness, 0.95, 0.3, 0, 1)
		consciousnessVol = math.Clamp(consciousnessVol, 0, 1)

		if IsValid(ConsciousnessSleepyStation) then
			ConsciousnessSleepyStation:SetVolume(consciousnessVol * 0.333)
		end
	else
		if IsValid(ConsciousnessSleepyStation) then
			ConsciousnessSleepyStation:SetVolume(0)
		end
	end

	local tempo = math.Clamp((5 - (tempLerp - 29)) * 0.5 - 5 * (org.heartbeat < 1 and 1 or 0), 0, 5)
	tempolerp = LerpFT(0.01, tempolerp, tempo)
	
	if (tempolerp > 0) then
		render.UpdateScreenEffectTexture()

		coldMat:SetFloat("$c0_y", tempolerp)
		
		render.SetMaterial(coldMat)
		render.DrawScreenQuad()
	end

	if (PainLerp > 0.001 or shockLerp > 5) or org.otrub then
		local strobe = getPainPulse(org)
		pain = PainLerp + strobe
		shock = shockLerp

		if org.otrub then
			--DrawMotionBlur(0.1, 1., 0.01)
			lply:ScreenFade( SCREENFADE.IN, Color(0,0,0), 2, 0.5 )
		end
		
		//if pain > 10 then
			painVolume = math.Clamp(math.Remap(pain, 0, hg.screeneffects_config.painThresholdMax, 0, 2), 0, 2)
			normalizedPain = math.Clamp(pain / hg.screeneffects_config.painThresholdMax, 0, 1)
			painPitch = math.Clamp(math.Remap(normalizedPain, 0, 1, 100, hg.screeneffects_config.painPitchMax), 100, hg.screeneffects_config.painPitchMax)
			local targetPainVolume = 0
			local targetRealityVolume = 0
			local targetAgonyVolume = 0
			local targetAltpainVolume = 0
			local targetSillypainVolume = 0
			local targetRemPainVolume = 0
			local targetRemAgonyVolume = 0
			local targetRemExcruciatingVolume = 0

			if painMode == 0 then
				targetPainVolume = painVolume
				targetRealityVolume = painVolume
			elseif painMode == 1 then
				targetPainVolume = painVolume
			elseif painMode == 2 then
				targetAgonyVolume = painVolume
			elseif painMode == 3 then
				targetAltpainVolume = painVolume
			elseif painMode == 4 then
				targetRealityVolume = painVolume
			elseif painMode == 5 then
				targetSillypainVolume = painVolume
			elseif painMode == 6 then
				targetPainVolume = painVolume
				targetRemPainVolume = painVolume * hg.screeneffects_config.painBeatOverlayVolumeMul
				targetRemAgonyVolume = getPainLayerBlend(rawPain, hg.screeneffects_config.painAgonyThreshold) * painVolume * hg.screeneffects_config.painAgonyVolumeMul
				targetRemExcruciatingVolume = getPainLayerBlend(rawPain, hg.screeneffects_config.painExcruciatingThreshold) * painVolume * hg.screeneffects_config.painExcruciatingVolumeMul
			end

			if IsValid(PainStation) then
				PainStation:SetVolume(targetPainVolume)
				PainStation:SetPlaybackRate(painPitch / 100)
			end
			if IsValid(PainStationOverlay) then
				PainStationOverlay:SetVolume(targetRemPainVolume)
				PainStationOverlay:SetPlaybackRate(painPitch / 100)
			end
			if IsValid(RealityStation) then RealityStation:SetVolume(targetRealityVolume) end
			if IsValid(AgonyStation) then AgonyStation:SetVolume(targetAgonyVolume) end
			if IsValid(AltpainStation) then AltpainStation:SetVolume(targetAltpainVolume) end
			if IsValid(RemAgonyStation) then
				RemAgonyStation:SetVolume(targetRemAgonyVolume)
				RemAgonyStation:SetPlaybackRate(painPitch / 100)
			end
			if IsValid(RemExcruciatingPainStation) then
				RemExcruciatingPainStation:SetVolume(targetRemExcruciatingVolume)
				RemExcruciatingPainStation:SetPlaybackRate(painPitch / 100)
			end
			if IsValid(SillypainStation) then SillypainStation:SetVolume(targetSillypainVolume) end
		//else
		//	if IsValid(PainStation) then
		//		PainStation:Stop()
		//		PainStation = nil
		//	end
		//end
	else
		//if IsValid(PainStation) then
		//	PainStation:Stop()
		//	PainStation = nil
		//end
	end

	local brainTrauma = math.max(brain, (org.brainHemorrhage or 0) * 0.85)
	if brainTrauma > 0.01 then
		local chooser = 1
		for i, choose in ipairs(stations) do
			if choose < brainTrauma then
				chooser = i
			end
		end
	
		if choosera != chooser or canRetrySound("BrainTraumaStation", BrainTraumaStation) then
			if IsValid(BrainTraumaStation) then
				BrainTraumaStation:Stop()
				BrainTraumaStation = nil
			end

			BrainTraumaStationLoading = true
			sound.PlayFile("sound/zcitysnd/real_sonar/brainhemorrhagestage"..chooser..".ogg", "noblock noplay", function(station, err)
				BrainTraumaStationLoading = false
				if IsValid(station) then
					station:SetVolume(0)
					station:Play()
					BrainTraumaStation = station
					station:EnableLooping(true)
				end
			end)
			choosera = chooser
		end

		if IsValid(BrainTraumaStation) then
			BrainTraumaStation:SetVolume(math.Clamp(sensoryActive and brainTrauma * 2 * sensoryMix or 0, 0, 1))
		end
	else
		if IsValid(BrainTraumaStation) then
			BrainTraumaStation:Stop()
			BrainTraumaStation = nil
		end
	end

	//if brain > 0.1 and not org.otrub and show_some_images_time > 0 and false then
	local temporalTinnitus = math.Clamp(((org.brainTemporal or 0) - 0.1) / 0.9, 0, 1)
	local tinnitusTime = lply.tinnitus and math.max(lply.tinnitus - CurTime(), 0) or 0
	local disorientation = org.disorientation or 0
	local concussion = org.concussion or 0
	local hypertension = math.Clamp(org.hypertension or 0, 0, 1)
	local hypertensionK = math.Clamp(hypertension * 1.27, 0, 1)
	local adrenalineMitigation = math.Clamp((org.adrenaline or 0) / 3, 0, 1) * 0.25
	local hypertensionDisorientation = hypertension > 0 and (0.25 + hypertensionK * (1 - adrenalineMitigation) * 1.5) or 0
	local neuroDisorientation = math.max(disorientation - hypertensionDisorientation, 0)
	local disorientationSpike = math.max(neuroDisorientation - (lastDisorientationFx or 0), 0)
	local concussionSpike = math.max(concussion - (lastConcussionFx or 0), 0)
	lastDisorientationFx = neuroDisorientation
	lastConcussionFx = concussion

	if lply:Alive() and not org.otrub and CurTime() >= nextNeuroTinnitus and (disorientationSpike >= 1.5 or concussionSpike >= 1.0) then
		local spike = math.max(disorientationSpike / 2, concussionSpike)
		local chance = math.Clamp(0.18 + spike * 0.18 + math.Clamp(neuroDisorientation / 10, 0, 1) * 0.12 + math.Clamp(concussion / 6, 0, 1) * 0.18, 0, 0.75)
		if math.Rand(0, 1) < chance then
			lply:AddTinnitus(math.Rand(0.7, 1.8) + spike * 0.7, false, concussion >= 3 or brain > 0.05)
			nextNeuroTinnitus = CurTime() + math.Rand(4, 9)
		else
			nextNeuroTinnitus = CurTime() + math.Rand(1.5, 3.5)
		end
	end

	disorientationFxLerp = LerpFT(disorientation > (disorientationFxLerp or 0) and 0.35 or 0.025, disorientationFxLerp or 0, math.max(disorientation, concussion * 0.65))
	if lply:Alive() and not org.otrub and disorientationFxLerp > 1.2 then
		local blurPower = math.Clamp((disorientationFxLerp - 1.2) / 7.5, 0, 1)
		DrawMotionBlur(0.08 + blurPower * 0.12, 0.45 + blurPower * 1.25, 0.01)
		if blurPower > 0.35 then
			DrawToyTown(blurPower * 2.2, ScrH() / 2)
		end
	end

	if (tinnitusTime > 0 or temporalTinnitus > 0.01) and lply:Alive() then
		if canRetrySound("Tinnitus", Tinnitus) then
			local choice = math.random(5)
			local soundFile
			if choice == 1 then
				soundFile = "sound/tinnitus.wav"
			elseif choice == 2 then
				soundFile = "sound/tinnituslong.wav"
			else
				soundFile = "sound/zcitysnd/real_sonar/tinnitus"..math.random(3)..".ogg"
			end

			sound.PlayFile(soundFile, "noblock noplay", function(station, err)
				if IsValid(station) then
					station:SetVolume(0)
					station:Play()
					Tinnitus = station
					station:EnableLooping(true)
				end
			end)
		end

		if IsValid(Tinnitus) then
			Tinnitus:SetVolume(math.Clamp(math.max(tinnitusTime / 10, temporalTinnitus * 0.65), 0, 1))
		end
	else
		if IsValid(Tinnitus) then
			Tinnitus:Stop()
			Tinnitus = nil
		end
	end
	
	-- Keep the original lobotomy effect self-contained: intermittent material
	-- overlays only. Head-trauma flashes are handled by their own net event.
	if brain > 0.1 and sensoryActive then
		if show_some_images_time > 0 then
			show_some_images_time = show_some_images_time - 1

			local flashRoll = math.max(math.floor(10 * (1 - brain)), 1)
			if show_image_time <= 0 and math.random(flashRoll) < 2 then
				show_image_time = 75 * math.Rand(0.1, 1) * (math.random(2) == 1 and 0.1 or 1)
				lobotomy_index = math.random(#lobotomy_mats)
			end

			if show_image_time > 0 then
				show_image_time = show_image_time - 1
				local mat = lobotomy_mats[lobotomy_index]
				if mat then
					local rand = 5
					surface.SetDrawColor(255, 255, 255, 255)
					surface.SetMaterial(mat)
					surface.DrawTexturedRect(-math.random(rand), -math.random(rand), ScrW() + math.random(rand), ScrH() + math.random(rand))
				end
			end
		else
			show_some_images_time = math.random(1200) < brain * 15 and 250 or 0
		end
	else
		show_image_time = 0
		show_some_images_time = 0
		lobotomy_index = 0
	end
	
	local terminalDyingVolume = 0
	if O2Lerp > 1 or incapacitated then
		o2 = O2Lerp
		
		if o2 > 50 and not org.otrub then
			local dyingMode = getServerSoundMode("hg_dyingsound", 2)

			if canRetrySound("NoiseStation2", NoiseStation2) then
				sound.PlayFile("sound/zbattle/conscioustypebeat.mp3", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength()), 87)
						NoiseStation2 = station
						station:EnableLooping(true)
					end
				end)
			end

			if (dyingMode == 8 or dyingMode == 9) and not NoiseStation2DyingLoading and canRetrySound("NoiseStation2Dying", NoiseStation2Dying) then
				NoiseStation2DyingLoading = true
				sound.PlayFile("sound/rem_dying2.mp3", "noblock noplay", function(station)
					NoiseStation2DyingLoading = false
					if IsValid(station) then
						local currentMode = getServerSoundMode("hg_dyingsound", 2)
						if currentMode != 8 and currentMode != 9 then
							station:Stop()
							return
						end
						station:SetVolume(0)
						station:Play()
						NoiseStation2Dying = station
						station:EnableLooping(true)
					end
				end)
			end
			
			-- Volume is assigned after the shared fade target is calculated below.

			if IsValid(NoiseStation2Dying) then
				NoiseStation2Dying:SetVolume(0)
			end

			if canRetrySound("EndStation", EndStation) then
				sound.PlayFile("sound/itsallcomingtoanend.mp3", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength()), 87)
						EndStation = station
						station:EnableLooping(true)
					end
				end)
			end

			local dyingAudioTarget = math.Clamp((o2 - 50) / 100 + (brain > 0.3 and (brain - 0.3) * 5 or 0), 0, 3)
			local blood = org.blood or 5000
			local bleed = org.bleed or 0
			if blood < 4000 and bleed > 0 then
				local bleedSeverity = math.Clamp((3500 - blood) / 3500, 0, 1)
				dyingAudioTarget = math.max(dyingAudioTarget, bleedSeverity * 2)
			end
			if incapacitated then
				dyingAudioTarget = math.max(dyingAudioTarget, Lerp(incapacitationProgress, 0.65, 0.9))
			end

			-- Low-O2/bleedout ambience ramps into the requested volume instead of
			-- appearing at full level on the first qualifying frame.
			dyingAudioFade = LerpFT(0.018, dyingAudioFade, dyingAudioTarget)
			local consciousVol = dyingAudioFade * (incapacitated and Lerp(incapacitationProgress, 0.72, 0.28) or 1)
			terminalDyingVolume = incapacitated and consciousVol or 0
			hg.consciousBeatIntensity = consciousVol

			if IsValid(NoiseStation2Dying) then
				NoiseStation2Dying:SetVolume(0)
			end
			if IsValid(RemDying1Station) then
				RemDying1Station:SetVolume(0)
			end
			if IsValid(AltRemDyingStation) then
				AltRemDyingStation:SetVolume(0)
			end
			if IsValid(ItsHopelessStation) then
				ItsHopelessStation:SetVolume(0)
			end

			if dyingMode == 0 then
				-- Default: both conscioustypebeat and itsallcomingtoanend play
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(consciousVol)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(consciousVol)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
			elseif dyingMode == 1 then
				-- Only conscioustypebeat at same volume as itsallcomingtoanend
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(consciousVol)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
			elseif dyingMode == 2 then
				-- Only dying.ogg with sound peak detection for screen shake
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(consciousVol)

					-- Sound peak detection for screen shake
					if hg_dyingpulse:GetInt() == 1 and IsValid(DyingStation) and DyingStation.FFT and DyingStation:GetState() == GMOD_CHANNEL_PLAYING then
						local fft = {}
						DyingStation:FFT(fft, FFT_512)
						if #fft > 0 then
							local peakSum = 0
							for i = 1, #fft do
								peakSum = peakSum + fft[i]
							end
							local avgPeak = peakSum / #fft

							-- Apply screen shake based on peak intensity
							if avgPeak > 0.3 then
								local shakeIntensity = math.Clamp((avgPeak - 0.3) * 2, 0, 1)
								local shakeAngle = Angle(
									math.Rand(-1, 1) * shakeIntensity * 2,
									math.Rand(-1, 1) * shakeIntensity * 2,
									math.Rand(-0.5, 0.5) * shakeIntensity
								)
								ViewPunch(shakeAngle)
							end
						end
					end
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
			elseif dyingMode == 3 then
				-- Only alto2.ogg, no screen shake
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(Alto2Station) then
					Alto2Station:SetVolume(consciousVol)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
			elseif dyingMode == 4 then
				-- Only itsallcomingtoanend, no screen shake
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(consciousVol)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
			elseif dyingMode == 5 then
				-- Only sillydying.mp3, no screen shake
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(consciousVol)
				end
			elseif dyingMode == 6 then
				-- Only fuck.mp3 with sound peak detection for screen shake
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
				if IsValid(ItssooverStation) then
					ItssooverStation:SetVolume(consciousVol)

					local fft = {}
					if ItssooverStation.FFT and ItssooverStation:GetState() == GMOD_CHANNEL_PLAYING then
						ItssooverStation:FFT(fft, FFT_512)
					end
					if #fft > 0 then
						local peakSum = 0
						for i = 1, #fft do
							peakSum = peakSum + fft[i]
						end
						local avgPeak = peakSum / #fft

						-- Apply screen shake based on peak intensity
						if avgPeak > 0.3 then
							local shakeIntensity = math.Clamp((avgPeak - 0.3) * 2, 0, 1)
							local shakeAngle = Angle(
								math.Rand(-1, 1) * shakeIntensity * 2,
								math.Rand(-1, 1) * shakeIntensity * 2,
								math.Rand(-0.5, 0.5) * shakeIntensity
							)
							ViewPunch(shakeAngle)
						end
					end
				end
				if IsValid(SonimCookedStation) then
					SonimCookedStation:SetVolume(0)
				end
			elseif dyingMode == 7 then
				-- Only sonimcooked.mp3, no screen shake
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
				if IsValid(ItssooverStation) then
					ItssooverStation:SetVolume(0)
				end
				if IsValid(SonimCookedStation) then
					SonimCookedStation:SetVolume(math.Clamp(consciousVol * 1.5, 0, hg.screeneffects_config.sonimCookedForegroundVolume))
				end
			elseif dyingMode == 8 then
				-- REM low-O2 stack from the reference: rem_dying1 + rem_dying2.
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
				if IsValid(ItssooverStation) then
					ItssooverStation:SetVolume(0)
				end
				if IsValid(SonimCookedStation) then
					SonimCookedStation:SetVolume(0)
				end
				if IsValid(RemDying1Station) then
					RemDying1Station:SetVolume(math.Clamp(consciousVol, 0, hg.screeneffects_config.consciousnessTypeBeatVolume))
				end
				if IsValid(NoiseStation2Dying) then
					NoiseStation2Dying:SetVolume(math.Clamp(consciousVol, 0, hg.screeneffects_config.dying2Volume))
				end
			elseif dyingMode == 9 then
				-- Alternate REM stack: keep rem_dying2, but replace rem_dying1
				-- with itssofuckingover as a restrained background.
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
				if IsValid(ItssooverStation) then
					ItssooverStation:SetVolume(0)
				end
				if IsValid(SonimCookedStation) then
					SonimCookedStation:SetVolume(0)
				end
				if IsValid(AltRemDyingStation) then
					AltRemDyingStation:SetVolume(math.Clamp(consciousVol * hg.screeneffects_config.alternateDyingBackgroundMul, 0, hg.screeneffects_config.alternateDyingBackgroundVolume))
					if AltRemDyingStation:GetTime() >= 120 then AltRemDyingStation:SetTime(0) end
				end
				if IsValid(NoiseStation2Dying) then
					NoiseStation2Dying:SetVolume(math.Clamp(consciousVol, 0, hg.screeneffects_config.alternateDyingForegroundVolume))
				end
			elseif dyingMode == 10 then
				-- Only itshopeless.mp3, no screen shake.
				if IsValid(NoiseStation2) then
					NoiseStation2:SetVolume(0)
				end
				if IsValid(EndStation) then
					EndStation:SetVolume(0)
				end
				if IsValid(DyingStation) then
					DyingStation:SetVolume(0)
				end
				if IsValid(Alto2Station) then
					Alto2Station:SetVolume(0)
				end
				if IsValid(AltpainStation) then
					AltpainStation:SetVolume(0)
				end
				if IsValid(SillydyingStation) then
					SillydyingStation:SetVolume(0)
				end
				if IsValid(ItssooverStation) then
					ItssooverStation:SetVolume(0)
				end
				if IsValid(SonimCookedStation) then
					SonimCookedStation:SetVolume(0)
				end
				if IsValid(ItsHopelessStation) then
					ItsHopelessStation:SetVolume(consciousVol)
				end
			end
			if dyingMode != 7 and IsValid(SonimCookedStation) then
				SonimCookedStation:SetVolume(0)
			end
			if dyingMode != 8 and IsValid(RemDying1Station) then
				RemDying1Station:SetVolume(0)
			end
			if dyingMode != 9 and IsValid(AltRemDyingStation) then
				AltRemDyingStation:SetVolume(0)
			end
			if dyingMode != 10 and IsValid(ItsHopelessStation) then
				ItsHopelessStation:SetVolume(0)
			end
			if dyingMode != 8 and dyingMode != 9 and IsValid(NoiseStation2Dying) then
				NoiseStation2Dying:SetVolume(0)
			end
		else
			dyingAudioFade = LerpFT(0.05, dyingAudioFade, 0)
			hg.consciousBeatIntensity = dyingAudioFade
			if IsValid(NoiseStation2) then
				NoiseStation2:SetVolume(0)
			end

			if IsValid(NoiseStation2Dying) then
				NoiseStation2Dying:SetVolume(0)
			end
			if IsValid(EndStation) then
				EndStation:SetVolume(0)
			end
			if IsValid(DyingStation) then
				DyingStation:SetVolume(0)
			end
			if IsValid(Alto2Station) then
				Alto2Station:SetVolume(0)
			end
			if IsValid(SillydyingStation) then
				SillydyingStation:SetVolume(0)
			end
			if IsValid(ItssooverStation) then
				ItssooverStation:SetVolume(0)
			end
			if IsValid(SonimCookedStation) then
				SonimCookedStation:SetVolume(0)
			end
			if IsValid(RemDying1Station) then
				RemDying1Station:SetVolume(0)
			end
			if IsValid(AltRemDyingStation) then
				AltRemDyingStation:SetVolume(0)
			end
			if IsValid(ItsHopelessStation) then
				ItsHopelessStation:SetVolume(0)
			end
		end
		
		if (o2 > 20 or incapacitated) and org.otrub then
			local otrubMode = getServerSoundMode("hg_otrubsound", 4)
			-- OTRU audio is selected solely by hg_otrubsound.  Remorseism
			-- incapacitation is a gameplay state, not an audio override: otherwise it
			-- replaced every configured OTRU track with rem_dying1.
			local otrubVol = math.Clamp((o2 - 30) / 100 + (brain > 0.3 and (brain - 0.3) * 5 or 0), 0, 1)
			if incapacitated then
				otrubVol = math.max(otrubVol, 0.3) * Lerp(incapacitationProgress, 0.45, 0.12)
			end

			if canRetrySound("NoiseStation", NoiseStation) then
				sound.PlayFile("sound/zbattle/unconscious_type_beat.mp3", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						NoiseStation = station
						station:EnableLooping(true)
					end
				end)
			end

			local sharedOtrubStation = otrubMode == 6 and ItssooverStation or otrubMode == 7 and ItsHopelessStation
			if otrubMode == 0 then
				if IsValid(NoiseStation) then NoiseStation:SetVolume(otrubVol) end
				if IsValid(OtrubModeStation) then OtrubModeStation:SetVolume(0) end
			elseif otrubMode == 6 or otrubMode == 7 then
				if IsValid(NoiseStation) then NoiseStation:SetVolume(0) end
				if IsValid(OtrubModeStation) then OtrubModeStation:SetVolume(0) end
				local sameDyingTrack = incapacitated and ((otrubMode == 6 and selectedDyingMode == 6) or (otrubMode == 7 and selectedDyingMode == 10))
				if IsValid(sharedOtrubStation) then sharedOtrubStation:SetVolume(math.max(otrubVol, sameDyingTrack and terminalDyingVolume or 0)) end
			else
				if IsValid(NoiseStation) then NoiseStation:SetVolume(0) end

				if activeOtrubMode ~= otrubMode then
					if IsValid(OtrubModeStation) then OtrubModeStation:Stop() end
					OtrubModeStation = nil
					activeOtrubMode = otrubMode
				end

				if canRetrySound("OtrubModeStation" .. otrubMode, OtrubModeStation) then
					local requestedMode = otrubMode
					sound.PlayFile(otrubSoundPaths[requestedMode], "noblock noplay", function(station)
						if not IsValid(station) then return end
						if getServerSoundMode("hg_otrubsound", 4) ~= requestedMode then
							station:Stop()
							return
						end

						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						station:EnableLooping(true)
						OtrubModeStation = station
					end)
				end

				if IsValid(OtrubModeStation) then OtrubModeStation:SetVolume(otrubVol) end
			end
			-- Do not let a dying-mode station bleed into the selected OTRU sound.
			-- Modes 6 and 7 deliberately reuse their dying channel so playback
			-- continues from the exact point where consciousness was lost.
			if not incapacitated then
				if otrubMode != 6 and IsValid(ItssooverStation) then ItssooverStation:SetVolume(0) end
				if IsValid(RemDying1Station) then RemDying1Station:SetVolume(0) end
				if IsValid(AltRemDyingStation) then AltRemDyingStation:SetVolume(0) end
				if otrubMode != 7 and IsValid(ItsHopelessStation) then ItsHopelessStation:SetVolume(0) end
				if IsValid(NoiseStation2Dying) then NoiseStation2Dying:SetVolume(0) end
			end
		else
			if IsValid(NoiseStation) then
				NoiseStation:SetVolume(0)
			end
			if IsValid(OtrubModeStation) then OtrubModeStation:SetVolume(0) end
		end
	else
		dyingAudioFade = LerpFT(0.05, dyingAudioFade, 0)
		if IsValid(NoiseStation) then
			NoiseStation:Stop()
			NoiseStation = nil
		end
	end

	-- Play noises.ogg when brain health is between 0.6 and 0.7
	if brain >= 0.6 and brain <= 0.7 and not org.otrub then
		local noisesVol = math.Remap(brain, 0.6, 0.7, 0, 0.75)
		noisesVol = math.Clamp(noisesVol, 0, 0.75)
		if IsValid(NoisesStation) then
			NoisesStation:SetVolume(noisesVol)
		end
	else
		if IsValid(NoisesStation) then
			NoisesStation:SetVolume(0)
		end
	end

	-- Suicide state visual effects
	if lply.suiciding and lply:Alive() and not org.otrub then
		local startTime = lply.startsuicide or CurTime()
		local duration = CurTime() - startTime
		local targetIntensity = math.Clamp(duration / 3, 0, 1)

		suicideLerp = math.Approach(suicideLerp, targetIntensity, FrameTime() * 0.4)

		local pulse = (math.sin(CurTime() * 1.2) + 1) * 0.5
		local pulseEffect = pulse * suicideLerp * 0.15

		-- Desaturation and darkening
		local suiGray = suicideLerp * 0.55
		tab["$pp_colour_colour"] = math.min(tab["$pp_colour_colour"] or 1, 1 - suiGray)
		tab["$pp_colour_brightness"] = (tab["$pp_colour_brightness"] or 0) - suicideLerp * 0.12
		tab["$pp_colour_contrast"] = math.min(tab["$pp_colour_contrast"] or 1, 1 - suicideLerp * 0.08)
		tab["$pp_colour_mulr"] = (tab["$pp_colour_mulr"] or 0) - suicideLerp * 0.02
		tab["$pp_colour_mulg"] = (tab["$pp_colour_mulg"] or 0) - suicideLerp * 0.02
		tab["$pp_colour_mulb"] = (tab["$pp_colour_mulb"] or 0) - suicideLerp * 0.01

		-- Strong vignette with slow pulse
		render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", suicideLerp * 0.6 + pulseEffect * 0.5)
		vignetteMat:SetFloat("$c1_y", suicideLerp * 0.85 + pulseEffect * 2)
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()

		-- Chromatic aberration
		-- View wobble for disorientation
		if suicideLerp > 0.3 then
			local wobbleTime = CurTime() * (1.5 + suicideLerp * 2)
			local wobbleStrength = (suicideLerp - 0.3) * 0.3
			ViewPunch(Angle(
				math.sin(wobbleTime) * wobbleStrength,
				math.cos(wobbleTime * 0.7) * wobbleStrength * 0.7,
				math.sin(wobbleTime * 0.5) * wobbleStrength * 0.3
			))
		end
		chromaticMat:SetFloat("$c0_x", suicideLerp * 0.025)
		chromaticMat:SetInt("$c0_y", 1)
		render.SetMaterial(chromaticMat)
		render.DrawScreenQuad()

		-- Motion blur disorientation
		if suicideLerp > 0.15 then
			local blurAlpha = 0.1 + suicideLerp * 0.15
			local blurDraw = suicideLerp * 1.5
			DrawMotionBlur(blurAlpha, blurDraw, 0.001)
		end

		-- ToyTown blur at high intensity
		if suicideLerp > 0.4 then
			DrawToyTown((suicideLerp - 0.4) * 2.5, ScrH() / 2)
		end

		-- View wobble for disorientation
		if suicideLerp > 0.3 then
			local wobbleTime = CurTime() * (1.5 + suicideLerp * 2)
			local wobbleStrength = (suicideLerp - 0.3) * 0.3
			suicideViewAng[1] = math.sin(wobbleTime) * wobbleStrength
			suicideViewAng[2] = math.cos(wobbleTime * 0.7) * wobbleStrength * 0.7
			suicideViewAng[3] = math.sin(wobbleTime * 0.5) * wobbleStrength * 0.3
			ViewPunch(suicideViewAng)
		end
	else
		suicideLerp = math.Approach(suicideLerp, 0, FrameTime() * 3)
	end

	do
		local grayscaleTarget = 0
		if not org.otrub then
		local zerlkersVisualMul = 1 - math.Clamp(org.zerlkers or 0, 0, 1) * 0.8

		local suppForce = (SIB_suppress and SIB_suppress.Force or 0)
		if suppForce > 1 then
			grayscaleTarget = grayscaleTarget + math.Clamp((suppForce - 1) / 9, 0, 1) * 0.20
		end

		local adrenaline = org.adrenaline or 0
		local adrenalineIntensity = math.Clamp((adrenaline - 1) / 1.5, 0, 1)
		if adrenalineIntensity > 0 then
			grayscaleTarget = grayscaleTarget + adrenalineIntensity * (0.03 + adrenalineVisualLerp * 0.17)
		end

		local blood = org.blood or 5000
		-- A very small desaturation begins with the first measurable loss, then the
		-- curve steepens as the circulation approaches the decompensation region.
		local lowBloodVisual = math.Clamp((5000 - blood) / 3000, 0, 1) ^ 1.25
		if lowBloodVisual > 0 then
			-- Blood loss starts with a restrained desaturation and blur, while the
			-- existing consciousness/shock effects still own severe collapse.
			grayscaleTarget = grayscaleTarget + lowBloodVisual * 0.18 * zerlkersVisualMul
			DrawMotionBlur((0.04 + lowBloodVisual * 0.04) * zerlkersVisualMul, (0.18 + lowBloodVisual * 0.22) * zerlkersVisualMul, 0.02)
		end
		if blood < 3500 then
			grayscaleTarget = grayscaleTarget + math.Clamp((3500 - blood) / 3500, 0, 1) * 0.25 * zerlkersVisualMul
		end

		local ischemiaVisual = math.Clamp(tonumber(org.ischemia) or 0, 0, 1)
		local internalBleedVisual = math.Clamp((tonumber(org.internalBleed) or 0) / 5, 0, 1)
		local hemothoraxVisual = math.Clamp(tonumber(org.hemothorax) or 0, 0, 1)
		local pneumothoraxVisual = math.Clamp(tonumber(org.pneumothorax) or 0, 0, 1)
		local perfusionVisual = math.Clamp(1 - (tonumber(org.perfusion) or 1), 0, 1)
		local circulatoryVisual = math.max(
			ischemiaVisual,
			internalBleedVisual * 0.65,
			hemothoraxVisual * 0.75,
			pneumothoraxVisual * 0.65,
			perfusionVisual * 0.8
		)
		grayscaleTarget = grayscaleTarget + circulatoryVisual * 0.24 * zerlkersVisualMul
		ischemicVignetteLerp = LerpFT(0.035, ischemicVignetteLerp, math.Clamp(lowBloodVisual * 0.45 + circulatoryVisual * 0.65, 0, 0.8) * zerlkersVisualMul)
		if ischemicVignetteLerp > 0.005 then
			render.UpdateScreenEffectTexture()
			vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
			vignetteMat:SetFloat("$c0_z", ischemicVignetteLerp * 0.35)
			vignetteMat:SetFloat("$c1_y", ischemicVignetteLerp * 0.75)
			render.SetMaterial(vignetteMat)
			render.DrawScreenQuad()
		end

		local o2 = (org.o2 and isnumber(org.o2[1])) and org.o2[1] or 100
		if o2 < 30 then
			grayscaleTarget = grayscaleTarget + math.Clamp((30 - o2) / 30, 0, 1) * 0.22 * zerlkersVisualMul
		end

		local shock = org.shock or 0
		if shock > 20 then
			grayscaleTarget = grayscaleTarget + math.Clamp((shock - 20) / 80, 0, 1) * 0.20 * zerlkersVisualMul
		end

		local immobilization = org.immobilization or 0
		if immobilization > 5 then
			grayscaleTarget = grayscaleTarget + math.Clamp((immobilization - 5) / 25, 0, 1) * 0.18
		end

		local consciousness = org.consciousness or 1
		if consciousness < 0.8 then
			grayscaleTarget = grayscaleTarget + math.Clamp((0.8 - consciousness) / 0.8, 0, 1) * 0.25
		end

		grayscaleTarget = math.Clamp(grayscaleTarget, 0, 0.65)
		grayscaleLerp = LerpFT(0.04, grayscaleLerp, grayscaleTarget)

		if grayscaleLerp > 0.005 then
			tab["$pp_colour_colour"] = math.min(tab["$pp_colour_colour"] or 1, 1 - grayscaleLerp)
		end
		else
			grayscaleLerp = LerpFT(0.04, grayscaleLerp, 0)
			ischemicVignetteLerp = LerpFT(0.04, ischemicVignetteLerp, 0)
		end
	end

	if (headtraumaSaturation or 0) > 0 then
		if not org.otrub then
			tab["$pp_colour_colour"] = 1 + headtraumaSaturation
		end
		headtraumaSaturation = math.max(headtraumaSaturation - FrameTime() * 0.85, 0)
	end

end)

-- Brief warning flashes for pain that is stored or still queued but currently
-- masked by adrenaline/analgesia. The uneven pauses keep this from becoming a
-- regular heartbeat effect, while felt pain gradually takes the warning over.
hook.Add("Post Post Pre Post Processing", "HiddenPainFlicker", function()
	local now = CurTime()
	local org = IsValid(lply) and lply:Alive() and (lply.new_organism or lply.organism)

	if not org or org.otrub then
		hiddenPainFlickerSeverity = math.Approach(hiddenPainFlickerSeverity, 0, FrameTime() * 5)
		hiddenPainFlickerEnd = 0
		hiddenPainNextFlicker = now + math.Rand(0.4, 1)
		return
	end

	local avgPain = math.max(org.avgpain or 0, 0)
	local painAdd = math.max(org.painadd or 0, 0)
	local feltPain = math.max(org.pain or 0, 0)
	local storedPain = math.Clamp(avgPain + painAdd, 0, 150)
	local hiddenDifference = math.max(storedPain - feltPain, 0)
	local targetSeverity = math.Clamp((hiddenDifference - 10) / 125, 0, 1)
	-- Zerlkers intentionally suppresses these warning fragments as well as the
	-- normal pain vignette; stored damage remains on the server and returns later.
	targetSeverity = targetSeverity * (1 - math.Clamp(org.zerlkers or 0, 0, 1))

	-- Felt pain starts quieting the warning between 40 and 60 pain depending on
	-- how much avgpain is waiting underneath, then fully wins over 35 pain later.
	local recedeStart = Lerp(math.Clamp(avgPain / 150, 0, 1), 40, 60)
	local feltPainSuppression = 1 - math.Clamp((feltPain - recedeStart) / 35, 0, 1)
	targetSeverity = targetSeverity * feltPainSuppression
	hiddenPainFlickerSeverity = math.Approach(
		hiddenPainFlickerSeverity,
		targetSeverity,
		FrameTime() * (targetSeverity > hiddenPainFlickerSeverity and 1.8 or 4)
	)

	if hiddenPainFlickerSeverity > 0.025 and now >= hiddenPainNextFlicker then
		local duration = math.Rand(0.1, Lerp(hiddenPainFlickerSeverity, 0.17, 0.26))
		hiddenPainFlickerStart = now
		hiddenPainFlickerAttackEnd = now + math.min(duration * math.Rand(0.12, 0.28), 0.05)
		hiddenPainFlickerEnd = now + duration
		hiddenPainFlickerPeak = hiddenPainFlickerSeverity * math.Rand(0.65, 1)

		local gap = math.Rand(
			Lerp(hiddenPainFlickerSeverity, 1.4, 0.35),
			Lerp(hiddenPainFlickerSeverity, 3.4, 1.15)
		)
		if math.Rand(0, 1) < 0.25 then gap = gap * math.Rand(1.4, 2.2) end
		hiddenPainNextFlicker = hiddenPainFlickerEnd + gap
	end

	if now >= hiddenPainFlickerEnd then return end

	local envelope
	if now < hiddenPainFlickerAttackEnd then
		envelope = math.TimeFraction(hiddenPainFlickerStart, hiddenPainFlickerAttackEnd, now)
	else
		envelope = 1 - math.TimeFraction(hiddenPainFlickerAttackEnd, hiddenPainFlickerEnd, now)
		envelope = math.max(envelope, 0) ^ 1.6
	end

	local flash = math.Clamp(envelope * hiddenPainFlickerPeak * hiddenPainFlickerSeverity, 0, 1)
	if flash <= 0.001 then return end

	hiddenPainColor["$pp_colour_brightness"] = -0.012 * flash
	hiddenPainColor["$pp_colour_contrast"] = 1 + 0.04 * flash
	hiddenPainColor["$pp_colour_colour"] = 1 - 0.12 * flash
	hiddenPainColor["$pp_colour_addr"] = 0.12 * flash
	hiddenPainColor["$pp_colour_addg"] = 0.008 * flash
	hiddenPainColor["$pp_colour_addb"] = 0.004 * flash
	hiddenPainColor["$pp_colour_mulr"] = 0.18 * flash
	DrawColorModify(hiddenPainColor)
end)

hook.Add("Post Pre Post Processing", "BrainLobeEffects", function()
	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	if !lply:Alive() and (!IsValid(spect) or viewmode != 1) then return end

	local org = lply:Alive() and lply.organism or (IsValid(spect) and spect.organism)
	if not org or org.otrub then return end

	local frontal = math.Clamp(brainFrontalLerp, 0, 1)
	local parietal = math.Clamp(brainParietalLerp, 0, 1)
	local temporal = math.Clamp(brainTemporalLerp, 0, 1)
	local occipital = math.Clamp(brainOccipitalLerp, 0, 1)
	local hemorrhage = math.Clamp(brainHemorrhageLerp, 0, 1)

	if frontal > 0.01 then
		brainFrontalColor["$pp_colour_brightness"] = -frontal * 0.035
		brainFrontalColor["$pp_colour_contrast"] = 1 - frontal * 0.18
		brainFrontalColor["$pp_colour_colour"] = 1 - frontal * 0.7
		brainFrontalColor["$pp_colour_mulr"] = frontal * 0.05
		brainFrontalColor["$pp_colour_mulb"] = frontal * 0.08
		DrawColorModify(brainFrontalColor)

		render.UpdateScreenEffectTexture()
		grainMat:SetFloat("$c0_x", CurTime() * 0.7)
		grainMat:SetFloat("$c0_y", 0.35)
		grainMat:SetFloat("$c0_z", frontal * 2.6)
		grainMat:SetFloat("$c1_x", frontal * 1.25)
		grainMat:SetFloat("$c1_y", frontal * 3.5)
		grainMat:SetFloat("$c1_z", frontal * 0.65)
		grainMat:SetFloat("$c2_x", frontal * 0.08)
		grainMat:SetFloat("$c2_y", 0)
		grainMat:SetFloat("$c2_z", frontal * 0.12)
		grainMat:SetFloat("$c3_x", 0)
		render.SetMaterial(grainMat)
		render.DrawScreenQuad()
	end

	if parietal > 0.01 then
		DrawMotionBlur(0.025 + parietal * 0.08, 0.35 + parietal * 0.55, 0.015 + parietal * 0.09)
		DrawSharpen(parietal * 0.8, parietal * 1.4)
	end

	if temporal > 0.01 then
		render.UpdateScreenEffectTexture()
		chromaticMat:SetFloat("$c0_x", 3.4 - temporal * 2.6)
		chromaticMat:SetInt("$c0_y", 1)
		render.SetMaterial(chromaticMat)
		render.DrawScreenQuad()
	end

	if occipital > 0.01 then
		surface.SetDrawColor(255, 255, 255, math.Clamp(occipital * 235, 0, 235))
		surface.SetMaterial(lobotomy_mats[5])
		surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
		if occipital > 0.6 then
			surface.SetDrawColor(0, 0, 0, math.Remap(occipital, 0.6, 1, 0, 210))
			surface.DrawRect(0, 0, ScrW(), ScrH())
		end
		surface.SetDrawColor(255, 255, 255, 255)
	end

	if hemorrhage > 0.01 then
		local pulse = hemorrhage * (0.7 + math.abs(math.sin(CurTime() * 2.2)) * 0.3)
		render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", pulse * 2.2)
		vignetteMat:SetFloat("$c1_y", pulse * 3.2)
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()
		painMat:SetFloat("$c2_x", CurTime() + 10000)
		painMat:SetFloat("$c0_y", 0.8)
		painMat:SetFloat("$c0_z", pulse)
		painMat:SetFloat("$c1_x", pulse * 0.45)
		painMat:SetFloat("$c1_y", pulse * 0.7)
		render.SetMaterial(painMat)
		render.DrawScreenQuad()
	end
end)

hook.Add("Post Pain Processing", "CardiologyEffects", function()
	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	if !lply:Alive() and (!IsValid(spect) or viewmode != 1) then return end

	local org = lply:Alive() and lply.organism or (IsValid(spect) and spect.organism)
	if not org or org.otrub then return end

	local cardio = math.Clamp(CardioLerp or 0, 0, 1)
	if cardio <= 0.01 then return end

	local beat = 0.75 + math.abs(math.sin(CurTime() * math.Clamp((org.heartbeat or 70) / 45, 0.8, 4))) * 0.25
	local intensity = cardio * beat

	render.UpdateScreenEffectTexture()
	vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
	vignetteMat:SetFloat("$c0_z", intensity * 1.2)
	vignetteMat:SetFloat("$c1_y", intensity * 2.1)
	render.SetMaterial(vignetteMat)
	render.DrawScreenQuad()

	render.UpdateScreenEffectTexture()
	painMat:SetFloat("$c2_x", CurTime() + 10000)
	painMat:SetFloat("$c0_y", 0.88)
	painMat:SetFloat("$c0_z", intensity * 0.35)
	painMat:SetFloat("$c1_x", intensity * 0.25)
	painMat:SetFloat("$c1_y", intensity * 0.35)
	render.SetMaterial(painMat)
	render.DrawScreenQuad()
end)

hook.Add("Post Pain Processing", "PainEffects", function()
	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	if !lply:Alive() and (!IsValid(spect) or viewmode != 1) then return end

	local org = lply:Alive() and lply.organism or (IsValid(spect) and spect.organism)
	if not org or not org.brain then return end
	if not ((PainLerp > 0.001 or shockLerp > 5) or org.otrub) then return end

	local strobe = math.ease.InOutSine(math.abs(math.cos(CurTime() * 2))) * PainLerp * painPulseIntensity
	local pain = PainLerp + strobe
	local shock = shockLerp
	local zerlkersVisualMul = 1 - math.Clamp(org.zerlkers or 0, 0, 1) * 0.85
	local thresholdReached = PainLerp >= painThresholdMax
	painThresholdIntensityLerp = LerpFT(0.03, painThresholdIntensityLerp, thresholdReached and 5 or 1)
	local intensityMul = painThresholdIntensityLerp
	local coverage = (thresholdReached and 1 or math.Clamp(pain / 70, 0, 0.95)) * zerlkersVisualMul
	local effectIntensity = (pain / 32 * painEffectIntensity * intensityMul + math.max(shock - 5, 0) / 2.4 * painEffectIntensity) * zerlkersVisualMul

	render.UpdateScreenEffectTexture()

	vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
	vignetteMat:SetFloat("$c0_z", org.otrub and 5 * unconsciousPainEffectIntensity or effectIntensity)
	vignetteMat:SetFloat("$c1_y", org.otrub and 10 * unconsciousPainEffectIntensity or effectIntensity)

	render.SetMaterial(vignetteMat)
	render.DrawScreenQuad()

	render.UpdateScreenEffectTexture()

	painMat:SetFloat("$c2_x", CurTime() + 10000)
	painMat:SetFloat("$c0_y", 0.8)
	painMat:SetFloat("$c0_z", org.otrub and unconsciousPainEffectIntensity or painEffectIntensity * intensityMul * zerlkersVisualMul)
	painMat:SetFloat("$c1_x", coverage)
	painMat:SetFloat("$c1_y", coverage)

	render.SetMaterial(painMat)
	render.DrawScreenQuad()
end)

hook.Add("Player_Death", "ItDoesntNow", function(ply)
	if !((ply == lply) or (ply == lply:GetNWEntity("spect"))) then return end

	stopthings()
end)

hook.Add("Player Spawn", "ItDoesntNow", function(ply)
	if ply != lply then return end

	stopthings()
end)

local suicidePhrases = {
	"theres no other way.",
	"just end it.",
	"nobody would care.",
	"its not worth it anymore.",
	"pull the trigger.",
	"everyone would be better off.",
}
local suicideTextLerp = 0
local suicidePhraseIndex = 1
local suicideNextPhraseTime = 0

hook.Add("DrawOverlay", "suicide_text", function()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) or !ply:Alive() then
		suicideTextLerp = LerpFT(0.15, suicideTextLerp, 0)
		return
	end

	if not ply.suiciding then
		suicideTextLerp = LerpFT(0.1, suicideTextLerp, 0)
		return
	end

	local org = ply.new_organism or ply.organism
	if org and org.otrub then
		suicideTextLerp = 0
		return
	end

	local startTime = ply.startsuicide or CurTime()
	local duration = CurTime() - startTime

	-- Only show text after 2 seconds in suicide state
	if duration < 2 then return end

	local target = math.Clamp((duration - 2) / 3, 0, 1)
	suicideTextLerp = LerpFT(0.02, suicideTextLerp, target)
	if suicideTextLerp <= 0.001 then return end

	-- Cycle phrases every 5 seconds
	if CurTime() > suicideNextPhraseTime then
		suicidePhraseIndex = math.random(#suicidePhrases)
		suicideNextPhraseTime = CurTime() + 5
	end

	local time = CurTime()
	local sway = 8 + 12 * suicideTextLerp
	local x = ScrW() * 0.5 + math.sin(time * 0.5) * sway + math.cos(time * 0.27) * sway * 0.6
	local y = ScrH() * 0.92 + math.sin(time * 0.43) * sway * 0.3
	local alpha = math.floor(200 * suicideTextLerp)

	local text = suicidePhrases[suicidePhraseIndex]
	draw.SimpleText(text, "ZCity_Suicide_Text", x + 2, y + 2, Color(0, 0, 0, math.floor(alpha * 0.7)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "ZCity_Suicide_Text", x, y, Color(210, 210, 210, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

local function removeflash()
	if IsValid(lply.blindflash) then
		lply.blindflash:Remove()
	end
end

hook.Add("PreDrawOpaqueRenderables", "renderblindnessflash", function()
	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	
	if !lply:Alive() and !IsValid(spect) then removeflash() return end
	if !lply:Alive() and viewmode != 1 then removeflash() return end

	local organism = lply:Alive() and lply.organism or (IsValid(spect) and spect.organism)
	if not organism or isbool(organism) then removeflash() return end

	if !(organism.blindness or (amtflashed or 0) >= 0.8) then removeflash() return end
	local blindness = ((organism.blindness and math.Round(organism.blindness) == 0) or amtflashed >= 0.8) and 0 or (organism.blindness)

	local eyesmode = math.Round(blindness)
	if eyesmode == 1 or eyesmode == 2 then removeflash() return end
	
	local view = render.GetViewSetup(true)
	
	if not IsValid(lply.blindflash) then
		lply.blindflash = ProjectedTexture()
		lply.blindflash:SetTexture("effects/flashlight001")
		lply.blindflash:SetEnableShadows(false)
		lply.blindflash:SetConstantAttenuation(.1)
	end
	
	local Ang = view.angles
	Ang[2] = Ang[2] + (eyesmode == 2 and 90 or eyesmode == 1 and -90 or 0)
	Ang[1] = eyesmode == 0 and Ang[1] or 0
	lply.blindflash:SetFarZ(40)
	lply.blindflash:SetFOV(160)
	lply.blindflash:SetBrightness(1)
	lply.blindflash:SetPos(view.origin)
	lply.blindflash:SetAngles(Ang)
	lply.blindflash:Update()
end)


local function GetConsciousBeatPulse()
	if not IsValid(lply) or not lply:Alive() then return 0 end

	-- Check if dying pulse detection is enabled
	if not hg_dyingpulse:GetBool() then return 0 end

	local dyingMode = getServerSoundMode("hg_dyingsound", 2)
	-- The camera pulse belongs only to the modes that actually play
	-- conscioustypebeat. Keep the other dying tracks visually quiet.
	if dyingMode != 0 and dyingMode != 1 then return 0 end

	local intensity = hg.consciousBeatIntensity or 0
	if intensity <= 0.01 then return 0 end

	-- Do not depend on GetVolume here. The track is intentionally capped at a
	-- quiet volume, and some clients report that capped channel as zero even
	-- while it is playing, which silently removed the camera shake.
	if not IsValid(NoiseStation2) or NoiseStation2:GetState() != GMOD_CHANNEL_PLAYING then return 0 end

	local time = NoiseStation2:GetTime()

	local phase = time % 1.85
	local pulse = math.exp(-phase * 5) -- sharp spike that quickly fades

	return pulse * intensity
end

hook.Add("TranslateFOV", "ConsciousBeatZoom", function(ply, fov)
	local pulse = GetConsciousBeatPulse()
	if pulse > 0 then
		return fov - (pulse * 20) -- zooms in slightly
	end
end)

hook.Add("HG_CalcView", "ConsciousBeatShake", function(ply, pos, angles, fova, znear, zfar)
	local pulse = GetConsciousBeatPulse()
	local painShake = 0
	local org = IsValid(lply) and lply:Alive() and (lply.new_organism or lply.organism)
	if org and isRapidPainShakeActive(org) then
		painShake = math.Clamp(math.Remap(org.pain, painRapidShakeThreshold, painThresholdMax, 0.65, 1.4), 0.65, 1.4)
	end

	local shakeAmt = pulse * 2.5 + painShake
	if shakeAmt > 0 then
		angles.p = angles.p + math.Rand(-shakeAmt, shakeAmt)
		angles.y = angles.y + math.Rand(-shakeAmt, shakeAmt)
		angles.r = angles.r + math.Rand(-shakeAmt, shakeAmt)
	end

	if pulse > 0 then
		-- Also modify fova for when RenderScene is disabled
		fova[1] = (fova[1] or 0) - (pulse * 20)
	end
end)

local HEADHIT_VOLUME = 1.0
local HEADHIT_BASE_BOOST = 1.2 -- every head hit is louder than full volume
local CONCUSSION_VOLUME = 0.45
local CONCUSSION_SOUND_PATHS = {
    "sound/concussion1.mp3",
    "sound/concussion2.mp3"
}
local last_headhit_sound = 0
local last_concussion_sound = 0

local function PlayHeadhitSound(volumeScale)
    if CurTime() < last_headhit_sound + 0.15 then return end
    last_headhit_sound = CurTime()
    volumeScale = math.Clamp(volumeScale or 1, 0.2, 1.0)
    -- Always above full volume, with extra scaling from damage
    local finalVolume = HEADHIT_VOLUME * (HEADHIT_BASE_BOOST + volumeScale * 0.8)
    sound.PlayFile("sound/headhit.mp3", "noblock noplay", function(station)
        if IsValid(station) then
            station:SetVolume(finalVolume)
            station:Play()
        end
    end)
end

local function PlayConcussionSound(volumeScale)
    if CurTime() < last_concussion_sound + 0.15 then return end
    last_concussion_sound = CurTime()
    volumeScale = math.Clamp(volumeScale or 1, 0.3, 1.2)
    local soundPath = CONCUSSION_SOUND_PATHS[math.random(#CONCUSSION_SOUND_PATHS)]
    sound.PlayFile(soundPath, "noblock noplay", function(station)
        if IsValid(station) then
            station:SetVolume(CONCUSSION_VOLUME * volumeScale)
            station:Play()
        end
    end)
end

net.Receive("headtrauma_flash", function()
    local pos = net.ReadVector()
    local time = net.ReadFloat()
    local size = net.ReadInt(20)
    local is_critical = net.ReadBool()
    local play_knockout_sound = net.ReadBool()
    local hasBrainDamage = net.ReadBool()
    local hasConcussion = net.ReadBool()
	local playConcussionSound = net.ReadBool()
	local trigger_tinnitus = net.ReadBool()

	local lply = LocalPlayer()
	if not IsValid(lply) then return end
	if lply.organism and lply.organism.otrub then return end

	if trigger_tinnitus then
        if is_critical then
            surface.PlaySound("tinnituslong.wav")
            if IsValid(lply) then lply:AddTinnitus(5 + time * 0.7, false, hasBrainDamage) end
        else
            surface.PlaySound("tinnitus.wav")
            if IsValid(lply) then lply:AddTinnitus(2.5 + time * 0.5, false, hasBrainDamage) end
        end
    end

	-- Head impacts need the same visible flare as other flash sources. Passing
	-- the head-trauma flag suppresses them in the shared flash renderer.
	if hg.AddFlash then
		hg.AddFlash(lply:EyePos(), 1, pos, time, size)
	end

    -- Scale effects by the received flash duration (which is scaled by damage on the server)
    local damageScale = math.Clamp(time / 1.5, 0.2, 1.0)
	if hasConcussion then
        headtraumaSaturation = math.max(headtraumaSaturation or 0, math.min(time * 9, 10))
    end

    PlayHeadhitSound(damageScale)
    if playConcussionSound then
        PlayConcussionSound(damageScale)
    end

    -- Scaled view punch based on damage
    local punchScale = (is_critical or hasBrainDamage or hasConcussion) and 1.5 or damageScale
    ViewPunch(Angle(math.random(-10, 10) * punchScale, math.random(-8, 8) * punchScale, math.random(-3, 3) * punchScale))

    if play_knockout_sound then
        ViewPunch(Angle(math.random(-15, 15), math.random(-15, 15), math.random(-5, 5)))
    end
end)

hook.Add("HG_OnOtrub", "FUCKINGSHITOW", function(ply)
	if ply == LocalPlayer() then
		sound.PlayFile("sound/owfuck.mp3", "noblock noplay", function(station)
			if IsValid(station) then station:Play() end
		end)
	end
end)

local function IsSkullBrokenFully(ent, visited)
	if not IsValid(ent) then return false end

	-- Guard against cyclic references (player <-> ragdoll point at each other)
	visited = visited or {}
	if visited[ent] then return false end
	visited[ent] = true

	if ent:IsPlayer() then
		if ent:GetNWBool("SkullBrokenFully", false) then
			ent.HGSkullBrokenFully = true
			return true
		end
		ent.HGSkullBrokenFully = nil
	elseif ent:GetNWBool("SkullBrokenFully", false) or ent.HGSkullBrokenFully then
		return true
	end

	-- Check organism
	if ent.organism and (ent.organism.skull or 0) >= 1 then
		ent.HGSkullBrokenFully = true
		return true
	end

	-- Check if ent is player and has organism
	if ent:IsPlayer() then
		local org = ent.organism or ent.new_organism
		if org and (org.skull or 0) >= 1 then
			ent.HGSkullBrokenFully = true
			return true
		end
		-- Check their fake ragdoll or death ragdoll
		local fakeRag = ent:GetNWEntity("FakeRagdoll")
		if IsValid(fakeRag) and IsSkullBrokenFully(fakeRag, visited) then
			return true
		end
		local deathRag = ent:GetNWEntity("RagdollDeath")
		if IsValid(deathRag) and IsSkullBrokenFully(deathRag, visited) then
			return true
		end
	elseif ent:IsRagdoll() then
		-- Check ragdoll's own organism first (works even after death when ply NWEntity is NULL)
		if ent.organism and (ent.organism.skull or 0) >= 1 then
			ent.HGSkullBrokenFully = true
			return true
		end
		-- Also check linked player if still valid
		local ply = ent:GetNWEntity("ply")
		if IsValid(ply) and IsSkullBrokenFully(ply, visited) then
			return true
		end
	end

	return false
end

hook.Add("HUDPaint", "DrawSkullBrokenBlackSquares", function()
	if hg_laivlik:GetInt() == 0 then return end
	
	local localPlayer = LocalPlayer()
	if not IsValid(localPlayer) then return end

	local camPos = EyePos()
	local camAngles = EyeAngles()

	for _, ply in ipairs(player.GetAll()) do
		-- Determine the active entity representing this player (could be player themselves, or their fake ragdoll, or death ragdoll)
		local ent = ply
		if not ply:Alive() then
			local deathRag = ply:GetNWEntity("RagdollDeath")
			if IsValid(deathRag) then
				ent = deathRag
			else
				local clRag = ply:GetRagdollEntity()
				if IsValid(clRag) then
					ent = clRag
				end
			end
		else
			local fakeRag = ply:GetNWEntity("FakeRagdoll")
			if IsValid(fakeRag) then
				ent = fakeRag
			end
		end

		if IsValid(ent) then
			local skullDestroyed = IsSkullBrokenFully(ply) or IsSkullBrokenFully(ent)
			if not (ent == localPlayer and not localPlayer:ShouldDrawLocalPlayer()) and skullDestroyed then
				-- Find head bone
				local bone = ent:LookupBone("ValveBiped.Bip01_Head1")
				if bone then
					local matrix = ent:GetBoneMatrix(bone)
					if matrix then
						local headPos = matrix:GetTranslation()

						-- Line-of-sight check to make sure head is not obscured by a wall
						local tr = util.TraceLine({
							start = camPos,
							endpos = headPos,
							filter = {localPlayer, ent},
							mask = MASK_VISIBLE
						})

						if not tr.Hit then
							-- Project head position to 2D screen coordinates
							local screenData = headPos:ToScreen()
							if screenData.visible then
								-- Calculate size of the square based on distance to maintain visual coverage of the head/face area
								local screenPosOffset = (headPos + camAngles:Up() * 5):ToScreen()
								local size = math.max(4, math.abs(screenData.y - screenPosOffset.y) * 4) -- Increased from 2.5 to 4 for larger square

								-- Draw a 2D black square over their head (shows from all directions)
								surface.SetDrawColor(0, 0, 0, 255)
								surface.DrawRect(screenData.x - size / 2, screenData.y - size / 2, size, size)
							end
						end
					end
				end
			end
		end
	end
end)
