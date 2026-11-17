util.AddNetworkString("HGNotificate")
util.AddNetworkString("HGNotificateBerserk")
util.AddNetworkString("HGThought")

--local hg_old_notificate = ConVarExists("hg_old_notificate") and GetConVar("hg_old_notificate") or CreateConVar("hg_old_notificate",0,FCVAR_SERVER_CAN_EXECUTE,"enable old notifications (chatprints)",0,1)
local hev_color = Color(255,125,0)
local CreateThought
local THOUGHT_GLOBAL_GAP = 1.2
local UNTHROTTLED_GROUPS = {
    blocked = true,
    status = true,
    good = true,
}

local function InDespair(ply)
    return (ply.despairUntil or 0) > CurTime()
end

local function SameThoughtText(msg)
    return msg
end

local thoughtMessages = {
    panicattack_start = {"Panic is clouding my head.", "I'm starting to panic."},
    panicattack = {"I'm panicking.", "I can't stop panicking."},
    fear = {"I'm afraid.", "I'm terrified."},
    threatened = {"You are under immediate threat.", "I'm in danger."},
    wake = {"You regain consciousness.", "You woke up."},
    neckslit_save = {"Your neck wound is causing severe blood loss.", "Your neck artery is bleeding dangerously."},
    cervical_respiratory_arrest = {"Your spinal injury is stopping you from moving or breathing.", "Your cervical spine is causing respiratory failure."},
    dislocations_unlucky = {"You are struggling to fix a dislocation.", "You fail to fix a dislocation."},
    fix = SameThoughtText,
    painfromjawspeak = {"My jaw hurts when I talk.", "Talking makes my jaw hurt."},
    arteria = {"Your neck has ben cut open.", "Your carotid artery is open."},
    take_gasmask = {"Your gas mask is restricting airflow.", "Your gas mask is making it hard to breathe."},
    take_gasmask2 = {"The gas mask is preventing you from breathing.", "You can't breathe due to a gas mask."},
    oxygen_lowintake = {"You cant get enough air.", "You are struggling to breathe."},
    lowoxy = {"You are low on oxygen.", "Your oxygen level is critically low."},
    lowoxy2 = {"You are critically low on oxygen.", "You are experiencing severe oxygen deprivation."},
    hypoxia_critical = {"Your oxygen level is critically low.", "Your body is failing from oxygen deprivation."},
    spine3_oxygen_loss = {"Your spinal injury is cutting off oxygen.", "Your body is losing oxygen below the neck."},
    cervical_paralysis = {"Your neck is broken. You can't move."},
    drugged = {"You have been drugged.", "You are overdosing."},
    pneumothorax1 = {"Air or blood is accumulating around a lung.", "Something is building up around your lungs."},
    pneumothorax2 = {"Your lungs are not breathing properly.", "Something causes your lungs to not expand properly."},
    pneumothorax3 = {"A chest injury is preventing you from breathing.", "Something around your lungs prevents breathing."},
    brain = {"You have a brain injury.", "You are brain damaged."},
    intracranial_bleed = {"You have intracranial bleeding.", "Your head is starting to hurt."},
    blood2 = {"You are losing a dangerous amount of blood.", "Blood loss is making you feel weak."},
    internalbleed = {"Something is bleeding inside.", "You are internally bleeding."},
    nosebleed = {"Something makes your nose bleed.", "Your nose is bleeding."},
    hungry = {"You need food.", "You are hungry."},
    hungry_severe = {"You are starving.", "Hunger is taking a serious toll on your body."},
    thirsty = {"You need water.", "You are thirsty."},
    thirsty_severe = {"You are severely dehydrated.", "Dehydration is taking a serious toll on your body."},
    heart = {"Your heart is not functioning properly.", "Something is wrong with your heart."},
    heartstop = {"You are undergoing cardiac arrest.", "Your heart has stopped."},
    painfrommoving = {"My leg hurts when I move.", "I can't move comfortably on this leg."},
    painfromjaw = {"My jaw hurts when I speak.", "My jaw is killing me."},
    painfromribs = {"My chest hurts.", "Something is poking at my lungs."},
    arrhythmia = {"Your heart rhythm is irregular.", "You have a heart arrhythmia."},
    tachycardia = {"Your heart rate is dangerously high.", "You have symptoms of tachycardia."},
    bradycardia = {"You are bradycardic.", "Your heart rate is dangerously low."},
    shortbreath = {"You are short of breath.", "You can't get enough air."},
    barely_breathing = {"You are breathing weakly.", "Your breathing is shallow."},
    low_stamina = {"You are exerted.", "You feel tired."},
    trachea1 = {"Your trachea is slightly damaged.", "Something hit your windpipe."},
    trachea2 = {"Your trachea is damaged.", "Your windpipe is injured."},
    trachea_critical = {"Your trachea is too damaged to work.", "Your windpipe can't provide air anymore."},
    phrase = {"You notice something is wrong.", "Your body is warning you that something is wrong."},
    concussion_thought = {"You have a concussion.", "You are concussed."},
    concussion_loc = {"Your consciousness is failing.", "You are about to lose consciousness."},
    concussion_choke = {"Head trauma is making breathing hard.", "You cant breathe due to head trauma."},
    concussion_dryheave = {"You feel nauseous due to trauma.", "You feel incredibly nauseous."},
    concussion_lucid = {"You are experiencing a temporary lucid interval.", "You feel a temporary relief from concussion symptoms."},
    cotard_wake = {"You woke up disoriented.", "You are awake but confused."},
    depression_block_selfharm = {"You are not ready to hurt yourself.", "Your body resists self-harm."},
    hg_torso_initial = {"Your torso has been severed.", "You have suffered a catastrophic torso injury."},
    hg_torso_pain = {"Your torso wound is causing severe pain.", "You are suffering from a catastrophic torso injury."},
    pain = {"I'm in severe pain.", "My injuries hurt so much."},
    pain_severe = {"I'm in extreme pain.", "The pain is overwhelming me."},
    cold = {"Your body temperature is dangerously low.", "You are becoming hypothermic."},
    freezing = {"Your body temperature is critically low.", "You are suffering from severe hypothermia."},
    numb = {"Your body is becoming numb from the cold.", "You are severely hypothermic."},
    hot = {"Your body temperature is dangerously high.", "You are overheating."},
    heatstroke = {"You are suffering from heatstroke.", "Your body temperature is critically high."},
    broken_rleg = {"Your right leg is broken.", "You fractured your right leg."},
    broken_lleg = {"Your left leg is broken.", "You fractured your left leg."},
    broken_rarm = {"Your right arm is broken.", "You fractured your right arm."},
    broken_larm = {"Your left arm is broken.", "You fractured your left arm."},
    dislocated_rleg = {"Your right leg is dislocated.", "You dislocated your right leg."},
    dislocated_lleg = {"Your left leg is dislocated.", "You dislocated your left leg."},
    dislocated_rarm = {"Your right arm is dislocated.", "You dislocated your right arm."},
    dislocated_larm = {"Your left arm is dislocated.", "You dislocated your left arm."},
    med_err_needle = {"Something went wrong with the needle.", "You placed the needle wrong."},
    med_err_tourniquet = {"The tourniquet was applied incorrectly.", "You botched the tourniquet placement."},
    med_err_transfusion = {"Something happened with the transfusion.", "Something went wrong with the transfusion."},
    med_err_dose = {"You administered the wrong dosage.", "You introduced the wrong dosage."},
    med_err_bandage = {"You failed to properly bandage the wound.", "Something went wrong while bandaging."},
    med_error_actor = {"You botched the treatment.", "Something went wrong during treatment."},
    neardeath = {"I'm close to death.", "My body is shutting down."},
    lowoxy_mild = {"You are short on oxygen.", "You feel lightheaded."},
    blood_mild = {"You have lost some blood.", "Blood loss is making you feel lightheaded."},
    bomb_disarm = {"That was close.", "You barely made it out of that."},
    touched_hot_thing = {"You shouldn't have touched that.", "It burns your hand."},
    ragdoll_almostfall = {"I'm at my limit.", "I can't hold on much longer."},
    hypercapnia = {"Your head is pounding and you feel drowsy.", "Everything is spinning and you can't breathe it out.", "You feel heavy, like you are slowly suffocating."},
    hypertension_crisis = {"Your vision keeps swimming in and out.", "You are about to black out.", "Your head is pounding so hard you can't think."},
    spinal_bradypnea = {"You can barely breathe.", "Every breath you take is weaker."},
    ply_burn = {"I'm burning!", "The burns are excruciating."},
    cantdoit = {"You can't bring yourself to do it.", "There must be another way."},
    desomorphine_paralysis = {"One of your limbs has gone numb.", "One of your limbs stopped responding."},
    fiberwire_strangle_start = {"You are being strangled.", "Something is crushing your throat."},
    poison1 = {"You can't breathe properly.", "Your breathing feels wrong."},
    poison2 = {"Something is stopping you from breathing normally.", "Your breathing feels restricted."},
    cyanide = {"It smells like almonds in here.", "You notice a faint smell of almonds."},
    cyanide2 = {"It's getting difficult to breathe.", "Breathing is getting harder for no clear reason."},
    poison4 = {"Something feels wrong.", "Breathing is oddly harder."},
    idkdrive = {"You don't know how to drive."},
    rocket_doubt = {"You wonder if you should really do this.", "You hope this thing doesn't blow up.", "You brace yourself."},
    rocket_relief = {"You thought you were going to die.", "What a relief.", "It didn't explode."},
    furry_assimilate = {"Another one joins you.", "The assimilation is complete.", "You feel unstoppable."},
    furry_kill = {"One freak less.", "You put down an abomination.", "You silenced a raving beast."},
    reload_fumble = {"You missed.", "You dropped it."},
    reload_onehand = {"You can't reload it in your hand."},
    cycle_onehand = {"You can't cycle it with one hand."},
    glassshard_cut = {"The glass shard is cutting through your hand."},
    vitals_unneeded = {"You don't think you need to check their vitals."},
    cpr_useless = {"You don't think CPR would help here."},
    vitals_nopulse = {"You can't find a pulse."},
    vitals_interrupted = {"You were interrupted."},
    admin_godmode_on = {"You are now immortal."},
    admin_godmode_off = {"You are now mortal."},
    admin_cloak_on = {"You are now invisible."},
    admin_cloak_off = {"You are now visible."},
    jam = SameThoughtText,
    adrenaline_rouse = SameThoughtText,
    autoresuscitator_nohead = SameThoughtText,
    spine_fail = SameThoughtText,
    bandage_tourniquet = SameThoughtText,
    suture_nothing = SameThoughtText,
    suture_tourniquet = SameThoughtText,
    armor_unusable = SameThoughtText,
    armor_conflict = SameThoughtText,
    accessory_slot_occupied = SameThoughtText,
    armor_headphones_blocked = SameThoughtText,
    splint_nofrac = SameThoughtText,
    splint_apply = SameThoughtText,
    splint_apply_other = SameThoughtText,
    conc_test = SameThoughtText,
    mannitol_hev = SameThoughtText,
    needle_hev = SameThoughtText,
    morphine_hev = SameThoughtText,
    co_hev = SameThoughtText,
    bones_hev = SameThoughtText,
    pulse_hev = SameThoughtText,
    admin_notify = SameThoughtText,
    ammo_pickup = SameThoughtText,
    ammo_full = SameThoughtText,
    magazine_pickup = SameThoughtText,
    ied_planted = SameThoughtText,
    vitals_bpm = SameThoughtText,
}

local thoughtMessagePrefixes = {
    armor_dependency_ = SameThoughtText,
}

local scpcbHitgroupToCat = {
    [HITGROUP_HEAD] = "head",
    [HITGROUP_CHEST] = "chest",
    [HITGROUP_STOMACH] = "stomach",
    [HITGROUP_LEFTARM] = "leftarm",
    [HITGROUP_RIGHTARM] = "rightarm",
    [HITGROUP_LEFTLEG] = "leftleg",
    [HITGROUP_RIGHTLEG] = "rightleg",
    [HITGROUP_GENERIC] = "generic",
    [8] = "pelvis"
}

local scpcbThoughts = {
    head = {
        "A {weapon} struck your head, killing you instantly.",
        "A {weapon} hit your head, killing you instantly.",
        "A {weapon} pierced your skull, ending your life instantly.",
        "A {weapon} struck your temple, killing you instantly.",
        "A {weapon} shattered your cranium, killing you instantly.",
        "A {weapon} tore through your brain, killing you instantly.",
        "A {weapon} hit your forehead, ending your life instantly.",
        "A {weapon} struck your head, causing immediate brain death.",
        "A {weapon} shattered your head, ending it all instantly."
    },
    pelvis = {
        "The {weapon} pierces your pelvis, narrowly missing your nads.",
        "A {weapon} strikes your waist, causing severe pain.",
        "A {weapon} hits your pelvis, making you cringe.",
        "A {weapon} grazes your groin, narrowly missing your nads.",
        "A {weapon} shatters your hip, making you stumble."
    },
    pelvis_lethal = {
        "A {weapon} destroyed your pelvis, causing fatal blood loss.",
        "A {weapon} tore through your waist, severing an artery.",
        "A {weapon} shattered your pelvis, killing you from shock."
    },
    head_nonlethal = {
        "A {weapon} hit your head, causing severe pain.",
        "A {weapon} struck your head.",
        "A {weapon} hit your skull, making you dizzy.",
        "A {weapon} grazed your head, leaving a laceration.",
        "A {weapon} struck your skull, leaving you dazed.",
        "A {weapon} hit your head, making you gasp."
    },
    chest = {
        "A {weapon} hit your chest, making you gasp.",
        "A {weapon} struck your chest, making you gasp.",
        "A {weapon} hit your ribs, causing severe pain.",
        "A {weapon} struck your chest. Breathing becomes difficult.",
        "A {weapon} penetrated your chest.",
        "A {weapon} hit your chest, causing pain."
    },
    chest_lethal = {
        "A {weapon} struck your chest, causing fatal internal injuries.",
        "A {weapon} hit your chest, destroying your heart.",
        "A {weapon} tore through your lung, drowning you in blood.",
        "A {weapon} struck your chest, killing you instantly.",
        "A {weapon} shattered your ribcage, puncturing your heart."
    },
    stomach = {
        "A {weapon} hit your stomach, making you gasp.",
        "A {weapon} struck your gut, causing severe pain.",
        "A {weapon} hit your abdomen.",
        "A {weapon} struck your stomach, causing pain.",
        "A {weapon} penetrated your stomach."
    },
    stomach_lethal = {
        "A {weapon} struck your stomach, causing fatal internal bleeding.",
        "A {weapon} tore through your gut, killing you.",
        "A {weapon} hit your liver, causing massive bleeding.",
        "A {weapon} destroyed your stomach, ending your life."
    },
    leftarm = {
        "A {weapon} hit your left arm.",
        "A {weapon} struck your left arm.",
        "A {weapon} hit your left shoulder.",
        "A {weapon} struck your left forearm.",
        "A {weapon} pierced your left arm."
    },
    leftarm_lethal = {
        "A {weapon} severed your left arm, causing fatal blood loss.",
        "A {weapon} tore through your left arm, hitting an artery.",
        "A {weapon} shattered your left shoulder, killing you from shock.",
        "A {weapon} destroyed your left arm, causing you to bleed out."
    },
    rightarm = {
        "A {weapon} hit your right arm.",
        "A {weapon} struck your right arm.",
        "A {weapon} hit your right shoulder.",
        "A {weapon} struck your right forearm.",
        "A {weapon} pierced your right arm."
    },
    rightarm_lethal = {
        "A {weapon} severed your right arm, causing fatal blood loss.",
        "A {weapon} tore through your right arm, hitting an artery.",
        "A {weapon} shattered your right shoulder, killing you from shock.",
        "A {weapon} destroyed your right arm, causing you to bleed out."
    },
    leftleg = {
        "A {weapon} hit your left leg.",
        "A {weapon} struck your left leg.",
        "A {weapon} hit your left thigh.",
        "A {weapon} struck your left calf.",
        "A {weapon} hit your left knee.",
        "A {weapon} pierced your left leg."
    },
    leftleg_lethal = {
        "A {weapon} severed your left leg, causing fatal blood loss.",
        "A {weapon} tore through your left thigh, severing the femoral artery.",
        "A {weapon} shattered your left leg, killing you from shock.",
        "A {weapon} destroyed your left leg, causing you to bleed out."
    },
    rightleg = {
        "A {weapon} hit your right leg.",
        "A {weapon} struck your right leg.",
        "A {weapon} hit your right thigh.",
        "A {weapon} struck your right calf.",
        "A {weapon} hit your right knee.",
        "A {weapon} pierced your right leg."
    },
    rightleg_lethal = {
        "A {weapon} severed your right leg, causing fatal blood loss.",
        "A {weapon} tore through your right thigh, severing the femoral artery.",
        "A {weapon} shattered your right leg, killing you from shock.",
        "A {weapon} destroyed your right leg, causing you to bleed out."
    },
    generic = {
        "A {weapon} hit you.",
        "A {weapon} struck you.",
        "A {weapon} hit your body.",
        "A {weapon} struck your torso.",
        "A {weapon} hit you, causing pain."
    },
    generic_lethal = {
        "A {weapon} hit you, killing you instantly.",
        "A {weapon} struck you, causing fatal trauma.",
        "A {weapon} hit your body, ending your life.",
        "A {weapon} tore through you, causing fatal damage."
    },
    near_miss = {
        "A {weapon} barely missed you.",
        "A {weapon} whizzed past your head.",
        "A {weapon} flew by your ear.",
        "A {weapon} narrowly missed you.",
        "A {weapon} grazed past you.",
        "A {weapon} passed within inches of your head.",
        "A {weapon} went past you.",
        "A {weapon} missed you, but barely."
    },
    armor_full = {
        "A {weapon} hit your chest. The vest absorbed most of the damage.",
        "A {weapon} hit your chest. The vest absorbed some of the damage.",
        "A {weapon} struck your vest. Armor absorbed the impact.",
        "A {weapon} hit your vest.",
        "A {weapon} struck your vest."
    },
    armor_partial = {
        "A {weapon} hit your chest. The vest absorbed some of the damage.",
        "A {weapon} struck your chest. Your armor slowed it down.",
        "A {weapon} hit your chest. Plating cracked but stopped the impact.",
        "A {weapon} struck your vest, partially penetrating.",
        "A {weapon} hit your chest. Armor slowed the strike, but it still hit you."
    }
}

local function SCPCBThoughtDamageType(dmginfo, target)
    if dmginfo:IsBulletDamage() or dmginfo:IsDamageType(DMG_BUCKSHOT) then return "bullet" end
    if dmginfo:IsDamageType(DMG_SLASH) then return "slash" end
    if dmginfo:IsDamageType(DMG_CLUB) or dmginfo:IsDamageType(DMG_CRUSH) then return "blunt" end

    local inflictor = dmginfo:GetInflictor()
    local attacker = dmginfo:GetAttacker()
    local wep = IsValid(inflictor) and inflictor or (IsValid(attacker) and attacker.GetActiveWeapon and attacker:GetActiveWeapon())

    if IsValid(wep) then
        if wep:GetClass() == "weapon_melee" or wep.Base == "weapon_melee" or wep.DamageType then
            return wep.DamageType == DMG_SLASH and "slash" or "blunt"
        end

        if wep.Base == "homigrad_base" or wep.Primary and wep.Primary.Ammo then
            return "bullet"
        end
    end

    if dmginfo:GetDamage() >= target:Health() then return "generic" end
end

local function SCPCBThoughtHitgroup(target, dmgType, dmginfo, hitPos)
    if dmgType == "generic" then return HITGROUP_GENERIC end

    hitPos = hitPos or dmginfo:GetDamagePosition()
    local plyPos = target:GetPos() + Vector(0, 0, target:OBBMins().z)
    local height = target:OBBMaxs().z - target:OBBMins().z
    local hitHeight = hitPos.z - plyPos.z

    if hitHeight > height * 0.85 then return HITGROUP_HEAD end

    local right = target:GetRight()
    local toHit = hitPos - plyPos
    toHit.z = 0
    toHit:Normalize()

    if hitHeight > height * 0.4 then
        local rightDot = right:Dot(toHit)

        if math.abs(rightDot) > 0.7 and hitHeight > height * 0.5 then
            return rightDot > 0 and HITGROUP_RIGHTARM or HITGROUP_LEFTARM
        end

        if hitHeight > height * 0.6 then return HITGROUP_CHEST end
        if hitHeight > height * 0.5 then return HITGROUP_STOMACH end
        return 8
    end

    return right:Dot(toHit) > 0 and HITGROUP_RIGHTLEG or HITGROUP_LEFTLEG
end

local function SCPCBArmorProtection(ent, ply, hitgroup)
    local placement

    if hitgroup == HITGROUP_CHEST or hitgroup == HITGROUP_STOMACH or hitgroup == HITGROUP_GENERIC or hitgroup == 8 then
        placement = "torso"
    else
        return 0
    end

    local armors = (IsValid(ent) and ent.armors) or ply.armors
    if not armors then return 0 end

    local armor = armors[placement]
    local armorData = armor and hg.armor and hg.armor[placement] and hg.armor[placement][armor]
    if not armorData then return 0 end

    local broken = ((IsValid(ent) and ent.armors_broken) or ply.armors_broken or {})[armor]
    return broken and 0 or (armorData.protection or 0)
end

local SCPCBCreateThought

local conditionThoughtCooldowns = {
    internalbleed = 30,
    nosebleed = 30,
}

local function GetConditionThought(ply, msgKey, msg)
    local options = thoughtMessages[msgKey]
    if options == nil and isstring(msgKey) then
        for prefix, prefixOptions in pairs(thoughtMessagePrefixes) do
            if string.StartWith(msgKey, prefix) then options = prefixOptions break end
        end
    end
    if isfunction(options) then return options(msg) end
    if not istable(options) then return options end

    local optionCount = #options
    if optionCount <= 0 then return end

    ply.lastConditionThought = ply.lastConditionThought or {}
    local index = math.random(optionCount)
    local lastIndex = ply.lastConditionThought[msgKey]
    if optionCount > 1 and index == lastIndex then
        index = index % optionCount + 1
    end

    ply.lastConditionThought[msgKey] = index
    return options[index]
end

local combatThoughts = {
    stabbed = {
        "JESUS CHRIST- I GOT STABBED!",
        "FUCK- HE STABBED ME!",
        "OH GOD- I'M STABBED-",
        "SHIT- THAT BLADE WENT IN-",
        "I'VE BEEN STABBED- FUCK-",
        "HE CUT ME- HE FUCKING CUT ME-",
        "AGH- THAT'S STEEL IN ME-",
    },
    shot = {
        "JESUS CHRIST- I GOT SHOT!",
        "FUCK- I'M HIT-",
        "OH FUCK- I'M HIT- I'M HIT-",
        "SHIT- SHIT- I'M SHOT-",
        "HE SHOT ME- FUCK-",
        "I'VE BEEN SHOT- OH GOD-",
    },
    shot_head = {
        "MY HEAD- FUCK- MY HEAD-",
        "JESUS- THAT HIT MY HEAD-",
        "OH GOD- MY FACE-",
    },
    shot_armor = {
        "FUCK- THE VEST TOOK IT-",
        "SHIT- THAT HIT MY VEST-",
        "I'M HIT- THE ARMOR HELD-",
    },
    clubbed = {
        "FUCK- HE HIT ME-",
        "AGH- SOMETHING JUST SMASHED INTO ME-",
        "SHIT- I GOT HIT-",
    },
    near_shot = {
        "FUCK- I ALMOST GOT SHOT...",
        "JESUS- THAT ONE WAS CLOSE-",
        "SHIT- THAT MISSED ME BY INCHES-",
        "HOLY SHIT- THAT WAS RIGHT AT MY HEAD-",
        "THEY'RE SHOOTING AT ME-",
        "FUCK- I'M BEING SHOT AT-",
        "THAT ROUND WENT RIGHT PAST ME-",
    },
    multi_pass = {
        "THEY'RE LAYING DOWN FIRE- GET DOWN-",
        "SO MANY ROUNDS- THEY'RE ALL AROUND ME-",
        "FUCK- BULLETS EVERYWHERE- I CAN'T MOVE-",
        "THEY'RE PINNING ME- I NEED COVER-",
        "RIGHT PAST MY HEAD- AGAIN AND AGAIN-",
        "KEEP YOUR HEAD DOWN- KEEP YOUR HEAD DOWN-",
    },
    multi_hit = {
        "I'M BEING HIT- AGAIN- AGAIN-",
        "THEY'RE TEARING ME APART-",
        "TOO MANY- I'M TAKING TOO MANY-",
        "FUCK- THEY KEEP HITTING ME-",
        "I'M GETTING SHREDDED-",
    },
    multi_mixed = {
        "SOME HIT- SOME MISS- I'M IN A KILL ZONE-",
        "THEY'RE RAKING ME- I NEED TO MOVE-",
        "ROUNDS ALL OVER- AND I'M HIT-",
        "I'M UNDER FIRE- I'M HIT- MOVE MOVE MOVE-",
    },
}

local multiBulletPools = {multi_pass = true, multi_hit = true, multi_mixed = true}

function hg.CombatThought(ply, pool)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if ply.HasTrait and ply:HasTrait("gurajchaka_child") then return false end
    if ply.PlayerClassName == "Gordon" then return false end
    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return false end
    if InDespair(ply) then return false end

    local org = ply.organism
    if org and org.otrub then return false end

    local options = combatThoughts[pool]
    if not options then return false end

    local isMulti = multiBulletPools[pool] == true
    local isNear = pool == "near_shot"
    local useNew = ply:GetInfoNum("hg_newthoughts", 0) > 0
    if useNew and not isNear and not isMulti then return false end

    local now = CurTime()
    local cdKey = isMulti and "nextMultiBulletThought" or isNear and "nextNearShotThought" or "nextCombatThought"
    if (ply[cdKey] or 0) > now then return false end
    ply[cdKey] = now + (isMulti and 4 or isNear and 5 or 8)

    local msg = options[math.random(#options)]
    if ply.lastCombatThoughtText == msg then msg = options[math.random(#options)] end
    ply.lastCombatThoughtText = msg

    if org then org.nextStatusThought = math.max(org.nextStatusThought or 0, now + 6) end

    if useNew then
        ply.nextThoughtGlobal = now + THOUGHT_GLOBAL_GAP
        net.Start("HGThought")
        net.WriteString(msg)
        net.WriteColor(Color(255, 90, 90, 255))
        net.WriteString("combat")
        net.Send(ply)
    else
        net.Start("HGNotificate")
        net.WriteString(msg)
        net.WriteColor(Color(255, 90, 90, 255))
        net.WriteUInt(110, 7)
        net.Send(ply)
    end

    return true
end

local function SCPCBHitThought(ply, target, dmgType, dmg, hitPos, dmginfo)
    if not dmg or dmg <= 0 then return end

    local isLethal = dmg >= ply:Health()

    if not isLethal and (dmgType == "bullet" or dmgType == "slash" or dmgType == "blunt") then
        local now = CurTime()
        local hits = ply.despairHits or {}
        for i = #hits, 1, -1 do
            if now - hits[i] > 2.5 then table.remove(hits, i) end
        end
        hits[#hits + 1] = now
        ply.despairHits = hits

        if #hits >= 4 then
            ply.despairHits = {}
            hg.DespairThought(ply, true)
        end
    end

    local hitgroup = SCPCBThoughtHitgroup(target, dmgType, dmginfo, hitPos)
    local category = scpcbHitgroupToCat[hitgroup] or "generic"

    if not isLethal then
        if dmgType == "slash" then
            hg.CombatThought(ply, "stabbed")
        elseif dmgType == "bullet" then
            if SCPCBArmorProtection(target, ply, hitgroup) > 0 then
                hg.CombatThought(ply, "shot_armor")
            elseif hitgroup == HITGROUP_HEAD then
                hg.CombatThought(ply, "shot_head")
            else
                hg.CombatThought(ply, "shot")
            end
        elseif dmgType == "blunt" and dmg >= 8 then
            hg.CombatThought(ply, "clubbed")
        end
    end

    ply.scpcbThoughtHitTime = CurTime() + 0.25

    if !isLethal and SCPCBArmorProtection(target, ply, hitgroup) > 0 then
        category = dmg > SCPCBArmorProtection(target, ply, hitgroup) and "armor_partial" or "armor_full"
    elseif !isLethal and hitgroup == HITGROUP_HEAD then
        category = "head_nonlethal"
    end

    if dmgType ~= "bullet" or category == "armor_full" or category == "armor_partial" then
        SCPCBCreateThought(ply, category, dmgType, isLethal)
    end
end

SCPCBCreateThought = function(ply, category, dmgType, isLethal)
    if not CreateThought or not IsValid(ply) or not ply:IsPlayer() then return end
    if ply:GetInfoNum("hg_newthoughts", 0) <= 0 then return end
    if isLethal then return end

    local curTime = CurTime()
    ply.scpcbThoughtNext = ply.scpcbThoughtNext or 0

    if !isLethal and ply.scpcbThoughtNext > curTime then return end

    local targetCategory = category
    if isLethal and category != "head" and category != "near_miss" and category != "armor_full" and category != "armor_partial" then
        targetCategory = category .. "_lethal"
    end

    local options = scpcbThoughts[targetCategory] or scpcbThoughts.generic
    if not options then return end

    local weaponStr = "bullet"
    if dmgType == "blunt" then weaponStr = "blunt object" end
    if dmgType == "slash" then weaponStr = "sharp object" end
    if dmgType == "generic" then weaponStr = "impact" end

    local msg = string.gsub(options[math.random(1, #options)], "{weapon}", weaponStr)
    local delay = isLethal and 1 or (category == "near_miss" and 12 or 8)

    if CreateThought(ply, msg, delay, "scpcb_damage_" .. targetCategory, 0, color_white) then
        ply.scpcbThoughtNext = curTime + (isLethal and 1 or (category == "near_miss" and 6 or 4))
        return true
    end
end

local function SCPCBThoughtOwner(ent)
    if not IsValid(ent) then return end
    if ent:IsPlayer() then return ent end

    if hg and hg.RagdollOwner then
        local ply = hg.RagdollOwner(ent)
        if IsValid(ply) then return ply end
    end

    local ply = ent.ply
    if IsValid(ply) and ply:IsPlayer() then return ply end

    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply.FakeRagdoll) and ply.FakeRagdoll == ent then return ply end
        if hg and hg.GetCurrentCharacter and hg.GetCurrentCharacter(ply) == ent then return ply end
    end
end

local notificationPriorities = {
    hypoxia_critical_air = 100,
    hypoxia_critical_dying = 100,
    spine3_oxygen_loss = 90,
    cervical_paralysis = 80,
    pain_scream = 110,
    ribs = 10,
}

local function LegacyThoughtText(msg)
    return msg:gsub("^Your ", "My "):gsub("^You ", "I "):gsub(" your ", " my ")
end

local function CreateNotification(ply, msg, delay, msgKey, showTime, func, clr)
    if not IsValid(ply) or not ply:IsPlayer() then error("player is not valid!") return false end
    if not msg or not isstring(msg) then error("no message or message is invalid!") return false end
    if ply.organism and ply.organism.otrub then return end
    if InDespair(ply) then return false end
    if ply.PlayerClassName and ply.PlayerClassName == "Gordon" and clr != hev_color then return end
    msgKey = msgKey or msg

    if ply:GetInfoNum("hg_newthoughts", 0) > 0 and CreateThought then
        local thought = GetConditionThought(ply, msgKey, msg)
        if not thought then return false end

        local conditionCooldown = conditionThoughtCooldowns[msgKey]
        if conditionCooldown and (delay == nil or isnumber(delay)) then
            delay = math.max(tonumber(delay) or 0, conditionCooldown)
        end

        return CreateThought(ply, thought, delay, "thought_" .. msgKey, showTime, clr, func)
    end

    if string.StartWith(msgKey, "thought_") then msg = LegacyThoughtText(msg) end

    if msg == "" then return end

    ply.msgs = ply.msgs or {}
    if msgKey and ply.msgs[msgKey] then
        if isnumber(ply.msgs[msgKey]) then
            if ply.msgs[msgKey] > CurTime() then
                return false
            end
        else
            return false
        end
    end

    delay = delay or 5

    if msgKey then ply.msgs[msgKey] = delay and (not isnumber(delay) or CurTime() + delay) or nil end
    --показывать один раз за промежуток времени
    --(если delay не номерок то оно пинганет в следующей жизни)

    if ply.organism and ply.organism.brain > 0.1 then
        for i = 1, utf8.len(msg) do
            if math.random(3) == 1 and msg[i] != "?" and msg[i] != "." then
                msg = hg.replace_by_index(msg, i, (math.random(1,2) > 1 and "m" or "b") )
            end
        end
    end
    
    showTime = showTime or 0

    local clr = clr or color_white
    local clr2 = Color(clr.r, clr.g, clr.b, 255)

    timer.Simple(showTime, function()
        if !IsValid(ply) then return end
        if !ply.msgs[msgKey] then return end

        if (ply.organism and ply.organism.otrub) or !ply:Alive() or InDespair(ply) then
            return
        end

        if ply.organism and ply.organism.pain > 60 and (!clr or clr.g > 250) then
            return
        end

        if func and isfunction(func) then
            if func(ply) then return end
        end

        net.Start("HGNotificate")
        net.WriteString(msg)
        //net.WriteFloat(showTime or 3)
        net.WriteColor(clr2)
        net.WriteUInt(notificationPriorities[msgKey] or 0, 7)
        net.Send(ply)
    end)

    return true
end

//erm it's ass but i don't care enough
local function CreateNotificationBerserk(ply, msg, delay, msgKey, showTime, func, clr)
    if ply.organism and ply.organism.otrub then return end
    if ply.PlayerClassName and ply.PlayerClassName == "Gordon" and clr != hev_color then return end
    if msg == "" then return end
    if not IsValid(ply) or not ply:IsPlayer() then error("player is not valid!") return false end
    if not msg or not isstring(msg) then error("no message or message is invalid!") return false end
    msgKey = msgKey or msg
    ply.msgs = ply.msgs or {}
    if msgKey and ply.msgs[msgKey] then
        if isnumber(ply.msgs[msgKey]) then
            if ply.msgs[msgKey] > CurTime() then
                return false
            end
        else
            return false
        end
    end

    delay = delay or 0

    if msgKey then ply.msgs[msgKey] = delay and (not isnumber(delay) or CurTime() + delay) or nil end
    --показывать один раз за промежуток времени
    --(если delay не номерок то оно пинганет в следующей жизни)
    if func and isfunction(func) then
        func(ply)
    end

    if ply.organism and ply.organism.brain > 0.1 then
        for i = 1, utf8.len(msg) do
            if math.random(3) == 1 and msg[i] != "?" and msg[i] != "." then
                msg = hg.replace_by_index(msg, i, (math.random(1,2) > 1 and "m" or "b") )
            end
        end
    end
    
    showTime = showTime or 0

    local clr = clr or color_white
    local clr2 = Color(clr.r, clr.g, clr.b, 255)

    timer.Simple(showTime, function()
        if !IsValid(ply) then return end
        if !ply.msgs[msgKey] then return end

        if (ply.organism and ply.organism.otrub) or !ply:Alive() then
            return
        end

        if ply.organism and ply.organism.pain > 60 and (!clr or clr.g > 250) then
            return
        end

        net.Start("HGNotificateBerserk")
        net.WriteString(msg)
        //net.WriteFloat(showTime or 3)
        net.WriteColor(clr2)
        net.Send(ply)
    end)

    return true
end

local function ResetNotification(ply, key)
	if ply.msgs then ply.msgs[key] = nil end
	if ply.thoughtmsgs then
		ply.thoughtmsgs[key] = nil
		ply.thoughtmsgs["thought_" .. key] = nil
	end
end

local thoughtGroupPatterns = {
    {"blocked_", "blocked"},
    {"hgstatus_", "status"},
    {"hggood_", "good"},
    {"emotion_", "emotion"}, {"witness_", "emotion"}, {"psyche_", "emotion"}, {"depression_", "emotion"}, {"selfharm", "emotion"}, {"wound_", "emotion"},
    {"oxygen", "respiration"}, {"hypox", "respiration"}, {"lowoxy", "respiration"}, {"breath", "respiration"}, {"lung", "respiration"}, {"pneumo", "respiration"}, {"hemothorax", "respiration"},
    {"blood", "circulation"}, {"bleed", "circulation"}, {"arter", "circulation"}, {"perfusion", "circulation"},
    {"heart", "cardiac"}, {"pulse", "cardiac"}, {"arrhythm", "cardiac"}, {"tachy", "cardiac"}, {"brady", "cardiac"},
    {"bone", "skeletal"}, {"limb", "skeletal"}, {"fract", "skeletal"}, {"disloc", "skeletal"},
    {"pain", "pain"}, {"hurt", "pain"}, {"concussion", "neuro"}, {"brain", "neuro"}, {"dizz", "neuro"},
    {"panic", "panic"}, {"fear", "panic"},
    {"temperature", "temperature"}, {"hypotherm", "temperature"}, {"heat", "temperature"}, {"cold", "temperature"},
    {"hunger", "metabolic"}, {"starv", "metabolic"}, {"thirst", "metabolic"}, {"dehyd", "metabolic"},
}

local function GetThoughtGroup(msgKey, msg)
    local haystack = string.lower(tostring(msgKey or ""))
    for _, rule in ipairs(thoughtGroupPatterns) do
        if string.find(haystack, rule[1], 1, true) then return rule[2] end
    end

    haystack = string.lower(tostring(msg or ""))
    for _, rule in ipairs(thoughtGroupPatterns) do
        if string.find(haystack, rule[1], 1, true) then return rule[2] end
    end

    return "misc"
end

CreateThought = function(ply, msg, delay, msgKey, showTime, clr, func)
    if not IsValid(ply) or not ply:IsPlayer() then error("player is not valid!") return false end
    if not msg or not isstring(msg) then error("no message or message is invalid!") return false end
    if ply.organism and ply.organism.otrub then return end
    if msg == "" then return end
    if InDespair(ply) then return false end
    if ply:GetInfoNum("hg_newthoughts", 0) <= 0 then return false end

    msgKey = msgKey or msg
    ply.thoughtmsgs = ply.thoughtmsgs or {}
    ply.thoughtGroupCooldowns = ply.thoughtGroupCooldowns or {}
    ply.recentThoughtText = ply.recentThoughtText or {}
    local now = CurTime()
    local group = GetThoughtGroup(msgKey, msg)

    local blocked = UNTHROTTLED_GROUPS[group] == true
    if not blocked and (ply.nextThoughtGlobal or 0) > now then return false end
    if (ply.thoughtGroupCooldowns[group] or 0) > now then return false end
    if not blocked and (ply.recentThoughtText[msg] or 0) > now then return false end

    if msgKey and ply.thoughtmsgs[msgKey] then
        if isnumber(ply.thoughtmsgs[msgKey]) then
            if ply.thoughtmsgs[msgKey] > CurTime() then
                return false
            end
        else
            return false
        end
    end

    delay = delay or 0

    if msgKey then ply.thoughtmsgs[msgKey] = delay and (not isnumber(delay) or now + delay) or nil end
    if not blocked then
        ply.nextThoughtGlobal = now + THOUGHT_GLOBAL_GAP
        ply.recentThoughtText[msg] = now + 25
    end
    ply.thoughtGroupCooldowns[group] = now + (blocked and 0 or (group == "misc" or group == "emotion") and 3 or 6)

    showTime = showTime or 0
    local clr = clr or color_white
    local clr2 = Color(clr.r, clr.g, clr.b, 255)

    timer.Simple(showTime, function()
        if !IsValid(ply) then return end
        if !ply.thoughtmsgs[msgKey] then return end
        if ply:GetInfoNum("hg_newthoughts", 0) <= 0 then return end
        if (ply.organism and ply.organism.otrub) or !ply:Alive() or InDespair(ply) then return end
        if func and isfunction(func) and func(ply) then return end

        net.Start("HGThought")
        net.WriteString(msg)
        net.WriteColor(clr2)
        net.WriteString(group)
        net.Send(ply)
    end)

    return true
end

function hg.OtrubThought(ply, msg, clr)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if not ply.organism or not ply.organism.otrub then return false end

    clr = clr or color_white
    net.Start("HGThought")
    net.WriteString(msg)
    net.WriteColor(Color(clr.r, clr.g, clr.b, 255))
    net.WriteString(GetThoughtGroup(msg, msg))
    net.Send(ply)

    return true
end

local function CreateModeThought(ply, msg, delay, msgKey, showTime, clr, func)
    if ply:GetInfoNum("hg_newthoughts", 0) > 0 then
        local thought = msgKey and GetConditionThought(ply, msgKey, msg)
        if thought then msg = thought end
        return CreateThought(ply, msg, delay, msgKey, showTime, clr, func)
    end

    return CreateNotification(ply, LegacyThoughtText(msg), delay, msgKey, showTime, func, clr)
end

local despairThoughts = {
    "STOP STOP STOP HELP HELP IT HURTS WHY IM GONNA DIE IM GONNA DIE",
    "NO NO NO NO PLEASE IT HURTS IT HURTS HELP ME HELP ME",
    "AAAGH HELP HELP SOMEBODY HELP ME I'M DYING I'M DYING",
    "MAKE IT STOP MAKE IT STOP PLEASE GOD MAKE IT STOP",
    "OH GOD OH GOD IT HURTS SO MUCH I'M GONNA DIE I'M GONNA DIE",
    "PLEASE PLEASE PLEASE STOP IT HURTS WHY WHY WHY",
}

local dyingThoughts = {
    "I dont want to die... i dont want to die...",
    "Please... not like this... not yet...",
    "I dont want to die... please... I dont want to die...",
    "It's getting so cold... I dont want to go...",
    "I'm so scared... please... somebody...",
    "I'm not ready... I'm not ready yet...",
    "Why me... why does it have to end like this...",
}

local function SendThoughtClear(ply)
    net.Start("HGThought")
    net.WriteString("")
    net.WriteColor(color_white)
    net.WriteString("clear")
    net.Send(ply)
end

local function SendDespairLine(ply, msg, clr, group)
    if ply:GetInfoNum("hg_newthoughts", 0) > 0 then
        net.Start("HGThought")
        net.WriteString(msg)
        net.WriteColor(clr)
        net.WriteString(group)
    else
        net.Start("HGNotificate")
        net.WriteString(msg)
        net.WriteColor(clr)
        net.WriteUInt(110, 7)
    end
    net.Send(ply)
end

local function DespairActive(ply, id)
    if not IsValid(ply) or ply.despairId ~= id or not ply:Alive() then return false end
    return not (ply.organism and ply.organism.otrub)
end

local DESPAIR_DAMAGE_CHANCE = 0.25
local DESPAIR_ROLL_COOLDOWN = 45
local DESPAIR_BROKEN_REGIONS = 5
local despairLimbs = {"larm", "rarm", "lleg", "rleg"}

local function IsEverythingBroken(org)
    if not org then return false end

    local broken = 0
    for _, limb in ipairs(despairLimbs) do
        if org[limb .. "amputated"] or (hg.IsLimbFractured and hg.IsLimbFractured(org, limb)) then broken = broken + 1 end
    end

    if (org.chest or 0) >= 1 then broken = broken + 1 end
    if (org.pelvis or 0) >= 1 then broken = broken + 1 end
    if (org.skull or 0) >= 1 then broken = broken + 1 end

    local orgLib = hg.organism
    if (org.spine1 or 0) >= (orgLib.fake_spine1 or 1) or (org.spine2 or 0) >= (orgLib.fake_spine2 or 1) or (org.spine3 or 0) >= (orgLib.fake_spine3 or 1) then
        broken = broken + 1
    end

    return broken >= DESPAIR_BROKEN_REGIONS
end

function hg.DespairThought(ply, fromDamage)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end

    local org = ply.organism
    if org and org.otrub then return false end

    local now = CurTime()
    if (ply.despairNext or 0) > now then return false end

    if fromDamage and not IsEverythingBroken(org) then
        if (ply.despairRollNext or 0) > now then return false end
        ply.despairRollNext = now + DESPAIR_ROLL_COOLDOWN
        if math.Rand(0, 1) > DESPAIR_DAMAGE_CHANCE then return false end
    end

    ply.despairNext = now + 45

    if ply.HasTrait and ply:HasTrait("gurajchaka_child") then return false end
    if ply.PlayerClassName == "Gordon" then return false end
    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return false end

    ply.despairUntil = now + 14
    ply.despairId = (ply.despairId or 0) + 1
    local id = ply.despairId

    ply.msgs = {}
    ply.thoughtmsgs = {}
    if org then org.nextStatusThought = math.max(org.nextStatusThought or 0, now + 14) end

    SendThoughtClear(ply)
    SendDespairLine(ply, despairThoughts[math.random(#despairThoughts)], Color(255, 40, 40, 255), "despair")

    timer.Simple(5.2, function()
        if not DespairActive(ply, id) then return end
        SendDespairLine(ply, dyingThoughts[math.random(#dyingThoughts)], Color(215, 150, 150, 255), "dying")
    end)

    return true
end

local traumaThoughts = {
    "HOLY SHIT- EVERYTHING IS BROKEN- EVERYTHING IS BROKEN-",
    "OH FUCK- OH FUCK- EVERYTHING'S BROKEN-",
    "AAAGH- EVERYTHING HURTS- EVERYTHING HURTS-",
    "WHAT THE FUCK- I HEARD EVERYTHING CRACK-",
    "OH GOD- OH GOD- I'M ALL BROKEN- I'M ALL BROKEN-",
    "NO NO NO- EVERYTHING SNAPPED- EVERYTHING SNAPPED-",
    "FUCK- FUCK- I CAN'T- EVERYTHING'S BROKEN-",
}

function hg.TraumaThought(ply, followMsg, followClr)
    if not IsValid(ply) or not ply:IsPlayer() or not ply:Alive() then return false end
    if ply.organism and ply.organism.otrub then return false end
    if InDespair(ply) then return false end
    if ply.HasTrait and ply:HasTrait("gurajchaka_child") then return false end
    if ply.PlayerClassName == "Gordon" then return false end
    if ply:GetInfoNum("hg_showthoughts", 1) == 0 then return false end

    local now = CurTime()
    if (ply.traumaNext or 0) > now then return false end
    ply.traumaNext = now + 20
    ply.traumaThoughtUntil = now + 8
    ply.nextThoughtGlobal = now + 3.5
    ply.traumaId = (ply.traumaId or 0) + 1
    local id = ply.traumaId

    SendDespairLine(ply, traumaThoughts[math.random(#traumaThoughts)], Color(255, 60, 40, 255), "trauma")

    if followMsg then
        timer.Simple(3.5, function()
            if not IsValid(ply) or ply.traumaId ~= id or not ply:Alive() then return end
            if (ply.organism and ply.organism.otrub) or InDespair(ply) then return end
            ply.nextThoughtGlobal = CurTime() + 3
            SendDespairLine(ply, followMsg, followClr or Color(255, 210, 210), "skeletal")
        end)
    end

    return true
end

hg.CreateNotification = CreateNotification

hook.Add("Player Spawn","removeNotifications",function(ply)
    ply.despairUntil = nil
    ply.despairNext = nil
    ply.hgHeartstopThought = nil
    ply.msgs = {}
    ply.thoughtmsgs = {}
    ply.lastConditionThought = {}
    ply.thoughtGroupCooldowns = {}
    ply.recentThoughtText = {}
    ply.nextThoughtGlobal = 0
end)

hook.Add("HG_OnOtrub","removeNotifications",function(ply)
    ply.despairUntil = nil
    ply.msgs = {}
    ply.thoughtmsgs = {}
    ply.lastConditionThought = {}
    ply.thoughtGroupCooldowns = {}
    ply.recentThoughtText = {}
    ply.nextThoughtGlobal = 0
end)

hook.Add("Player_Death","removeNotifications",function(ply)
    ply.despairUntil = nil
    ply.msgs = {}
    ply.thoughtmsgs = {}
    ply.lastConditionThought = {}
    ply.thoughtGroupCooldowns = {}
    ply.recentThoughtText = {}
    ply.nextThoughtGlobal = 0
end)

local PLAYER = FindMetaTable("Player")

function PLAYER:Notify(...)
    if self.HasTrait and self:HasTrait("gurajchaka_child") then return end
    local msg, delay, msgKey, showTime, func, clr = ...
    if self:GetInfoNum("hg_newthoughts", 0) > 0 and msgKey and thoughtMessages[msgKey] then
        return CreateModeThought(self, msg, delay, msgKey, showTime, clr, func)
    end
    return CreateNotification(self, ...)
end

function PLAYER:NotifyBerserk(...)
    return CreateNotificationBerserk(self, ...)
end

function PLAYER:Thought(...)
    if self.HasTrait and self:HasTrait("gurajchaka_child") then return end
    return CreateModeThought(self, ...)
end

function PLAYER:InterruptThought(msg, clr)
    if self.HasTrait and self:HasTrait("gurajchaka_child") then return end
    if self.organism and self.organism.otrub then return end
    if InDespair(self) then return end
    clr = clr or color_white
    self.nextThoughtGlobal = CurTime() + 4
    if self:GetInfoNum("hg_newthoughts", 0) > 0 then
        net.Start("HGThought")
        net.WriteString(msg)
        net.WriteColor(Color(clr.r, clr.g, clr.b, 255))
        net.WriteString("faint")
        net.Send(self)
    else
        net.Start("HGNotificate")
        net.WriteString(LegacyThoughtText(msg))
        net.WriteColor(Color(clr.r, clr.g, clr.b, 255))
        net.WriteUInt(110, 7)
        net.Send(self)
    end
end

function PLAYER:ResetNotification(key)
    ResetNotification(self,key)
end

hook.Add("EntityTakeDamage", "SCPCB_HGThoughtDamage", function(target, dmginfo)
    if not dmginfo or dmginfo:GetDamage() <= 0 then return end

    local ply = SCPCBThoughtOwner(target)
    if not IsValid(ply) then return end
    if dmginfo:IsDamageType(DMG_FALL) or dmginfo:IsDamageType(DMG_CRUSH) then return end

    local dmgType = SCPCBThoughtDamageType(dmginfo, ply)
    if not dmgType then return end

    SCPCBHitThought(ply, target, dmgType, dmginfo:GetDamage(), nil, dmginfo)
end)

local BODY_SEGMENTS = {
	{"ValveBiped.Bip01_Head1", nil, "head"},
	{"ValveBiped.Bip01_Neck1", "ValveBiped.Bip01_Head1", "neck"},
	{"ValveBiped.Bip01_Spine2", "ValveBiped.Bip01_Spine4", "chest"},
	{"ValveBiped.Bip01_Spine", "ValveBiped.Bip01_Spine2", "stomach"},
	{"ValveBiped.Bip01_Pelvis", nil, "pelvis"},
	{"ValveBiped.Bip01_L_UpperArm", "ValveBiped.Bip01_L_Forearm", "left upper arm"},
	{"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_L_Hand", "left forearm"},
	{"ValveBiped.Bip01_L_Hand", nil, "left hand"},
	{"ValveBiped.Bip01_R_UpperArm", "ValveBiped.Bip01_R_Forearm", "right upper arm"},
	{"ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_R_Hand", "right forearm"},
	{"ValveBiped.Bip01_R_Hand", nil, "right hand"},
	{"ValveBiped.Bip01_L_Thigh", "ValveBiped.Bip01_L_Calf", "left thigh"},
	{"ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_L_Foot", "left shin"},
	{"ValveBiped.Bip01_L_Foot", "ValveBiped.Bip01_L_Toe0", "left foot"},
	{"ValveBiped.Bip01_R_Thigh", "ValveBiped.Bip01_R_Calf", "right thigh"},
	{"ValveBiped.Bip01_R_Calf", "ValveBiped.Bip01_R_Foot", "right shin"},
	{"ValveBiped.Bip01_R_Foot", "ValveBiped.Bip01_R_Toe0", "right foot"},
}
local NEAR_MISS_PARTS = {head = {"head", "forehead", "face"}, neck = {"neck", "throat"}}
local HIT_ORGAN_KEYS = {"heart", "liver", "flank", "gut", "trachea", "eyeL", "eyeR", "brainFrontal", "brainParietal", "brainTemporal", "brainOccipital"}
local HIT_LUNG_KEYS = {"lungsL", "lungsR"}
local HIT_BONES = {
	lleg_up = "left thigh", lleg_down = "left shin", rleg_up = "right thigh", rleg_down = "right shin",
	larm_up = "left upper arm", larm_down = "left forearm", rarm_up = "right upper arm", rarm_down = "right forearm",
	chest = "ribs", pelvis = "pelvis", spine1 = "spine", spine2 = "spine", spine3 = "neck", skull = "skull", jaw = "jaw",
}
local HIT_ARTERIES = {
	arteria = "You are bleeding from an artery in your neck.",
	aorta = "Your aorta is torn open.",
	larmartery = "You are bleeding from an artery in your left arm.",
	rarmartery = "You are bleeding from an artery in your right arm.",
	llegartery = "You are bleeding from an artery in your left leg.",
	rlegartery = "You are bleeding from an artery in your right leg.",
}
local HIT_REPORT_COLOR = Color(255, 110, 110)
local HIT_REPORT_COOLDOWN = 0.5
local NEAR_MISS_REACTION_CHANCE = 0.5
local NEAR_MISS_REACTIONS = {
	"Holy shit- I almost got shot...",
	"Fuck- that was way too close...",
	"Shit, shit- that almost hit me...",
	"Jesus- that was close...",
}

local function segmentDistanceSqr(point, a, b)
	if not b then return point:DistToSqr(a) end

	local ab = b - a
	local lengthSqr = ab:LengthSqr()
	if lengthSqr <= 0 then return point:DistToSqr(a) end

	local t = math.Clamp((point - a):Dot(ab) / lengthSqr, 0, 1)

	return point:DistToSqr(a + ab * t)
end

local function boneSegment(body, segment)
	local bone = body:LookupBone(segment[1])
	if not bone then return end

	local startPos = body:GetBonePosition(bone)
	local child = segment[2] and body:LookupBone(segment[2])
	local endPos = child and body:GetBonePosition(child) or nil

	return startPos, endPos
end

local function nearestBodyPart(body, point)
	local best, bestDist

	for _, segment in ipairs(BODY_SEGMENTS) do
		local startPos, endPos = boneSegment(body, segment)
		if startPos then
			local dist = segmentDistanceSqr(point, startPos, endPos)
			if not bestDist or dist < bestDist then best, bestDist = segment[3], dist end
		end
	end

	return best
end

local function nearestBodyPartToLine(body, src, dir, length)
	local best, bestDist

	for _, segment in ipairs(BODY_SEGMENTS) do
		local startPos, endPos = boneSegment(body, segment)
		if startPos then
			local samples = endPos and {startPos, (startPos + endPos) * 0.5, endPos} or {startPos}
			for _, sample in ipairs(samples) do
				local closest = src + dir * math.Clamp((sample - src):Dot(dir), 0, length)
				local dist = sample:DistToSqr(closest)
				if not bestDist or dist < bestDist then best, bestDist = segment[3], dist end
			end
		end
	end

	return best
end

local function snapshotOrganism(org)
	local snapshot = {time = CurTime(), organs = 0, bones = {}}

	for _, key in ipairs(HIT_ORGAN_KEYS) do
		snapshot.organs = snapshot.organs + (tonumber(org[key]) or 0)
	end
	for _, key in ipairs(HIT_LUNG_KEYS) do
		local lung = org[key]
		snapshot.organs = snapshot.organs + (istable(lung) and tonumber(lung[1]) or 0)
	end
	for key in pairs(HIT_BONES) do
		snapshot.bones[key] = tonumber(org[key]) or 0
	end

	snapshot.wounds = istable(org.wounds) and #org.wounds or 0
	snapshot.arterial = istable(org.arterialwounds) and #org.arterialwounds or 0

	return snapshot
end

local function sendHitReport(ply, key, msg)
	CreateThought(ply, msg, HIT_REPORT_COOLDOWN, "hgstatus_hit_" .. key, 0, HIT_REPORT_COLOR)
end

local function hitReportTarget(victim, ent)
	local ply = SCPCBThoughtOwner(victim)
	if not IsValid(ply) or ply:GetInfoNum("hg_newthoughts", 0) <= 0 then return end

	local org = (IsValid(ent) and ent.organism) or ply.organism
	if not org then return end

	return ply, org
end

hook.Add("PreHomigradDamage", "HGThoughtHitReport", function(victim, dmgInfo, hitgroup, ent)
	if not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end

	local ply, org = hitReportTarget(victim, ent)
	if not ply then return end

	org.hgHitSnapshot = snapshotOrganism(org)
end)

hook.Add("HomigradDamage", "HGThoughtHitReport", function(victim, dmgInfo, hitgroup, ent)
	if not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end

	local ply, org = hitReportTarget(victim, ent)
	if not ply then return end

	local before = org.hgHitSnapshot
	org.hgHitSnapshot = nil
	if not before or before.time ~= CurTime() then return end

	local after = snapshotOrganism(org)
	local newArteries = after.arterial > before.arterial
	local organHit = after.organs > before.organs + 0.001
	local fractures = {}

	for key, label in pairs(HIT_BONES) do
		if before.bones[key] < 1 and after.bones[key] >= 1 then fractures[#fractures + 1] = label end
	end

	local wounded = newArteries or after.wounds > before.wounds or organHit or #fractures > 0
	if not wounded then return end

	local body = IsValid(ent) and ent or hg.GetCurrentCharacter(ply)
	local part = IsValid(body) and nearestBodyPart(body, dmgInfo:GetDamagePosition())
	sendHitReport(ply, "location", part and "A bullet hit your " .. part .. "." or "A bullet hit you.")

	for _, label in ipairs(fractures) do
		sendHitReport(ply, "fracture_" .. label, label == "ribs" and "Your ribs are broken." or "Your " .. label .. " is broken.")
	end

	if organHit then sendHitReport(ply, "organ", "You have organ damage.") end

	if newArteries then
		local wound = org.arterialwounds[#org.arterialwounds]
		local name = istable(wound) and wound[7]
		sendHitReport(ply, "artery", HIT_ARTERIES[name] or "You are bleeding from an artery.")
	elseif after.wounds > before.wounds then
		sendHitReport(ply, "bleed", "You are bleeding.")
	end
end)

local BULLET_BURST_WINDOW = 0.75

local function flushBulletBurst(ply)
	local burst = ply.hgBulletBurst
	ply.hgBulletBurst = nil
	if not burst or not IsValid(ply) or not ply:Alive() then return end

	local passes, hits = burst.passes, burst.hits
	if passes + hits >= 2 then
		local pool = hits == 0 and "multi_pass" or passes == 0 and "multi_hit" or "multi_mixed"
		hg.CombatThought(ply, pool)

		return
	end

	if passes ~= 1 then return end

	local now = CurTime()
	if (ply.hgNearMissNext or 0) > now then return end

	if ply:GetInfoNum("hg_newthoughts", 0) > 0 then
		local part = burst.part or "head"
		local variants = NEAR_MISS_PARTS[part]
		if variants then part = variants[math.random(#variants)] end

		if not CreateThought(ply, "A bullet almost hit your " .. part .. ".", 6, "near_miss_report", 0, color_white) then return end

		if math.Rand(0, 1) < NEAR_MISS_REACTION_CHANCE then
			CreateThought(ply, NEAR_MISS_REACTIONS[math.random(#NEAR_MISS_REACTIONS)], 10, "hgstatus_near_miss_reaction", 0.6, color_white)
		end
	elseif not CreateNotification(ply, NEAR_MISS_REACTIONS[math.random(#NEAR_MISS_REACTIONS)], 10, "near_miss_reaction") then
		return
	end

	ply.hgNearMissNext = now + 6
end

local function registerBulletEvent(ply, kind, part)
	local burst = ply.hgBulletBurst
	if not burst then
		burst = {passes = 0, hits = 0}
		ply.hgBulletBurst = burst

		timer.Simple(BULLET_BURST_WINDOW, function()
			if IsValid(ply) then flushBulletBurst(ply) end
		end)
	end

	local now = CurTime()
	if kind == "hits" then
		if now - (burst.lastHit or -1) < 0.05 then return end
		burst.lastHit = now
	end

	burst[kind] = burst[kind] + 1
	if kind == "passes" and not burst.part then burst.part = part end
end

local function NearMissThought(ply, body, src, dir, length)
	registerBulletEvent(ply, "passes", nearestBodyPartToLine(body, src, dir, length))

	return true
end

hook.Add("PreHomigradDamage", "HGThoughtBulletBurst", function(victim, dmgInfo)
	if not dmgInfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) then return end

	local ply = SCPCBThoughtOwner(victim)
	if IsValid(ply) and ply:Alive() then registerBulletEvent(ply, "hits") end
end)

local function SCPCBCheckBulletNearMiss(entity, shooter, src, hitPos, hitEntity, reported)
	local dir = hitPos - src
	local length = dir:Length()
	if length <= 0 then return end
	dir:Normalize()
	local hitPly = SCPCBThoughtOwner(hitEntity)
	local now = CurTime()

	for _, ply in player.Iterator() do
		if not ply:Alive() or ply == shooter or ply == entity or ply == hitPly then continue end
		if (ply.scpcbThoughtHitTime or 0) >= now or (reported and reported[ply]) then continue end
		local body = hg.GetCurrentCharacter(ply)
		if not IsValid(body) then continue end
		local plyPos = body:IsPlayer() and body:GetPos() + Vector(0, 0, 50) or body:WorldSpaceCenter()
		local projection = math.Clamp((plyPos - src):Dot(dir), 0, length)
		local closestPoint = src + dir * projection

		if plyPos:DistToSqr(closestPoint) < 125 * 125 then
			if NearMissThought(ply, body, src, dir, length) and reported then
				reported[ply] = true
			end
		end
	end
end

hook.Add("HG.Plugin.List[PhysBullet].Hooks[BulletNearMiss]", "SCPCB_HGThoughtNearMiss", function(bullet, src, hitPos, hitEntity)
	bullet.scpcbNearMissPlayers = bullet.scpcbNearMissPlayers or {}
	SCPCBCheckBulletNearMiss(bullet.Inflictor, bullet.Shooter, src, hitPos, hitEntity, bullet.scpcbNearMissPlayers)
end)

hook.Add("EntityFireBullets", "SCPCB_HGThoughtNearMiss", function(entity, data)
    if not IsValid(entity) then return end
    if (data.limit_ricochet or 0) > 0 or (data.penetrated or 0) > 0 then return end

    local oldCallback = data.Callback
    local shooter = IsValid(data.Attacker) and data.Attacker or (entity.GetOwner and entity:GetOwner() or entity)

    data.Callback = function(attacker, tr, dmginfo)
        shooter = IsValid(attacker) and attacker or shooter
        local hitPly = SCPCBThoughtOwner(tr.Entity)
        local blocked = false

        if IsValid(hitPly) and hitPly != shooter then
            blocked = hg.TryExtinguisherBulletBlock and hg.TryExtinguisherBulletBlock(tr.Entity, dmginfo)
            SCPCBHitThought(hitPly, tr.Entity, "bullet", dmginfo:GetDamage(), tr.HitPos, dmginfo)
        end

        if not blocked then
            SCPCBCheckBulletNearMiss(entity, shooter, data.Src, tr.HitPos, tr.Entity)
        end

        if oldCallback then return oldCallback(attacker, tr, dmginfo) end
    end

end)
