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

local despair_font = function()
	return "Mx437 IBM PS/55 re."
end

surface.CreateFont("ZCity_Despair_Text", {
	font = despair_font(),
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
	["$pp_colour_colour"] = 1
}

--local potatopc = GetConVar("hg_potatopc") or CreateClientConVar("hg_potatopc", "0", true, false, "enable this if you are noob", 0, 1)
local hg_painsound = CreateClientConVar("hg_painsound", "0", true, false, "Pain sound mode: 0=default, 1=pain beat only, 2=agony.mp3, 3=altpain.ogg, 4=reality only, 5=sillypain.mp3", 0, 5)
local hg_dyingsound = CreateClientConVar("hg_dyingsound", "0", true, false, "Dying sound mode: 0=default, 1=consciousbeat only, 2=dying.ogg no shake, 3=alto2.ogg no shake, 4=itsallcomingtoanend only, 5=sillydying.mp3, 6=fuck.mp3", 0, 6)
local hg_otrubsound = CreateClientConVar("hg_otrubsound", "0", true, false, "Otrub sound mode: 0=default, 1=altotrub.ogg, 2=sleepy.ogg, 3=itssoover.mp3, 4=ngaimcooked.mp3", 0, 4)
local hg_dyingpulse = CreateClientConVar("hg_dyingpulse", "1", true, false, "Detect peaks for screen shake when dying", 0, 1)
local hg_laivlik = CreateClientConVar("hg_laivlik", "1", true, false, "Show black square on skull destruction: 0=off, 1=on", 0, 1)
local hg_damage_corner_distortion = CreateClientConVar("hg_damage_corner_distortion", "1", true, false, "Distort screen corners from pain and head trauma", 0, 1)
local snd_musicvolume = GetConVar("snd_musicvolume")
local themeVolume = CreateClientConVar("hg_theme_volume", "1", true, false, "Volume multiplier for despair, panic, and giving-up themes", 0, 2)
local hook_Run = hook.Run
local hg_despairsystem_convar
local function despair_system_mode()
	if not hg_despairsystem_convar then hg_despairsystem_convar = GetConVar("hg_despairsystem") end
	return hg_despairsystem_convar and hg_despairsystem_convar:GetInt() or 0
end
local zcity_mental_effects_convar
local zcity_mental_enabled_convar
local function mental_effects_enabled()
	if not zcity_mental_enabled_convar then zcity_mental_enabled_convar = GetConVar("zcity_delta_mental_enabled") end
	if zcity_mental_enabled_convar and not zcity_mental_enabled_convar:GetBool() then return false end
	if not zcity_mental_effects_convar then zcity_mental_effects_convar = GetConVar("zcity_delta_mental_effects_enabled") end
	return not zcity_mental_effects_convar or zcity_mental_effects_convar:GetBool()
end

hook.Add("PlayerSpawn", "RandomizeSounds", function(ply)
	if ply == LocalPlayer() then
		RunConsoleCommand("hg_painsound", math.random(0, 5))
		RunConsoleCommand("hg_dyingsound", math.random(0, 6))
	end
end)
hook.Add("RenderScreenspaceEffects", "homigrad", function()
	tab["$pp_colour_brightness"] = 0
	tab["$pp_colour_contrast"] = 1
	tab["$pp_colour_colour"] = 1
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

	hook_Run("Post Pre Post Processing")

	hook_Run("Post Post Processing")
	DrawColorModify(tab)
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

local pickupHaloColor = Color(255, 255, 255, 255)
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

local pickuphalo = {}
local function CanPickupHalo(ent)
	if not IsValid(ent) then return false end
	if ent:IsNPC() or ent:IsPlayer() or ent:IsWorld() then return false end
	if ent:GetNoDraw() then return false end
	if ent.IsZPickup then return true end
	if haloents[ent.Base] or haloents[ent:GetClass()] then return true end
	if ent:IsWeapon() and haloents[ent.Base] then return true end
	return false
end

hook.Add( "PreDrawHalos", "AddPropHalos", function()
	table.Empty(pickuphalo)

	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return end

	for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 72)) do
		if CanPickupHalo(ent) then
			pickuphalo[#pickuphalo + 1] = ent
		end
	end

	if #pickuphalo > 0 then
		halo.Add(pickuphalo, pickupHaloColor, 1, 1, 1)
	end
end )

-- funny :)

--that one furry game


local painMat = Material("effects/shaders/zb_grain")
local noiseMat = Material("effects/shaders/zb_grainwhite")
local vignetteMat = Material("effects/shaders/zb_vignette")
local assimilationMat = Material("effects/shaders/zb_assimilation")
local coldMat = Material("effects/shaders/zb_colda")
local grainMat = Material("effects/shaders/zb_grain2")
local heatMat = Material("effects/shaders/zb_heat")
local chromaticMat = Material("effects/shaders/merc_chromaticaberration")
local blindMat = Material("effects/shaders/zb_blind")
local zombMat = grainMat -- Material("effects/shaders/zb_zomb")
local hurtoverlay = Material("zcity/neurotrauma/damageOverlay.png")

local PainLerp = 0
local O2Lerp = 0
local AnalgesiaLerp = 0
local assimilatedLerp = 0
local tempLerp = 36.6
local headtraumaSaturation = 0
local suicideLerp = 0
local suicideViewAng = Angle()
local addtime = CurTime()

local show_image_time = 0
local show_some_images_time = 0
local lobotomy_memory_mat
local lobotomy_memory_total = 1
local lobotomy_memory_flash = false
local lobotomy_recent_trauma = 0
local lobotomy_recent_trauma_power = 0
local lobotomy_mats = {
	[1] = Material("overlays/photopsiaoverlay1.png"),
	[2] = Material("overlays/photopsiaoverlay2.png"),
	[3] = Material("overlays/photopsiaoverlay3.png"),
	[4] = Material("overlays/photopsiaoverlay4.png"),
	[5] = Material("overlays/peripheralorboverlay.png"),
	[6] = Material("overlays/tallflash1.png"),
	[7] = Material("overlays/tallflash2.png"),
	[8] = Material("overlays/tallflash3.png")
}

local function getLobotomyMemoryMat()
	local screens = hg and hg.screens
	if not screens then return end

	local valid = {}
	for i = 1, #screens do
		local mat = screens[i]
		if mat and not mat:IsError() then
			valid[#valid + 1] = mat
		end
	end

	if #valid <= 0 then return end
	return valid[math.random(#valid)]
end

local function drawLobotomyFlash(alpha)
	local mat = lobotomy_mats[math.random(#lobotomy_mats)]
	if not mat then return end

	local rand = 5
	surface.SetDrawColor(255, 255, 255, alpha or 255)
	surface.SetMaterial(mat)
	surface.DrawTexturedRect(-math.random(rand), -math.random(rand), ScrW() + math.random(rand), ScrH() + math.random(rand))
end

local function stopthings()
	PainLerp = 0
	O2Lerp = 0
	AnalgesiaLerp = 0
	shockLerp = 0
	assimilatedLerp = 0
	tempLerp = 36.6
	headtraumaSaturation = 0
	consciousnessLerp = 1
	grayscaleLerp = 0

	lply.tinnitus = 0
	
	if IsValid(PainStation) then
		PainStation:Stop()
		PainStation = nil
	end

	if IsValid(NoiseStation) then
		NoiseStation:Stop()
		NoiseStation = nil
	end

	if IsValid(NoiseStation2) then
		NoiseStation2:Stop()
		NoiseStation2 = nil
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

	if IsValid(SillypainStation) then
		SillypainStation:Stop()
		SillypainStation = nil
	end

	if IsValid(DyingStation) then
		DyingStation:Stop()
		DyingStation = nil
	end

	if IsValid(SillydyingStation) then
		SillydyingStation:Stop()
		SillydyingStation = nil
	end

	if IsValid(ItssooverStation) then
		ItssooverStation:Stop()
		ItssooverStation = nil
	end

	if IsValid(AltotrubStation) then
		AltotrubStation:Stop()
		AltotrubStation = nil
	end

	if IsValid(SleepyStation) then
		SleepyStation:Stop()
		SleepyStation = nil
	end

	if IsValid(FuckStation) then
		FuckStation:Stop()
		FuckStation = nil
	end

	if IsValid(NgaimCookedStation) then
		NgaimCookedStation:Stop()
		NgaimCookedStation = nil
	end

	if IsValid(NoisesStation) then
		NoisesStation:Stop()
		NoisesStation = nil
	end

	if IsValid(ConsciousnessWhiteNoise) then
		ConsciousnessWhiteNoise:Stop()
		ConsciousnessWhiteNoise = nil
	end

	if IsValid(EndStation) then
		EndStation:Stop()
		EndStation = nil
	end
	if IsValid(WhiteNoiseStation) then
        WhiteNoiseStation:Stop()
        WhiteNoiseStation = nil
    end

	if IsValid(Alto2Station) then
		Alto2Station:Stop()
		Alto2Station = nil
	end

	if IsValid(GivingUpStation) then
		GivingUpStation:Stop()
		GivingUpStation = nil
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
local despairLerp = 0
local despairVisualLerp = 0
local despairTextLerp = 0
local giveUpWhiteLerp = 0
local WhiteNoiseStation
local soundRetry = {}
local function canRetrySound(key, station)
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
		despairLerp = 0
		despairVisualLerp = 0
		despairTextLerp = 0
		tab["$pp_colour_brightness"] = 0
		tab["$pp_colour_contrast"] = 1
		tab["$pp_colour_colour"] = 1
		return
	end
	if not lply:Alive() then
		stopthings()
		despairLerp = 0
		despairVisualLerp = 0
		despairTextLerp = 0
		tab["$pp_colour_brightness"] = 0
		tab["$pp_colour_contrast"] = 1
		tab["$pp_colour_colour"] = 1
		return
	end

	local spect = IsValid(lply:GetNWEntity("spect")) and lply:GetNWEntity("spect")
	
	if IsValid(PainStation) then
		PainStation:SetVolume(0)
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
	if IsValid(SillypainStation) then
		SillypainStation:SetVolume(0)
	end
	
	if !lply:Alive() and !IsValid(spect) then stopthings() return end
	if !lply:Alive() and viewmode != 1 then stopthings() return end
	local organism = lply:Alive() and (lply.new_organism or lply.organism) or (IsValid(spect) and (spect.new_organism or spect.organism))
	if not organism then stopthings() return end
	if not organism.brain then stopthings() return end
	local org = organism

    -- Concussion and low blood blur
    local blurAmount = 0
    if org.concussion and org.concussion > 2 then
        blurAmount = math.min((org.concussion - 2) / 8, 1) * 4
    end

    if org.blood and org.blood < 4000 then
        blurAmount = math.max(blurAmount, math.min((4000 - org.blood) / 3500, 1) * 5)
    end

    local adrenaline = org.adrenaline or 0
    if adrenaline > 1.5 then
        blurAmount = math.max(blurAmount, (adrenaline - 1.5) * 3)

		local adrenalineShock = (adrenaline - 1.5) * 2
        if not (lply:IsBerserk() or lply:IsStimulated()) then
            render.UpdateScreenEffectTexture()
            heatMat:SetFloat("$c0_x", -CurTime() * 0.18)
            heatMat:SetFloat("$c0_y", adrenalineShock * 0.01)
            heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.75) - 1.5) * (adrenalineShock * 0.1))
            render.SetMaterial(heatMat)
            render.DrawScreenQuad()

            render.UpdateScreenEffectTexture()
            chromaticMat:SetFloat("$c0_x", adrenalineShock * 0.04 * 1.5)
            chromaticMat:SetInt("$c0_y", 1)
            render.SetMaterial(chromaticMat)
            render.DrawScreenQuad()
        end
        render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", adrenalineShock * 0.6)
		vignetteMat:SetFloat("$c1_y", adrenalineShock * 0.8)
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()
    end

    if blurAmount > 0 then
        DrawToyTown(blurAmount, ScrH() / 2)
    end

	local bothEyesGone = (org.eyeL or 0) >= 1 and (org.eyeR or 0) >= 1
	if org.blindness or amtflashed >= 0.8 or bothEyesGone then
		local blindness = ((org.blindness and math.Round(org.blindness) == 0) or amtflashed >= 0.8 or bothEyesGone) and 0 or (org.blindness)
		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()
		
		blindMat:SetFloat("$c0_x", 5)
		blindMat:SetFloat("$c0_y", CurTime())
		blindMat:SetFloat("$c0_z", math.Round(blindness))
	
		render.SetMaterial(blindMat)
		render.DrawScreenQuad()
	end

	if (org.consciousness < 0.7) then
		lerpblood = LerpFT(0.01, lerpblood or 0, math.Clamp((0.7 - org.consciousness) * 5, 0, 1) * 255)
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
		surface.DrawTexturedRect(-ScrW() * 2.0, -ScrH() * 2.0, ScrW() * 5, ScrH() * 5)
		//ViewPunch(Angle(-amt * 1, amt2 * 1,0))
		//ViewPunch2(Angle(-amt * 1, amt2 * 1,0))
	end
	
	local painMode = hg_painsound:GetInt()

	if canRetrySound("PainStation", PainStation) then
		sound.PlayFile("sound/zbattle/pain_beat.ogg", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				PainStation = station
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
		sound.PlayFile("sound/altpain.ogg", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				AltpainStation = station
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
		sound.PlayFile("sound/dying.ogg", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				DyingStation = station
				station:EnableLooping(true)
			end
		end)
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

	if canRetrySound("Alto2Station", Alto2Station) then
		sound.PlayFile("sound/alto2.ogg", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				Alto2Station = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("AltotrubStation", AltotrubStation) then
		sound.PlayFile("sound/altotrub.ogg", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				AltotrubStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("SleepyStation", SleepyStation) then
		sound.PlayFile("sound/sleepy.ogg", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				station:SetTime(math.min(math.Rand(0, station:GetLength()), 139))
				SleepyStation = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("ConsciousnessWhiteNoise", ConsciousnessWhiteNoise) then
		sound.PlayFile("sound/homigrad/whitenoise.wav", "noblock noplay", function(station)
			if IsValid(station) then
				station:SetVolume(0)
				station:Play()
				ConsciousnessWhiteNoise = station
				station:EnableLooping(true)
			end
		end)
	end

	if canRetrySound("NoisesStation", NoisesStation) then
		sound.PlayFile("sound/noises.ogg", "noblock noplay", function(station)
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

	local o2 = org.o2[1] or 0
	o2 = o2 + (org.CO or 0)
	local brain = org.brain or 0
	O2Lerp = LerpFT(0.01, O2Lerp, (30 - o2) * (org.otrub and 2 or 10) + (brain * 100) * (org.otrub and 1 or 5))
	AnalgesiaLerp = LerpFT(0.04, AnalgesiaLerp, math.Clamp(((org.analgesia or 0) - 0.35) / 2.4, 0, 1))

	tempLerp = LerpFT(0.01, tempLerp, org.temperature)

	if AnalgesiaLerp > 0.005 then
		local pulse = (math.sin(CurTime() * 1.35) + 1) * 0.5
		local drugFx = AnalgesiaLerp * (0.75 + pulse * 0.25)

		DrawMaterialOverlay("particle/warp4_warp_noz", -drugFx * 0.045)

		if not (lply:IsBerserk() or lply:IsStimulated()) then
			render.UpdateScreenEffectTexture()
			heatMat:SetFloat("$c0_x", -CurTime() * 0.08)
			heatMat:SetFloat("$c0_y", drugFx * 0.008)
			heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.5) - 1.5) * drugFx * 0.08)
			render.SetMaterial(heatMat)
			render.DrawScreenQuad()

			render.UpdateScreenEffectTexture()
			chromaticMat:SetFloat("$c0_x", drugFx * 0.018)
			chromaticMat:SetInt("$c0_y", 1)
			render.SetMaterial(chromaticMat)
			render.DrawScreenQuad()
		end

		tab["$pp_colour_colour"] = math.max(tab["$pp_colour_colour"] or 1, 1 + drugFx * 0.45)
		tab["$pp_colour_brightness"] = (tab["$pp_colour_brightness"] or 0) + drugFx * 0.025
		tab["$pp_colour_contrast"] = math.max(tab["$pp_colour_contrast"] or 1, 1 + drugFx * 0.04)
	end

	if lply.PlayerClassName == "headcrabzombie" then
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

	local pain = org.pain or 0
	pain = math.max(pain - 15, 0)
	local shock = (org.shock or 0) * 1 + (1 - org.consciousness) * 40
	shockLerp = LerpFT(0.01, shockLerp or 0, shock)
	consciousnessLerp = LerpFT(org.consciousness < (consciousnessLerp or 1) and 1 or 0.01, consciousnessLerp or 1, org.consciousness)
	-- local immobilization = org.immobilization
	PainLerp = LerpFT(0.05, PainLerp, math.max(pain * (org.otrub and 0.05 or 1), 0))
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
			sound.PlayFile("sound/zbattle/furry/conversion/assimilation_noise3.ogg", "noblock noplay", function(station, err)
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

	if (org.consciousness or 0) < 1 then
		local consciousness = 1 - consciousnessLerp
		render.UpdateScreenEffectTexture()
		render.UpdateFullScreenDepthTexture()

		grainMat:SetFloat("$c0_x", CurTime()) -- time
		grainMat:SetFloat("$c0_y", 0.5) -- gate
		grainMat:SetFloat("$c0_z", consciousness * 3) -- Pixelize
		grainMat:SetFloat("$c1_x", consciousness) -- lerp
		grainMat:SetFloat("$c1_y", 10) -- vignette intensity
		grainMat:SetFloat("$c1_z", consciousness) -- BlurIntensity
		grainMat:SetFloat("$c2_x", 0) -- r
		grainMat:SetFloat("$c2_y", 0) -- g
		grainMat:SetFloat("$c2_z", 0) -- b
		grainMat:SetFloat("$c3_x", 0) -- ImageIntensity

		render.SetMaterial(grainMat)
		render.DrawScreenQuad()
	end

	-- Consciousness whitenoise: ramps up from 0 at 0.95 consciousness to full at 0.1
	-- Despair overrides this sound
	local mentalDistress = math.Clamp(tonumber(lply:GetNWFloat("zcity_delta_mental_distress", 0)) or 0, 0, 1)
	if mentalDistress <= 0 then mentalDistress = math.Clamp(org.despair or 0, 0, 1) end
	if despair_system_mode() == 0 or not mental_effects_enabled() then mentalDistress = 0 end

	if not org.otrub and (org.consciousness or 1) < 0.95 and mentalDistress <= 0 then
		local consciousnessVol = math.Remap(org.consciousness, 0.95, 0.1, 0, 1)
		consciousnessVol = math.Clamp(consciousnessVol, 0, 1)

		if IsValid(ConsciousnessWhiteNoise) then
			ConsciousnessWhiteNoise:SetVolume(consciousnessVol * 0.333)
		end
	else
		if IsValid(ConsciousnessWhiteNoise) then
			ConsciousnessWhiteNoise:SetVolume(0)
		end
	end

	if org.consciousness < 0.5 and mentalDistress <= 0 then
        if canRetrySound("WhiteNoiseStation", WhiteNoiseStation) then
            sound.PlayFile("sound/whitenoise.wav", "noblock noplay", function(station)
                if IsValid(station) then
                    station:EnableLooping(true)
                    station:Play()
                    WhiteNoiseStation = station
                end
            end)
        end
    else
        if IsValid(WhiteNoiseStation) then
            WhiteNoiseStation:Stop()
            WhiteNoiseStation = nil
        end
    end

    if IsValid(WhiteNoiseStation) then
        local vol = math.Remap(org.consciousness, 0, 0.5, 0.6, 0)
        WhiteNoiseStation:SetVolume(vol * 0.5)
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
		local strobe = math.ease.InOutSine(math.abs(math.cos(CurTime() * 2))) * PainLerp / 2
		pain = PainLerp + strobe
		shock = shockLerp
		
		-- Extreme pain flickering effect (> 90)
		local extremePainFlicker = 0
		if pain > 90 then
			local flickerIntensity = (pain - 90) / 30 -- 0 to 1 as pain goes from 90 to 120
			extremePainFlicker = math.abs(math.sin(CurTime() * 15)) * flickerIntensity * 0.5
		end
		
		render.UpdateScreenEffectTexture()

		vignetteMat:SetFloat("$c2_x", CurTime() + 10000) //Time
		vignetteMat:SetFloat("$c0_z", org.otrub and 5 or (pain / 30 + math.max(shock - 5, 0) / 2 + extremePainFlicker)) //ColorIntensity
		vignetteMat:SetFloat("$c1_y", org.otrub and 10 or (pain / 30 + math.max(shock - 5, 0) / 2 + extremePainFlicker)) //Vignette

		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()

		painMat:SetFloat("$c2_x", CurTime() + 10000) //Time
		painMat:SetFloat("$c0_y", 0.8) //Gate
		painMat:SetFloat("$c0_z", 1 + extremePainFlicker) //ColorIntensity
		painMat:SetFloat("$c1_x", math.Clamp(pain / 90 + extremePainFlicker, 0, 0.85)) //Lerp
		painMat:SetFloat("$c1_y", math.Clamp(pain / 90 + extremePainFlicker, 0, 0.85)) //Vignette

		render.SetMaterial(painMat)
		render.DrawScreenQuad()

		render.UpdateScreenEffectTexture()
		chromaticMat:SetFloat("$c0_x", math.Clamp(shockLerp / 100 + extremePainFlicker * 0.3, 0, 0.35) * 1.5)
		chromaticMat:SetInt("$c0_y", 1)
		render.SetMaterial(chromaticMat)
		render.DrawScreenQuad()

		if hg_damage_corner_distortion:GetBool() then
			local painWarp = math.Clamp((pain - 18) / 92, 0, 1)
			local trauma = math.Clamp(painWarp + (shock / 170) + (org.brain or 0) * 0.65 + (org.concussion or 0) / 14, 0, 1.25)
			if painWarp > 0.01 or (org.brain or 0) > 0.12 or (org.concussion or 0) > 1 then
				render.UpdateScreenEffectTexture()
				heatMat:SetFloat("$c0_x", math.sin(CurTime() * 1.7) * trauma * 0.025)
				heatMat:SetFloat("$c0_y", trauma * 0.018)
				heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.9) - 1.5) * trauma * 0.16)
				render.SetMaterial(heatMat)
				render.DrawScreenQuad()
			end
		end

		if org.otrub then
			DrawMotionBlur(0.1, 1., 0.01)
			lply:ScreenFade( SCREENFADE.IN, Color(0,0,0), 2, 0.5 )
		end
		
		//if pain > 10 then
			local painVol = math.Clamp(math.Remap(pain, 0, 120, 0, 6), 0, 6)

			-- Panic attack and despair override pain sounds (except brain damage)
			local panicAttack = (org.panicAttack or false)
			local brain = (org.brain or 0)
			local overridePainSounds = (panicAttack or mentalDistress > 0.5) and brain < 0.01

			local targetPainVol = 0
			local targetRealityVol = 0
			local targetAgonyVol = 0
			local targetAltpainVol = 0
			local targetSillypainVol = 0

			if painMode == 0 then
				-- Default: both pain_beat and reality play
				targetPainVol = painVol
				targetRealityVol = painVol
			elseif painMode == 1 then
				-- Only pain_beat at same volume as reality.mp3
				targetPainVol = painVol
			elseif painMode == 2 then
				-- Only agony.mp3 instead of reality or painbeat
				targetAgonyVol = painVol
			elseif painMode == 3 then
				-- Only altpain.ogg instead of reality or painbeat
				targetAltpainVol = painVol
			elseif painMode == 4 then
				-- Only reality.mp3
				targetRealityVol = painVol
			elseif painMode == 5 then
				-- Only sillypain.mp3
				targetSillypainVol = painVol
			end

			-- Panic attack and despair lower the active pain sound(s)
			if overridePainSounds then
				targetPainVol = targetPainVol * 0.6
				targetRealityVol = targetRealityVol * 0.6
				targetAgonyVol = targetAgonyVol * 0.6
				targetAltpainVol = targetAltpainVol * 0.6
				targetSillypainVol = targetSillypainVol * 0.6
			end

			if IsValid(PainStation) then PainStation:SetVolume(targetPainVol) end
			if IsValid(RealityStation) then RealityStation:SetVolume(targetRealityVol) end
			if IsValid(AgonyStation) then AgonyStation:SetVolume(targetAgonyVol) end
			if IsValid(AltpainStation) then AltpainStation:SetVolume(targetAltpainVol) end
			if IsValid(SillypainStation) then SillypainStation:SetVolume(targetSillypainVol) end
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

	if brain > 0.01 then
		local chooser = 1
		for i, choose in ipairs(stations) do
			if choose < brain then
				chooser = i
			end
		end
	
		if choosera != chooser or canRetrySound("BrainTraumaStation", BrainTraumaStation) then
			if IsValid(BrainTraumaStation) then
				BrainTraumaStation:Stop()
				BrainTraumaStation = nil
			end

			sound.PlayFile("sound/zcitysnd/real_sonar/brainhemorrhagestage"..chooser..".mp3", "noblock noplay", function(station, err)
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
			BrainTraumaStation:SetVolume(math.Clamp(!org.otrub and brain * 2 or 0, 0, 1))
		end
	else
		if IsValid(BrainTraumaStation) then
			BrainTraumaStation:Stop()
			BrainTraumaStation = nil
		end
	end

	//if brain > 0.1 and not org.otrub and show_some_images_time > 0 and false then
	if lply.tinnitus and lply.tinnitus > CurTime() and lply:Alive() and lply.tinnitusBrainDamage then
		if canRetrySound("Tinnitus", Tinnitus) then
			local choice = math.random(5)
			local soundFile
			if choice == 1 then
				soundFile = "sound/tinnitus.wav"
			elseif choice == 2 then
				soundFile = "sound/tinnituslong.wav"
			else
				soundFile = "sound/zcitysnd/real_sonar/tinnitus"..math.random(3)..".mp3"
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
			Tinnitus:SetVolume(math.min(math.max(lply.tinnitus - CurTime(), 0) / 10, 1))
		end
	else
		if IsValid(Tinnitus) then
			Tinnitus:Stop()
			Tinnitus = nil
		end
	end
	
	if ((org.skull or 0) > 0.2 or (org.jaw or 0) > 0.2 or (org.concussion or 0) > 0) and not org.otrub then
		if show_some_images_time > 0 then
			brain_motionblur = true
			DrawMotionBlur(0.1, 1., 0.1)
			show_some_images_time = show_some_images_time - 1
			local recentTrauma = lobotomy_recent_trauma > CurTime()
			local traumaPower = recentTrauma and lobotomy_recent_trauma_power or 0
			local flashChance = recentTrauma and math.max(2, 7 - traumaPower * 4) or math.max(2, 10 * (1 - brain))
			if show_image_time <= 0 and math.random(flashChance) < 2 then
				show_image_time = 250 * (0.1 * 3) * math.Rand(0.1, 1) * (math.random(2) == 1 and 0.1 or 1)
				lobotomy_memory_total = math.max(show_image_time, 1)
				local memoryChance = math.Clamp(0.08 + (brain or 0) * 0.22 + traumaPower * 0.18, 0.08, 0.45)
				lobotomy_memory_flash = math.Rand(0, 1) < memoryChance
				lobotomy_memory_mat = lobotomy_memory_flash and getLobotomyMemoryMat() or nil
			end

			if show_image_time > 0 then
				show_image_time = show_image_time - 1

				if lobotomy_memory_flash and lobotomy_memory_mat then
					local phase = 1 - math.Clamp(show_image_time / lobotomy_memory_total, 0, 1)
					local alpha = 255 * math.sin(phase * math.pi)
					local rand = 12
					surface.SetDrawColor(255, 255, 255, alpha)
					surface.SetMaterial(lobotomy_memory_mat)
					surface.DrawTexturedRect(-math.random(rand), -math.random(rand), ScrW() + math.random(rand * 2), ScrH() + math.random(rand * 2))

					render.UpdateScreenEffectTexture()
					vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
					vignetteMat:SetFloat("$c0_z", 3.0)
					vignetteMat:SetFloat("$c1_y", 5.0)
					render.SetMaterial(vignetteMat)
					render.DrawScreenQuad()
				else
					drawLobotomyFlash(255)
				end
			end
		else
			brain_motionblur = false
			local chance = (brain or 0) * 15
			if (org.skull or 0) >= 1 then
				chance = chance + 6
			end
			if (org.jaw or 0) >= 1 then
				chance = chance + 3
			end
			show_some_images_time = math.random(1200) < chance and 250 or 0
		end
	else
		brain_motionblur = false
		show_image_time = 0
		lobotomy_memory_mat = nil
		lobotomy_memory_flash = false
		if lobotomy_recent_trauma <= CurTime() then
			lobotomy_recent_trauma_power = 0
		end
	end
	
	if O2Lerp > 1 then
		render.UpdateScreenEffectTexture()
		
		o2 = O2Lerp
		
		noiseMat:SetFloat("$c0_y", 1 - o2 / 200) //Gate
		noiseMat:SetFloat("$c0_z", 1) //ColorIntensity
		noiseMat:SetFloat("$c1_x", math.Clamp(o2 / 200, 0, 2)) //Lerp
		noiseMat:SetFloat("$c1_y", o2 * (!org.otrub and 0.05 or 1)) //Vignette
		noiseMat:SetFloat("$c2_x", CurTime() + 10000) //Time

		render.SetMaterial(noiseMat)
		render.DrawScreenQuad()
		
		if o2 > 50 and !org.otrub then
			local dyingMode = hg_dyingsound:GetInt()

			-- Despair is handled by the cl_despair theme; dying sounds keep playing in the background

			if canRetrySound("NoiseStation2", NoiseStation2) then
				sound.PlayFile("sound/zbattle/conscioustypebeat.ogg", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength()), 87)
						NoiseStation2 = station
						station:EnableLooping(true)
					end
				end)
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

			local consciousVol = math.Clamp((o2 - 50) / 100 + (brain > 0.3 and (brain - 0.3) * 5 or 0), 0, 3)
			hg.consciousBeatIntensity = consciousVol

			-- Dying ambience when bleeding out (low blood + active bleeding)
			local blood = org.blood or 5000
			local bleed = org.bleed or 0
			local bleedingOut = blood < 4000 and bleed > 0

			if bleedingOut then
				local bleedSeverity = math.Clamp((3500 - blood) / 3500, 0, 1)
				consciousVol = math.max(consciousVol, bleedSeverity * 2)
				hg.consciousBeatIntensity = math.max(hg.consciousBeatIntensity, bleedSeverity * 2)
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
					if hg_dyingpulse:GetInt() == 1 and IsValid(DyingStation) and DyingStation.GetFFT and DyingStation:GetState() == GMOD_CHANNEL_PLAYING then
						local fft = DyingStation:GetFFT(512)
						if fft then
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
				-- Only itssoover.mp3 with sound peak detection for screen shake
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

					local fft = ItssooverStation:GetFFT(512)
					if fft then
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
		else
			hg.consciousBeatIntensity = 0
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
			if IsValid(SillydyingStation) then
				SillydyingStation:SetVolume(0)
			end
			if IsValid(ItssooverStation) then
				ItssooverStation:SetVolume(0)
			end
		end
		
		if o2 > 20 and org.otrub then
			local otrubMode = hg_otrubsound:GetInt()

			if canRetrySound("NoiseStation", NoiseStation) then
				sound.PlayFile("sound/zbattle/unconscious_type_beat.ogg", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						NoiseStation = station
						station:EnableLooping(true)
					end
				end)
			end

			if canRetrySound("AltotrubStation", AltotrubStation) then
				sound.PlayFile("sound/altotrub.ogg", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						AltotrubStation = station
						station:EnableLooping(true)
					end
				end)
			end

			if canRetrySound("SleepyStation", SleepyStation) then
				sound.PlayFile("sound/sleepy.ogg", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						SleepyStation = station
						station:EnableLooping(true)
					end
				end)
			end

			if canRetrySound("FuckStation", FuckStation) then
				sound.PlayFile("sound/itssoover.mp3", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						FuckStation = station
						station:EnableLooping(true)
					end
				end)
			end

			if canRetrySound("NgaimCookedStation", NgaimCookedStation) then
				sound.PlayFile("sound/ngaimcooked.mp3", "noblock noplay", function(station)
					if IsValid(station) then
						station:SetVolume(0)
						station:Play()
						station:SetTime(math.min(brain / 0.5 * station:GetLength(), 200))
						NgaimCookedStation = station
						station:EnableLooping(true)
					end
				end)
			end

			local otrubVol = math.Clamp((o2 - 30) / 100 + (brain > 0.3 and (brain - 0.3) * 5 or 0), 0, 3)

			if otrubMode == 0 then
				-- Default: unconscious_type_beat
				if IsValid(NoiseStation) then
					NoiseStation:SetVolume(otrubVol)
				end
				if IsValid(AltotrubStation) then
					AltotrubStation:SetVolume(0)
				end
				if IsValid(SleepyStation) then
					SleepyStation:SetVolume(0)
				end
				if IsValid(FuckStation) then
					FuckStation:SetVolume(0)
				end
				if IsValid(NgaimCookedStation) then
					NgaimCookedStation:SetVolume(0)
				end
			elseif otrubMode == 1 then
				-- Use altotrub.ogg instead
				if IsValid(NoiseStation) then
					NoiseStation:SetVolume(0)
				end
				if IsValid(AltotrubStation) then
					AltotrubStation:SetVolume(otrubVol)
				end
				if IsValid(SleepyStation) then
					SleepyStation:SetVolume(0)
				end
				if IsValid(FuckStation) then
					FuckStation:SetVolume(0)
				end
				if IsValid(NgaimCookedStation) then
					NgaimCookedStation:SetVolume(0)
				end
			elseif otrubMode == 2 then
				-- Use sleepy.ogg instead
				if IsValid(NoiseStation) then
					NoiseStation:SetVolume(0)
				end
				if IsValid(AltotrubStation) then
					AltotrubStation:SetVolume(0)
				end
				if IsValid(SleepyStation) then
					SleepyStation:SetVolume(otrubVol)
				end
				if IsValid(FuckStation) then
					FuckStation:SetVolume(0)
				end
				if IsValid(NgaimCookedStation) then
					NgaimCookedStation:SetVolume(0)
				end
			elseif otrubMode == 3 then
				-- Use fuck.mp3 instead
				if IsValid(NoiseStation) then
					NoiseStation:SetVolume(0)
				end
				if IsValid(AltotrubStation) then
					AltotrubStation:SetVolume(0)
				end
				if IsValid(SleepyStation) then
					SleepyStation:SetVolume(0)
				end
				if IsValid(FuckStation) then
					FuckStation:SetVolume(otrubVol)
				end
				if IsValid(NgaimCookedStation) then
					NgaimCookedStation:SetVolume(0)
				end
			elseif otrubMode == 4 then
				-- Use ngaimcooked.mp3 instead
				if IsValid(NoiseStation) then
					NoiseStation:SetVolume(0)
				end
				if IsValid(AltotrubStation) then
					AltotrubStation:SetVolume(0)
				end
				if IsValid(SleepyStation) then
					SleepyStation:SetVolume(0)
				end
				if IsValid(FuckStation) then
					FuckStation:SetVolume(0)
				end
				if IsValid(NgaimCookedStation) then
					NgaimCookedStation:SetVolume(otrubVol)
				end
			end
		else
			if IsValid(NoiseStation) then
				NoiseStation:SetVolume(0)
			end
			if IsValid(AltotrubStation) then
				AltotrubStation:SetVolume(0)
			end
			if IsValid(SleepyStation) then
				SleepyStation:SetVolume(0)
			end
			if IsValid(FuckStation) then
				FuckStation:SetVolume(0)
			end
			if IsValid(NgaimCookedStation) then
				NgaimCookedStation:SetVolume(0)
			end
		end
	else
		if IsValid(NoiseStation) then
			NoiseStation:Stop()
			NoiseStation = nil
		end
	end

	local despair = org.givingUp and 0 or math.Clamp(tonumber(lply:GetNWFloat("zcity_delta_mental_distress", 0)) or 0, 0, 1)
	if despair <= 0 then despair = math.Clamp(org.despair or 0, 0, 1) end
	if despair_system_mode() == 0 or not mental_effects_enabled() then despair = 0 end
	despairLerp = LerpFT(0.04, despairLerp, despair)
	despairVisualLerp = math.Approach(despairVisualLerp, despairLerp, FrameTime() * 0.45)

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

	local panicAttack = org and org.panicAttack or false
	local despairFx = math.Clamp((despairVisualLerp - 0.03) / 0.97, 0, 1)
	-- When panicking, the gray effect partially subsides
	local despairGrayFx = panicAttack and despairFx * 0.35 or despairFx
	if despairFx > 0.05 then
		local despairShock = despairFx ^ 0.7
		local despairGrayShock = despairGrayFx ^ 0.7
        if not (lply:IsBerserk() or lply:IsStimulated()) then
    		render.UpdateScreenEffectTexture()
    		heatMat:SetFloat("$c0_x", -CurTime() * 0.18)
    		heatMat:SetFloat("$c0_y", despairShock * 0.015)
    		heatMat:SetFloat("$c2_x", (math.sin(CurTime() * 0.75) - 1.5) * (despairShock * 0.15))
    		render.SetMaterial(heatMat)
    		render.DrawScreenQuad()
        end

		render.UpdateScreenEffectTexture()
		vignetteMat:SetFloat("$c2_x", CurTime() + 10000)
		vignetteMat:SetFloat("$c0_z", despairShock * 0.35)
		vignetteMat:SetFloat("$c1_y", despairShock * 0.55)
		render.SetMaterial(vignetteMat)
		render.DrawScreenQuad()

        if not (lply:IsBerserk() or lply:IsStimulated()) then
			-- Panic: heavier chromatic aberration, despair: lighter
			local chromAmt = panicAttack and (0.04 + despairShock * 0.09 + math.sin(CurTime() * 6) * 0.015) or (despairShock * 0.035)
    		render.UpdateScreenEffectTexture()
    		chromaticMat:SetFloat("$c0_x", chromAmt * 1.5)
    		chromaticMat:SetInt("$c0_y", 1)
    		render.SetMaterial(chromaticMat)
    		render.DrawScreenQuad()
        end

		tab["$pp_colour_brightness"] = -(despairGrayShock ^ 1.2) * 0.2
		tab["$pp_colour_contrast"] = 1 - despairGrayShock * 0.18
		tab["$pp_colour_colour"] = 1 - despairGrayShock * 0.45
		tab["$pp_colour_mulr"] = -despairGrayShock * 0.06
		tab["$pp_colour_mulg"] = -despairGrayShock * 0.04
		tab["$pp_colour_mulb"] = -despairGrayShock * 0.02
	end

	-- Despair sound is handled by cl_despair.lua module

	-- Give up mechanic: white vignette and itssofuckingover.mp3
	if org.givingUp then
		-- Give-up theme layers in the background alongside other dying/despair music.
		-- It does not override or mute any other themes.

		-- Play itssofuckingover.mp3
		if canRetrySound("GivingUpStation", GivingUpStation) then
			sound.PlayFile("sound/itssofuckingover.mp3", "noblock noplay", function(station, err)
				if err or not IsValid(station) then return end
				station:SetVolume(0)
				station:Play()
				GivingUpStation = station
				station:EnableLooping(true)
			end)
		end

		if IsValid(GivingUpStation) then
			GivingUpStation:SetVolume(1.5 * themeVolume:GetFloat())
			if GivingUpStation:GetTime() >= 120 then
				GivingUpStation:SetTime(0)
			end
		end

		giveUpWhiteLerp = math.Approach(giveUpWhiteLerp, 1, FrameTime() * 0.08)
		local whiteAmt = giveUpWhiteLerp * 0.35
		tab["$pp_colour_addr"] = whiteAmt * 0.22
		tab["$pp_colour_addg"] = whiteAmt * 0.22
		tab["$pp_colour_addb"] = whiteAmt * 0.22
		tab["$pp_colour_colour"] = math.max(tab["$pp_colour_colour"] or 1, 1 - whiteAmt * 0.45)
		tab["$pp_colour_brightness"] = (tab["$pp_colour_brightness"] or 0) + whiteAmt * 0.18
		tab["$pp_colour_contrast"] = math.min(tab["$pp_colour_contrast"] or 1, 1 - whiteAmt * 0.12)

		-- Suppress regular despair visual effects
		despairVisualLerp = 0
	else
		giveUpWhiteLerp = math.Approach(giveUpWhiteLerp, 0, FrameTime() * 0.3)
		tab["$pp_colour_addr"] = 0
		tab["$pp_colour_addg"] = 0
		tab["$pp_colour_addb"] = 0
		-- Stop the give-up theme once no longer giving up
		if IsValid(GivingUpStation) then
			GivingUpStation:Stop()
			GivingUpStation = nil
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

		local fear = org.fear or 0
		if fear > 0 then
			grayscaleTarget = grayscaleTarget + math.Clamp(fear / 2, 0, 1) * 0.18
		end

		local suppForce = (SIB_suppress and SIB_suppress.Force or 0)
		if suppForce > 1 then
			grayscaleTarget = grayscaleTarget + math.Clamp((suppForce - 1) / 9, 0, 1) * 0.20
		end

		local adrenaline = org.adrenaline or 0
		if adrenaline > 4 then
			grayscaleTarget = grayscaleTarget + math.Clamp((adrenaline - 4) / 1, 0, 1) * 0.20
		end

		local blood = org.blood or 5000
		if blood < 3500 then
			grayscaleTarget = grayscaleTarget + math.Clamp((3500 - blood) / 3500, 0, 1) * 0.25
		end

		local o2 = (org.o2 and isnumber(org.o2[1])) and org.o2[1] or 100
		if o2 < 30 then
			grayscaleTarget = grayscaleTarget + math.Clamp((30 - o2) / 30, 0, 1) * 0.22
		end

		local shock = org.shock or 0
		if shock > 20 then
			grayscaleTarget = grayscaleTarget + math.Clamp((shock - 20) / 80, 0, 1) * 0.20
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
	end

	if (headtraumaSaturation or 0) > 0 then
		tab["$pp_colour_colour"] = 1 + headtraumaSaturation
		headtraumaSaturation = math.max(headtraumaSaturation - FrameTime() * 0.85, 0)
	end
end)

hook.Add("Player_Death", "ItDoesntNow", function(ply)
	local me = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(me) then return end
	if !((ply == me) or (ply == me:GetNWEntity("spect"))) then return end

	stopthings()
end)

hook.Add("Player Spawn", "ItDoesntNow", function(ply)
	local me = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(me) or ply != me then return end

	stopthings()
end)

hook.Add("DrawOverlay", "despair_text", function()
	local ply = IsValid(lply) and lply or LocalPlayer()
	if not IsValid(ply) then return end
	if !ply:Alive() then
		despairTextLerp = LerpFT(0.15, despairTextLerp, 0)
		return
	end

	local org = ply.new_organism or ply.organism
	if not org then return end
	if org.otrub then
		despairTextLerp = 0
		return
	end

	if despair_system_mode() == 0 or not mental_effects_enabled() then
		despairTextLerp = 0
		return
	end

	local despair = math.Clamp(tonumber(ply:GetNWFloat("zcity_delta_mental_distress", 0)) or 0, 0, 1)
	if despair <= 0 then despair = math.Clamp(org.despair or 0, 0, 1) end
	local target = math.Clamp((despair - 0.45) / 0.55, 0, 1)
	despairTextLerp = LerpFT(0.03, despairTextLerp, target)
	if despairTextLerp <= 0.001 then return end

	local time = CurTime()
	local sway = 10 + 16 * despairTextLerp
	local x = ScrW() * 0.5 + math.sin(time * 0.7) * sway + math.cos(time * 0.33) * sway * 0.7
	local y = ScrH() * 0.08 + math.sin(time * 0.51) * sway * 0.4
	local alpha = math.floor(255 * despairTextLerp)

	local state = ply:GetNWString("zcity_delta_mental_state", "stable")
	local text = state == "desperate" and "im so fucking scared." or state == "distress" and "i cant calm down." or "everything feels wrong."
	draw.SimpleText(text, "ZCity_Despair_Text", x + 2, y + 2, Color(0, 0, 0, math.floor(alpha * 0.7)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "ZCity_Despair_Text", x, y, Color(235, 235, 235, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
	draw.SimpleText(text, "ZCity_Despair_Text", x + 2, y + 2, Color(0, 0, 0, math.floor(alpha * 0.7)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	draw.SimpleText(text, "ZCity_Despair_Text", x, y, Color(210, 210, 210, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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
	if not organism or isbool(organism) then return end

	local bothEyesGone = (organism.eyeL or 0) >= 1 and (organism.eyeR or 0) >= 1
	if !(organism.blindness or (amtflashed or 0) >= 0.8 or bothEyesGone) then removeflash() return end
	local blindness = ((organism.blindness and math.Round(organism.blindness) == 0) or amtflashed >= 0.8 or bothEyesGone) and 0 or (organism.blindness)

	local eyesmode = math.Round(blindness)
	
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

	local dyingMode = hg_dyingsound:GetInt()
	-- Disable screen shake for modes 2, 3, 4, 5, and 6
	if dyingMode == 2 or dyingMode == 3 or dyingMode == 4 or dyingMode == 5 or dyingMode == 6 then return 0 end

	local intensity = hg.consciousBeatIntensity or 0
	if intensity <= 0.01 then return 0 end

	-- Only trigger the pulse if the sound is actually playing and hasn't been stopped
	if not IsValid(NoiseStation2) or NoiseStation2:GetState() != GMOD_CHANNEL_PLAYING or NoiseStation2:GetVolume() <= 0.01 then return 0 end

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
	if pulse > 0 then
		local shakeAmt = pulse * 2.5
		angles.p = angles.p + math.Rand(-shakeAmt, shakeAmt)
		angles.y = angles.y + math.Rand(-shakeAmt, shakeAmt)
		angles.r = angles.r + math.Rand(-shakeAmt, shakeAmt)
		-- Also modify fova for when RenderScene is disabled
		fova[1] = (fova[1] or 0) - (pulse * 20)
	end
end)

local function GetDespairCamPulse()
	-- Screen shaking disabled when in despair
	return 0, 0
end

hook.Add("TranslateFOV", "DespairBreathFov", function(ply, fov)
	local pushPull = GetDespairCamPulse()
	if pushPull ~= 0 then
		return fov + pushPull * 2.8
	end
end)

hook.Add("HG_CalcView", "DespairBreathShake", function(ply, pos, angles, fova, znear, zfar)
	local pushPull, jitter = GetDespairCamPulse()
	if pushPull == 0 and jitter == 0 then return end
	angles.p = angles.p + jitter * 0.75
	angles.y = angles.y + jitter * 0.6
	angles.r = angles.r + jitter * 0.5
	fova[1] = (fova[1] or 0) + pushPull * 2.8
end)

local HEADHIT_VOLUME = 1.0
local HEADHIT_BASE_BOOST = 1.2 -- every head hit is louder than full volume
local CONCUSSION_VOLUME = 0.45
local CONCUSSION_SOUND_PATH = "sound/concussion"
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
    sound.PlayFile(CONCUSSION_SOUND_PATH .. math.random(1, 4) .. ".mp3", "noblock noplay", function(station)
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
    local trigger_tinnitus = net.ReadBool()

    local lply = LocalPlayer()

    if trigger_tinnitus then
        if is_critical then
            surface.PlaySound("tinnituslong.wav")
            if IsValid(lply) then lply:AddTinnitus(5 + time * 0.7, false, hasBrainDamage) end
        else
            surface.PlaySound("tinnitus.wav")
            if IsValid(lply) then lply:AddTinnitus(2.5 + time * 0.5, false, hasBrainDamage) end
        end
    end

    if not IsValid(lply) then return end

    if lply.organism and lply.organism.otrub then
        hg.PlayOtrubHeadTraumaEffect(pos, time, size)
        return
    end

    hg.AddFlash(lply:EyePos(), 1, pos, time, size, true)

    -- Scale effects by the received flash duration (which is scaled by damage on the server)
    local damageScale = math.Clamp(time / 1.5, 0.2, 1.0)
    local traumaPower = math.Clamp(damageScale + (is_critical and 0.55 or 0) + (hasBrainDamage and 0.35 or 0) + (hasConcussion and 0.25 or 0), 0, 1.8)
    lobotomy_recent_trauma = CurTime() + math.Clamp(2 + traumaPower * 4, 3, 9)
    lobotomy_recent_trauma_power = math.max(lobotomy_recent_trauma_power or 0, traumaPower)
    show_some_images_time = math.max(show_some_images_time or 0, math.floor(80 + traumaPower * 140))
    if traumaPower > 0.75 then
        show_image_time = 0
    end

    if hasConcussion then
        headtraumaSaturation = math.max(headtraumaSaturation or 0, math.min(time * 9, 10))
    end

    PlayHeadhitSound(damageScale)
    if is_critical or hasBrainDamage or hasConcussion then
        PlayConcussionSound(damageScale)
    end

    -- Scaled view punch based on damage
    local punchScale = (is_critical or hasBrainDamage or hasConcussion) and 1.5 or damageScale
    ViewPunch(Angle(math.random(-10, 10) * punchScale, math.random(-8, 8) * punchScale, math.random(-3, 3) * punchScale))

    if play_knockout_sound then
        ViewPunch(Angle(math.random(-15, 15), math.random(-15, 15), math.random(-5, 5)))
    end
end)

local showing_otrub_headtrauma = false
local last_otrub_concussion_time = 0
function hg.PlayOtrubHeadTraumaEffect(pos, time, size)
    if showing_otrub_headtrauma then return end
    showing_otrub_headtrauma = true
    timer.Simple(0.5, function() showing_otrub_headtrauma = false end)

    local lply = LocalPlayer()
    if not IsValid(lply) or not lply:Alive() then return end

    PlayHeadhitSound()
    if CurTime() > last_otrub_concussion_time + 5 then
        sound.PlayFile(CONCUSSION_SOUND_PATH .. math.random(1, 4) .. ".mp3", "noblock noplay", function(station)
            if IsValid(station) then
                station:SetVolume(CONCUSSION_VOLUME)
                station:Play()
            end
        end)
        last_otrub_concussion_time = CurTime()
    end
    hg.AddFlash(lply:EyePos(), 1, pos, time, size, true)
end
hook.Add("HG_OnOtrub", "FUCKINGSHITOW", function(ply)
    if ply == LocalPlayer() then
        sound.PlayFile("sound/owfuck.ogg", "noblock noplay", function(station) if IsValid(station) then station:Play() end end)
    end
end)

local function IsSkullBrokenFully(ent, visited)
	if not IsValid(ent) then return false end

	-- Guard against cyclic references (player <-> ragdoll point at each other)
	visited = visited or {}
	if visited[ent] then return false end
	visited[ent] = true

	if ent:GetNWBool("SkullBrokenFully") or ent.HGSkullBrokenFully then return true end

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
			if ent == localPlayer and not localPlayer:ShouldDrawLocalPlayer() then continue end

			if IsSkullBrokenFully(ent) then
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

