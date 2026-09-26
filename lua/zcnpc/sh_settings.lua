--[[
	Every setting the addon has, in one list, described well enough that both
	halves of the mod can be built out of it: the server turns each entry into a
	convar (sv_config.lua) and the client turns the same entries into the Q menu
	panel (cl_menu.lua). Adding a setting is adding a line here.

	Nothing about Artagdoll is in this list on purpose. Handing it NPC bodies is
	either possible or it is not - there is no reason anybody would want it
	installed and switched off - so the bridge reads whether the addon is there
	and nothing else. Fatal Headshot and ArtAgdoll Player are held off in
	sv_artagdoll.lua, not exposed here.

	A handful of things are missing from the list for the same reason. Lethal head
	shots, a brain hit dropping whoever took it, a gun that stays in the hand it
	was in, amputations that survive standing up, a voice that comes out of the
	body it belongs to - every one of those is the addon working rather than a
	taste anybody holds, and the off position was only ever a way to break part of
	it by accident. They are simply how it behaves now, written into the code that
	used to ask.
]]

ZCNPC = ZCNPC or {}

--\\ Categories, in the order the menu shows them
ZCNPC.Categories = {
	{ id = "general", name = "General", icon = "icon16/cog.png" },
	{ id = "damage", name = "Damage", icon = "icon16/exclamation.png" },
	{ id = "head", name = "Head Shots", icon = "icon16/bomb.png" },
	{ id = "wounds", name = "Wounds & Status", icon = "icon16/heart_delete.png" },
	{ id = "impact", name = "Kicks & Impacts", icon = "icon16/arrow_down.png" },
	{ id = "downed", name = "Downed Bodies", icon = "icon16/user_gray.png" },
	{ id = "getup", name = "Waking Up", icon = "icon16/arrow_up.png" },
	{ id = "medical", name = "Medical & Cuffs", icon = "icon16/lock.png" },
	{ id = "hl2", name = "Half-Life 2", icon = "icon16/brick.png" },
	{ id = "compat", name = "Other Addons", icon = "icon16/plugin.png" },
}
--//

--\\ The settings
-- key      the field it lands on as ZCNPC.Config[key]
-- cvar     console variable name
-- type     "bool" or "float"
-- label    what the menu calls it
-- help     the tooltip, and the console variable's own description
local S = {
	--\\ General
	{ cat = "general", key = "enabled", cvar = "zcnpc_enabled", type = "bool", default = 1,
		label = "Enable addon",
		help = "Master switch for the Z-City NPC Overhaul" },
	{ cat = "general", key = "allnpcs", cvar = "zcnpc_allnpcs", type = "bool", default = 1,
		label = "All humanoid NPCs",
		help = "Give the organism to every living humanoid NPC, detected off its skeleton. Off means only the class list in sv_config.lua" },
	{ cat = "general", key = "names", cvar = "zcnpc_names", type = "bool", default = 1,
		label = "Names above NPCs",
		help = "Show Z-City style names above managed NPCs" },
	{ cat = "general", key = "debug", cvar = "zcnpc_debug", type = "bool", default = 0,
		label = "Debug output",
		help = "Print what the addon is doing to the server console" },
	{ cat = "general", key = "idle_patrol", cvar = "zcnpc_idle_patrol", type = "bool", default = 1,
		label = "Idle patrolling (iNPC)",
		help = "When iNPC Opti+ is installed, idle NPCs walk a patrol instead of standing still. Off forces iNPC's own Idle Patrolling switch off as well. Does nothing without iNPC" },
	{ cat = "general", key = "respect_scripts", cvar = "zcnpc_respect_scripts", type = "bool", default = 1,
		label = "Leave scripted NPCs alone",
		help = "Never take the schedule off an NPC the map is driving. Everything here that walks an NPC somewhere - fetching a dropped gun or a vest, crossing to a wounded ally, taking cover, patrolling - stands down for one that is playing a scripted sequence, waiting for its cue, or held by an ai_goal_ entity such as an assault rally point or a follow order. Off lets those chores outrank the mapper, which on a built map is a garrison that leaves its post and wanders at you" },
	{ cat = "general", key = "fury_npc_kills", cvar = "zcnpc_fury_npc_kills", type = "bool", default = 1,
		label = "Fury-13 counts NPC kills",
		help = "Fury-13's killstreak only ever added berserk for a player that died. On, an NPC that goes down the same way counts too: the number goes up, the notify fires, and the stim lasts. Off leaves the stock rule, players only. Does nothing without Fury-13" },

	--\\ Damage
	{ cat = "damage", key = "knockdown", cvar = "zcnpc_knockdown", type = "bool", default = 1,
		label = "Knockdowns",
		help = "Heavy hits knock NPCs off their feet, the same way they do players" },
	{ cat = "damage", key = "knockdown_force", cvar = "zcnpc_knockdown_force", type = "float", default = 7000, min = 500, max = 50000, decimals = 0,
		label = "Knockdown force",
		help = "Damage force needed for a knockdown. Same scale Z-City uses on players, where 7000 is the hard stun that actually puts one on the floor" },
	{ cat = "damage", key = "knockdown_bullets", cvar = "zcnpc_knockdown_bullets", type = "bool", default = 0,
		label = "Bullets can knock down",
		help = "Let plain gunfire floor an NPC on force alone. Off by default: getting shot in the chest hurts, it does not knock people over" },
	{ cat = "damage", key = "knockdown_time", cvar = "zcnpc_knockdown_time", type = "float", default = 3, min = 0.5, max = 60, decimals = 1,
		label = "Knockdown time",
		help = "Seconds a knocked down NPC stays on the ground. This is a stagger, not a knockout" },
	{ cat = "damage", key = "bullet_down", cvar = "zcnpc_bullet_down", type = "float", default = 2, min = 0, max = 10, decimals = 0,
		label = "Body hits that floor",
		help = "How many rounds into the chest or the stomach put an NPC on the ground. Rolled a round either side and per NPC, so two means one of them drops on the first, most on the second or the third, and armour that stopped the round is not a round that landed. 0 leaves being shot in the body as something to stay standing through. This is a knockdown, not a knockout: it is up again in Knockdown time unless the wounds are what keep it there" },
	{ cat = "damage", key = "bullet_ko", cvar = "zcnpc_bullet_ko", type = "bool", default = 1,
		label = "Pain can knock out",
		help = "Let the pain of being shot switch an NPC off where it stands. On by default: enough shock from gunfire can drop an NPC unconscious where it stands" },
	{ cat = "damage", key = "falldamage", cvar = "zcnpc_falldamage", type = "bool", default = 1,
		label = "Fall damage & ragdoll",
		help = "Fall damage for managed NPCs, and ragdoll on landing from a real drop (same idea as players LightStun above 600 speed). Native Z-City NPCs keep their own damage and only get the ragdoll half from us" },
	{ cat = "damage", key = "body_hp", cvar = "zcnpc_body_hp", type = "float", default = 100, min = 0, max = 1000, decimals = 0,
		label = "Body health",
		help = "How much damage a body lying on the ground takes before it gives up. 0 leaves the whole question to the organism" },
	{ cat = "damage", key = "body_maxspeed", cvar = "zcnpc_body_maxspeed", type = "float", default = 3000, min = 0, max = 10000, decimals = 0,
		label = "Body speed limit",
		help = "Speed limit for every bone of a body we manage, in units per second. 0 turns the limit off" },
	{ cat = "damage", key = "body_maxspin", cvar = "zcnpc_body_maxspin", type = "float", default = 1200, min = 0, max = 10000, decimals = 0,
		label = "Body spin limit",
		help = "Same thing for how fast a bone may rotate, in degrees per second. Artagdoll's head shot adds a flat 1500 of angular velocity to a head, which is what sends a body cartwheeling" },
	{ cat = "damage", key = "throat_cut", cvar = "zcnpc_throat_cut", type = "float", default = 0.5, min = 0, max = 1, decimals = 2,
		label = "Throat cut chance",
		help = "How readily a blade across an NPC's neck opens the artery rather than leaving a cut. On a hit it is this chance; a body on the floor or one that never saw it coming is twice as likely, up to certain. An opened throat is what it sounds like - the NPC cannot breathe, bleeds arterially and is dead in well under a minute unless somebody clamps it. 0 leaves knives doing plain neck damage" },
	{ cat = "damage", key = "throat_edge", cvar = "zcnpc_throat_edge", type = "float", default = 6, min = 1, max = 20, decimals = 0,
		label = "Throat cut reach",
		help = "How close to the neck bone a blade has to land to count as across the throat, in units. Larger is a more forgiving swing and a stab to the collar counting as a cut throat; smaller asks for the neck itself" },

	--\\ Head shots
	{ cat = "head", key = "instakill_head", cvar = "zcnpc_instakill_head", type = "bool", default = 1,
		label = "Forced insta-kill headshots",
		help = "A bullet into a bare head, or one that reached the brain, finishes that head. Off only holds Z-City's kinetic beheading until the brain is already gone — they still die, the head just stays on. Rubber / gas rounds and a helmet that stopped the shot are never lethal here" },
	{ cat = "head", key = "instakill_chest", cvar = "zcnpc_instakill_chest", type = "bool", default = 0,
		label = "Forced insta-kill chest shots",
		help = "A burst into the chest may force the brain dead the same way a head shot used to. Off leaves the torso to Z-City: blood, the heart, oxygen. Several weak rounds then hurt instead of ending the fight on the second or third" },
	{ cat = "head", key = "headshot_ko", cvar = "zcnpc_headshot_ko", type = "float", default = 0.35, min = 0, max = 1, decimals = 2,
		label = "Cracked skull knockout chance",
		help = "Chance that a hit which got into a head without killing outright knocks the NPC out anyway. This is the roll for a hit that only cracked the skull, which is what a helmet leaves of a head shot" },
	{ cat = "head", key = "headgib", cvar = "zcnpc_headgib", type = "bool", default = 1,
		label = "Heads can come off",
		help = "Enough kinetic damage to a head takes it off" },
	{ cat = "head", key = "headgib_damage", cvar = "zcnpc_headgib_damage", type = "float", default = 230, min = 10, max = 2000, decimals = 0,
		label = "Decapitation threshold",
		help = "How much head damage one shot has to stack up to blow the head off (player-scale; NPC's internal 3x bonus is divided back out). Default 230 is 2.3× Z-City's stock 100. Below this a head shot is still lethal, the head just stays on. Metrocops never lose the head" },
	{ cat = "head", key = "gib_threshold", cvar = "zcnpc_gib_threshold", type = "float", default = 150, min = 50, max = 2000, decimals = 0,
		label = "Limb gib threshold",
		help = "How much kinetic damage a limb has to stack up before it comes off. Z-City's stock line is 100, and NPCs get that stack tripled — default 150 is 1.5× so limbs last a bit longer without feeling armoured" },
	{ cat = "head", key = "gib_heavy_only", cvar = "zcnpc_gib_heavy_only", type = "bool", default = 1,
		label = "Heavy weapons only for gibs",
		help = "Limb and head gibs only from shotguns, carbines and sniper rifles — plus explosions, falls and crush. Pistols and SMGs can still kill - they just do not take pieces off" },
	{ cat = "head", key = "headfix", cvar = "zcnpc_headfix", type = "bool", default = 1,
		label = "Re-anchor the neck stump",
		help = "Hang Z-City's gore cap off the neck bone. Without this it sits on whatever attachment 3 happens to be on an NPC model, which is a hand on a combine soldier" },
	{ cat = "head", key = "headgib_drop", cvar = "zcnpc_headgib_drop", type = "float", default = 1, min = 0, max = 8, decimals = 1,
		label = "Neck stump height",
		help = "How far up the neck the gore cap sits, in units. Z-City's own five is measured on a player model and stands well clear of an NPC collar; one sits down in it" },
	{ cat = "head", key = "headshot_sound", cvar = "zcnpc_headshot_sound", type = "bool", default = 1,
		label = "Head shot sound",
		help = "Play the gore hit on every lethal head shot, so shooting a body in the head sounds like shooting anything else in the head. Z-City only ever voices the ones that take the head clean off" },
	{ cat = "head", key = "headcrab", cvar = "zcnpc_headcrab", type = "bool", default = 1,
		label = "Headcrabs latch onto NPCs",
		help = "A headcrab leap knocks a droppable helmet/mask off, or latches onto the NPC's head, knocks them out as Body with headcrab, and eats for about a minute before the host dies and the crab climbs off to hunt again. Metrocops take two leaps (first floors them), combine take three (second floors them). Players stay on Z-City's own headcrab code" },
	{ cat = "general", key = "weapon_pickup", cvar = "zcnpc_weapon_pickup", type = "bool", default = 1,
		label = "NPCs pick up weapons",
		help = "Standing NPCs that lost their gun walk over to a loose weapon on the ground and pick it up. Off leaves them hiding / keeping distance instead of fetching one" },
	{ cat = "general", key = "melee_pickup", cvar = "zcnpc_melee_pickup", type = "bool", default = 0,
		label = "NPCs pick up melee weapons",
		help = "Let an NPC take a knife, a stunstick or a crowbar off the ground. Off by default: an unarmed NPC that finds one stops looking for a gun and walks at whoever it is angry with holding it. What an NPC spawned with is a separate question and is left alone either way" },
	{ cat = "general", key = "weapon_upgrade", cvar = "zcnpc_weapon_upgrade", type = "bool", default = 1,
		label = "NPCs trade up for a better gun",
		help = "An NPC holding a pistol will walk over to a rifle, a shotgun or an SMG lying on the ground and swap, and one holding a stunstick or a crowbar will take any gun at all. Without this only an NPC with nothing whatever in its hands goes to fetch anything, which is a metrocop with a pistol standing next to the AR2 its squad mate just dropped. What counts as better is damage a second and magazine size, the same measure rebels rank a body's gun by. Its job has no say here: a shotgunner is issued a shotgun and one who has lost his keeps whatever he can find" },
	{ cat = "general", key = "wep_random", cvar = "zcnpc_wep_random", type = "bool", default = 1,
		label = "Randomised weapons",
		help = "For a group whose weapon list is empty, roll a gun out of everything installed instead of leaving the NPC with the one the map gave it. Filtered to what its job would carry, so a metrocop gets pistols and an elite gets rifles, and filtered to what a soldier actually carries: no machineguns, no rocket or grenade launchers, nothing explosive, no anti-materiel rifles, nothing an admin has to spawn, and nothing that is not a weapon - the game's NPC weapon list has Z-City's bandages and blood bags in it too. This is what an empty box means unless you have filled it in, because writing out which of four hundred installed guns each group may carry is not work anybody is going to do; a list you have filled in yourself always wins over it. It replaces and never issues: an NPC the spawner gave no gun to was left that way on purpose, so refugees and everybody else who turned up unarmed stay unarmed, a metrocop keeps the stunstick it was placed with, and arming any of them is a list in their own box. Off gives an empty box its older meaning: leave the NPC holding whatever the map or the spawn menu gave it" },
	{ cat = "general", key = "wep_roles", cvar = "zcnpc_wep_roles", type = "bool", default = 1,
		label = "Match the gun to the job",
		help = "Pick each NPC's gun from the ones in its group's list that suit what it was carrying: a shotgunner gets the shotguns, a soldier with an SMG gets the machine pistols and rifles, an elite with a pulse rifle gets the rifles. Off rolls the whole list for everybody, which is where a Combine shotgunner ends up with an AR2. A group whose list has nothing for a given job falls back to the whole list rather than to nothing" },
	{ cat = "general", key = "armor_pickup", cvar = "zcnpc_armor_pickup", type = "bool", default = 1,
		label = "NPCs pick up armour",
		help = "Standing NPCs walk over to loose Z-City armour on the ground and put it on, the same way they fetch a dropped gun. Empty slots are filled; a worn piece is swapped only when the floor piece has higher protection" },
	{ cat = "general", key = "armor_spawn", cvar = "zcnpc_armor_spawn", type = "bool", default = 1,
		label = "Spawn armour",
		help = "Let NPCs spawn wearing something. With an armour list filled in for their group that list is what they wear; with none, rebel / medic / hostile-rebel citizens get the built-in light helmet/vest kit, refugees stay unarmoured, and Combine and metrocops keep Z-City's own. Off means nothing is put on anybody at spawn" },
	{ cat = "general", key = "looting", cvar = "zcnpc_looting", type = "bool", default = 1,
		label = "Rebels search bodies",
		help = "Rebels walk to a nearby dead body and go through it, for a gun better than the one they are holding or for medicine they have already used up. Only rebels, and only when nothing hostile is close. Whatever they take is gone from the body a player would have searched" },

	--\\ Wounds & status
	{ cat = "wounds", key = "pain", cvar = "zcnpc_pain_reaction", type = "bool", default = 1,
		label = "Wound reactions",
		help = "A wounded NPC clutches the wound and flinches instead of taking bullets without a twitch" },
	{ cat = "wounds", key = "limbs", cvar = "zcnpc_limb_damage", type = "bool", default = 1,
		label = "Realistic limb damage",
		help = "Shooting a limb to pieces does what it would do to a person: a leg that has been shot through stops carrying weight and the NPC goes down on it" },
	{ cat = "wounds", key = "limb_threshold", cvar = "zcnpc_limb_threshold", type = "float", default = 0.45, min = 0.15, max = 1, decimals = 2,
		label = "Leg failure point",
		help = "How far gone a leg has to be before it gives out (knockdown + limp), on Z-City's own 0 to 1 bone scale. Standing up again only needs the hard Z-City break cleared — this soft line alone does not pin them to the floor forever" },
	{ cat = "wounds", key = "limb_mul", cvar = "zcnpc_limb_mul", type = "float", default = 1.0, min = 0.3, max = 6, decimals = 1,
		label = "Limb damage mul",
		help = "How hard bullets count against NPC arms and legs. Z-City's bone boxes are easy to miss on a standing NPC, so limb damage also accumulates from the hit location. About 1.0 needs roughly a dozen Makarov rounds into a thigh for the default failure point" },
	{ cat = "wounds", key = "status", cvar = "zcnpc_status_effects", type = "bool", default = 1,
		label = "Status effects",
		help = "Injuries leave something behind: a broken leg slows an NPC to a limp, a knock on the head ruins its aim" },
	{ cat = "wounds", key = "status_speed", cvar = "zcnpc_status_speed", type = "float", default = 0.55, min = 0.2, max = 1, decimals = 2,
		label = "Limp speed",
		help = "How fast an NPC moves on a broken leg, as a fraction of its normal speed" },
	{ cat = "wounds", key = "status_concussion", cvar = "zcnpc_status_concussion", type = "bool", default = 1,
		label = "Concussion",
		help = "A blow to the head or a blast nearby leaves an NPC shooting badly and slow to react, for as long as Z-City's disorientation lasts" },
	{ cat = "wounds", key = "woundedwalk", cvar = "zcnpc_woundedwalk", type = "bool", default = 1,
		label = "Wounded Walk bridge",
		help = "If Wounded Walk is installed, feed it organism injury (legs, bleed, blood, pain) instead of engine HP so its NPC slowdown matches Z-City wounds. Our own limp playback rate steps aside so the two do not stack. Wounded Walk itself is never modified" },
	{ cat = "wounds", key = "tranq", cvar = "zcnpc_tranq_ragdoll", type = "bool", default = 1,
		label = "Tranquilizer collapse",
		help = "A dart drops an NPC where it stands rather than letting it walk around until the drug finishes the job. It is awake on the floor first and asleep a few seconds later, the way being sedated actually goes" },
	{ cat = "wounds", key = "blood_mul", cvar = "zcnpc_blood_mul", type = "float", default = 0.6, min = 0, max = 1, decimals = 2,
		label = "NPC blood amount",
		help = "How much of Z-City's blood spray NPCs are allowed to spawn, as a fraction of full. Players are untouched. Lower this if arterial bleeding from many wounded NPCs tanks the framerate; 0.6 is still visible and cheaper than full spray" },
	{ cat = "wounds", key = "blood_decal", cvar = "zcnpc_blood_decal", type = "float", default = 1.0, min = 0.3, max = 1.1, decimals = 2,
		label = "Blood decal size",
		help = "How big each blood decal on the floor is drawn, as a fraction of the size Z-City gives it - so 1 is exactly Z-City's own and the number to go back to. A decal costs what it covers rather than what it is, so a firefight that has painted the room is paying for every pixel of it twice over; 0.6 is a floor that still reads as bloody for a good deal less. Unlike the amount above this is every decal rather than the NPC ones, because the size lives on the material and a material does not know who bled on it" },
	{ cat = "wounds", key = "organ_chance", cvar = "zcnpc_organ_chance", type = "float", default = 1, min = 0, max = 3, decimals = 2,
		label = "Organ hit chance",
		help = "How readily a blade or a bullet that already reached the torso also lands in an organ. 1 is Z-City's own hitboxes and nothing extra. Above 1 is a second roll on a chest or stomach hit, so a knife that would have only opened the wall of the belly can still find the liver. 0 leaves organs alone unless the trace itself named one" },
	{ cat = "wounds", key = "artery_chance", cvar = "zcnpc_artery_chance", type = "float", default = 1, min = 0, max = 3, decimals = 2,
		label = "Artery hit chance",
		help = "Same idea for arteries. 1 is the hitbox. Above 1 is a second roll on a neck, groin or inner-thigh hit so a slash that was close can still open one. 0 leaves arteries to the trace alone" },

	--\\ Kicks & impacts
	{ cat = "impact", key = "kick_ragdoll", cvar = "zcnpc_kick_ragdoll", type = "bool", default = 1,
		label = "Leg kicks knock down",
		help = "A kick (hg_kick) puts an NPC on the floor" },
	{ cat = "impact", key = "kick_force", cvar = "zcnpc_kick_force", type = "float", default = 120, min = 0, max = 1000, decimals = 0,
		label = "Kick force",
		help = "How hard a kick throws the body it floors, in units per second" },
	{ cat = "impact", key = "kick_downtime", cvar = "zcnpc_kick_downtime", type = "float", default = 4, min = 1, max = 60, decimals = 1,
		label = "Kick downtime",
		help = "Seconds a kicked NPC stays down before standing back up" },
	{ cat = "impact", key = "melee_headdown", cvar = "zcnpc_melee_headdown", type = "bool", default = 1,
		label = "Melee to the head floors",
		help = "A melee hit to the head drops the NPC on the spot. Knocked off its feet, not knocked out" },
	{ cat = "impact", key = "collide", cvar = "zcnpc_ragdoll_collide", type = "bool", default = 1,
		label = "Bodies collide with NPCs",
		help = "Z-City lays every body down in the weapon collision group, which the engine specifically excludes from touching NPCs, so bodies fall straight through them. This puts that collision back" },
	{ cat = "impact", key = "stomp", cvar = "zcnpc_stomp", type = "bool", default = 1,
		label = "Landing on an NPC floors it",
		help = "Come down on an NPC hard enough - jumping onto one while in a ragdoll, being thrown into one - and it goes down with you" },
	{ cat = "impact", key = "stomp_speed", cvar = "zcnpc_stomp_speed", type = "float", default = 300, min = 100, max = 1500, decimals = 0,
		label = "Landing speed needed",
		help = "How fast a body has to be travelling to take an NPC down with it, in units per second" },
	{ cat = "impact", key = "stomp_downtime", cvar = "zcnpc_stomp_downtime", type = "float", default = 4, min = 1, max = 60, decimals = 1,
		label = "Landing downtime",
		help = "Seconds an NPC that was landed on stays on the ground" },

	--\\ Downed bodies
	{ cat = "downed", key = "loot_downed", cvar = "zcnpc_loot_downed", type = "bool", default = 1,
		label = "Search living bodies",
		help = "Downed NPCs can be searched while they are still alive" },
	{ cat = "downed", key = "pulse_info", cvar = "zcnpc_pulse_info", type = "bool", default = 1,
		label = "Pulse check tells you more",
		help = "Add two lines under Z-City's own pulse check: whether anybody is home (Knocked out / Reaction present), and how many bones are broken (including No broken bones). Out cold is unconscious, not merely on the floor. Same grip, same hands — if Z-City did not check, nothing is added" },
	{ cat = "downed", key = "downed_fight", cvar = "zcnpc_downed_fight", type = "bool", default = 0,
		label = "Bodies fight back",
		help = "A body with somebody still awake in it goes on shooting and swinging from the floor. What comes out of it is not what it looks like: the rounds and the swings come from the hidden entity, standing where it collapsed, so what you see is a gun firing at you out of thin air over the body - which is why this is off. Out cold or dying, nothing fights either way" },
	{ cat = "downed", key = "armless", cvar = "zcnpc_armless", type = "bool", default = 1,
		label = "One arm, no rifle",
		help = "An NPC that loses the right arm drops whatever it was holding. One that loses the left arm cannot keep a two-handed rifle: it puts that down and, if there is a pistol in its kit, draws the pistol. Either way it cannot reload - a magazine change is two hands. Off leaves a one-armed soldier shooting a rifle that is hanging in the air where the hand used to be" },
	{ cat = "downed", key = "inventory_use", cvar = "zcnpc_inventory_use", type = "bool", default = 1,
		label = "NPCs use their own kit",
		help = "An NPC only throws, wears and spends what is actually in its inventory. A soldier whose kit rolled a molotov throws the molotov instead of a Combine grenade. Off leaves Half-Life 2 throwing its own frag no matter what is in the pockets" },
	{ cat = "downed", key = "hit_extend", cvar = "zcnpc_down_hit_extend", type = "float", default = 0.7, min = 0, max = 10, decimals = 1,
		label = "Hit extends downtime",
		help = "Seconds added to how long a downed NPC stays on the floor when it is shot or struck. Counted from the moment of the hit, so a body that was about to stand up is put back under" },
	{ cat = "downed", key = "bleed_extend", cvar = "zcnpc_down_bleed_extend", type = "float", default = 0.15, min = 0, max = 2, decimals = 2,
		label = "Bleed extends downtime",
		help = "Seconds added to downtime every monitor pass (~0.25s) while a downed NPC is still bleeding. 0.15 means an open wound keeps them pinned until the bleeding is stopped" },
	{ cat = "downed", key = "kick_extend", cvar = "zcnpc_down_kick_extend", type = "float", default = 1.3, min = 0, max = 10, decimals = 1,
		label = "Kick extends downtime",
		help = "Seconds a kick adds to downtime on a body that is already down. Separate from the first-kick knockdown timer" },

	--\\ Waking up
	{ cat = "getup", key = "wakeup", cvar = "zcnpc_wakeup", type = "bool", default = 1,
		label = "NPCs wake up",
		help = "Unconscious NPCs can come round and stand back up" },
	{ cat = "getup", key = "wakeup_time", cvar = "zcnpc_wakeup_time", type = "float", default = 8, min = 1, max = 300, decimals = 0,
		label = "Minimum time down",
		help = "Seconds an NPC stays down before it may wake up at all" },
	{ cat = "getup", key = "death_brain", cvar = "zcnpc_death_brain", type = "bool", default = 1,
		label = "Dead when the brain is",
		help = "A downed NPC dies when Z-City's organism says it has died, which is the same line a player dies on: a brain that has been without oxygen long enough. A stopped heart is then a stopped heart rather than a death sentence - the body reads as critical to everything that looks at it, medicine still works on it, and there are about two minutes to restart the heart and put blood back in before the brain goes. Off goes back to the timer below, which is where an NPC read as dead to us and as savable to 1nazuma's Medicine at the same time" },
	{ cat = "getup", key = "death_time", cvar = "zcnpc_death_time", type = "float", default = 45, min = 5, max = 600, decimals = 0,
		label = "Bleed-out time",
		help = "Seconds of cardiac arrest after which a downed NPC dies. Only read with the setting above off - when the brain is what decides, how long a body has is the organism's to say and this is not asked" },
	{ cat = "getup", key = "getup", cvar = "zcnpc_getup", type = "bool", default = 1,
		label = "Get up animation",
		help = "Play the motion captured get up instead of snapping an NPC upright" },
	{ cat = "getup", key = "getup_speed", cvar = "zcnpc_getup_speed", type = "float", default = 0.4, min = 0.2, max = 2, decimals = 2,
		label = "Get up speed",
		help = "How fast to replay the recording. The source clips are Left 4 Dead survivors bouncing back up mid horde, which reads as fast forward on someone who was just bleeding out. 1 is the recorded speed" },
	{ cat = "getup", key = "getup_time", cvar = "zcnpc_getup_time", type = "float", default = 1.3, min = 0, max = 5, decimals = 2,
		label = "Fixed get up length",
		help = "Length of the animation in seconds. 0 keeps the recording's own timing scaled by the speed above" },

	--\\ Medical & cuffs
	{ cat = "medical", key = "medical_standing", cvar = "zcnpc_medical_standing", type = "bool", default = 1,
		label = "Dressings stay on",
		help = "Keep bandages and tourniquets visible on an NPC that got treated and stood back up" },
	{ cat = "medical", key = "selfheal", cvar = "zcnpc_selfheal", type = "bool", default = 1,
		label = "NPCs heal themselves",
		help = "Wounded NPCs spend bandage / painkillers from their own loot kit on themselves. Painkillers are used on the spot; bandages, kits and anything that needs both hands wait until the fight is over and nothing hostile is nearby. Off leaves those items for players to loot or to use on them" },
	{ cat = "medical", key = "allyheal", cvar = "zcnpc_allyheal", type = "bool", default = 0, hidden = true,
		label = "Medic rebels heal allies",
		help = "Removed. Medic rebels no longer walk over to wrap a standing teammate" },
	{ cat = "medical", key = "med_items", cvar = "zcnpc_med_items", type = "bool", default = 1,
		label = "NPCs use the rest of the kit",
		help = "Not just the bandage and the pills. An NPC that is carrying a medkit uses the medkit, and one carrying a tourniquet ties it off - each item through its own code, so it treats exactly what it treats for a player and spends exactly what it spends. Which one comes out depends on what is wrong: the kit or a wrap for a wound, the tourniquet for a limb artery, adrenaline for a heart that has stopped, morphine for pain. Food, drink and the recreational half of the shelf are left alone. Off, an NPC goes back to spending only the two items it was ever given and carrying the rest around unused" },
	{ cat = "medical", key = "rescue", cvar = "zcnpc_rescue", type = "bool", default = 0, hidden = true,
		label = "NPCs drag the wounded out",
		help = "Removed. NPCs no longer drag or treat downed teammates" },
	{ cat = "medical", key = "rescue_medic", cvar = "zcnpc_rescue_medic", type = "bool", default = 0, hidden = true,
		label = "Only medics rescue",
		help = "Removed with teammate rescue" },
	{ cat = "medical", key = "rescue_range", cvar = "zcnpc_rescue_range", type = "float", default = 1000, min = 200, max = 3000, decimals = 0, hidden = true,
		label = "How far to a body",
		help = "Removed with teammate rescue" },
	{ cat = "medical", key = "cms", cvar = "zcnpc_cms", type = "bool", default = 1,
		label = "NPCs use the surgical kit",
		help = "If 1nazuma's Medicine is installed, an NPC carrying a CMS kit will stop and operate on itself: twelve seconds on the spot with the kit in its hands, and only when there is nothing hostile anywhere near it. It closes what the kit closes for a player - open wounds, limb arteries, shot-through arms and legs - and not the wounds the kit tells a player to find a surgeon for. Anything that interrupts it costs nothing but the wait before it tries again" },
	{ cat = "medical", key = "cms_loot", cvar = "zcnpc_cms_loot", type = "bool", default = 1,
		label = "Surgical kits in NPC loot",
		help = "Roll a CMS kit into NPC loot on top of whatever pool filled it - Z-City's own, Nazuma's, or a bridged pack. Does nothing unless 1nazuma's Medicine is installed" },
	{ cat = "medical", key = "cms_chance", cvar = "zcnpc_cms_chance", type = "float", default = 0.10, min = 0, max = 1, decimals = 2,
		label = "Surgical kit chance",
		help = "How often an NPC turns out to be carrying one. Rolled once per NPC and remembered, so a kit that fills in late does not get a second go at it" },
	{ cat = "medical", key = "cuffs", cvar = "zcnpc_cuffs", type = "bool", default = 1,
		label = "Handcuffs work on NPCs",
		help = "Handcuffs work on NPCs" },
	{ cat = "medical", key = "cuffs_standing", cvar = "zcnpc_cuffs_standing", type = "bool", default = 1,
		label = "Cuff NPCs on their feet",
		help = "Handcuffs also work on an NPC that is still standing" },
	{ cat = "medical", key = "cuffs_pose", cvar = "zcnpc_cuffs_pose", type = "bool", default = 1,
		label = "Hands behind the back",
		help = "Put a cuffed NPC's hands behind its back" },

	--\\ Half-Life 2
	{ cat = "hl2", key = "hl2_shrapnel", cvar = "zcnpc_hl2_shrapnel", type = "bool", default = 1,
		label = "Mines and bombs throw fragments",
		help = "Combine mines and helicopter bombs spray metal debris when they go off, the way Z-City's own grenades do, instead of being a pressure wave and nothing else" },
	{ cat = "hl2", key = "hl2_flechettes", cvar = "zcnpc_hl2_flechettes", type = "bool", default = 1,
		label = "Hunter flechettes wound",
		help = "Hunter darts leave a stab wound where they land and an explosion wound where they go off. Off leaves them as DMG_DISSOLVE, which the organism ignores completely - the darts then only take engine health" },
	{ cat = "hl2", key = "hl2_flechette_hit", cvar = "zcnpc_hl2_flechette_hit", type = "float", default = 18, min = 1, max = 100, decimals = 0,
		label = "Flechette hit",
		help = "Damage for the dart itself, dealt as a stab wound. Half-Life 2's own number is 4, which is why an unmodified hunter can empty a burst into somebody and barely mark them" },
	{ cat = "hl2", key = "hl2_flechette_blast", cvar = "zcnpc_hl2_flechette_blast", type = "float", default = 25, min = 1, max = 150, decimals = 0,
		label = "Flechette detonation",
		help = "Damage for the small explosion a dart makes a second after it lands, dealt as a blast" },
	{ cat = "hl2", key = "hl2_rollermines", cvar = "zcnpc_hl2_rollermines", type = "bool", default = 1,
		label = "Rollermines hurt",
		help = "A rollermine's shock only ever reaches a player or an NPC still on its feet, and even then it is worth single figures the organism divides to nothing. Off, a mine can roll over everybody on the map forever without doing anything at all" },
	{ cat = "hl2", key = "hl2_rollermine_pain", cvar = "zcnpc_hl2_rollermine_pain", type = "float", default = 12, min = 0, max = 60, decimals = 0,
		label = "Rollermine shock",
		help = "Pain per shock, standing or on the floor. Half-Life 2's own number is small enough that the organism reads it as nothing at all. The convulsions and the sound are the taser's" },
	{ cat = "hl2", key = "hl2_rollermine_stun", cvar = "zcnpc_hl2_rollermine_stun", type = "float", default = 3, min = 0, max = 15, decimals = 1,
		label = "Rollermine knockdown",
		help = "Seconds a shock keeps you on the floor, the same hold a taser uses. 0 shocks without knocking anybody down. A body already down is always held for the length of the current so it does not stand up mid jolt" },
	{ cat = "hl2", key = "hl2_barnacles", cvar = "zcnpc_hl2_barnacles", type = "bool", default = 1,
		label = "Barnacles can eat you",
		help = "A barnacle's bite is dealt as DMG_CRUSH, which the organism drops on sight, so without this one holds you in its tongue and chews forever without ever hurting you. On, the bite is the tearing wound it looks like" },
	{ cat = "hl2", key = "hl2_barnacle_bite", cvar = "zcnpc_hl2_barnacle_bite", type = "float", default = 22, min = 1, max = 150, decimals = 0,
		label = "Barnacle bite",
		help = "Damage for one bite. Half-Life 2 chews a player for 15 and takes everything an NPC has left in one go; here both are worth the same and the organism decides how many it takes" },

	--\\ Other addons
	-- Each of these does nothing at all unless the addon it names is installed,
	-- so the off position is not "do without it" - it is "leave that addon exactly
	-- as it came", which is the only reason anybody would want one.
	{ cat = "compat", key = "cai", cvar = "zcnpc_cai", type = "bool", default = 1,
		label = "Combat Intelligence AI bridge",
		help = "Teach Combat Intelligence AI what a downed body is, and who is on whose side. CAI decides who is worth shooting on health alone and never learned to read the engine's stop-looking-at-this flag, so a knocked out NPC stays on its books as a live enemy that has gone quiet - which is what suppressing fire is for, and why they keep putting rounds into a corpse. Its squads are the other half: it groups NPCs by the faction their class is listed under, and every citizen there is - refugee, rebel, and a rebel somebody spawned hostile - is one faction to it, so two of them standing near each other are put in a squad together and told to like each other at the highest priority there is. That is the whole of 'hostile rebels walk straight past civilians': the hostility is overwritten by the join and CAI then deletes them out of each other's memory for being friendly. On, a body that is finished with is forgotten by every NPC CAI is running, nobody is squadded with somebody it is at war with, and NPCs the addon has sent to fetch a gun or search a body keep their feet until they are done. Does nothing without Combat Intelligence AI" },
	{ cat = "compat", key = "reasfx", cvar = "zcnpc_reasfx", type = "bool", default = 1,
		label = "ReaSFX bridge",
		help = "Give downed bodies ReaSFX's voice. A body this addon lays down is deliberately kept out of ReAgdoll's death handling so it can get back up again, and the cost was that the one who did not get back up died in silence. On, a body that bleeds out screams, a limb coming off cracks, and a body that sits back up stops mid-rattle instead of finishing it. Respects ReAgdoll's own sound switches. Does nothing without ReaSFX" },
	{ cat = "compat", key = "manhunt", cvar = "zcnpc_manhunt", type = "bool", default = 1,
		label = "[Z-City] Manhunt Executions",
		help = "Keep this addon's wounds on a body that is being executed. Without it the execution addon builds a fresh prop_ragdoll, plays the animation on that, then deletes the NPC and leaves a generic corpse with none of the cuts that just happened. On, the same organism stays on the body you are looking at. Does nothing without fuzyaker's Manhunt Executions" },
	{ cat = "compat", key = "manhunt_kill", cvar = "zcnpc_manhunt_kill", type = "bool", default = 1,
		label = "Manhunt executions kill",
		help = "The execution's last hit finishes the NPC. Off, the animation still plays and the body takes one to five stab wounds instead of the 1000-damage finish. The head stays on and they stay a downed person, not a corpse. They can still bleed out afterwards. Does nothing without fuzyaker's Manhunt Executions" },
	{ cat = "compat", key = "eeer", cvar = "zcnpc_eeer", type = "bool", default = 1,
		label = "EEER / ragdoll expressions",
		help = "Tell EEER that a body this addon laid down came from an NPC, so pain expressions, death stiffness and the rest still run on it. A ragdoll we spawn by hand is not an engine death ragdoll, and EEER's NPC-only filter would otherwise skip it. Does nothing without EEER" },
}

ZCNPC.Settings = S

ZCNPC.SettingByCvar = {}
for _, setting in ipairs(S) do ZCNPC.SettingByCvar[setting.cvar] = setting end

function ZCNPC.SettingsIn(category)
	local out = {}

	for _, setting in ipairs(S) do
		if setting.cat == category and not setting.hidden then
			out[#out + 1] = setting
		end
	end

	return out
end
--//

--\\ The client's own copy of every server convar
-- FCVAR_REPLICATED does not hand a client a convar it does not have. It enforces the
-- server's value on one of the same name that already exists on that client
-- (Enums/FCVAR), and if there is none there is nothing to enforce it on: GetConVar
-- answers nil and every reader on that side sees a server with no settings at all.
-- Made on the server alone, which is what this was, it works perfectly on a listen
-- server - both realms are one process and read the same convar - and not at all on a
-- dedicated one, so the fault lived exactly where nobody testing at home could see it.
--
-- No FCVAR_ARCHIVE on this side, deliberately: an archived replicated convar is read
-- back out of the client's own config when it connects and can sit there holding a
-- value the server has since stopped sending (garrysmod-issues #3323). The server's
-- copy keeps it, because the server's is the one worth saving.
function ZCNPC.MirrorCvar(name, default)
	if ConVarExists(name) then return GetConVar(name) end

	return CreateConVar(name, default, FCVAR_REPLICATED, "Set by the server. Read only from here")
end

-- Convars the server keeps for the menu to read rather than for anybody to set: zero
-- is "no", and the numbers above it are in the help text of each. Made in
-- sv_config.lua, named here because the client needs a copy of each of them too, and
-- defaulting to zero on both sides - the server says what it is by setting it, so what
-- a client reads is never a default that was never sent.
ZCNPC.ServerCvars = {
	"zcnpc_loaded",
	"zcnpc_bridge_artagdoll",
	"zcnpc_bridge_reagdoll",
	"zcnpc_bridge_manhunt",
	"zcnpc_bridge_eeer",
}

if CLIENT then
	for _, setting in ipairs(S) do
		ZCNPC.MirrorCvar(setting.cvar, tostring(setting.default))
	end

	for _, name in ipairs(ZCNPC.ServerCvars) do
		ZCNPC.MirrorCvar(name, "0")
	end
end
--//

--\\ Presets
-- Normal is the defaults above, so it is written as an empty table rather than a
-- copy of them: anything a preset does not name goes back to its default, which
-- keeps the three of them honest about what they actually change.
ZCNPC.Presets = {
	{
		id = "normal",
		name = "Normal",
		desc = "The defaults. NPCs go down to the things that would put a person down and get back up from the things a person gets back up from.",
		values = {},
	},
	{
		id = "realistic",
		name = "Realistic",
		desc = "One round in the wrong place ends it. Bodies stay where they fall for a long time, wounds decide what a body can still do, and nobody shrugs off a rifle.",
		values = {
			zcnpc_headshot_ko = 0.6,
			zcnpc_headgib_damage = 184,
			zcnpc_gib_threshold = 120,
			zcnpc_knockdown_force = 6000,
			zcnpc_knockdown_time = 4,
			zcnpc_body_hp = 70,
			zcnpc_wakeup_time = 25,
			-- Read only by somebody who has turned the brain rule off, and left at
			-- seventy for them: this preset's answer to how long a body has is the
			-- organism's, which is what the brain rule already is.
			zcnpc_death_time = 70,
			zcnpc_getup_speed = 0.3,
			zcnpc_kick_force = 100,
			zcnpc_kick_downtime = 6,
			zcnpc_stomp_speed = 260,
			zcnpc_stomp_downtime = 6,
			zcnpc_limb_threshold = 0.35,
			zcnpc_limb_mul = 1.2,
			zcnpc_status_speed = 0.4,
			zcnpc_bullet_down = 1,
			zcnpc_organ_chance = 1.4,
			zcnpc_artery_chance = 1.35,
		},
	},
	{
		id = "fun",
		name = "Fun",
		desc = "Everything is loud and everything moves. Bodies fly, heads come off easily, and an NPC that goes down is back up before you have walked past it.",
		values = {
			zcnpc_knockdown_bullets = 1,
			zcnpc_knockdown_force = 3000,
			zcnpc_knockdown_time = 2,
			zcnpc_bullet_ko = 1,
			zcnpc_headshot_ko = 1,
			zcnpc_headgib_damage = 127,
			zcnpc_gib_threshold = 83,
			zcnpc_body_hp = 150,
			zcnpc_body_maxspeed = 1600,
			zcnpc_body_maxspin = 2200,
			zcnpc_wakeup_time = 4,
			-- The one preset that goes back to a clock. Waiting out two minutes of
			-- somebody else's cardiac arrest is the opposite of what this preset is
			-- for, and thirty seconds only means anything with the brain rule off.
			zcnpc_death_brain = 0,
			zcnpc_death_time = 30,
			zcnpc_getup_speed = 0.8,
			zcnpc_kick_force = 380,
			zcnpc_kick_downtime = 3,
			zcnpc_stomp_speed = 200,
			zcnpc_stomp_downtime = 3,
			zcnpc_limb_threshold = 0.7,
			zcnpc_limb_mul = 0.7,
			zcnpc_status_speed = 0.75,
			zcnpc_bullet_down = 3,
			zcnpc_gib_heavy_only = 0,
			zcnpc_instakill_head = 1,
			zcnpc_organ_chance = 1.6,
			zcnpc_artery_chance = 1.5,
		},
	},
}

function ZCNPC.GetPreset(id)
	for _, preset in ipairs(ZCNPC.Presets) do
		if preset.id == id then return preset end
	end
end

-- What a preset actually means, with every setting it does not mention filled in
-- from the defaults. Reading a preset back out of the convars is what tells the
-- menu which one is currently loaded, and it can only do that against a complete
-- list.
function ZCNPC.PresetValues(preset)
	local values = {}

	for _, setting in ipairs(S) do
		values[setting.cvar] = preset.values[setting.cvar] or setting.default
	end

	return values
end
--//
