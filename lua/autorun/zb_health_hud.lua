--мяу мяу
if SERVER then
	local SPRITES = {
		"materials/vgui/hud/health_head.png",
		"materials/vgui/hud/health_torso.png",
		"materials/vgui/hud/health_right_arm.png",
		"materials/vgui/hud/health_left_arm.png",
		"materials/vgui/hud/health_right_leg.png",
		"materials/vgui/hud/health_left_leg.png",
	}
	
	local ICONS = {
		"materials/vgui/hud/bloodmeter.png",
		"materials/vgui/hud/pulsemeter.png",
		"materials/vgui/hud/assimilationmeter.png",
		"materials/vgui/hud/o2meter.png",
		"materials/vgui/hud/o2meter_alt.png",
	}
	
	local STATUS_SPRITES = {
		"materials/vgui/hud/status_level1_bg.png",   
		"materials/vgui/hud/status_level2_bg.png",   
		"materials/vgui/hud/status_level3_bg.png",   
		"materials/vgui/hud/status_level4_bg.png",   
		
		"materials/vgui/hud/status_background.png",
		
		"materials/vgui/hud/status_pain_icon.png",
		"materials/vgui/hud/status_conscious_icon.png",
		"materials/vgui/hud/status_stamina_icon.png",
		"materials/vgui/hud/status_bleeding_icon.png",
		"materials/vgui/hud/status_internal_bleed_icon.png",
		"materials/vgui/hud/status_organ_damage.png",
		"materials/vgui/hud/status_dislocation.png",
		"materials/vgui/hud/status_spine_fracture.png",
		"materials/vgui/hud/status_leg_fracture.png",
		
		"materials/vgui/hud/status_blood_loss.png",      
		"materials/vgui/hud/status_cardiac_arrest.png",  
		"materials/vgui/hud/status_cold.png",            
		"materials/vgui/hud/status_heat.png",            
		"materials/vgui/hud/status_hemothorax.png",      
		"materials/vgui/hud/status_lungs_failure.png",   
		"materials/vgui/hud/status_overdose.png",        
		"materials/vgui/hud/status_oxygen.png",          
		"materials/vgui/hud/status_vomit.png",           
		"materials/vgui/hud/status_brain_damage.png",
		
		"materials/vgui/hud/status_adrenaline.png",
		"materials/vgui/hud/status_shock.png",
		"materials/vgui/hud/status_trauma.png",
		
		"materials/vgui/hud/status_death.png",
		"materials/vgui/hud/status_berserk.png",
		"materials/vgui/hud/status_amputant.png",
		
		"materials/vgui/hud/status_adrenalinealt.png",
		"materials/vgui/hud/status_amputantalt.png",
		"materials/vgui/hud/status_backgroundalt.png",
		"materials/vgui/hud/status_berserkalt.png",
		"materials/vgui/hud/status_bleeding_iconalt.png",
		"materials/vgui/hud/status_blood_lossalt.png",
		"materials/vgui/hud/status_brain_damagealt.png",
		"materials/vgui/hud/status_cardiac_arrestalt.png",
		"materials/vgui/hud/status_coldalt.png",
		"materials/vgui/hud/status_conscious_iconalt.png",
		"materials/vgui/hud/status_deathalt.png",
		"materials/vgui/hud/status_dislocationalt.png",
		"materials/vgui/hud/status_heatalt.png",
		"materials/vgui/hud/status_hemothoraxalt.png",
		"materials/vgui/hud/status_internal_bleed_iconalt.png",
		"materials/vgui/hud/status_leg_fracturealt.png",
		"materials/vgui/hud/status_level1_bgalt.png",
		"materials/vgui/hud/status_level2_bgalt.png",
		"materials/vgui/hud/status_level3_bgalt.png",
		"materials/vgui/hud/status_level4_bgalt.png",
		"materials/vgui/hud/status_lungs_failurealt.png",
		"materials/vgui/hud/status_organ_damagealt.png",
		"materials/vgui/hud/status_overdosealt.png",
		"materials/vgui/hud/status_oxygenalt.png",
		"materials/vgui/hud/status_pain_iconalt.png",
		"materials/vgui/hud/status_shockalt.png",
		"materials/vgui/hud/status_spine_fracturealt.png",
		"materials/vgui/hud/status_stamina_iconalt.png",
		"materials/vgui/hud/status_traumaalt.png",
		"materials/vgui/hud/status_vomitalt.png",
	}
	
	for _, path in ipairs(SPRITES) do resource.AddFile(path) end
	for _, path in ipairs(ICONS) do resource.AddFile(path) end
	for _, path in ipairs(STATUS_SPRITES) do resource.AddFile(path) end
	
	AddCSLuaFile("autorun/zb_health_hud.lua")
	
	hook.Add("Initialize", "ZB_HealthHUD_ServerInit", function()
	end)
	
	return
end

local math_min, math_max, math_floor, math_sin, math_abs, math_cos, math_sqrt = math.min, math.max, math.floor, math.sin, math.abs, math.cos, math.sqrt
local Color = Color
local draw_SimpleText = draw.SimpleText
local surface_SetDrawColor = surface.SetDrawColor
local surface_DrawRect = surface.DrawRect
local surface_DrawOutlinedRect = surface.DrawOutlinedRect
local surface_SetMaterial = surface.SetMaterial
local surface_DrawTexturedRect = surface.DrawTexturedRect
local ScrW, ScrH = ScrW, ScrH
local FrameTime = FrameTime
local Lerp = Lerp
local CurTime = CurTime
local gui = gui
--шкварки
local cvar_enabled = CreateClientConVar("mzb_MoodleHud_enabled", "1", true, false)
local cvar_limbs_always = CreateClientConVar("mzb_popalimbs", "0", true, false)
local cvar_alt_icons = CreateClientConVar("mzb_nopixelicons", "0", true, false)
local cvar_status_effects = CreateClientConVar("mzb_Disable_moodle", "1", true, false)
local cvar_language = CreateClientConVar("mzb_language", "eng", true, false)

local LANGUAGE = cvar_language:GetString()
local USE_ALT_ICONS = cvar_alt_icons:GetBool()

LANGUAGE = cvar_language:GetString()
if LANGUAGE ~= "ru" and LANGUAGE ~= "eng" then
    LANGUAGE = "eng"
    RunConsoleCommand("mzb_language", "eng")
end

local ALT_ICON_SETTINGS = {
	size_multiplier = 0.85, 
	
	background_multiplier = 0.85,
	
	padding_offset = -1,
}

local function getOrgVal(org, key, def)
	local v = org[key]
	return type(v) == "number" and v or (def or 0)
end

local function getOrgTableVal(org, tbl, key, index, def)
	if not org[tbl] or type(org[tbl]) ~= "table" then return def or 0 end
	local val = org[tbl][key]
	if index and type(val) == "table" then
		val = val[index]
	end
	return type(val) == "number" and val or (def or 0)
end

local function getO2Value(org)
	if not org.o2 then return 30 end
	if type(org.o2) == "table" then
		return org.o2[1] or 30
	end
	return type(org.o2) == "number" and org.o2 or 30
end

local function getO2Max(org)
	if not org.o2 then return 30 end
	if type(org.o2) == "table" then
		return org.o2.range or 30
	end
	return 30
end

local function isPlayerDead(ply)
	if not IsValid(ply) then return true end
	if not ply:Alive() then return true end
	local org = ply.organism
	if org and org.alive == false then return true end
	return false
end

local function isBerserkActive(org)
	return org and org.berserkActive2 == true
end

local function lerpCol(ratio, from, to)
	ratio = math_min(math_max(ratio, 0), 1)
	return Color(
		math_floor((from.r or 0) + ((to.r or 0) - (from.r or 0)) * ratio),
		math_floor((from.g or 0) + ((to.g or 0) - (from.g or 0)) * ratio),
		math_floor((from.b or 0) + ((to.b or 0) - (from.b or 0)) * ratio),
		255
	)
end

local function getLimbColor(damage)
	local ratio = math_min(math_max(damage, 0), 1)
	if ratio <= 0.3 then return Color(128, 128, 128, 255)
	elseif ratio <= 0.6 then return Color(255, 165, 0, 255)
	else return Color(255, 0, 0, 255) end
end

local function hasAnyLimbDamage(org)
	return (getOrgVal(org, "skull", 0) > 0.01 or
			getOrgVal(org, "jaw", 0) > 0.01 or
			getOrgVal(org, "chest", 0) > 0.01 or
			getOrgVal(org, "spine1", 0) > 0.01 or
			getOrgVal(org, "spine2", 0) > 0.01 or
			getOrgVal(org, "spine3", 0) > 0.01 or
			getOrgVal(org, "pelvis", 0) > 0.01 or
			getOrgVal(org, "rarm", 0) > 0.01 or
			getOrgVal(org, "larm", 0) > 0.01 or
			getOrgVal(org, "rleg", 0) > 0.01 or
			getOrgVal(org, "lleg", 0) > 0.01)
end

local function hasAnyAmputation(org)
	return org.llegamputated == true or 
		   org.rlegamputated == true or 
		   org.larmamputated == true or 
		   org.rarmamputated == true
end

local function hasAnyFracture(org, threshold)
	threshold = threshold or 0.95
	
	local lleg = getOrgVal(org, "lleg", 0)
	local rleg = getOrgVal(org, "rleg", 0)
	local larm = getOrgVal(org, "larm", 0)
	local rarm = getOrgVal(org, "rarm", 0)
	
	return (lleg >= threshold and not org.llegamputated) or
		   (rleg >= threshold and not org.rlegamputated) or
		   (larm >= threshold and not org.larmamputated) or
		   (rarm >= threshold and not org.rarmamputated)
end


local function getBerserkCamEffect()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply.organism then return 0, 0, 0 end
    
    local berserkActive = isBerserkActive(ply.organism)
    if not berserkActive then return 0, 0, 0 end
    

    local offsetVal = 0.85
    local bpmVal = 70
    
 
    local stationTime = 0
    if hg and hg.berserkStation and IsValid(hg.berserkStation) then
        stationTime = hg.berserkStation:GetTime()
    else

        local now = CurTime()
        stationTime = (now % (60 / bpmVal)) * bpmVal / 60
    end
    

    local beat = 1 - ((stationTime - offsetVal) / 60 * bpmVal)
    beat = (beat - math.Round(beat)) % 1
    local pulseIntensity = math.abs(math.cos(1 - (beat * 2)))
    

    local berserkVal = ply.organism.berserk or 0
    local berserkClamped = math.Clamp(berserkVal, 0, 3) * (ply.organism.consciousness or 1)
    

    local intensity = pulseIntensity * berserkClamped * 2
    

    local shakeX = math.sin(CurTime() * 30) * intensity * 0.5
    local shakeY = math.cos(CurTime() * 25) * intensity * 0.3
    
    return intensity, shakeX, shakeY
end

--кладкорды
local HUD = {
	enabled = cvar_enabled:GetBool(),
	bar_y = 4440,
	bar_scale = 0,
	base_x = nil,
	base_y = 60,
	use_alt_icons = USE_ALT_ICONS,
	
	limb_offsets = {
		head =        { x = 55,   y = -15 },
		torso =       { x = 54	,   y = 33 },
		right_arm =   { x = 83,  y = 36 },
		left_arm =    { x = 24, y = 38 },
		right_leg =   { x = 66,  y = 92 },
		left_leg =    { x = 35, y = 106 },
	},
	
	limb_scale = {
		head =        { w = 1, h = 1 },
		torso =       { w = 1.4, h = 1.8 },
		right_arm =   { w = 1, h = 2 },
		left_arm =    { w = 1, h = 2 },
		right_leg =   { w = 1.2, h = 3.5 },
		left_leg =    { w = 1.2, h = 2.7 },
	},
	
	sprite_visibility = 100,
	always_show_limbs = cvar_limbs_always:GetBool(),
	smooth = 0.35,
	show_damage_percent = false,
	
	blood_hide_threshold = 4500,
	pulse_hide_min = 60,
	pulse_hide_max = 100,
	stable_time = 15,
	
	status_effects_x = -10,
	status_effects_y = 220,
	status_effects_spacing = 55,
	status_effects_size = 58,
	show_status_effects = cvar_status_effects:GetBool(),
	
	organ_damage_threshold = 0.3,
	fracture_threshold = 0.95,
	
	bleeding_threshold = 0.1,
	internal_bleed_threshold = 0.1,
	
	blood_loss_threshold = 4700,
	cardiac_arrest_threshold = true,
	cold_threshold = 36,
	heat_threshold = 37,
	hemothorax_threshold = 0.01,
	oxygen_threshold = 28,
	vomit_threshold = 0.2,
	brain_damage_threshold = 0.01,
	
	adrenaline_threshold = 0.3,
	shock_threshold = 20,
	trauma_threshold = 0.2,
	
	limb_damage_threshold = 0.01,
	limb_fade_speed = 3.0,
}

local sprites = {}
local icons = {}
local status_sprites = {
	level_backgrounds = {nil, nil, nil, nil},
	background = nil,
	pain_icon = nil,
	conscious_icon = nil,
	stamina_icon = nil,
	bleeding_icon = nil,
	internal_bleed_icon = nil,
	organ_damage = nil,
	dislocation = nil,
	spine_fracture = nil,
	fracture = nil,
	
	blood_loss = nil,
	cardiac_arrest = nil,
	cold = nil,
	heat = nil,
	hemothorax = nil,
	lungs_failure = nil,
	overdose = nil,
	oxygen = nil,
	vomit = nil,
	brain_damage = nil,
	
	adrenaline = nil,
	shock = nil,
	trauma = nil,
	
	death = nil,
	berserk = nil,
	amputant = nil,
}
local status_sprites_loaded = false
local debug_done = false
local statusEffectAppearance = {}
local statusEffectPositions = {}
local tooltipHoverTime = {}
local lastHoveredStatus = nil
local lastStatusEffectLevels = {}

local smooth = {
	blood = 5000,
	conscious = 1.0,
	pain = 0,
	pulse = 70,
	assimilation = 0,
	o2 = 30,
	bleed = 0,
	internalBleed = 0,
	
	temperature = 36.7,
	pneumothorax = 0,
	analgesia = 0,
	brain = 0,
	wantToVomit = 0,
	
	adrenaline = 0,
	shock = 0,
	disorientation = 0,
}

local limbFadeStates = {
	head = {alpha = 0, target = 0},
	torso = {alpha = 0, target = 0},
	right_arm = {alpha = 0, target = 0},
	left_arm = {alpha = 0, target = 0},
	right_leg = {alpha = 0, target = 0},
	left_leg = {alpha = 0, target = 0},
}

local limbsRevealed = false

local stability = {
	blood = {last_value = 5000, last_change = 0, hidden = false},
	pulse = {last_value = 70, last_change = 0, hidden = false},
}

local hoverEffect = {
	hoveredIndex = nil,
	hoverTime = 0,
	mouseOffsetX = 0,
	mouseOffsetY = 0,
	lastMouseX = 0,
	lastMouseY = 0,
	scale = 1.0,
	
	painShakeTime = 0,
	berserkShakeTime = 0,
}

local function isAnyMenuOpen()
    local menu = g_ContextMenu
    if menu and (menu.Visible or menu:IsVisible()) then
        return true
    end
    
    local spawnmenu = g_SpawnMenu
    if spawnmenu and spawnmenu:IsVisible() then
        return false
    end
    
    if gui.MouseX() ~= 0 or gui.MouseY() ~= 0 then
        local hovered = vgui.GetHoveredPanel()
        if hovered then
            local name = hovered:GetName() or ""
            local className = hovered:GetClassName() or ""
            
            if string.find(className, "Radial") or string.find(className, "Menu") then
                return true
            end
            if string.find(name, "Radial") or string.find(name, "Menu") then
                return true
            end
            
            local parent = hovered:GetParent()
            while parent do
                local pname = parent:GetName() or ""
                local pclass = parent:GetClassName() or ""
                if string.find(pclass, "Radial") or string.find(pclass, "Menu") then
                    return true
                end
                if string.find(pname, "Radial") or string.find(pname, "Menu") then
                    return true
                end
                parent = parent:GetParent()
            end
        end
    end
    
    return gui.MouseX() ~= 0 or gui.MouseY() ~= 0
end
--ткст
local tooltipTexts = {
	ru = {
		pain = {
			[4] = "Агония - Невыносимая боль. Движения ограничены. Смерть сейчас звучит заманчиво.",
			[3] = "Сильная боль - Полусознателен, разум затуманен сильной болью.",
			[2] = "Боль - Довольно сильная боль.",
			[1] = "Небольшая боль - Ощущается легкая боль."
		},
		bleeding = {
			[4] = "Кровоизлияние - Вы быстро истекаете кровью. Смерть неизбежна без немедленного медицинского вмешательства.",
			[3] = "Сильное кровотечение - Кровь свободно течет из серьезной раны. Требуется немедленная помощь.",
			[2] = "Умеренное кровотечение - Вы теряете заметное количество крови. Следует скоро обработать.",
			[1] = "Незначительное кровотечение - Небольшая рана вызывает некоторую потерю крови. Вряд ли это станет серьезной проблемой."
		},
		internal_bleed = "Внутреннее кровотечение - Как выяснилось, кишки и легкие — это явно НЕ место для твоей крови. Крайне рекомендуется лечение.",
		conscious = {
			[4] = "Без сознания - Нет реакции ни на какие внешние раздражители. Ты в отключке.",
			[3] = "Обморок - Едва в сознании, чувствуя, что можешь упасть в любой момент.",
			[2] = "Растерян - Чувство растерянности и головокружения, трудности с восприятием окружающего мира.",
			[1] = "Запутан - Слегка дезориентирован с легким головокружением."
		},
		stamina = {
			[4] = "Совершенно измотан - Кое-как способен дышать.",
			[3] = "Сильно выдохся - Практически не можешь двигаться.",
			[2] = "Выдохся - Испытываешь дискомфорт и усталость, с трудом двигаешься и работаешь.",
			[1] = "Слегка устал - Незначительное физическое напряжение."
		},
		spine_fracture = "Сломаный позвоночник - Сломан позвоночник. Если спинной мозг не оборван, считай это удачей.",
		fracture = "Перелом конечности - У тебя сломана рука или нога. Движение повреждённой конечностью затруднено и причиняет сильную боль.",
		organ_damage = "Повреждение органов - Органы внутри тебя чувствуют себя не хорошо.",
		dislocation = "Вывих сустава - Ты вывихнул конечность. Постарайся не использовать поврежденную конечность и найди способ ее вправить.",
		amputant = "Ампутант - Одна из твоих конечностей была оторвана. Травмирующе. Очевидно, ты навсегда утратил возможность пользоваться оторванной конечностью.",
		blood_loss = {
			[4] = "Обескровлен - Угрожающая жизни потеря крови. Еще чуть-чуть, и сердце остановится. Смерть неизбежна.",
			[3] = "Критическая гиповолемия - Сильная потеря крови. Полусознателен. Ты нечетко видишь... Необходимо лечение.",
			[2] = "Гиповолемия - Слабость и дезориентация вследствие кровопотери. Ты чувствуешь себя очень плохо. Рекомендуется лечение.",
			[1] = "Бледен - Незначительная потеря крови. Артериальное давление понижено. Ты чувствуваешь небольшую слабость, кожа бледная."
		},
		cardiac_arrest = "Остановка сердца - Твоё сердце перестало биться, а значит кислород в мозг больше не поступает.",
		cold = {
			[4] = "Замерзание до смерти - По неизвестной причине тебе становится тепло...",
			[3] = "Гипотермия - Опасно низкая температура, тело и разум изнемогают от холода.",
			[2] = "Холодно - Неприятно холодно. Твой организм замедляется.",
			[1] = "Прохладно - Немного прохладно для комфорта."
		},
		heat = {
			[4] = "Тепловой удар - Твой организм явно долго не протянет в такую жару.",
			[3] = "Гипертермия - Опасно жарко. Тебе тяжело выдерживать жару...",
			[2] = "Жарко - Неприятно жарко.",
			[1] = "Тепло - Немного жарковато для комфорта."
		},
		hemothorax = {
			[4] = "Критический гемоторакс - Лёгкие пытаются зачерпнуть хоть каплю кислорода, но всё четно... Спокойной ночи.",
			[3] = "Сильнейший гемоторакс - Грудная клетка очень сильно болит. Кровь уже заполнила лёгкие больше, чем на половину.",
			[2] = "Серьёзный гемоторакс - Кровь скопилась до такого уровня, что дышать стало труднее.",
			[1] = "Гемоторакс - В плевральной полости скапливается кровь из-за внутреннего кровотечения или прокола лёгких. У тебя болит грудь... Требуется лечение."
		},
		lungs_failure = "Отказ лёгких - лёгкие перестали работать в связи с повреждением, долгим отсутсвием цикла дыхания или по другой причине.",
		overdose = {
			[4] = "Фатальная передозировка - Дыхательная недостаточность. Ты покидаешь этот мир в состоянии эйфории, вызванной наркотиками, но тебе уже глубоко наплевать.",
			[3] = "Передозировка - Дышать тяжело, в голове царит эйфория. Это определенно плохо для организма. Если бы только это могло длиться вечно...",
			[2] = "Средняя доза - Очень расслаблен и спокоен, но легкие ощущаются тяжелыми. Устаешь немного быстрее обычного. Чувствуешь себя отлично, пока что...",
			[1] = "Доза - Расслаблен и спокоен. Тело чувствуется онемевшим."
		},
		oxygen = {
			[4] = "Аноксемия - Мозг отмирает от кислородного голодания. Весь организм стремительно отказывает. Смерть неизбежна.",
			[3] = "Асфиксия - Теряешь сознание. Ткани лишены кислорода.",
			[2] = "Сильная гипоксемия - Недостаточно кислорода в организме. Головокружение и онемение конечностей. Что-то ЯВНО не так.",
			[1] = "Гипоксемия - Понижен уровень кислорода в крови. Немного запутан, кожа вялая. Что-то не так..."
		},
		vomit = {
			[4] = "Ужасная тошнота - Опасная тошнота. Внутри что-то ОЧЕНЬ не так.",
			[3] = "Сильная тошнота - Сильный дискомфорт. Сильная склонность к рвоте.",
			[2] = "Тошнота - Дискомфорт в области желудка. Склонность к рвоте.",
			[1] = "Подташнивает - Чувствуешь дискомфорт. Немного плохо. Небольшая склонность к рвоте."
		},
		brain_damage = {
			[4] = "Кома - Едва цепляясь за жизнь, ты страдаешь от cильнейшего повреждения мозга. Ты - овощ. Восстановление маловероятно.",
			[3] = "Тяжелое нейрофизиологическое ухудшение - Сильно умственно отстал, едва способный мыслить разумно и оставаться в сознании. Серьёзная мозговая травма",
			[2] = "Неврологические повреждения - Тяжелый ментальный дефицит. Ограничена способность к интеллектуальному мышлению и самодостаточности. Серьезные повреждения головного мозга.",
			[1] = "Когнитивные нарушения - Психические расстройства вследствие повреждения головного мозга. Ты чувствуешь странную растерянность..."
		},
		adrenaline = {
			[4] = "Адреналин - Сердце работает на износ качая кровь. Практически полное отсутствие боли, прилив сил, и увеличенная стойкость.",
			[3] = "Адреналин - Почти не чувствуешь боль. Выносливость увеличилась в разы.",
			[2] = "Адреналин - Боль притупилась. Состояние повышенной готовности",
			[1] = "Адреналин - Ты чувствуешь небольшой прилив сил."
		},
		shock = {
			[4] = "Шок - Организм включает самый лучший защитный механизм, чтобы справится с этой болью. Сладких снов.",
			[3] = "Шок - Сильнейшая боль в твоей жизни туманит разум и рассудок делая из тебя животное.",
			[2] = "Шок - Агонизирующая боль прорезает каждую клеточку твоего тела.",
			[1] = "Шок - Входишь в состояние шока"
		},
		trauma = {
			[4] = "Контужен - Ужас и Беспомощность.",
			[3] = "Сильная дезориентация - Звон в ушах и мир, как на карусели.",
			[2] = "Серьёзная дезориентация - Голова кружится и всё кругом плывёт.",
			[1] = "Лёгкая дезориентация - Чувствуешь себя сонным."
		},
		death = "Смерть - Пермаментная и грустная или весёлая, а впрочем уже не важно.",
		berserk = {
			[4] = "Берсерк - Невообразимая сила, регенерация, и стойкость. Ты машина для убийств.",
			[3] = "Берсерк - Невообразимая сила, регенерация, и стойкость. Ты машина для убийств.",
			[2] = "Берсерк - Невообразимая сила, регенерация, и стойкость. Ты машина для убийств.",
			[1] = "Берсерк - Невообразимая сила, регенерация, и стойкость. Ты машина для убийств."
		},
		berserk_brain_damage = "Повреждение мозга - ЧУТЬ ЧУТЬ ОТЛЕЖУСЬ И НОРМАЛЬНО.",
		berserk_fracture = "Перелом - МНЕ РАЗВЕ ДОЛЖНО БЫТЬ НЕ БОЛЬНО... А ПОХУЙ ВООБЩЕМ.",
		berserk_dislocation = "Вывих - ДА КОГО ОН ЁБЕТ ВООБЩЕ.",
		berserk_adrenaline = "Адреналин - ПРИЯТНЫЙ БОНУС.",
		berserk_oxygen = "Кислородное голодание - ОДНА ВЕЩЬ, КОТОРАЯ МЕНЯ ПУГАЕТ.",
		berserk_trauma = "Дезориентация - ЭТО ОЧЕНЬ ЗАВОРАЖИВАЕТ.",
		berserk_amputant = "Ампутант - МЕНЯ ЭТО ДОЛЖНО ОСТАНОВИТЬ?",
		berserk_cardiac_arrest = "Остановка сердца - ЭТО УЖЕ ЗВУЧИТ НЕ ТАК КРУТО.",
		berserk_lungs_failure = "Отказ лёгких - ЭТО УЖЕ ЗВУЧИТ НЕ ТАК КРУТО.",
	},
	
	en = {
		pain = {
			[4] = "JESUS FUCKING CHRIST, I JUST WANT TO PASS OUT RIGHT NOW",
			[3] = "Severe Pain - Its starting to hurt real bad now, something is totally wrong...",
			[2] = "Pain - Its probably just a headache...",
			[1] = "Mild pain - Your average tuesday."
		},
		bleeding = {
			[4] = "Hemorrhaging - You are bleeding out rapidly. Death is imminent without immediate medical intervention.",
			[3] = "Severe Bleeding - Blood is flowing freely from a serious wound. Immediate attention is required.",
			[2] = "Moderate Bleeding - You're losing a noticeable amount of blood. Should be treated soon.",
			[1] = "Minor Bleeding - A small wound is causing some blood loss. Unlikely to be a major issue."
		},
		internal_bleed = "Internal bleeding - Something inside broke and you are starting to lose blood inside, while not usually lethal on its own you should get it fixed to prevent complications.",
		conscious = {
			[4] = "...",
			[3] = "Fainting - Your body and mind are severely affected by something, you feel extremely sleepy.",
			[2] = "Confused - Confused and disoriented, you are starting to feel drowsy.",
			[1] = "Disoriented - Feeling kind of sleepy right now."
		},
		stamina = {
			[4] = "I CANT BREATHE NOR MOVE, LETS TAKE A BREAK...",
			[3] = "Very exhausted - Okay, now its REALLY time to stop doing what you are doing...",
			[2] = "Exhausted - You are starting to feel tired, its time to stop fatiguing yourself.",
			[1] = "Slightly tired - Strained from activity, you can keep going a little."
		},
		spine_fracture = "Something is wrong, my back feels non existant and I cant feel something on my body.",
		fracture = "Fracture",
		organ_damage = "Organ damage - The organs inside you don't feel well.",
		dislocation = "Joint dislocation - You've dislocated a limb. Try not to use the injured limb and find a way to reset it.",
		amputant = "Amputation - A limb has been amputated. You will never be able to use it again.",
		blood_loss = {
			[4] = "Exsanguination - Blood loss threatens your life. A little more and your heart will stop. Death is inevitable.",
			[3] = "Critical hypovolemia - Severe blood loss. Semi-conscious. You see blurry... Treatment needed.",
			[2] = "Hypovolemia - Weakness and disorientation due to blood loss. You feel very unwell. Treatment recommended.",
			[1] = "Pale - Minor blood loss. Blood pressure is low. You feel slight weakness, skin is pale."
		},
		cardiac_arrest = "Cardiac arrest - Your heart has stopped beating, which means oxygen no longer reaches your brain.",
		cold = {
			[4] = "Freezing to death - For some unknown reason, you're feeling warm... Good night.",
			[3] = "Hypothermia - Dangerously low temperature, body and mind exhausted from cold. The whole body is gradually failing.",
			[2] = "Cold - Unpleasantly cold. Your body is slowing down.",
			[1] = "Chilly - A bit chilly for comfort."
		},
		heat = {
			[4] = "Heat stroke - Brain cells are starting to die from intense heat.",
			[3] = "Hyperthermia - Dangerously hot. It's hard for you to bear the heat...",
			[2] = "Hot - Unpleasantly hot.",
			[1] = "Warm - A bit too warm for comfort."
		},
		hemothorax = {
			[4] = "Critical hemothorax - Your lungs are trying to grasp at least a drop of oxygen, but it's hopeless... Good night.",
			[3] = "Severe hemothorax - Your chest is about to explode, and blood has already filled more than half of your lungs.",
			[2] = "Serious hemothorax - Blood has accumulated to the point where breathing has become difficult.",
			[1] = "Hemothorax - Blood is accumulating in the pleural cavity due to internal bleeding or lung puncture. Your chest hurts... Treatment required."
		},
		lungs_failure = "Lung failure - Lungs have stopped working due to damage or prolonged absence of breathing cycle.",
		overdose = {
			[4] = "Fatal overdose - Respiratory failure. You're leaving this world in a drug-induced euphoria, but you couldn't care less.",
			[3] = "Overdose - Breathing is hard, euphoria reigns in your head. This is definitely bad for the body. If only this could last forever...",
			[2] = "Moderate dose - Very relaxed and calm, but your lungs feel heavy. You tire a bit faster than usual. You feel great, for now...",
			[1] = "Dose - Relaxed and calm. Your body feels numb."
		},
		oxygen = {
			[4] = "Anoxemia - Your brain is dying from oxygen starvation. The whole body is rapidly failing. Death is inevitable.",
			[3] = "Asphyxia - You're losing consciousness. Tissues are deprived of oxygen. Inevitable brain damage.",
			[2] = "Severe hypoxemia - Insufficient oxygen in the body. Dizziness and numbness in extremities. Something is DEFINITELY wrong.",
			[1] = "Hypoxemia - Low blood oxygen level. Slightly confused, skin is sluggish. Something's not right..."
		},
		vomit = {
			[4] = "Terrible nausea - Dangerous nausea. Something is VERY wrong inside.",
			[3] = "Severe nausea - Severe discomfort. Strong tendency to vomit.",
			[2] = "Nausea - Discomfort in the stomach area. Tendency to vomit.",
			[1] = "Queasy - You feel discomfort. Slightly unwell. Slight tendency to vomit."
		},
		brain_damage = {
			[4] = "Coma - Barely clinging to life, you suffer from severe brain damage. You're a vegetable. Recovery is unlikely.",
			[3] = "Severe neurophysiological deterioration - Severely mentally impaired, barely able to think rationally and remain conscious. Serious brain injury.",
			[2] = "Neurological damage - Severe mental deficit. Limited ability for intellectual thinking and self-sufficiency. Serious brain damage.",
			[1] = "Cognitive impairment - Mental disorders due to brain damage. You feel strange confusion..."
		},
		adrenaline = {
			[4] = "Adrenaline - Heart working overtime pumping blood. Almost complete absence of pain, surge of strength, and increased resilience.",
			[3] = "Adrenaline - Almost no pain felt. Stamina increased dramatically.",
			[2] = "Adrenaline - Pain dulled. State of heightened alertness.",
			[1] = "Adrenaline - You feel a slight surge of strength."
		},
		shock = {
			[4] = "Shock - Your body activates the best defense mechanism to cope with this pain. Sweet dreams.",
			[3] = "Shock - The most intense pain of your life clouds your mind and reason, turning you into an animal.",
			[2] = "Shock - Agonizing pain cuts through every cell of your body.",
			[1] = "Shock - Entering a state of shock"
		},
		trauma = {
			[4] = "Shell-shocked - Terror. Helplessness.",
			[3] = "Severe disorientation - Ringing in ears and the world like a carousel.",
			[2] = "Serious disorientation - Head spinning and everything floating around.",
			[1] = "Mild disorientation - Feeling sleepy."
		},
		death = "Death - You are dead. Observe what's happening.",
		berserk = {
			[4] = "Berserk - Unimaginable strength, regeneration, and resilience. You are a killing machine.",
			[3] = "Berserk - Unimaginable strength, regeneration, and resilience. You are a killing machine.",
			[2] = "Berserk - Unimaginable strength, regeneration, and resilience. You are a killing machine.",
			[1] = "Berserk - Unimaginable strength, regeneration, and resilience. You are a killing machine."
		},
		berserk_brain_damage = "Brain damage - Even in rage, your damaged brain affects you.",
		berserk_fracture = "Fracture - Adrenaline numbs the pain, but the bone is still broken.",
		berserk_dislocation = "Dislocation - The joint is out of place, but rage allows you to ignore it.",
		berserk_adrenaline = "Adrenaline - Your body is working at its limit.",
		berserk_oxygen = "Oxygen deprivation - Your brain lacks oxygen, even in berserk mode.",
		berserk_trauma = "Disorientation - The world is spinning, but rage drives you forward.",
		berserk_amputant = "Amputation - The limb is gone, but nothing will stop you.",
		berserk_cardiac_arrest = "Cardiac arrest - You are already dead, but rage still drives you.",
		berserk_lungs_failure = "Lung failure - No air to breathe, but berserk won't let you fall.",
	}
}

local function getTooltipText(statusName, pos, berserkActive)
	local lang = LANGUAGE
	local texts = tooltipTexts[lang] or tooltipTexts.en
	
	if berserkActive then
		local berserkKey = "berserk_" .. statusName
		if texts[berserkKey] then
			return texts[berserkKey]
		end
	end
	
	if statusName == "pain" or statusName == "conscious" or statusName == "stamina" or 
	   statusName == "bleeding" or statusName == "blood_loss" or statusName == "cold" or statusName == "heat" or
	   statusName == "hemothorax" or statusName == "overdose" or statusName == "oxygen" or
	   statusName == "vomit" or statusName == "brain_damage" or statusName == "adrenaline" or
	   statusName == "shock" or statusName == "trauma" or statusName == "berserk" then
		
		local levelTexts = texts[statusName]
		if levelTexts and type(levelTexts) == "table" then
			return levelTexts[pos.level_num] or levelTexts[1] or ""
		end
	else
		return texts[statusName] or ""
	end
	
	return ""
end

local function load_icons()
	if icons.loaded and icons.alt == HUD.use_alt_icons then return end
	icons.loaded = true
	icons.alt = HUD.use_alt_icons
	
	local fixed_icons = {
		blood = "vgui/hud/bloodmeter.png",
		pulse = "vgui/hud/pulsemeter.png",
		assimilation = "vgui/hud/assimilationmeter.png",
	}
	
	local suffix = HUD.use_alt_icons and "_alt" or ""
	local dynamic_icons = {
		o2 = "vgui/hud/o2meter" .. suffix .. ".png",
	}
	
	for name, path in pairs(fixed_icons) do
		local mat = Material(path, "smooth")
		icons[name] = (mat and not mat:IsError()) and mat or false
	end
	
	for name, path in pairs(dynamic_icons) do
		local mat = Material(path, "smooth")
		icons[name] = (mat and not mat:IsError()) and mat or false
	end
end

local function load_status_sprites()
	if status_sprites_loaded and icons.alt == USE_ALT_ICONS then return end
	status_sprites_loaded = true
	icons.alt = USE_ALT_ICONS
	
	local suffix = USE_ALT_ICONS and "alt" or ""
	
	local function loadMaterial(basePath, suffix)
		local path = basePath
		if suffix ~= "" then
			local dotPos = string.find(path, ".png")
			if dotPos then
				path = string.sub(path, 1, dotPos - 1) .. suffix .. string.sub(path, dotPos)
			end
		end
		local mat = Material(path, "smooth")
		return (mat and not mat:IsError()) and mat or nil
	end
	
	for i = 1, 4 do
		status_sprites.level_backgrounds[i] = loadMaterial("vgui/hud/status_level" .. i .. "_bg.png", suffix)
	end
	--мудль
	status_sprites.background = loadMaterial("vgui/hud/status_background.png", suffix)
	
	status_sprites.pain_icon = loadMaterial("vgui/hud/status_pain_icon.png", suffix)
	status_sprites.conscious_icon = loadMaterial("vgui/hud/status_conscious_icon.png", suffix)
	status_sprites.stamina_icon = loadMaterial("vgui/hud/status_stamina_icon.png", suffix)
	status_sprites.bleeding_icon = loadMaterial("vgui/hud/status_bleeding_icon.png", suffix)
	status_sprites.internal_bleed_icon = loadMaterial("vgui/hud/status_internal_bleed_icon.png", suffix)
	status_sprites.organ_damage = loadMaterial("vgui/hud/status_organ_damage.png", suffix)
	status_sprites.dislocation = loadMaterial("vgui/hud/status_dislocation.png", suffix)
	status_sprites.spine_fracture = loadMaterial("vgui/hud/status_spine_fracture.png", suffix)
	status_sprites.fracture = loadMaterial("vgui/hud/status_leg_fracture.png", suffix)
	
	status_sprites.blood_loss = loadMaterial("vgui/hud/status_blood_loss.png", suffix)
	status_sprites.cardiac_arrest = loadMaterial("vgui/hud/status_cardiac_arrest.png", suffix)
	status_sprites.cold = loadMaterial("vgui/hud/status_cold.png", suffix)
	status_sprites.heat = loadMaterial("vgui/hud/status_heat.png", suffix)
	status_sprites.hemothorax = loadMaterial("vgui/hud/status_hemothorax.png", suffix)
	status_sprites.lungs_failure = loadMaterial("vgui/hud/status_lungs_failure.png", suffix)
	status_sprites.overdose = loadMaterial("vgui/hud/status_overdose.png", suffix)
	status_sprites.oxygen = loadMaterial("vgui/hud/status_oxygen.png", suffix)
	status_sprites.vomit = loadMaterial("vgui/hud/status_vomit.png", suffix)
	status_sprites.brain_damage = loadMaterial("vgui/hud/status_brain_damage.png", suffix)
	
	status_sprites.adrenaline = loadMaterial("vgui/hud/status_adrenaline.png", suffix)
	status_sprites.shock = loadMaterial("vgui/hud/status_shock.png", suffix)
	status_sprites.trauma = loadMaterial("vgui/hud/status_trauma.png", suffix)
	
	status_sprites.death = loadMaterial("vgui/hud/status_death.png", suffix)
	status_sprites.berserk = loadMaterial("vgui/hud/status_berserk.png", suffix)
	status_sprites.amputant = loadMaterial("vgui/hud/status_amputant.png", suffix)
end

local function update_stability(blood_val, pulse_val)
	local now = CurTime()
	
	if math_abs(blood_val - stability.blood.last_value) > 50 then
		stability.blood.last_value = blood_val
		stability.blood.last_change = now
		stability.blood.hidden = false
	end
	
	if math_abs(pulse_val - stability.pulse.last_value) > 3 then
		stability.pulse.last_value = pulse_val
		stability.pulse.last_change = now
		stability.pulse.hidden = false
	end
	
	if blood_val >= HUD.blood_hide_threshold and (now - stability.blood.last_change) >= HUD.stable_time then
		stability.blood.hidden = true
	end
	
	if pulse_val >= HUD.pulse_hide_min and pulse_val <= HUD.pulse_hide_max and (now - stability.pulse.last_change) >= HUD.stable_time then
		stability.pulse.hidden = true
	end
end

local function draw_bar()
	if not HUD.enabled then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end
	
	local org = ply.organism
	local scale = math_max(HUD.bar_scale, 0.5)
	
	local base_bar_h = 34
	local base_bar_w = 440
	local bar_h = math_floor(base_bar_h * scale)
	local bar_w = math_floor(base_bar_w * scale)
	local bar_y = ScrH() + HUD.bar_y
	
	local max_bar_w = ScrW() * 0.95
	local max_scale = max_bar_w / base_bar_w
	if scale > max_scale then
		scale = max_scale
		bar_w = math_floor(base_bar_w * scale)
		bar_h = math_floor(base_bar_h * scale)
	end
	
	local bar_x = ScrW() * 0.5 - bar_w * 0.5
	local pad = math_floor(5 * scale)
	local icon_size = math_floor(26 * scale)
	
	load_icons()
	
	local dt = math_min(FrameTime() * 60, 1)
	local s = HUD.smooth
	
	local o2_val = getO2Value(org)
	local o2_max = getO2Max(org)
	
	smooth.blood = Lerp(s * dt, smooth.blood or 5000, getOrgVal(org, "blood", 5000))
	smooth.conscious = Lerp(s * dt, smooth.conscious or 1.0, getOrgVal(org, "consciousness", 1))
	smooth.pain = Lerp(s * dt, smooth.pain or 0, getOrgVal(org, "pain", 0))
	smooth.pulse = Lerp(s * dt, smooth.pulse or 70, getOrgVal(org, "pulse", 70))
	smooth.assimilation = Lerp(s * dt, smooth.assimilation or 0, getOrgVal(org, "assimilated", 0))
	smooth.o2 = Lerp(s * dt, smooth.o2 or o2_max, o2_val)
	smooth.bleed = Lerp(s * dt, smooth.bleed or 0, getOrgVal(org, "bleed", 0))
	smooth.internalBleed = Lerp(s * dt, smooth.internalBleed or 0, getOrgVal(org, "internalBleed", 0))
	
	smooth.temperature = Lerp(s * dt, smooth.temperature or 36.7, getOrgVal(org, "temperature", 36.7))
	smooth.pneumothorax = Lerp(s * dt, smooth.pneumothorax or 0, getOrgVal(org, "pneumothorax", 0))
	smooth.analgesia = Lerp(s * dt, smooth.analgesia or 0, getOrgVal(org, "analgesia", 0))
	smooth.brain = Lerp(s * dt, smooth.brain or 0, getOrgVal(org, "brain", 0))
	smooth.wantToVomit = Lerp(s * dt, smooth.wantToVomit or 0, getOrgVal(org, "wantToVomit", 0))
	
	smooth.adrenaline = Lerp(s * dt, smooth.adrenaline or 0, getOrgVal(org, "adrenaline", 0))
	smooth.shock = Lerp(s * dt, smooth.shock or 0, getOrgVal(org, "shock", 0))
	smooth.disorientation = Lerp(s * dt, smooth.disorientation or 0, getOrgVal(org, "disorientation", 0))
	
	update_stability(smooth.blood or 5000, smooth.pulse or 70)
	
	local segs = {}
	
	local blood_val = smooth.blood or 5000
	if not stability.blood.hidden then
		local r_blood = math_min(blood_val / 5000, 1)
		local c_blood = r_blood < 0.5 and lerpCol(r_blood * 2, Color(80, 255, 80), Color(255, 180, 50)) or lerpCol((r_blood - 0.5) * 2, Color(255, 180, 50), Color(255, 50, 50))
		table.insert(segs, {label = "BLOOD", val = math_floor(blood_val), suf = "ml", ratio = r_blood, col = c_blood, w = math_floor(95 * scale), icon = "blood", prio = 1})
	end
	
	local o2_val = smooth.o2 or o2_max
	local r_o2 = math_min(o2_val / o2_max, 1)
	local c_o2 = lerpCol(r_o2, Color(255, 50, 50), Color(80, 200, 255))
	if o2_val < HUD.oxygen_threshold or (#segs == 0 and not stability.pulse.hidden) then
		table.insert(segs, {label = "O2", val = math_floor(o2_val), suf = "%", ratio = r_o2, col = c_o2, w = math_floor(75 * scale), icon = "o2", prio = 2})
	end
	
	local assim_val = smooth.assimilation or 0
	if assim_val > 0.005 then
		local r_assim = assim_val
		table.insert(segs, {label = "ASSIMILATION", val = math_floor(assim_val * 100), suf = "%", ratio = r_assim, col = Color(180, 50, 255, 255), w = math_floor(105 * scale), icon = "assimilation", prio = 3})
	end
	
	local pulse_val = smooth.pulse or 70
	if not stability.pulse.hidden then
		local r_pulse = math_min(pulse_val / 100, 1)
		local c_pulse = (pulse_val < 50 or pulse_val > 130) and Color(255, 80, 80) or Color(180, 220, 255)
		table.insert(segs, {label = "PULSE", val = math_floor(pulse_val), suf = "bpm", ratio = r_pulse, col = c_pulse, w = math_floor(80 * scale), icon = "pulse", prio = 4})
	end
	
	if #segs == 0 then return end
	
	table.sort(segs, function(a, b) return a.prio < b.prio end)
	
	local total_width = pad
	for _, seg in ipairs(segs) do total_width = total_width + seg.w + pad end
	
	if total_width > bar_w then
		local new_scale = (bar_w - pad) / (total_width - pad)
		scale = scale * new_scale * 0.98
		bar_w = math_floor(base_bar_w * scale)
		bar_h = math_floor(base_bar_h * scale)
		bar_x = ScrW() * 0.5 - bar_w * 0.5
		pad = math_floor(5 * scale)
		icon_size = math_floor(26 * scale)
		
		for i, seg in ipairs(segs) do
			segs[i].w = math_floor(segs[i].w * new_scale * 0.98)
		end
	end
	
	local x = bar_x + pad
	
	for _, seg in ipairs(segs) do
		local icon = icons[seg.icon]
		if icon and not icon:IsError() then
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(icon)
			surface_DrawTexturedRect(x, bar_y + (bar_h - icon_size) * 0.5, icon_size, icon_size)
		else
			local letters = {blood = "B", o2 = "O", assimilation = "A", pulse = "♥"}
			surface_SetDrawColor(40, 40, 50, 200)
			surface_DrawRect(x + 1, bar_y + (bar_h - icon_size) * 0.5 + 1, icon_size - 2, icon_size - 2)
			surface_SetDrawColor(seg.col.r, seg.col.g, seg.col.b, 255)
			surface_DrawRect(x + 2, bar_y + (bar_h - icon_size) * 0.5 + 2, icon_size - 4, icon_size - 4)
			draw_SimpleText(letters[seg.icon] or "?", "TargetID", x + icon_size * 0.5, bar_y + bar_h * 0.5, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
		
		local meter_x = x + icon_size + math_floor(3 * scale)
		local meter_w = seg.w - icon_size - math_floor(10 * scale)
		local meter_y = bar_y + pad + math_floor(2 * scale)
		local meter_h = bar_h - pad * 2 - math_floor(4 * scale)
		
		surface_SetDrawColor(30, 30, 40, 180)
		surface_DrawRect(meter_x, meter_y, meter_w, meter_h)
		
		surface_SetDrawColor(seg.col.r, seg.col.g, seg.col.b, 200)
		surface_DrawRect(meter_x, meter_y, meter_w * seg.ratio, meter_h)
		
		surface_SetDrawColor(80, 80, 90, 230)
		surface_DrawOutlinedRect(meter_x, meter_y, meter_w, meter_h)
		
		local value_text = seg.val .. (seg.suf or "")
		local text_x = meter_x + math_floor(4 * scale)
		local text_y = bar_y + bar_h * 0.5
		draw_SimpleText(value_text, "DermaDefault", text_x, text_y, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		x = x + seg.w + pad
	end
end

local function draw_status_effects()
	if not HUD.enabled or not HUD.show_status_effects then 
		statusEffectPositions = {}
		return 
	end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then 
		statusEffectPositions = {}
		return 
	end
	
	local org = ply.organism
	local base_x = ScrW() + HUD.status_effects_x
	local base_y = HUD.status_effects_y
	local spacing = HUD.status_effects_spacing
	local size = HUD.status_effects_size
	local currentTime = CurTime()
	
	local mx, my = gui.MousePos()
	if mx and my then
		hoverEffect.lastMouseX = mx
		hoverEffect.lastMouseY = my
	end
	
	local dead = isPlayerDead(ply)
	
	local berserkActive = isBerserkActive(org)
	local painVal = smooth.pain or getOrgVal(org, "pain", 0)
	
	if painVal >= 60 then
		hoverEffect.painShakeTime = currentTime
	end
	if berserkActive then
		hoverEffect.berserkShakeTime = currentTime
	end
	
	load_status_sprites()
	statusEffectPositions = {}
	
	local currentEffectNames = {}
	local effects = {}
	
	if dead then
		table.insert(effects, {
			name = "death",
			priority = -1000,
			value = nil
		})
		currentEffectNames["death"] = true
	else
		local pain_val = smooth.pain or getOrgVal(org, "pain", 0)
		if pain_val > 10 and not berserkActive then
			local level_num = 1
			if pain_val >= 60 then level_num = 4
			elseif pain_val >= 40 then level_num = 3
			elseif pain_val >= 25 then level_num = 2 end
			
			table.insert(effects, {
				name = "pain",
				level_num = level_num,
				has_levels = true,
				priority = 0,
				value = math_floor(pain_val)
			})
			currentEffectNames["pain"] = true
		end
		
		if berserkActive then
			local berserk_val = org.berserk or 0
			local level_num = 1
			if berserk_val > 2.5 then level_num = 4
			elseif berserk_val > 1.5 then level_num = 3
			elseif berserk_val > 0.5 then level_num = 2 end
			
			table.insert(effects, {
				name = "berserk",
				level_num = level_num,
				has_levels = true,
				priority = -1,
				value = math_floor(berserk_val * 10) / 10
			})
			currentEffectNames["berserk"] = true
		end
		
		local showAllIcons = not berserkActive
		
		if berserkActive then
			local brain_val = smooth.brain or getOrgVal(org, "brain", 0)
			if brain_val > HUD.brain_damage_threshold then
				local level_num = 1
				if brain_val > 0.3 then level_num = 4
				elseif brain_val > 0.25 then level_num = 3
				elseif brain_val > 0.15 then level_num = 2 end
				
				table.insert(effects, {
					name = "brain_damage",
					level_num = level_num,
					has_levels = true,
					priority = 0.6,
					value = math_floor(brain_val * 100)
				})
				currentEffectNames["brain_damage"] = true
			end
			
			local spine1 = getOrgVal(org, "spine1", 0)
			local spine2 = getOrgVal(org, "spine2", 0)
			local spine3 = getOrgVal(org, "spine3", 0)
			local spine_fracture = spine1 >= HUD.fracture_threshold or spine2 >= HUD.fracture_threshold or spine3 >= HUD.fracture_threshold
			if spine_fracture then
				table.insert(effects, {name = "spine_fracture", priority = 3})
				currentEffectNames["spine_fracture"] = true
			end
			
			if hasAnyFracture(org, HUD.fracture_threshold) then
				table.insert(effects, {name = "fracture", priority = 6})
				currentEffectNames["fracture"] = true
			end
			
			if org.llegdislocation or org.rlegdislocation or 
			   org.larmdislocation or org.rarmdislocation or 
			   org.jawdislocation then
				table.insert(effects, {name = "dislocation", priority = 5})
				currentEffectNames["dislocation"] = true
			end
			
			local adrenaline_val = smooth.adrenaline or getOrgVal(org, "adrenaline", 0)
			if adrenaline_val > HUD.adrenaline_threshold then
				local level_num = 1
				if adrenaline_val > 2.1 then level_num = 4
				elseif adrenaline_val > 1.5 then level_num = 3
				elseif adrenaline_val > 0.8 then level_num = 2 end
				
				table.insert(effects, {
					name = "adrenaline",
					level_num = level_num,
					has_levels = true,
					priority = 0.65,
					value = math_floor(adrenaline_val * 10) / 10
				})
				currentEffectNames["adrenaline"] = true
			end
			
			local o2_val = getO2Value(org)
			if o2_val < HUD.oxygen_threshold then
				local level_num = 1
				if o2_val < 8 then level_num = 4
				elseif o2_val < 14 then level_num = 3
				elseif o2_val < 23 then level_num = 2 end
				
				table.insert(effects, {
					name = "oxygen",
					level_num = level_num,
					has_levels = true,
					priority = 0.5,
					value = math_floor(o2_val)
				})
				currentEffectNames["oxygen"] = true
			end
			
			local trauma_val = smooth.disorientation or getOrgVal(org, "disorientation", 0)
			if trauma_val > HUD.trauma_threshold then
				local level_num = 1
				if trauma_val > 3 then level_num = 4
				elseif trauma_val > 2.5 then level_num = 3
				elseif trauma_val > 1 then level_num = 2 end
				
				table.insert(effects, {
					name = "trauma",
					level_num = level_num,
					has_levels = true,
					priority = 0.75,
					value = math_floor(trauma_val * 10) / 10
				})
				currentEffectNames["trauma"] = true
			end
			
			if hasAnyAmputation(org) then
				table.insert(effects, {name = "amputant", priority = 8})
				currentEffectNames["amputant"] = true
			end
			
			if org.heartstop == true then
				table.insert(effects, {name = "cardiac_arrest", priority = 0.15})
				currentEffectNames["cardiac_arrest"] = true
			end
			
			if org.lungsfunction == false then
				table.insert(effects, {name = "lungs_failure", priority = 0.35})
				currentEffectNames["lungs_failure"] = true
			end
		end
		
		if showAllIcons then
			local bleed_val = smooth.bleed or getOrgVal(org, "bleed", 0)
			if bleed_val > HUD.bleeding_threshold then
				local level_num = 1
				if bleed_val > 7.5 then level_num = 4
				elseif bleed_val > 5 then level_num = 3
				elseif bleed_val > 2.5 then level_num = 2 end
				
				table.insert(effects, {
					name = "bleeding",
					level_num = level_num,
					has_levels = true,
					priority = 0.3,
					value = math_floor(bleed_val)
				})
				currentEffectNames["bleeding"] = true
			end
			
			local internal_bleed_val = smooth.internalBleed or getOrgVal(org, "internalBleed", 0)
			if internal_bleed_val > HUD.internal_bleed_threshold then
				table.insert(effects, {
					name = "internal_bleed",
					priority = 0.4,
					value = math_floor(internal_bleed_val * 100)
				})
				currentEffectNames["internal_bleed"] = true
			end
			
			local cons_val = smooth.conscious or getOrgVal(org, "consciousness", 1)
			local cons_percent = math_floor(cons_val * 100)
			if cons_percent < 90 then
				local level_num = 1
				if cons_percent <= 24 then level_num = 4
				elseif cons_percent <= 49 then level_num = 3
				elseif cons_percent <= 74 then level_num = 2 end
				
				table.insert(effects, {
					name = "conscious",
					level_num = level_num,
					has_levels = true,
					priority = 1,
					value = cons_percent
				})
				currentEffectNames["conscious"] = true
			end
			
			local stamina_table = org.stamina
			if stamina_table and type(stamina_table) == "table" then
				local stamina_val = stamina_table[1] or 0
				local stamina_max = stamina_table.max or 180
				
				if stamina_max <= 0 then stamina_max = 180 end
				
				local stamina_percent = (stamina_val / stamina_max) * 100
				
				if stamina_percent < 75 then
					local level_num = 1
					if stamina_percent <= 24 then level_num = 4
					elseif stamina_percent <= 49 then level_num = 3
					elseif stamina_percent <= 74 then level_num = 2 end
					
					table.insert(effects, {
						name = "stamina",
						level_num = level_num,
						has_levels = true,
						priority = 2,
						value = math_floor(stamina_percent)
					})
					currentEffectNames["stamina"] = true
				end
			end
			
			local spine1 = getOrgVal(org, "spine1", 0)
			local spine2 = getOrgVal(org, "spine2", 0)
			local spine3 = getOrgVal(org, "spine3", 0)
			local spine_fracture = spine1 >= HUD.fracture_threshold or spine2 >= HUD.fracture_threshold or spine3 >= HUD.fracture_threshold
			if spine_fracture then
				table.insert(effects, {name = "spine_fracture", priority = 3})
				currentEffectNames["spine_fracture"] = true
			end
			
			if hasAnyFracture(org, HUD.fracture_threshold) then
				table.insert(effects, {name = "fracture", priority = 6})
				currentEffectNames["fracture"] = true
			end
			
			local organ_damage = math_max(
				getOrgVal(org, "heart", 0),
				getOrgVal(org, "liver", 0),
				getOrgVal(org, "stomach", 0),
				getOrgVal(org, "intestines", 0),
				getOrgTableVal(org, "lungsR", 1, nil, 0),
				getOrgTableVal(org, "lungsL", 1, nil, 0),
				getOrgTableVal(org, "lungsR", 2, nil, 0),
				getOrgTableVal(org, "lungsL", 2, nil, 0)
			)
			if organ_damage > HUD.organ_damage_threshold then
				table.insert(effects, {name = "organ_damage", priority = 4})
				currentEffectNames["organ_damage"] = true
			end
			
			if org.llegdislocation or org.rlegdislocation or 
			   org.larmdislocation or org.rarmdislocation or 
			   org.jawdislocation then
				table.insert(effects, {name = "dislocation", priority = 5})
				currentEffectNames["dislocation"] = true
			end
			
			local blood_val = smooth.blood or getOrgVal(org, "blood", 5000)
			if blood_val < HUD.blood_loss_threshold then
				local level_num = 1
				if blood_val < 2500 then level_num = 4
				elseif blood_val < 3600 then level_num = 3
				elseif blood_val < 4500 then level_num = 2 end
				
				table.insert(effects, {
					name = "blood_loss",
					level_num = level_num,
					has_levels = true,
					priority = 0.1,
					value = math_floor(blood_val)
				})
				currentEffectNames["blood_loss"] = true
			end
			
			if org.heartstop == true then
				table.insert(effects, {
					name = "cardiac_arrest",
					priority = 0.15
				})
				currentEffectNames["cardiac_arrest"] = true
			end
			
			local temp_val = smooth.temperature or getOrgVal(org, "temperature", 36.7)
			if temp_val < HUD.cold_threshold then
				local level_num = 1
				if temp_val < 31 then level_num = 4
				elseif temp_val < 33 then level_num = 3
				elseif temp_val < 35 then level_num = 2 end
				
				table.insert(effects, {
					name = "cold",
					level_num = level_num,
					has_levels = true,
					priority = 0.2,
					value = math_floor(temp_val * 10) / 10
				})
				currentEffectNames["cold"] = true
			end
			
			if temp_val > HUD.heat_threshold then
				local level_num = 1
				if temp_val > 40 then level_num = 4
				elseif temp_val > 39 then level_num = 3
				elseif temp_val > 38 then level_num = 2 end
				
				table.insert(effects, {
					name = "heat",
					level_num = level_num,
					has_levels = true,
					priority = 0.2,
					value = math_floor(temp_val * 10) / 10
				})
				currentEffectNames["heat"] = true
			end
			
			local pneumo_val = smooth.pneumothorax or getOrgVal(org, "pneumothorax", 0)
			if pneumo_val > HUD.hemothorax_threshold then
				local level_num = 1
				if pneumo_val > 0.7 then level_num = 4
				elseif pneumo_val > 0.3 then level_num = 3
				elseif pneumo_val > 0.1 then level_num = 2 end
				
				table.insert(effects, {
					name = "hemothorax",
					level_num = level_num,
					has_levels = true,
					priority = 0.25,
					value = math_floor(pneumo_val * 100)
				})
				currentEffectNames["hemothorax"] = true
			end
			
			if org.lungsfunction == false then
				table.insert(effects, {
					name = "lungs_failure",
					priority = 0.35
				})
				currentEffectNames["lungs_failure"] = true
			end
			
			local analgesia_val = smooth.analgesia or getOrgVal(org, "analgesia", 0)
			if analgesia_val > 0.1 then
				local level_num = 1
				if analgesia_val > 2 then level_num = 4
				elseif analgesia_val > 1.6 then level_num = 3
				elseif analgesia_val > 1 then level_num = 2 end
				
				table.insert(effects, {
					name = "overdose",
					level_num = level_num,
					has_levels = true,
					priority = 0.45,
					value = math_floor(analgesia_val * 10) / 10
				})
				currentEffectNames["overdose"] = true
			end
			
			local o2_val = getO2Value(org)
			if o2_val < HUD.oxygen_threshold then
				local level_num = 1
				if o2_val < 8 then level_num = 4
				elseif o2_val < 14 then level_num = 3
				elseif o2_val < 23 then level_num = 2 end
				
				table.insert(effects, {
					name = "oxygen",
					level_num = level_num,
					has_levels = true,
					priority = 0.5,
					value = math_floor(o2_val)
				})
				currentEffectNames["oxygen"] = true
			end
			
			local vomit_val = smooth.wantToVomit or getOrgVal(org, "wantToVomit", 0)
			if vomit_val > HUD.vomit_threshold then
				local level_num = 1
				if vomit_val > 0.9 then level_num = 4
				elseif vomit_val > 0.8 then level_num = 3
				elseif vomit_val > 0.6 then level_num = 2 end
				
				table.insert(effects, {
					name = "vomit",
					level_num = level_num,
					has_levels = true,
					priority = 0.55,
					value = math_floor(vomit_val * 100)
				})
				currentEffectNames["vomit"] = true
			end
			
			local brain_val = smooth.brain or getOrgVal(org, "brain", 0)
			if brain_val > HUD.brain_damage_threshold then
				local level_num = 1
				if brain_val > 0.3 then level_num = 4
				elseif brain_val > 0.25 then level_num = 3
				elseif brain_val > 0.15 then level_num = 2 end
				
				table.insert(effects, {
					name = "brain_damage",
					level_num = level_num,
					has_levels = true,
					priority = 0.6,
					value = math_floor(brain_val * 100)
				})
				currentEffectNames["brain_damage"] = true
			end
			
			local adrenaline_val = smooth.adrenaline or getOrgVal(org, "adrenaline", 0)
			if adrenaline_val > HUD.adrenaline_threshold then
				local level_num = 1
				if adrenaline_val > 2.1 then level_num = 4
				elseif adrenaline_val > 1.5 then level_num = 3
				elseif adrenaline_val > 0.8 then level_num = 2 end
				
				table.insert(effects, {
					name = "adrenaline",
					level_num = level_num,
					has_levels = true,
					priority = 0.65,
					value = math_floor(adrenaline_val * 10) / 10
				})
				currentEffectNames["adrenaline"] = true
			end
			
			local shock_val = smooth.shock or getOrgVal(org, "shock", 0)
			if shock_val > HUD.shock_threshold then
				local level_num = 1
				if shock_val > 35 then level_num = 4
				elseif shock_val > 25 then level_num = 3
				elseif shock_val > 10 then level_num = 2 end
				
				table.insert(effects, {
					name = "shock",
					level_num = level_num,
					has_levels = true,
					priority = 0.7,
					value = math_floor(shock_val)
				})
				currentEffectNames["shock"] = true
			end
			
			local trauma_val = smooth.disorientation or getOrgVal(org, "disorientation", 0)
			if trauma_val > HUD.trauma_threshold then
				local level_num = 1
				if trauma_val > 3 then level_num = 4
				elseif trauma_val > 2.5 then level_num = 3
				elseif trauma_val > 1 then level_num = 2 end
				
				table.insert(effects, {
					name = "trauma",
					level_num = level_num,
					has_levels = true,
					priority = 0.75,
					value = math_floor(trauma_val * 10) / 10
				})
				currentEffectNames["trauma"] = true
			end
			
			if hasAnyAmputation(org) then
				table.insert(effects, {name = "amputant", priority = 8})
				currentEffectNames["amputant"] = true
			end
		end
	end
	
	for _, effect in ipairs(effects) do
		if not statusEffectAppearance[effect.name] or (effect.level_num and effect.level_num ~= lastStatusEffectLevels[effect.name]) then
			statusEffectAppearance[effect.name] = currentTime
		end
		lastStatusEffectLevels[effect.name] = effect.level_num
	end

	for name, _ in pairs(statusEffectAppearance) do
		if not currentEffectNames[name] then
			statusEffectAppearance[name] = nil
			tooltipHoverTime[name] = nil
			lastStatusEffectLevels[name] = nil
		end
	end
	
	local isAdmiring = LocalPlayer():GetNWBool("mcd_admiring", false)
	local effectsToDraw = {}
	for _, effect in ipairs(effects) do
	    local timeActive = currentTime - (statusEffectAppearance[effect.name] or 0)
	    if isAdmiring or timeActive < 10 then
	        table.insert(effectsToDraw, effect)
	    end
	end

	table.sort(effectsToDraw, function(a, b) return a.priority < b.priority end)

	local rawPositions = {}
	for i, effect in ipairs(effectsToDraw) do
		local base_x_pos = base_x - size
		local base_y_pos = base_y + (i - 1) * spacing
		table.insert(rawPositions, {
			x = base_x_pos,
			y = base_y_pos,
			index = i,
			effect = effect
		})
	end
	
	local hoveredIndex = nil
	if mx and my then
		for i, pos in ipairs(rawPositions) do
			if mx >= pos.x and mx <= pos.x + size and my >= pos.y and my <= pos.y + size then
				hoveredIndex = i
				break
			end
		end
	end
	
	if hoveredIndex then
		if hoverEffect.hoveredIndex ~= hoveredIndex then
			hoverEffect.hoveredIndex = hoveredIndex
			hoverEffect.hoverTime = currentTime
		end
	else
		hoverEffect.hoveredIndex = nil
	end
	
	local mouseOffsetX = 0
	local mouseOffsetY = 0
	if hoverEffect.hoveredIndex and mx and my then
		local hoveredPos = rawPositions[hoverEffect.hoveredIndex]
		if hoveredPos then
			local centerX = hoveredPos.x + size / 2
			local centerY = hoveredPos.y + size / 2
			local distX = mx - centerX
			local distY = my - centerY
			local maxDist = 30
			mouseOffsetX = math_min(math_max(distX * 0.15, -maxDist), maxDist)
			mouseOffsetY = math_min(math_max(distY * 0.15, -maxDist), maxDist)
		end
	end
	
	local targetScale = hoverEffect.hoveredIndex and 1.35 or 1.0
	hoverEffect.scale = Lerp(0.2, hoverEffect.scale, targetScale)
	

	local painShakeX, painShakeY = 0, 0
	if painVal > 20 then
		local painIntensity = math_min((painVal - 20) / 80, 1)
		local baseShake = painIntensity * 5
		
		painShakeX = math_sin(currentTime * 120) * baseShake * 0.8 + 
					 math_sin(currentTime * 70) * baseShake * 0.4
		
		painShakeY = math_cos(currentTime * 2) * baseShake * 0.8 + 
					 math_cos(currentTime * 2) * baseShake * 0.4
	end
	

	local beatShakeX, beatShakeY = 0, 0
	local beatScale = 1.0
	local berserkCamIntensity, berserkCamShakeX, berserkCamShakeY = getBerserkCamEffect()
	
	if berserkActive then

		local offsetVal = 0.85
		local bpmVal = 70
		local stationTime = 0
		
		if hg and hg.berserkStation and IsValid(hg.berserkStation) then
			stationTime = hg.berserkStation:GetTime()
		else
			stationTime = (currentTime % (60 / bpmVal)) * bpmVal / 60
		end
		
		local beat = 1 - ((stationTime - offsetVal) / 60 * bpmVal)
		beat = (beat - math.Round(beat)) % 1
		local beatIntensity = math.abs(math.sin(beat * math.pi * 2)) ^ 2
		

		beatShakeX = math_sin(currentTime * (bpmVal / 60 * math.pi * 2)) * beatIntensity * 5
		beatShakeY = math_cos(currentTime * 0.2) * beatIntensity * 4
		

		beatScale = 1.0 + beatIntensity * 0.2
		

		beatShakeX = beatShakeX + berserkCamShakeX
		beatShakeY = beatShakeY + berserkCamShakeY
	end
	

	local totalShakeX = painShakeX + beatShakeX
	local totalShakeY = painShakeY + beatShakeY
	
	for i, pos in ipairs(rawPositions) do
		local effect = pos.effect
		local base_x_pos = pos.x
		local base_y_pos = pos.y
		
		local repelX = 0
		local repelY = 0
		local scale = 1.0
		local offsetX = 0
		local offsetY = 0
		
		if hoverEffect.hoveredIndex then
			local dist = i - hoverEffect.hoveredIndex
			if dist == 0 then
				scale = hoverEffect.scale
				offsetX = mouseOffsetX
				offsetY = mouseOffsetY
			else
				local distAbs = math_abs(dist)
				local repelStrength = (hoverEffect.scale - 1) * size * 0.8
				
				local hoveredPos = rawPositions[hoverEffect.hoveredIndex]
				if hoveredPos then
					local dx = base_x_pos - hoveredPos.x
					local dy = base_y_pos - hoveredPos.y
					local distance = math_sqrt(dx * dx + dy * dy)
					if distance > 0 then
						local normX = dx / distance
						local normY = dy / distance
						local falloff = 1 / (1 + distAbs * 0.3)
						repelX = normX * repelStrength * falloff
						repelY = normY * repelStrength * falloff * 0.5
					end
				end
			end
		end
		
		scale = scale * beatScale
		
		local shakeOffset = 0
		local appearanceTime = statusEffectAppearance[effect.name]
		if appearanceTime then
			local timeActive = currentTime - appearanceTime
			if timeActive < 1.5 then
				local easeOut = (1 - timeActive) ^ 3
				shakeOffset = math_sin(timeActive * 18) * easeOut * 30
			end
		end
		
		local final_x = base_x_pos + repelX + shakeOffset + totalShakeX
		local final_y = base_y_pos + repelY + totalShakeY
		

		local screenWidth = ScrW()
		local screenHeight = ScrH()
		local margin = 10
		
		if final_x < margin then
			final_x = margin
		elseif final_x + size > screenWidth - margin then
			final_x = screenWidth - size - margin
		end
		
		if final_y < margin then
			final_y = margin
		elseif final_y + size > screenHeight - margin then
			final_y = screenHeight - size - margin
		end
		
		table.insert(statusEffectPositions, {
			x = final_x,
			y = final_y,
			size = size,
			name = effect.name,
			level_num = effect.level_num,
			value = effect.value
		})
		
		local drawSize = size * scale
		local drawX = final_x - (drawSize - size) / 2
		local drawY = final_y - (drawSize - size) / 2
		
		local bg_mat
		if effect.has_levels then
			bg_mat = status_sprites.level_backgrounds[effect.level_num] or status_sprites.background
		else
			bg_mat = status_sprites.background
		end
		
		if bg_mat and not bg_mat:IsError() then
			surface_SetDrawColor(255, 255, 255, 220)
			surface_SetMaterial(bg_mat)
			
			local bgDrawSize = drawSize
			local bgDrawX = drawX
			local bgDrawY = drawY
			local padding = 0
			
			if USE_ALT_ICONS then
				local multiplier = ALT_ICON_SETTINGS.background_multiplier
				bgDrawSize = drawSize * multiplier
				padding = ALT_ICON_SETTINGS.padding_offset
				bgDrawX = drawX + (drawSize - bgDrawSize) / 2
				bgDrawY = drawY + (drawSize - bgDrawSize) / 2
			end
			
			bgDrawX = bgDrawX + offsetX * 0.5
			bgDrawY = bgDrawY + offsetY * 0.5
			
			surface_DrawTexturedRect(bgDrawX + padding, bgDrawY + padding, bgDrawSize - padding * 2, bgDrawSize - padding * 2)
		else
			local bg_color = Color(40, 40, 50, 220)
			if effect.name == "bleeding" then
				bg_color = Color(180, 30, 30, 220)
			elseif effect.name == "internal_bleed" then
				bg_color = Color(200, 50, 100, 220)
			elseif effect.name == "blood_loss" then
				bg_color = Color(150, 0, 0, 220)
			elseif effect.name == "cardiac_arrest" then
				bg_color = Color(100, 0, 100, 220)
			elseif effect.name == "cold" then
				bg_color = Color(0, 100, 200, 220)
			elseif effect.name == "heat" then
				bg_color = Color(200, 100, 0, 220)
			elseif effect.name == "hemothorax" then
				bg_color = Color(150, 50, 0, 220)
			elseif effect.name == "lungs_failure" then
				bg_color = Color(100, 100, 100, 220)
			elseif effect.name == "overdose" then
				bg_color = Color(150, 0, 150, 220)
			elseif effect.name == "oxygen" then
				bg_color = Color(0, 50, 150, 220)
			elseif effect.name == "vomit" then
				bg_color = Color(100, 80, 0, 220)
			elseif effect.name == "brain_damage" then
				bg_color = Color(100, 0, 50, 220)
			elseif effect.name == "adrenaline" then
				bg_color = Color(255, 100, 0, 220)
			elseif effect.name == "shock" then
				bg_color = Color(100, 100, 200, 220)
			elseif effect.name == "trauma" then
				bg_color = Color(150, 50, 150, 220)
			elseif effect.name == "death" then
				bg_color = Color(0, 0, 0, 220)
			elseif effect.name == "berserk" then
				bg_color = Color(180, 0, 0, 220)
			elseif effect.name == "amputant" then
				bg_color = Color(80, 40, 40, 220)
			elseif effect.name == "fracture" then
				bg_color = Color(200, 100, 0, 220)
			elseif effect.has_levels then
				if effect.level_num == 4 then bg_color = Color(180, 30, 30, 220)
				elseif effect.level_num == 3 then bg_color = Color(220, 60, 30, 220)
				elseif effect.level_num == 2 then bg_color = Color(255, 140, 40, 220)
				else bg_color = Color(80, 200, 100, 220) end
			end
			
			surface_SetDrawColor(bg_color.r, bg_color.g, bg_color.b, bg_color.a)
			surface_DrawRect(drawX, drawY, drawSize, drawSize)
		end
		
		local icon_mat = nil
		if effect.name == "pain" then icon_mat = status_sprites.pain_icon
		elseif effect.name == "conscious" then icon_mat = status_sprites.conscious_icon
		elseif effect.name == "stamina" then icon_mat = status_sprites.stamina_icon
		elseif effect.name == "bleeding" then icon_mat = status_sprites.bleeding_icon
		elseif effect.name == "internal_bleed" then icon_mat = status_sprites.internal_bleed_icon
		elseif effect.name == "blood_loss" then icon_mat = status_sprites.blood_loss
		elseif effect.name == "cardiac_arrest" then icon_mat = status_sprites.cardiac_arrest
		elseif effect.name == "cold" then icon_mat = status_sprites.cold
		elseif effect.name == "heat" then icon_mat = status_sprites.heat
		elseif effect.name == "hemothorax" then icon_mat = status_sprites.hemothorax
		elseif effect.name == "lungs_failure" then icon_mat = status_sprites.lungs_failure
		elseif effect.name == "overdose" then icon_mat = status_sprites.overdose
		elseif effect.name == "oxygen" then icon_mat = status_sprites.oxygen
		elseif effect.name == "vomit" then icon_mat = status_sprites.vomit
		elseif effect.name == "brain_damage" then icon_mat = status_sprites.brain_damage
		elseif effect.name == "adrenaline" then icon_mat = status_sprites.adrenaline
		elseif effect.name == "shock" then icon_mat = status_sprites.shock
		elseif effect.name == "trauma" then icon_mat = status_sprites.trauma
		elseif effect.name == "death" then icon_mat = status_sprites.death
		elseif effect.name == "berserk" then icon_mat = status_sprites.berserk
		elseif effect.name == "amputant" then icon_mat = status_sprites.amputant
		elseif effect.name == "fracture" then icon_mat = status_sprites.fracture
		else icon_mat = status_sprites[effect.name] end
		
		if icon_mat and not icon_mat:IsError() then
			surface_SetDrawColor(255, 255, 255, 255)
			surface_SetMaterial(icon_mat)
			
			local iconDrawSize = drawSize - 4
			local iconDrawX = drawX + 2 + offsetX
			local iconDrawY = drawY + 2 + offsetY
			
			if USE_ALT_ICONS then
				local multiplier = ALT_ICON_SETTINGS.size_multiplier
				if ALT_ICON_SETTINGS.individual and ALT_ICON_SETTINGS.individual[effect.name] then
					multiplier = ALT_ICON_SETTINGS.individual[effect.name]
				end
				
				iconDrawSize = (drawSize - 4) * multiplier
				iconDrawX = drawX + (drawSize - iconDrawSize) / 2 + offsetX
				iconDrawY = drawY + (drawSize - iconDrawSize) / 2 + offsetY
			end
			
			surface_DrawTexturedRect(iconDrawX, iconDrawY, iconDrawSize, iconDrawSize)
		else
			local letterColor = berserkActive and Color(255, 100, 100, 255) or Color(255, 255, 255, 255)
			local letter = "?"
			local value_text = ""
			
			if effect.name == "pain" then
				letter = "P"
				value_text = effect.value .. ""
			elseif effect.name == "conscious" then
				letter = "C"
				value_text = effect.value .. "%"
			elseif effect.name == "stamina" then
				letter = "S"
				value_text = effect.value .. "%"
			elseif effect.name == "bleeding" then
				letter = "B"
				value_text = effect.value .. ""
			elseif effect.name == "internal_bleed" then
				letter = "IB"
				value_text = effect.value .. "%"
			elseif effect.name == "blood_loss" then
				letter = "BL"
				value_text = effect.value .. "ml"
			elseif effect.name == "cardiac_arrest" then
				letter = "CA"
			elseif effect.name == "cold" then
				letter = "C"
				value_text = effect.value .. "°C"
			elseif effect.name == "heat" then
				letter = "H"
				value_text = effect.value .. "°C"
			elseif effect.name == "hemothorax" then
				letter = "HX"
				value_text = effect.value .. "%"
			elseif effect.name == "lungs_failure" then
				letter = "LF"
			elseif effect.name == "overdose" then
				letter = "OD"
				value_text = effect.value .. ""
			elseif effect.name == "oxygen" then
				letter = "O2"
				value_text = effect.value .. "%"
			elseif effect.name == "vomit" then
				letter = "V"
				value_text = effect.value .. "%"
			elseif effect.name == "brain_damage" then
				letter = "BD"
				value_text = effect.value .. "%"
			elseif effect.name == "adrenaline" then
				letter = "A"
				value_text = effect.value .. ""
			elseif effect.name == "shock" then
				letter = "SH"
				value_text = effect.value .. ""
			elseif effect.name == "trauma" then
				letter = "T"
				value_text = effect.value .. ""
			elseif effect.name == "death" then
				letter = "☠"
			elseif effect.name == "berserk" then
				letter = "⚡"
				value_text = effect.value .. ""
			elseif effect.name == "amputant" then
				letter = "✂"
			elseif effect.name == "fracture" then
				letter = "F"
			else
				local letters = {spine_fracture = "SF", organ_damage = "OD", dislocation = "D"}
				letter = letters[effect.name] or "?"
			end
			
			if berserkActive then
				draw_SimpleText(letter, "TargetID", drawX + drawSize * 0.4 + offsetX + 1, drawY + drawSize * 0.3 + offsetY + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				draw_SimpleText(letter, "TargetID", drawX + drawSize * 0.4 + offsetX - 1, drawY + drawSize * 0.3 + offsetY - 1, Color(255, 50, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
			
			draw_SimpleText(letter, "TargetID", drawX + drawSize * 0.4 + offsetX, drawY + drawSize * 0.3 + offsetY, letterColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			
			if value_text ~= "" then
				if berserkActive then
					draw_SimpleText(value_text, "DermaDefault", drawX + drawSize * 0.5 + offsetX + 1, drawY + drawSize * 0.7 + offsetY + 1, Color(0, 0, 0, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
					draw_SimpleText(value_text, "DermaDefault", drawX + drawSize * 0.5 + offsetX - 1, drawY + drawSize * 0.7 + offsetY - 1, Color(255, 50, 50, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
				end
				draw_SimpleText(value_text, "DermaDefault", drawX + drawSize * 0.5 + offsetX, drawY + drawSize * 0.7 + offsetY, letterColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
			end
		end
	end
end

local function draw_status_tooltips()
    if not HUD.enabled or not HUD.show_status_effects or #statusEffectPositions == 0 then return end
    
    if not isAnyMenuOpen() then return end
    
    local mx, my = gui.MousePos()
    if not mx or mx == 0 then return end
    
    local ply = LocalPlayer()
    local berserkActive = IsValid(ply) and ply.organism and isBerserkActive(ply.organism) or false
    
    local hoveredStatus = nil
    local hoveredPos = nil
    local hoveredIndex = nil
    
    for idx, pos in ipairs(statusEffectPositions) do
        if mx >= pos.x and mx <= pos.x + pos.size and my >= pos.y and my <= pos.y + pos.size then
            hoveredStatus = pos.name
            hoveredPos = pos
            hoveredIndex = idx
            break
        end
    end
    
    if hoveredStatus and hoveredPos then
        local tooltipText = getTooltipText(hoveredStatus, hoveredPos, berserkActive)
        
        if tooltipText and tooltipText ~= "" then
            local font = "DermaDefault"
            if berserkActive then
                font = "HuyFont"
            end
            
            surface.SetFont(font)
            local textW, textH = surface.GetTextSize(tooltipText)
            
            local baseTooltipX = hoveredPos.x - textW - 30
            local baseTooltipY = hoveredPos.y + (hoveredPos.size - textH) / 2
            
            local centerX = hoveredPos.x - textW / 2 - 10
            local centerY = hoveredPos.y + hoveredPos.size / 2
            local distX = mx - centerX
            local distY = my - centerY
            local maxDist = 15
            
            local parallaxX = math_min(math_max(distX * 0.1, -maxDist), maxDist)
            local parallaxY = math_min(math_max(distY * 0.1, -maxDist), maxDist)
            
            local tooltipX = baseTooltipX + parallaxX
            local tooltipY = baseTooltipY + parallaxY
            
            if tooltipX < 10 then tooltipX = 10 end
            if tooltipY < 10 then tooltipY = 10 end
            if tooltipY + textH > ScrH() - 10 then tooltipY = ScrH() - textH - 10 end
            
            local padding = 8
            
            surface.SetDrawColor(25, 25, 35, 240)
            surface.DrawRect(tooltipX - padding, tooltipY - padding, textW + padding * 2, textH + padding * 2)
            
            surface.SetDrawColor(255, 50, 50, 255)
            surface.DrawOutlinedRect(tooltipX - padding, tooltipY - padding, textW + padding * 2, textH + padding * 2)
            
            draw.SimpleText(tooltipText, font, tooltipX, tooltipY, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end

local function draw_sprites()
	if not HUD.enabled then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply.organism then return end
	
	if HUD.base_x == nil then HUD.base_x = ScrW() - 120 end
	
	local org = ply.organism
	local base_x = HUD.base_x
	local base_y = HUD.base_y
	local dt = FrameTime() * HUD.limb_fade_speed
	
	if not debug_done then
		debug_done = true
		local paths = {
			head = {"vgui/hud/health_head.png", "vgui/hud/health_head"},
			torso = {"vgui/hud/health_torso.png", "vgui/hud/health_torso"},
			right_arm = {"vgui/hud/health_right_arm.png", "vgui/hud/health_right_arm"},
			left_arm = {"vgui/hud/health_left_arm.png", "vgui/hud/health_left_arm"},
			right_leg = {"vgui/hud/health_right_leg.png", "vgui/hud/health_right_leg"},
			left_leg = {"vgui/hud/health_left_leg.png", "vgui/hud/health_left_leg"},
		}
		
		for name, tries in pairs(paths) do
			for _, path in ipairs(tries) do
				local mat = Material(path, "smooth")
				if mat and not mat:IsError() then
					sprites[name] = mat
					break
				end
			end
			if not sprites[name] then sprites[name] = false end
		end
	end
	
	local anyDamage = hasAnyLimbDamage(org)
	
	if anyDamage and not limbsRevealed then
		limbsRevealed = true
	elseif not anyDamage and limbsRevealed then
		limbsRevealed = false
	end
	
	local limbs = {
		{name = "head", dmg = math_max(getOrgVal(org, "skull", 0), getOrgVal(org, "jaw", 0) * 0.7), amput = "headamputated", label = "H"},
		{name = "torso", dmg = math_max(getOrgVal(org, "chest", 0), getOrgVal(org, "spine1", 0), getOrgVal(org, "spine2", 0), getOrgVal(org, "spine3", 0), getOrgVal(org, "pelvis", 0) * 0.9), amput = nil, label = "T"},
		{name = "right_arm", dmg = getOrgVal(org, "rarm", 0), amput = "rarmamputated", label = "RA"},
		{name = "left_arm", dmg = getOrgVal(org, "larm", 0), amput = "larmamputated", label = "LA"},
		{name = "right_leg", dmg = getOrgVal(org, "rleg", 0), amput = "rlegamputated", label = "RL"},
		{name = "left_leg", dmg = getOrgVal(org, "lleg", 0), amput = "llegamputated", label = "LL"},
	}
	
	for _, limb in ipairs(limbs) do
		local state = limbFadeStates[limb.name]
		if not state then continue end
		
		if limb.amput and org[limb.amput] then
			state.target = 0
		else
			state.target = 255
		end
		
		state.alpha = Lerp(dt, state.alpha, state.target)
		
		if state.alpha < 1 then
			continue
		end
		
		local dmg = limb.dmg
		local ofs = HUD.limb_offsets[limb.name] or {x = 0, y = 0}
		local scale = HUD.limb_scale[limb.name] or {w = 1.0, h = 1.0}
		
		local x = base_x + ofs.x
		local y = base_y + ofs.y
		
		local base_size = 40
		local width = base_size * scale.w
		local height = base_size * scale.h
		
		local col = getLimbColor(dmg)
		local damage_boost = math_min(dmg * 150, 100)
		local total_visibility = math_min(HUD.sprite_visibility + damage_boost, 100)
		local alpha = math_floor(state.alpha * (total_visibility / 100))
		
		local mat = sprites[limb.name]
		if mat and not mat:IsError() then
			surface_SetDrawColor(col.r, col.g, col.b, alpha)
			surface_SetMaterial(mat)
			surface_DrawTexturedRect(x - width * 0.5, y - height * 0.5, width, height)
		else
			surface_SetDrawColor(0, 0, 0, math_floor(alpha * 0.5))
			surface_DrawRect(x - width * 0.5 + 2, y - height * 0.5 + 2, width - 4, height - 4)
			surface_SetDrawColor(col.r, col.g, col.b, alpha)
			surface_DrawRect(x - width * 0.5 + 4, y - height * 0.5 + 4, width - 8, height - 8)
			draw_SimpleText(limb.label, "TargetID", x, y, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		end
	end
end

hook.Add("PopulateToolMenu", "ZMoodle_PopulateMenu", function()
	spawnmenu.AddToolMenuOption("Utilities", "Zcity", "ZMoodle_Settings", "Zcity Moodle", "", "", function(panel)
		panel:ClearControls()
		
		panel:CheckBox("Enable HUD", "mzb_MoodleHud_enabled")
		panel:CheckBox("Always show limbs", "mzb_popalimbs")
		panel:CheckBox("NoPixel icons(test)", "mzb_nopixelicons")
		panel:CheckBox("Show moodles(Maybe it doesn't work:))", "mzb_Disable_moodle")
		
		local langCombo = panel:ComboBox("Language", "mzb_language")
		langCombo:AddChoice("English", "eng")
		langCombo:AddChoice("Russian", "ru")
		
		local currentLang = GetConVarString("mzb_language") or "eng"
		langCombo:SetText(currentLang == "ru" and "Русский" or "English")
		
		function langCombo:OnSelect(index, value, data)
			RunConsoleCommand("mzb_language", data)
			self:SetText(value)
		end
		
		panel:Help("Hover over status icons for detailed info")
	end)
end)

concommand.Add("mzb_language", function(ply, cmd, args)
	if args[1] then
		local lang = string.lower(args[1])
		if lang == "ru" or lang == "русский" or lang == "russian" then
			LANGUAGE = "ru"
			RunConsoleCommand("mzb_language", "ru")
			chat.AddText(Color(0, 200, 255), "Language set to: ", Color(255, 255, 255), "Русский")
		elseif lang == "eng" or lang == "english" or lang == "английский" then
			LANGUAGE = "eng"
			RunConsoleCommand("mzb_language", "eng")
			chat.AddText(Color(0, 200, 255), "Language set to: ", Color(255, 255, 255), "English")
		else
			chat.AddText(Color(255, 100, 100), "Unknown language. Use: ru / eng")
		end
	else
		chat.AddText(Color(0, 200, 255), "Current language: ", Color(255, 255, 255), 
			LANGUAGE == "ru" and "Русский" or "English")
		chat.AddText(Color(200, 200, 200), "Usage: mzb_language ru / eng")
	end
end)

concommand.Add("mzb_nopixelicons", function(ply, cmd, args)
	local newValue
	if args[1] then
		local val = tonumber(args[1])
		if val ~= nil then
			newValue = val ~= 0
		end
	end
	
	if newValue == nil then
		newValue = not USE_ALT_ICONS
	end
	
	USE_ALT_ICONS = newValue
	HUD.use_alt_icons = USE_ALT_ICONS
	RunConsoleCommand("mzb_nopixelicons", tostring(USE_ALT_ICONS and 1 or 0))
	
	status_sprites_loaded = false
	status_sprites = {
		level_backgrounds = {nil, nil, nil, nil},
		background = nil,
		pain_icon = nil,
		conscious_icon = nil,
		stamina_icon = nil,
		bleeding_icon = nil,
		internal_bleed_icon = nil,
		organ_damage = nil,
		dislocation = nil,
		spine_fracture = nil,
		fracture = nil,
		blood_loss = nil,
		cardiac_arrest = nil,
		cold = nil,
		heat = nil,
		hemothorax = nil,
		lungs_failure = nil,
		overdose = nil,
		oxygen = nil,
		vomit = nil,
		brain_damage = nil,
		adrenaline = nil,
		shock = nil,
		trauma = nil,
		death = nil,
		berserk = nil,
		amputant = nil,
	}
	
	local status = USE_ALT_ICONS and "ON" or "OFF"
	chat.AddText(Color(0, 200, 255), "Alternative icons: ", USE_ALT_ICONS and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), status)
end)

concommand.Add("mzb_popalimbs", function(ply, cmd, args)
	local newValue
	if args[1] then
		local val = tonumber(args[1])
		if val ~= nil then
			newValue = val ~= 0
		end
	end
	
	if newValue == nil then
		newValue = not HUD.always_show_limbs
	end
	
	HUD.always_show_limbs = newValue
	RunConsoleCommand("mzb_popalimbs", tostring(HUD.always_show_limbs and 1 or 0))
	
	local status = HUD.always_show_limbs and "ON (always visible)" or "OFF (show if damaged)"
	chat.AddText(Color(0, 200, 255), "Limbs Viewer: ", HUD.always_show_limbs and Color(100, 255, 100, 255) or Color(255, 100, 100, 255), status)
end)

cvars.AddChangeCallback("mzb_MoodleHud_enabled", function(name, old, new)
	HUD.enabled = tonumber(new) ~= 0
end)

cvars.AddChangeCallback("mzb_popalimbs", function(name, old, new)
	HUD.always_show_limbs = tonumber(new) ~= 0
end)

cvars.AddChangeCallback("mzb_nopixelicons", function(name, old, new)
	USE_ALT_ICONS = tonumber(new) ~= 0
	HUD.use_alt_icons = USE_ALT_ICONS
	status_sprites_loaded = false
end)

cvars.AddChangeCallback("mzb_language", function(name, old, new)
	LANGUAGE = new
end)

hook.Add("HUDPaint", "ZB_Health_Bar", draw_bar)
-- hook.Add("HUDPaint", "ZB_Health_Sprites", draw_sprites)
hook.Add("HUDPaint", "ZB_Health_StatusEffects", draw_status_effects)
hook.Add("HUDPaint", "ZB_Health_StatusTooltips", draw_status_tooltips)